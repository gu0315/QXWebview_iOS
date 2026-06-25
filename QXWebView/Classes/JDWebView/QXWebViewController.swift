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

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        QXLifecyclePlugin.dispatchPageLifecycle(webView: webView, type: "pageHide", nativeType: "viewDidDisappear")
        // 被 pop 出栈 / 被 dismiss（用户返回，未调用 closeWithResult）=> 回传取消兜底
        if isMovingFromParent || isBeingDismissed, let pageId = hostPageId {
            QXPageResultCenter.shared.cancel(pageId)
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateWebViewFrame()
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        if isImmersiveStatusBar {
            return .lightContent
        } else {
            return .darkContent
        }
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // 低内存时尝试释放缓存
        clearWebViewCache()
    }
    
    // MARK: - 初始化方法
    /// 初始化方法 - 通过URL
    /// - Parameter url: 要加载的URL
    public init(url: String) {
        self.urlString = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - 私有方法
    
    /// 设置UI
    private func setupUI() {
        // 设置背景色
        view.backgroundColor = .systemBackground
        // 初始化WebView
        setupWebView()
        // 添加原生AutoLayout约束
        setupNativeConstraints()
    }
    
    /// 设置WebView
    private func setupWebView() {
        let configuration = JDWebViewContainer.defaultConfiguration()
        // 优化WebView配置
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = false
        webView = JDWebViewContainer(
            frame: .init(x: 0, y: 0, width: ScreenConst.screenWidth, height: ScreenConst.screenHeight),
            configuration: configuration
        )
        if #available(iOS 16.4, *) {
            webView.realWebView.isInspectable = true
        }
        webView.delegate = self
        webView.backgroundColor = .systemBackground
        webView.realWebView.scrollView.decelerationRate = .normal
        webView.realWebView.scrollView.bounces = true
        webView.realWebView.scrollView.showsVerticalScrollIndicator = true
        webView.realWebView.scrollView.showsHorizontalScrollIndicator = false
        // 禁用AutoresizingMask，启用AutoLayout
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
    }
    
    /// 添加原生AutoLayout约束（替代SnapKit）
    private func setupNativeConstraints() {
        // 初始化约束
        webViewLeadingConstraint = webView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        webViewTrailingConstraint = webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        // 初始top/bottom约束（后续动态更新）
        webViewTopConstraint = webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        webViewBottomConstraint = webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        // 激活所有约束
        NSLayoutConstraint.activate([
            webViewLeadingConstraint,
            webViewTrailingConstraint,
            webViewTopConstraint,
            webViewBottomConstraint
        ])
    }
    
    /// 配置WebView
    private func configureWebView() {
        // 设置WebView的基本属性
        webView.isUserInteractionEnabled = true
        webView.realWebView.scrollView.showsVerticalScrollIndicator = false
        webView.realWebView.scrollView.showsHorizontalScrollIndicator = false
        webView.realWebView.scrollView.bounces = true
    }
    
    /// 设置通知监听
    private func setupNotificationObservers() {
        // 监听状态栏更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleImmersiveStatusBarUpdate),
            name: NSNotification.Name("UpdateImmersiveStatusBar"),
            object: nil
        )
        
        // 监听导航栏更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigationBarUpdate),
            name: NSNotification.Name("UpdateNavigationBarHidden"),
            object: nil
        )
    }
    
    @objc private func handleImmersiveStatusBarUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let immersive = userInfo["immersive"] as? Bool {
            isImmersiveStatusBar = immersive
        }
    }
    
    @objc private func handleNavigationBarUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let hidden = userInfo["hidden"] as? Bool {
            isNavigationBarHidden = hidden
        }
    }

    // MARK: - 布局更新方法
    
    /// 统一处理布局相关的UI更新
    private func updateUIForLayoutChanges() {
        DispatchQueue.main.async {
            // 更新导航栏显示状态
            self.navigationController?.setNavigationBarHidden(self.isNavigationBarHidden, animated: true)
            // 更新WebView布局
            self.updateWebViewFrame()
        }
    }
    
    /// 更新WebView的Frame（原生AutoLayout版）
    private func updateWebViewFrame() {
        // 确保在主队列上执行UI更新
        if Thread.isMainThread {
            performWebViewFrameUpdate()
        } else {
            DispatchQueue.main.async {
                self.performWebViewFrameUpdate()
            }
        }
    }
    
    /// 执行WebView的Frame更新（原生AutoLayout，动画版）
    private func performWebViewFrameUpdate() {
        UIView.animate(withDuration: 0.25) {
            // 先停用所有约束
            NSLayoutConstraint.deactivate([
                self.webViewTopConstraint,
                self.webViewBottomConstraint
            ])
            // 更新Top约束
            if self.isNavigationBarHidden && self.isImmersiveStatusBar {
                self.webViewTopConstraint = self.webView.topAnchor.constraint(equalTo: self.view.topAnchor)
            } else {
                self.webViewTopConstraint = self.webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor)
            }
            // 更新Bottom约束
            if self.shouldHandleBottomSafeArea {
                self.webViewBottomConstraint = self.webView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            } else {
                self.webViewBottomConstraint = self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            }
            // 激活新约束
            NSLayoutConstraint.activate([
                self.webViewTopConstraint,
                self.webViewBottomConstraint
            ])
            // 强制刷新布局
            self.view.layoutIfNeeded()
        }
    }
    
    /// 更新状态栏样式
    private func updateStatusBarStyle() {
        let resolvedStyle = navigationBarStyleOverride ?? (isImmersiveStatusBar ? .black : .default)
        navigationController?.navigationBar.barStyle = resolvedStyle
        setNeedsStatusBarAppearanceUpdate()
    }

    func setNavigationBarStyleOverride(_ style: UIBarStyle?) {
        navigationBarStyleOverride = style
        if let style {
            isImmersiveStatusBar = (style == .black)
        } else {
            updateStatusBarStyle()
        }
    }
    
    /// 清理资源
    private func cleanupResources() {
        // 清理WebView缓存
        clearWebViewCache()
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
        print("QRWebViewController资源清理完成")
    }
    
    private static let webCacheTokenKey = "QXWebView.cachePurgeToken"

    /// 供 H5 调用(QXBasePlugin.setWebCacheToken)触发的按 token 清缓存:
    /// 传入 token 与上次记录不同时,清一次 HTTP 缓存并记录新 token;相同则跳过、零开销。
    /// **保留 cookie、localStorage、sessionStorage**(不影响登录态)。
    /// - Parameter completion: 回调 `cleared` —— 本次是否真的执行了清理。
    static func purgeHTTPCacheIfTokenChanged(_ token: String, completion: @escaping (_ cleared: Bool) -> Void) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: webCacheTokenKey) != token else {
            completion(false)
            return
        }
        defaults.set(token, forKey: webCacheTokenKey)
        purgeHTTPCachePreservingLogin {
            print("WebView 磁盘缓存已清理(token=\(token))")
            completion(true)
        }
    }

    /// 清磁盘/内存/离线/Fetch 缓存,**保留 cookie、localStorage、sessionStorage**(不掉登录)。
    static func purgeHTTPCachePreservingLogin(completion: @escaping () -> Void) {
        var dataTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache
        ]
        if #available(iOS 11.3, *) {
            dataTypes.insert(WKWebsiteDataTypeFetchCache)
        }
        URLCache.shared.removeAllCachedResponses()
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: Date(timeIntervalSince1970: 0),
            completionHandler: completion
        )
    }

    /// 清理 WebView 缓存(磁盘/内存/Offline/Fetch),**保留 cookie、localStorage、sessionStorage**(不掉登录)。
    /// 与 purgeHTTPCachePreservingLogin 行为一致,确保低内存等场景不会误清登录态。
    private func clearWebViewCache(completion: (() -> Void)? = nil) {
        webView.stopLoading()
        URLCache.shared.removeAllCachedResponses()

        var dataTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache
        ]
        if #available(iOS 11.3, *) {
            dataTypes.insert(WKWebsiteDataTypeFetchCache)
        }

        let dataStore = webView.realWebView.configuration.websiteDataStore
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) {
            print("WebView 缓存清理完成(保留登录态)")
            completion?()
        }
    }
    
    // MARK: - 事件处理
    /// 返回按钮点击事件
    @objc private func backButtonClicked() {
        if webView.canGoBack() {
            webView.goBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: - 加载方法
    /// 加载URL
    /// - Parameter urlString: URL字符串
    func loadURL(_ urlString: String) {
        // 检查URL中是否包含状态栏和导航栏的控制参数
        parseURLParameters(urlString: urlString)
        // 安全地转换URL字符串为URL
        guard let url = URL(string: urlString) else {
            print("URL格式错误：\(urlString)")
            return
        }
        if url.isFileURL {
            let readAccessURL = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
            print("开始加载本地URL: \(urlString)")
            return
        }
        webView.load(URLRequest(url: url))
        print("开始加载URL: \(urlString)")
    }

    public func refreshForNetworkRecovery(url fallbackURLString: String? = nil) {
        if let currentURL = webView.realWebView.url {
            if currentURL.isFileURL {
                webView.loadFileURL(currentURL, allowingReadAccessTo: currentURL.deletingLastPathComponent())
            } else {
                webView.realWebView.reloadFromOrigin()
            }
            print("网络状态恢复，刷新当前 H5 页面")
            return
        }

        let targetURLString = fallbackURLString ?? urlString
        if let targetURLString {
            loadURL(targetURLString)
            print("网络状态恢复，重新加载初始 H5 页面")
        }
    }

    /// 解析URL参数
    /// - Parameter urlString: URL字符串
    private func parseURLParameters(urlString: String) {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        // 处理沉浸式状态栏参数
        if let immersiveParam = components.queryItems?.first(where: { $0.name == "immersive" })?.value {
            isImmersiveStatusBar = (immersiveParam.lowercased() == "true")
        }
        
        // 处理导航栏隐藏参数
        if let navHiddenParam = components.queryItems?.first(where: { $0.name == "navHidden" })?.value {
            isNavigationBarHidden = (navHiddenParam.lowercased() == "true")
        }
        
        // 处理状态栏样式参数
        if let statusBarStyleParam = components.queryItems?.first(where: { $0.name == "statusBarStyle" })?.value,
           statusBarStyleParam == "dark" {
           // 扩展：可添加更多状态栏样式逻辑
        }
    }

    public func openFile(fileURL: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                       
            guard fileURL.isFileURL else {
               print("❌ 文件URL错误：非本地沙盒文件")
               return
            }
            let filePath = fileURL.path
            guard !filePath.isEmpty else {
               print("❌ 文件路径为空")
               return
            }
            guard FileManager.default.fileExists(atPath: filePath) else {
               print("❌ 文件不存在：\(filePath)")
               return
            }
        
            self.previewFileURL = fileURL
            let qlPreviewVC = QLPreviewController()
            qlPreviewVC.dataSource = self
            qlPreviewVC.delegate = self
            qlPreviewVC.hidesBottomBarWhenPushed = true
            qlPreviewVC.navigationItem.title = "文件预览"
            self.present(qlPreviewVC, animated: true, completion: nil)
        }
    }
    
    deinit {
        QXLifecyclePlugin.dispatchPageLifecycle(webView: webView, type: "pageDestroy", nativeType: "deinit")
        QXLifecyclePlugin.clear(webView: webView)
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
        print("QRWebViewController已释放")
    }
}

