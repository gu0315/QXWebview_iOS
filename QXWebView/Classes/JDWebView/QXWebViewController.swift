//
//  QXWebViewController.swift
//  chery_ios
//
//  Created by 顾钱想 on 10/10/25.
//

import UIKit
import WebKit
import Foundation
import CoreTelephony
import QuickLook


private struct ScreenConst {
    static let screenWidth = UIScreen.main.bounds.width
    static let screenHeight = UIScreen.main.bounds.height
}

@objc(QRWebViewController)
public class QXWebViewController: UIViewController {

    // MARK: - 公开属性
    /// WebView实例
    var webView: JDWebViewContainer!
    /// 加载的URL
    var urlString: String?
    private var navigationBarStyleOverride: UIBarStyle?

    @objc public weak var hostDelegate: QXWebViewHostDelegate?

    /// 由 openWebViewForResult 打开时分配的回传 id（用于 closeWithResult / 取消兜底）
    var hostPageId: String?

    private var previewFileURL: URL!
    private var initialLoadingView: UIView?
    private var initialLoadingWorkItem: DispatchWorkItem?

    // MARK: - 布局控制属性
    var isNavigationBarHidden: Bool = true {
        didSet {
            guard oldValue != isNavigationBarHidden else { return }
            updateUIForLayoutChanges()
        }
    }

    var isImmersiveStatusBar: Bool = true {
        didSet {
            guard oldValue != isImmersiveStatusBar else { return }
            updateStatusBarStyle()
        }
    }

    var shouldHandleBottomSafeArea: Bool = true {
        didSet {
            guard oldValue != shouldHandleBottomSafeArea else { return }
            updateWebViewFrame()
        }
    }

    // MARK: - 布局约束（原生AutoLayout）
    private var webViewTopConstraint: NSLayoutConstraint!
    private var webViewBottomConstraint: NSLayoutConstraint!
    private var webViewLeadingConstraint: NSLayoutConstraint!
    private var webViewTrailingConstraint: NSLayoutConstraint!

    // MARK: - 生命周期
    public override func viewDidLoad() {
        super.viewDidLoad()
        // 初始化UI
        setupUI()
        // 设置通知监听
        setupNotificationObservers()
        let basePlugin = QXBasePlugin()
        let blePlugin = QXBlePlugin()
        let hostBridgePlugin = QXHostBridgePlugin()
        let lifecyclePlugin = QXLifecyclePlugin()
        webView.registerPlugin(withName: "QXBasePlugin", plugin: basePlugin)
        webView.registerPlugin(withName: "QXBlePlugin", plugin: blePlugin)
        webView.registerPlugin(withName: "QXHostBridgePlugin", plugin: hostBridgePlugin)
        webView.registerPlugin(withName: QXLifecyclePlugin.pluginName, plugin: lifecyclePlugin)
        QXLifecyclePlugin.dispatchPageLifecycle(webView: webView, type: "pageLoad", nativeType: "viewDidLoad")
        // 入口 HTML 由服务端响应头 `Cache-Control: no-cache` + `ETag` 控制,
        // WKWebView 默认策略即可命中 304/重拉,H5 更新即时生效;
        // 需要强制清缓存时,由 H5 调用 QXBasePlugin.setWebCacheToken 触发(保留登录态)
        if let url = urlString {
            self.loadURL(url)
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 应用导航栏设置
        navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: animated)
        // 更新状态栏样式
        updateStatusBarStyle()
        QXLifecyclePlugin.dispatchPageLifecycle(webView: webView, type: "pageWillShow", nativeType: "viewWillAppear")
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        QXLifecyclePlugin.dispatchPageLifecycle(webView: webView, type: "pageShow", nativeType: "viewDidAppear")
    }

    public override func viewWillDisappear(_ animated: Bool) {
        QXLifecyclePlugin.dispatchPageLifecycle(webView: webView, type: "pageWillHide", nativeType: "viewWillDisappear")
        super.viewWillDisappear(animated)
    }