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
    
    private func hostContext(for callback: JDBridgeCallBack) -> (delegate: QXWebViewHostDelegate, viewController: QXWebViewController?)? {
        if let viewController = callback.webViewController as? QXWebViewController,
           let delegate = viewController.hostDelegate {
            return (delegate, viewController)
        }
        if let viewController = callback.findWebViewController(),
           let delegate = viewController.hostDelegate {
            return (delegate, viewController)
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
        let url = (params["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (params["pageName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let targetURL = url, !targetURL.isEmpty else {
            callbackError(message: "缺少 url/pageName", callback: callback)
            return
        }
        let pageParams = params["params"] as? [String: Any]
        if let context = hostContext(for: callback) {
            if let viewController = context.viewController,
               let _ = context.delegate.webViewRequestOpenPage?(webViewController: viewController, url: targetURL, params: pageParams, completion: { [weak self] result in
                    self?.callbackSuccess(data: result ?? ["success": true], callback: callback)
                }) {
                return
            }
            if let _ = context.delegate.webViewRequestOpenPage?(url: targetURL, params: pageParams, completion: { [weak self] result in
                self?.callbackSuccess(data: result ?? ["success": true], callback: callback)
            }) {
                return
            }
            callbackError(message: "宿主 APP 未实现 delegate 或未设置 hostDelegate", callback: callback)
        } else {
            callbackError(message: "宿主 APP 未实现 delegate 或未设置 hostDelegate", callback: callback)
        }
    }
    
    private func callCustomMethod(_ methodName: String, params: [String: Any], callback: JDBridgeCallBack) {
        if let context = hostContext(for: callback) {
            if let viewController = context.viewController,
               let _ = context.delegate.webViewRequestCustomMethod?(webViewController: viewController, methodName: methodName, params: params, completion: { [weak self] result in
                    self?.callbackSuccess(data: result ?? ["success": true], callback: callback)
                }) {
                return
            }
            if let _ = context.delegate.webViewRequestCustomMethod?(methodName: methodName, params: params, completion: { [weak self] result in
                self?.callbackSuccess(data: result ?? ["success": true], callback: callback)
            }) {
                return
            }
            callbackError(message: "宿主 APP 未实现 delegate 或未设置 hostDelegate", callback: callback)
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
