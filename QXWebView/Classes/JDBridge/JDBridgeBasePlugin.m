//
//  JDBridgeBasePlugin.m
/*
 MIT License

Copyright (c) 2022 JD.com, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

#import "JDBridgeBasePlugin.h"
#import "JDBridgePluginUtils.h"
#import "JDBridgeBasePluginPrivate.h"
#import <WebKit/WebKit.h>
#import "JDWebViewContainer.h"


@interface JDBridgeCallBack()

@property(nonatomic, weak)WKWebView                     *webview;
/// success block
@property(nonatomic, copy)SuccessCallback               onSuccess;

/// success block with progress
@property(nonatomic, copy)SuccessProgressCallback       onSuccessProgress;

/// fail block, return an error
@property(nonatomic, copy)ErrorCallBack                 onFail;

@end

@implementation JDBridgeCallBack

+ (JDBridgeCallBack *)callback{
    return [JDBridgeCallBack new];
}

- (void)setMessage:(WKScriptMessage *)message{
    _message = message;
    _webview = message.webView;
    __weak JDBridgeCallBack *weakSelf = self;
    self.onSuccess = ^(id arg) {
        __strong __typeof(weakSelf) self = weakSelf;
        [self flushMessageClassMethodWithParams:arg progress:-1.0 isFailure:NO];
    };
    self.onFail = ^(id arg) {
        __strong __typeof(weakSelf) self = weakSelf;
        [self flushMessageClassMethodWithParams:arg progress:-1.0 isFailure:YES];
    };

    self.onSuccessProgress = ^(id  _Nonnull arg, float progress) {
        __strong __typeof(weakSelf) self = weakSelf;
        [self flushMessageClassMethodWithParams:arg progress:progress isFailure:NO];
    };

}

/// 把业务任意 key/value 透传到 errorBody,跳过 Cocoa 系统 key 和已内置字段
static inline void QX_MergeExtraFieldsIntoErrorBody(NSDictionary *source, NSMutableDictionary *errorBody) {
    if (![source isKindOfClass:[NSDictionary class]]) { return; }
    [source enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if (![key isKindOfClass:[NSString class]]) { return; }
        NSString *k = (NSString *)key;
        // 跳过 NSError 系统 key(NSLocalizedDescriptionKey / NSUnderlyingErrorKey 等)
        if ([k hasPrefix:@"NS"]) { return; }
        // 跳过已经单独处理的内置字段
        if ([k isEqualToString:@"code"] ||
            [k isEqualToString:@"message"] ||
            [k isEqualToString:@"success"]) { return; }
        // 值必须能被 JSON 序列化,避免整体序列化失败
        if ([NSJSONSerialization isValidJSONObject:@[value]]) {
            errorBody[k] = value;
        }
    }];
}

- (void)flushMessageClassMethodWithParams:(id)data
                                 progress:(float)progress
                                isFailure:(BOOL)isFailure {
    NSDictionary *body = self.message.body;
    if (![JDBridgePluginUtils validateDictionary:body]) {
        body = [JDBridgePluginUtils jsonStrToDictionary:(NSString *)body];
    }
    if (![JDBridgePluginUtils validateDictionary:body]) {
        return;
    }

    NSString *callbackName = body[KJDBridgeCallbackName]?:@"window.JDBridge && window.JDBridge._handleResponseFromNative && window.JDBridge._handleResponseFromNative";
    NSString *callbackId = body[KJDBridgeCallbackId];

    NSString *status = @"0";
    id msg = @"";

    NSMutableDictionary *callbackParams = [NSMutableDictionary dictionary];

    if (isFailure) {
        // 统一失败下发:对齐 Android,H5 从 err.msg 拿到 {code, message, success, ...业务扩展字段}
        NSMutableDictionary *errorBody = [NSMutableDictionary dictionary];
        NSString *messageStr = @"";
        NSInteger codeNum = -1;

        if ([data isKindOfClass:[NSError class]]) {
            NSError *error = (NSError *)data;
            codeNum = error.code;
            messageStr = [error.userInfo[@"message"] isKindOfClass:[NSString class]]
                ? error.userInfo[@"message"]
                : (error.localizedDescription ?: @"");
            QX_MergeExtraFieldsIntoErrorBody(error.userInfo, errorBody);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            // 业务可直接 callback.onFail(@{@"code":@1001, @"message":@"xx", @"业务字段":@"yy"})
            NSDictionary *dict = (NSDictionary *)data;
            id codeVal = dict[@"code"];
            if ([codeVal respondsToSelector:@selector(integerValue)]) {
                codeNum = [codeVal integerValue];
            }
            if ([dict[@"message"] isKindOfClass:[NSString class]]) {
                messageStr = dict[@"message"];
            }
            QX_MergeExtraFieldsIntoErrorBody(dict, errorBody);
        } else if ([data isKindOfClass:[NSString class]]) {
            // 兜底:onFail(@"xxx失败")
            messageStr = (NSString *)data;
        }

        // 走到失败分支时 code 不能为 0,否则 H5 JDBridge 会把 status=0 误判为成功,
        // 业务若漏传 code 或传了无法解析的字符串,统一归一为 -1。
        if (codeNum == 0) { codeNum = -1; }
        status = [NSString stringWithFormat:@"%ld", (long)codeNum];
        errorBody[@"code"] = @(codeNum);
        errorBody[@"message"] = messageStr ?: @"";
        errorBody[@"success"] = @NO;

        msg = [NSJSONSerialization isValidJSONObject:errorBody] ? (id)errorBody : (id)(messageStr ?: @"");
    } else {
        if ([data isKindOfClass:[NSNumber class]]) {
            callbackParams[KJDBridgeData] = [NSString stringWithFormat:@"%@",data];
        }  else {
            callbackParams[KJDBridgeData] = data; //we will check the callbackParams valid later.
        }
    }

    callbackParams[KJDBridgeStatus] = status?:@"";
    callbackParams[KJDBridgeMsg] = msg ?: @"";
    callbackParams[KJDBridgeCallbackId] = callbackId?:@"";
    if (progress>=0.0) {
        if (progress > 0.999999 && progress < 1.000001) {
            callbackParams[KJDBridgeComplete] = @(YES);
        }
        else{
            callbackParams[KJDBridgeComplete] = @(NO);
        }
        callbackParams[KJDBridgeProgress] = @(progress);
    }
    [self flushData:callbackParams callBackName:callbackName];
}


- (void)flushData:(NSDictionary *)callBackParams callBackName:(NSString *)callBackName{
    if (![NSJSONSerialization isValidJSONObject:callBackParams]) {
        callBackParams = @{KJDBridgeStatus : @(-1), KJDBridgeData : @"", KJDBridgeMsg : @"invalid json object"};
    }
    NSString *callBackString = [NSString stringWithFormat:@"%@(\'%@\')", callBackName, [JDBridgePluginUtils serializeMessage:callBackParams]];
    [self flushMessage:callBackString];
}

- (void)flushMessage:(NSString *)message{
    if (self.webview) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.webview evaluateJavaScript:message completionHandler:^(id  _Nullable obj, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"%@",error.description);
                }
            }];
        });
    }
}

#pragma mark --- return webview controller

- (UIViewController *)webViewController{
    id vc = self.webview;
    while (vc && ![vc isKindOfClass:[UIViewController class]]) {
        vc = [vc nextResponder];
    }
    return [vc isKindOfClass:[UIViewController class]]? vc : nil;
}


@end

@interface JDBridgeBasePlugin()

@end

@implementation JDBridgeBasePlugin

- (BOOL)excute:(NSString *)action
        params:(NSDictionary *)params
      callback:(JDBridgeCallBack *)jsBridgeCallback{
    NSLog(@"subclass should impl");
    return NO;
}

- (BOOL)inValidBridgeCallBack:(JDBridgeCallBack *)jsBridgeCallback message:(NSString *)description{
    if (jsBridgeCallback.onFail) {
        jsBridgeCallback.onFail([NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:-2
                                                userInfo:@{
                                       NSLocalizedDescriptionKey:description?:@""
                               }]);
    }
    return NO;
}


@end
