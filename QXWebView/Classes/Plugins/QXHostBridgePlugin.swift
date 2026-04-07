//
//  QXHostBridgePlugin.swift
//  QXWebView
//
//  用于 H5 调用宿主 APP 功能的 Bridge Plugin
//

import UIKit
import Foundation

@objc(QXHostBridgePlugin)
public class QXHostBridgePlugin: JDBridgeBasePlugin {
    
    private func hostDelegate(for callback: JDBridgeCallBack) -> QXWebViewHostDelegate? {
        if let viewController = callback.webViewController as? QXWebViewController {
            return viewController.hostDelegate
        }
        if let viewController = callback.findWebViewController() {
            return viewController.hostDelegate
        }
        return nil
    }
    
    public override func excute(_ action: String, params: [AnyHashable : Any]?, callback: JDBridgeCallBack) -> Bool {
        guard let params = params as? [String: Any] else {
            callbackError(message: "参数错误", callback: callback)
            return true
        }
        if action == "openPage" {
            openPage(params, callback: callback)
        } else {
            callCustomMethod(action, params: params, callback: callback)
        }
        
        return true
    }
    
    private func openPage(_ params: [String: Any], callback: JDBridgeCallBack) {
        guard let url = params["url"] as? String else {
            callbackError(message: "缺少 url", callback: callback)
            return
        }
        let pageParams = params["params"] as? [String: Any]
        if let delegate = hostDelegate(for: callback) {
            delegate.webViewRequestOpenPage?(url: url, params: pageParams) { [weak self] result in
                self?.callbackSuccess(data: result ?? ["success": true], callback: callback)
            }
        } else {
            callbackError(message: "宿主 APP 未实现 delegate 或未设置 hostDelegate", callback: callback)
        }
    }
    
    private func callCustomMethod(_ methodName: String, params: [String: Any], callback: JDBridgeCallBack) {
        if let delegate = hostDelegate(for: callback) {
            delegate.webViewRequestCustomMethod?(methodName: methodName, params: params) { [weak self] result in
                self?.callbackSuccess(data: result ?? ["success": true], callback: callback)
            }
        } else {
            callbackError(message: "宿主 APP 未实现 delegate 或未设置 hostDelegate", callback: callback)
        }
    }
    
    private func callbackSuccess(data: Any, callback: JDBridgeCallBack) {
        callback.onSuccess(data)
    }
    
    private func callbackError(message: String, callback: JDBridgeCallBack) {
        let error = NSError(domain: "QXHostBridgePlugin", 
                           code: -1, 
                           userInfo: [NSLocalizedDescriptionKey: message])
        callback.onFail(error)
    }
}
