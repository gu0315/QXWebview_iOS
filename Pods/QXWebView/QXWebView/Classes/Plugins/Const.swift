//
//  Const.swift
//  chery_ios
//
//  Created by 顾钱想 on 10/11/25.
//

import Foundation
import UIKit

public enum ConfigType {
    case debug, release
}

public struct Const {}

public extension Const {
    static var homeMixHeadHeight: CGFloat = 0
    
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
    /// 状态栏高度
    static var statusBarHeight: CGFloat {
        if #available(iOS 13.0, *) {
            let windowScene = UIApplication.shared.connectedScenes
                .first { $0.activationState == .foregroundActive } as? UIWindowScene
            return windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        } else {
            return UIApplication.shared.statusBarFrame.height
        }
    }

    /// 导航栏高度
    static let realNavBarHeight: CGFloat = 44
    /// Tabbar高度
    static let tabBarHeight: CGFloat = 49
    /// 安全区域的高度
    static let bottomSafeHeight: CGFloat = isIphoneX ? 34 : 0
    /// 顶部导航高度
    static let navBarHeight: CGFloat = statusBarHeight + realNavBarHeight
    /// 包含底部toolbar和安全区域
    static let bottomTabBarHeight: CGFloat = tabBarHeight + bottomSafeHeight
    /// 页面高度 减去导航栏高度
    static let pageHeight: CGFloat = screenHeight - navBarHeight
    /// 宽度比
    static let widthRatio = screenWidth / 375.0
    /// 主屏幕高度 减去导航栏高度和底部安全区高度
    static let viewHeight = screenHeight - navBarHeight - bottomSafeHeight

    /// 屏幕适配
    static func afw(_ size: CGFloat) -> CGFloat {
        return size * widthRatio
    }

    static let animateDuration = 0.3

    /// 是否是iphoneX
    static var isIphoneX: Bool {
        guard UI_USER_INTERFACE_IDIOM() == .phone else { return false }
        guard #available(iOS 11.0, *) else { return false }
        guard let window = UIApplication.shared.windows.first else { return false }
        let isX = window.safeAreaInsets.bottom > 0
        return isX
    }

    static var config: ConfigType {
#if DEBUG
        return .debug
#else
        return .release
#endif
    }
}

// MARK: - Other

public extension Const {
    /// ====================系统版本====================///
    static func appVersion() -> String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Build Ver sion Code
    static func appBuildVersionCode() -> String {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as? String ?? ""
    }

    /// Build Ver sion Code
    static func appBuildVersion() -> Int {
        let bundleString = appBuildVersionCode()
        return Int(bundleString) ?? 0
    }

    /// 去掉版本号小数点
    static func appId() -> String {
        return appVersion().replacingOccurrences(of: ".", with: "")
    }

    /// 手机系统版本
    static func OSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    static func DeviceID() -> String {
        return UUID().uuidString
    }

    /// 手机型号
    static func appPlatform() -> String {
        return iphoneType()
    }

    // swiftlint:disable opening_brace cyclomatic_complexity
    fileprivate static func iphoneType() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let platform = withUnsafePointer(to: &systemInfo.machine.0) { ptr in
            String(cString: ptr)
        }
        if platform == "iPhone5,1" { return "iPhone 5" }
        if platform == "iPhone5,2" { return "iPhone 5" }
        if platform == "iPhone5,3" { return "iPhone 5C" }
        if platform == "iPhone5,4" { return "iPhone 5C" }
        if platform == "iPhone6,1" { return "iPhone 5S" }
        if platform == "iPhone6,2" { return "iPhone 5S" }
        if platform == "iPhone7,1" { return "iPhone 6 Plus" }
        if platform == "iPhone7,2" { return "iPhone 6" }
        if platform == "iPhone8,1" { return "iPhone 6S" }
        if platform == "iPhone8,2" { return "iPhone 6S Plus" }
        if platform == "iPhone8,4" { return "iPhone SE" }
        if platform == "iPhone9,1" { return "iPhone 7" }
        if platform == "iPhone9,2" { return "iPhone 7 Plus" }
        if platform == "iPhone9,3" { return "iPhone 7" }
        if platform == "iPhone9,4" { return "iPhone 7 Plus" }
        if platform == "iPhone10,1" { return "iPhone 8" }
        if platform == "iPhone10,2" { return "iPhone 8 Plus" }
        if platform == "iPhone10,3" { return "iPhone X" }
        if platform == "iPhone10,4" { return "iPhone 8" }
        if platform == "iPhone10,5" { return "iPhone 8 Plus" }
        if platform == "iPhone10,6" { return "iPhone X" }
        if platform == "iPhone11,2" { return "iPhone XS" }
        if platform == "iPhone11,4" { return "iPhone XS Max" }
        if platform == "iPhone11,6" { return "iPhone XS Max" }
        if platform == "iPhone11,8" { return "iPhone XR" }
        if platform == "iPhone12,1" { return "iPhone 11" }
        if platform == "iPhone12,3" { return "iPhone 11 Pro" }
        if platform == "iPhone12,5" { return "iPhone 11 Pro Max" }
        if platform == "iPhone12,8" { return "iPhone SE2" }
        if platform == "iPhone13,1" { return "iPhone 12 Mini" }
        if platform == "iPhone13,2" { return "iPhone 12" }
        if platform == "iPhone13,3" { return "iPhone 12 Pro" }
        if platform == "iPhone13,4" { return "iPhone 12 Pro Max" }
        if platform == "iPhone14,2" { return "iPhone 13 Pro" }
        if platform == "iPhone14,3" { return "iPhone 13 Pro Max" }
        if platform == "iPhone14,4" { return "iPhone 13 Mini" }
        if platform == "iPhone14,5" { return "iPhone 13" }
        return platform
    }

    /// 自定义打印方法
    static func logs<T>(_ message: T,
                        file: String = #file,
                        function: String = #function,
                        line: Int = #line)
    {
        if Const.config == .release {
            return
        }
        let fileName = (file as NSString).lastPathComponent
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        print("\(dateString) \(fileName):(\(line)) [\(function)]\n\(message)")
    }
}
