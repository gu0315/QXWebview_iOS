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
    
    private var currentCallback: JDBridgeCallBack?
    
    private var hostDelegate: QXWebViewHostDelegate? {
        guard let viewController = currentCallback?.webViewController as? QXWebViewController else {
            return nil
        }
        return viewController.hostDelegate
    }
    
    public override func excute(_ action: String, params: [AnyHashable : Any]?, callback: JDBridgeCallBack) -> Bool {
        self.currentCallback = callback
        
        guard let params = params as? [String: Any] else {
            callbackError(message: "参数错误")
            return true
        }
        if action == "openPage" {
            openPage(params)
        } else {
            callCustomMethod(action, params: params)
        }
        
        return true
    }
    
    private func openPage(_ params: [String: Any]) {
        guard let url = params["url"] as? String else {
            callbackError(message: "缺少 url")
            return
        }
        
        let pageParams = params["params"] as? [String: Any]
        
        if let delegate = hostDelegate {
            delegate.webViewRequestOpenPage?(url: url, params: pageParams) { [weak self] result in
                self?.callbackSuccess(data: result ?? ["success": true])
            }
        } else {
            callbackError(message: "宿主 APP 未实现 delegate")
        }
    }
    
    private func callCustomMethod(_ methodName: String, params: [String: Any]) {
        if let delegate = hostDelegate {
            delegate.webViewRequestCustomMethod?(methodName: methodName, params: params) { [weak self] result in
                self?.callbackSuccess(data: result ?? ["success": true])
            }
        } else {
            callbackError(message: "宿主 APP 未实现 delegate")
        }
    }
    
    private func callbackSuccess(data: Any) {
        currentCallback?.onSuccess(data)
    }
    
    private func callbackError(message: String) {
        let error = NSError(domain: "QXHostBridgePlugin", 
                           code: -1, 
                           userInfo: [NSLocalizedDescriptionKey: message])
        currentCallback?.onFail(error)
    }
}
