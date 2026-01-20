//
//  JDBridgeCallBack+JDWebViewContainer.swift
//  QXWebView
//
//  Created by AI on 2025/12/23.
//

import Foundation
import UIKit

/// JDBridgeCallBack扩展，提供获取JDWebViewContainer的便捷方法
extension JDBridgeCallBack {
    
    /// 递归查找视图及其子视图中的JDWebViewContainer
    /// - Parameter view: 要查找的视图
    /// - Returns: JDWebViewContainer实例，如果无法找到则返回nil
    @objc public func findJDWebViewContainer(in view: UIView) -> JDWebViewContainer? {
        // 检查当前视图是否为JDWebViewContainer
        if let container = view as? JDWebViewContainer {
            return container
        }
        // 递归查找所有子视图
        for subview in view.subviews {
            if let container = findJDWebViewContainer(in: subview) {
                return container
            }
        }
        return nil
    }
    
    
    
    
    /// 直接通过JDBridgeCallBack调用JS插件方法
    /// - Parameters:
    ///   - pluginName: 插件名称
    ///   - params: 参数
    ///   - callback: 回调闭包
    @objc public func callJSWithPluginName(_ pluginName: String?, params: Any?, callback: @escaping (Any?, Error?) -> Void) {
        guard let view = webViewController.view else {
            let error = NSError(domain: "JDBridgeCallBack", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取webViewController或其view"])
            callback(nil, error)
            return
        }
        
        if let container = findJDWebViewContainer(in: view) {
            container.callJS(withPluginName: pluginName, params: params, callback: callback)
        } else {
            let error = NSError(domain: "JDBridgeCallBack", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取JDWebViewContainer实例"])
            callback(nil, error)
        }
    }
}
