//
//  QXLifecyclePlugin.swift
//  QXWebView
//
//  WebView page lifecycle subscription bridge.
//

import Foundation

@objc(QXLifecyclePlugin)
public class QXLifecyclePlugin: JDBridgeBasePlugin {
    public static let pluginName = "QXLifecyclePlugin"
    private static let eventName = "onPageLifecycle"
    private static var subscribedWebViews = Set<ObjectIdentifier>()
    private static var latestStates: [ObjectIdentifier: [String: Any]] = [:]
    private static let lock = NSLock()

    public override func excute(_ action: String, params: [AnyHashable : Any]?, callback: JDBridgeCallBack) -> Bool {
        guard let webView = resolveWebView(callback: callback) else {
            callback.onFail(QXBridgeError.notFound("WebView 不存在", domain: Self.pluginName))
            return true
        }

        switch action {
        case "subscribePageLifecycle", "subscribe":
            Self.setSubscribed(true, for: webView)
            callback.onSuccess([
                "subscribed": true,
                "state": Self.currentState(for: webView)
            ])
        case "unsubscribePageLifecycle", "unsubscribe":
            Self.setSubscribed(false, for: webView)
            callback.onSuccess(["subscribed": false])
        case "getPageLifecycleState":
            callback.onSuccess(Self.currentState(for: webView))
        default:
            callback.onFail(QXBridgeError.make(.unsupported, message: "未知生命周期操作: \(action)", domain: Self.pluginName))
        }
        return true
    }

    public static func dispatchPageLifecycle(webView: JDWebViewContainer?, type: String, nativeType: String) {
        guard let webView = webView else { return }
        let state = buildState(webView: webView, type: type, nativeType: nativeType)
        let identifier = ObjectIdentifier(webView)
        lock.lock()
        latestStates[identifier] = state
        let subscribed = subscribedWebViews.contains(identifier)
        lock.unlock()

        guard subscribed else { return }
        webView.callJS(withPluginName: pluginName, params: state) { _, _ in }
    }

    public static func clear(webView: JDWebViewContainer?) {
        guard let webView = webView else { return }
        let identifier = ObjectIdentifier(webView)
        lock.lock()
        subscribedWebViews.remove(identifier)
        latestStates.removeValue(forKey: identifier)
        lock.unlock()
    }

    private static func setSubscribed(_ subscribed: Bool, for webView: JDWebViewContainer) {
        let identifier = ObjectIdentifier(webView)
        lock.lock()
        if subscribed {
            subscribedWebViews.insert(identifier)
        } else {
            subscribedWebViews.remove(identifier)
        }
        lock.unlock()
    }

    private static func currentState(for webView: JDWebViewContainer) -> [String: Any] {
        let identifier = ObjectIdentifier(webView)
        lock.lock()
        let state = latestStates[identifier]
        lock.unlock()
        return state ?? buildState(webView: webView, type: "unknown", nativeType: "unknown")
    }

    private static func buildState(webView: JDWebViewContainer, type: String, nativeType: String) -> [String: Any] {
        [
            "eventName": eventName,
            "type": type,
            "nativeType": nativeType,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "url": webView.realWebView.url?.absoluteString ?? "",
            "isForeground": type == "pageWillShow" || type == "pageShow"
        ]
    }

    private func resolveWebView(callback: JDBridgeCallBack) -> JDWebViewContainer? {
        if let viewController = callback.webViewController as? QXWebViewController {
            return viewController.webView
        }
        if let viewController = callback.findWebViewController() {
            return viewController.webView
        }
        if let view = callback.webViewController.view {
            return findJDWebViewContainer(in: view)
        }
        return nil
    }
}
