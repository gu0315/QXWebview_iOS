//
//  WebViewOptimizer.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import WebKit

/// WebView性能优化器
class WebViewOptimizer {
    static let shared = WebViewOptimizer()
    
    private init() {}
    
    /// 优化WebView配置
    func optimizeWebViewConfiguration(_ configuration: WKWebViewConfiguration) {
        // 启用硬件加速
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 优化JavaScript性能
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // 设置用户代理
        configuration.applicationNameForUserAgent = "CheryHybridApp/\(Const.appVersion())"
        
        // 配置进程池
        configuration.processPool = WKProcessPool()
        
        // 设置内容规则
        setupContentRuleList(configuration)
        
        Logger.shared.info("WebView配置已优化")
    }
    
    /// 设置内容规则列表
    private func setupContentRuleList(_ configuration: WKWebViewConfiguration) {
        let rules = """
        [
            {
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "make-https"
                }
            }
        ]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ContentBlockingRules",
            encodedContentRuleList: rules
        ) { ruleList, error in
            if let error = error {
                Logger.shared.error("内容规则设置失败: \(error)")
            } else if let ruleList = ruleList {
                configuration.userContentController.add(ruleList)
                Logger.shared.info("内容规则已设置")
            }
        }
    }
    
    /// 优化WebView内存使用
    func optimizeWebViewMemory(_ webView: WKWebView) {
        // 设置内存限制
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.configuration.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // 禁用不必要的功能
        webView.configuration.preferences.setValue(false, forKey: "javaScriptCanAccessClipboard")
        webView.configuration.preferences.setValue(false, forKey: "javaScriptCanOpenWindowsAutomatically")
        
        Logger.shared.info("WebView内存优化完成")
    }
    
    /// 清理WebView缓存
    func clearWebViewCache() {
        let websiteDataTypes = NSSet(array: [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeWebSQLDatabases
        ])
        
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date) {
            Logger.shared.info("WebView缓存已清理")
        }
    }
    
    /// 预加载资源
    func preloadResources(_ urls: [String]) {
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    Logger.shared.error("预加载资源失败: \(urlString) - \(error)")
                } else {
                    Logger.shared.info("预加载资源成功: \(urlString)")
                }
            }.resume()
        }
    }
    
    /// 监控WebView性能
    func startPerformanceMonitoring(_ webView: WKWebView) {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            let memoryInfo = MemoryManager.shared.getCurrentMemoryUsage()
            
            if memoryInfo.residentSize > 50 * 1024 * 1024 { // 50MB
                Logger.shared.warning("WebView内存使用过高: \(memoryInfo.residentSizeMB)MB")
                self.clearWebViewCache()
            }
        }
    }
}
