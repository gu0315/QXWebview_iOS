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
    
    @objc public weak var hostDelegate: QXWebViewHostDelegate?
    
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
        // 加载URL
        if let url = urlString {
            loadURL(url)
        }
        let basePlugin = QXBasePlugin()
        let blePlugin = QXBlePlugin()
        let hostBridgePlugin = QXHostBridgePlugin()
        webView.registerPlugin(withName: "QXBasePlugin", plugin: basePlugin)
        webView.registerPlugin(withName: "QXBlePlugin", plugin: blePlugin)
        webView.registerPlugin(withName: "QXHostBridgePlugin", plugin: hostBridgePlugin)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 应用导航栏设置
        navigationController?.setNavigationBarHidden(isNavigationBarHidden, animated: animated)
        // 更新状态栏样式
        updateStatusBarStyle()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateWebViewFrame()
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        if isImmersiveStatusBar {
            return .lightContent
        } else {
            if #available(iOS 13.0, *) {
                return .darkContent
            } else {
                return .default
            }
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
        // 配置缓存策略
        let cacheConfig = URLCache(memoryCapacity: 1024 * 1024 * 10, diskCapacity: 1024 * 1024 * 100, diskPath: "WebCache")
        URLCache.shared = cacheConfig
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
    
    /// 更新状态栏样式（通过系统首选项）
    private func updateStatusBarStyle() {
        navigationController?.navigationBar.barStyle = isImmersiveStatusBar ? .black : .default
        setNeedsStatusBarAppearanceUpdate()
    }
    
    /// 清理资源
    private func cleanupResources() {
        // 清理WebView缓存
        clearWebViewCache()
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
        print("QRWebViewController资源清理完成")
    }
    
    /// 清理WebView缓存
    private func clearWebViewCache() {
        let dataStore = webView.realWebView.configuration.websiteDataStore
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let date = Date(timeIntervalSince1970: 0)
        
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: date) {
            print("WebView缓存清理完成")
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
        // 创建请求
        let request = URLRequest(url: url)
        webView.load(request)
        
        print("开始加载URL: \(urlString)")
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
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }
        // 处理外部 scheme
        let scheme = url.scheme?.lowercased() ?? ""
        let allowedSchemes: Set<String> = ["http", "https"]
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
