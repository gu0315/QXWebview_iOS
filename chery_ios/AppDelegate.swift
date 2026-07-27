//
//  AppDelegate.swift
//  chery_ios
//
//  Created by 顾钱想 on 10/10/25.
//

import UIKit
import Foundation
import Network
import QXWebView
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    // 18352537909
    // "https://test-fr-home-charge-web.cheryge.com/#/pages/bluetooth-test/index"
    // private let homeChargingUrl = "http://169.254.142.113:5173/#/pages/bluetooth-test/index"
    //"https://test-fr-home-charge-web.cheryge.com/#/pages/bluetooth-test/index"
    private let homeChargingUrl = "https://www.baidu.com/"
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "com.chery.app.network-monitor")
    private var lastNetworkStatus: NWPath.Status?
    private var shouldRefreshWhenAppBecomesActive = false
    private var lastRefreshAt: Date?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupApplication()
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.backgroundColor = .white
        showLaunchScreen()
        startNetworkMonitoring()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard shouldRefreshWhenAppBecomesActive else { return }
        shouldRefreshWhenAppBecomesActive = false
        refreshCurrentWebViewForNetworkRecovery()
    }

    /// 显示启动屏幕
    private func showLaunchScreen() {
        // 暂时直接设置主界面，稍后添加启动屏幕
        setupRootViewController()
    }

    // MARK: - 私有方法

    /// 初始化应用配置
    private func setupApplication() {
        // 初始化用户偏好设置
        // UserDefaultsManager.shared.isFirstLaunch = false
    }


    /// 设置根视图控制器
    private func setupRootViewController() {
        // 主界面：用户输入手机号、车辆 VIN / MAC，再进入 H5
        let rootViewController = ViewController()
        // 创建导航控制器
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.navigationBar.isTranslucent = false
        navigationController.navigationBar.barTintColor = .white
        navigationController.navigationBar.tintColor = .systemBlue
        self.window?.rootViewController = navigationController
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let status = path.status
            let previousStatus = self.lastNetworkStatus
            self.lastNetworkStatus = status

            guard let previousStatus else { return }
            guard previousStatus != status else { return }
            guard previousStatus != .satisfied, status == .satisfied else { return }

            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active {
                    self.refreshCurrentWebViewForNetworkRecovery()
                } else {
                    self.shouldRefreshWhenAppBecomesActive = true
                }
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }

    private func refreshCurrentWebViewForNetworkRecovery() {
        let now = Date()
        if let lastRefreshAt, now.timeIntervalSince(lastRefreshAt) < 1.5 {
            return
        }
        lastRefreshAt = now

        findTopWebViewController(from: window?.rootViewController)?.refreshForNetworkRecovery(url: homeChargingUrl)
    }

    private func findTopWebViewController(from viewController: UIViewController?) -> QXWebViewController? {
        guard let viewController else { return nil }
        if let navigationController = viewController as? UINavigationController {
            return findTopWebViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController {
            return findTopWebViewController(from: tabBarController.selectedViewController)
        }
        if let presentedViewController = viewController.presentedViewController {
            return findTopWebViewController(from: presentedViewController)
        }
        return viewController as? QXWebViewController
    }
}

extension AppDelegate: QXWebViewHostDelegate {
    func webViewRequestOpenPage(
        url: String,
        params: [String: Any]?,
        completion: @escaping (Any?) -> Void
    ) {
        let safeParams = params ?? [:]
        switch url {
        case "app://openFRConfirmPay":
            // 参数:orderSeq 绿能侧充电订单号 / stationName 充电站名称 / powerConnectorId 充电桩编号
            // 真实宿主在这里跳自己的确认支付页;Demo 用模拟页面代替:
            // 「确认支付」-> code 0,「取消」/ 返回 -> code 1,拉不起页面 -> code 2
            FRConfirmPayViewController.present(params: safeParams, completion: completion)
        case "app://login":
            let result: [String: Any] = [
                "phone": "18352537909",
                "list": [
                    ["vin": "vin1", "mac": "mac1"],
                    ["vin": "vin2", "mac": "mac2"],
                    ["vin": "vin3", "mac": "mac3"]
                ],
                "userId": "1232323232xxx",
                "isLogin": true,
                "userName": "xxx"
            ]
            completion(result)
        default:
            print("未处理的 URL: \(url)")
            completion([
                "success": false,
                "message": "未处理的 URL: \(url)",
                "params": safeParams
            ])
        }
    }

    func webViewRequestCustomMethod(
        methodName: String,
        params: [String : Any]?,
        completion: @escaping (Any?) -> Void
    ) {
        switch methodName {
        case "getToken":
            completion(["token": "xxx"])
        case "getUserInfo":
            let result: [String: Any] = [
                "phone": "18352537909",
                "list": [
                    ["vin": "vin1", "mac": "mac1"],
                    ["vin": "vin2", "mac": "mac2"],
                    ["vin": "vin3", "mac": "mac3"]
                ],
                "userId": "xxx",
                "isLogin": true,
                "userName": "xxx"
            ]
            completion(result)
        default:
            completion(["success": false, "message": "未知的方法: \(methodName)"])
        }
    }
}

