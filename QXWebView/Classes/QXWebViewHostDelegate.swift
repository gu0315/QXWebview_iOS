//
//  QXWebViewHostDelegate.swift
//  QXWebView
//
//  SDK 对外暴露的协议，宿主 APP 需要实现此协议来处理 SDK 的回调
//

import UIKit

/// SDK 回调宿主 APP 的协议
@objc public protocol QXWebViewHostDelegate: AnyObject {
    
    /// SDK 请求打开宿主 APP 的页面
    /// - Parameters:
    ///   - url: 页面名称/路由
    ///   - params: 参数
    ///   - completion: 执行结果回调
    @objc optional func webViewRequestOpenPage(url: String, 
                                               params: [String: Any]?, 
                                               completion: @escaping (Any?) -> Void)

    /// SDK 请求打开宿主 APP 的页面（增强版，携带来源 WebViewController）
    /// 仅作为增量能力开放，未实现时会自动回退到旧方法。
    @objc optional func webViewRequestOpenPage(webViewController: QXWebViewController,
                                               url: String,
                                               params: [String: Any]?,
                                               completion: @escaping (Any?) -> Void)
    
    /// SDK 请求调用宿主 APP 的自定义方法
    /// - Parameters:
    ///   - methodName: 方法名
    ///   - params: 参数
    ///   - completion: 执行结果回调
    @objc optional func webViewRequestCustomMethod(methodName: String, 
                                                   params: [String: Any]?, 
                                                   completion: @escaping (Any?) -> Void)

    /// SDK 请求调用宿主 APP 的自定义方法（增强版，携带来源 WebViewController）
    /// 仅作为增量能力开放，未实现时会自动回退到旧方法。
    @objc optional func webViewRequestCustomMethod(webViewController: QXWebViewController,
                                                   methodName: String,
                                                   params: [String: Any]?,
                                                   completion: @escaping (Any?) -> Void)
}