// MARK: - WebViewDelegate实现
extension QXWebViewController: WebViewDelegate {
    
    // 网页开始加载时调用
    public func webView(_ webView: JDWebViewContainer, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("网页开始加载")
    }
    
    // 网页加载完成时调用
    public func webView(_ webView: JDWebViewContainer, didFinish navigation: WKNavigation!) {
        print("网页加载完成")
    }
    
    // 网页加载失败时调用
    public func webView(_ webView: JDWebViewContainer, didFail navigation: WKNavigation!, withError error: Error) {
        print("网页加载失败: \(error.localizedDescription)")
    }
    
    // 网页加载进度更新（现在用于优化加载体验）
    func webView(_ webView: JDWebViewContainer, didUpdateProgress progress: Float) {
        // 当进度达到一定值时，可以切换到更精细的加载指示器
    }
    
    // 决定是否允许导航
    public func webView(_ webView: JDWebViewContainer, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: ((WKNavigationActionPolicy) -> Void)) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        // 处理 target=_blank 的情况：在当前视图中打开
        if navigationAction.targetFrame == nil {
            if url.isFileURL {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                webView.load(URLRequest(url: url))
            }
            decisionHandler(.cancel)
            return
        }
        // 处理外部 scheme
        let scheme = url.scheme?.lowercased() ?? ""
        let allowedSchemes: Set<String> = ["http", "https", "file"]
        if !allowedSchemes.contains(scheme) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

extension QXWebViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.previewFileURL as QLPreviewItem
    }
}