/// 模拟的 FR 确认支付页(Demo 宿主用)
/// 真实宿主应替换成自己的收银台,只需保证结束时回调同样的 code / message / orderSeq
final class FRConfirmPayViewController: UIViewController {

    /// (code, message, orderSeq) —— code: 0 成功 / 1 用户取消 / 2 失败
    typealias FinishHandler = (String, String, String) -> Void

    private let orderSeq: String
    private let stationName: String
    private let powerConnectorId: String
    private let onFinish: FinishHandler
    private var didFinish = false

    private let statusLabel = UILabel()
    private let payButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    /// H5 调 app://openFRConfirmPay 的统一入口:解析参数 -> 弹出模拟页 -> 回传结果
    /// 各个 hostDelegate 实现(AppDelegate / ViewController)都走这里,避免逻辑分叉
    static func present(params: [String: Any], completion: @escaping (Any?) -> Void) {
        let orderSeq = stringValue(params["orderSeq"])                  // 绿能侧充电订单号
        let stationName = stringValue(params["stationName"])            // 充电站名称
        let powerConnectorId = stringValue(params["powerConnectorId"])  // 充电桩编号

        DispatchQueue.main.async {
            guard let presenter = topViewController() else {
                completion(["code": "2", "message": "未找到可展示的控制器", "orderSeq": orderSeq])
                return
            }
            let payViewController = FRConfirmPayViewController(
                orderSeq: orderSeq,
                stationName: stationName,
                powerConnectorId: powerConnectorId
            ) { code, message, resultOrderSeq in
                completion([
                    "code": code,
                    "message": message,
                    "orderSeq": resultOrderSeq
                ])
            }
            payViewController.modalPresentationStyle = .fullScreen
            presenter.present(payViewController, animated: true)
        }
    }

    /// 参数容错:H5 传过来的值统一按字符串取
    private static func stringValue(_ value: Any?) -> String {
        guard let value = value, !(value is NSNull) else { return "" }
        if let text = value as? String { return text }
        return String(describing: value)
    }

    /// 找到当前最顶层的控制器,作为模拟支付页的宿主
    private static func topViewController() -> UIViewController? {
        let rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
            ?? (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController
        return topViewController(from: rootViewController)
    }

    private static func topViewController(from viewController: UIViewController?) -> UIViewController? {
        guard let viewController = viewController else { return nil }
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigationController = viewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController) ?? navigationController
        }
        if let tabBarController = viewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController) ?? tabBarController
        }
        return viewController
    }

    init(orderSeq: String, stationName: String, powerConnectorId: String, onFinish: @escaping FinishHandler) {
        self.orderSeq = orderSeq
        self.stationName = stationName
        self.powerConnectorId = powerConnectorId
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 兜底:页面被其他方式关掉时,按用户取消回调,避免 H5 一直等
        finish(code: "1", message: "用户取消支付")
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "确认支付"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center

        let infoLabel = UILabel()
        infoLabel.numberOfLines = 0
        infoLabel.font = .systemFont(ofSize: 15)
        infoLabel.textColor = .darkGray
        infoLabel.text = """
        电站名称：\(stationName.isEmpty ? "-" : stationName)
        充电桩编号：\(powerConnectorId.isEmpty ? "-" : powerConnectorId)
        订单号：\(orderSeq.isEmpty ? "-" : orderSeq)
        """

        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textColor = .systemBlue
        statusLabel.textAlignment = .center
        statusLabel.text = " "

        payButton.setTitle("确认支付", for: .normal)
        payButton.titleLabel?.font = .systemFont(ofSize: 18)
        payButton.backgroundColor = .systemBlue
        payButton.setTitleColor(.white, for: .normal)
        payButton.layer.cornerRadius = 8
        payButton.addTarget(self, action: #selector(handlePay), for: .touchUpInside)

        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 18)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [titleLabel, infoLabel, statusLabel, payButton, cancelButton])
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            payButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc private func handlePay() {
        payButton.isEnabled = false
        cancelButton.isEnabled = false
        statusLabel.text = "支付处理中..."
        // 模拟支付耗时,1.5s 后回调成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.statusLabel.text = "支付成功"
            self.finish(code: "0", message: "success")
            self.dismiss(animated: true)
        }
    }

    @objc private func handleCancel() {
        finish(code: "1", message: "用户取消支付")
        dismiss(animated: true)
    }

    /// 结果只回调一次
    private func finish(code: String, message: String) {
        guard !didFinish else { return }
        didFinish = true
        onFinish(code, message, orderSeq)
    }
}
