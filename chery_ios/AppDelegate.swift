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
    private let homeChargingUrl = "https://fr.dongxie.top/fr/#/pages/bluetooth-test/index"
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
        let rootViewController = QXWebViewController(url: homeChargingUrl)
        rootViewController.hostDelegate = self
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
        case "app://pay":
            completion([
                "success": true,
                "action": "pay",
                "params": safeParams
            ])
        case "app://login":
            let result: [String: Any] = [
                "phone": "xxx",
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
                "phone": "xxx",
                "list": [
                    ["vin": "vin1", "mac": "mac1"],
                    ["vin": "vin2", "mac": "mac2"],
                    ["vin": "vin3", "mac": "mac3"]
                ],
                "userId": "xxx",
                "isLogin": false,
                "userName": "xxx"
            ]
            completion(result)
        default:
            completion(["success": false, "message": "未知的方法: \(methodName)"])
        }
    }
}
