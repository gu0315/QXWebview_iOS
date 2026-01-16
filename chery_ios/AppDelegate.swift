//
//  AppDelegate.swift
//  chery_ios
//
//  Created by 顾钱想 on 10/10/25.
//

import UIKit
import Foundation
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化应用
        setupApplication()
        // 创建窗口
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.backgroundColor = .white
        // 显示启动屏幕
        showLaunchScreen()
        
        print("应用启动完成")
        return true
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
        let rootViewController = ViewController()
        // 创建导航控制器
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.navigationBar.isTranslucent = false
        navigationController.navigationBar.barTintColor = .white
        navigationController.navigationBar.tintColor = .systemBlue
        
        self.window?.rootViewController = navigationController
    }

}

