//
//  DeviceInfoPlugin.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import UIKit
import CoreTelephony

/// 设备信息插件
@objc class DeviceInfoPlugin: JDBridgeBasePlugin {
    
    override func excute(_ action: String, params: [AnyHashable : Any], callback: JDBridgeCallBack) -> Bool {
        switch action {
        case "getDeviceInfo":
            handleGetDeviceInfo(callback: callback)
            return true
        case "getNetworkInfo":
            handleGetNetworkInfo(callback: callback)
            return true
        case "getBatteryInfo":
            handleGetBatteryInfo(callback: callback)
            return true
        case "getStorageInfo":
            handleGetStorageInfo(callback: callback)
            return true
        case "vibrate":
            handleVibrate(params: params, callback: callback)
            return true
        default:
            callback.onFail(NSError(domain: "DeviceInfoPlugin", code: 1001, userInfo: [NSLocalizedDescriptionKey: "未知操作"]))
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 获取设备信息
    private func handleGetDeviceInfo(callback: JDBridgeCallBack) {
        let deviceInfo = [
            "deviceModel": Const.appPlatform(),
            "systemVersion": Const.OSVersion(),
            "appVersion": Const.appVersion(),
            "buildVersion": Const.appBuildVersionCode(),
            "deviceId": UserDefaultsManager.shared.deviceId,
            "screenWidth": Const.screenWidth,
            "screenHeight": Const.screenHeight,
            "isIphoneX": Const.isIphoneX,
            "statusBarHeight": Const.statusBarHeight,
            "navBarHeight": Const.navBarHeight,
            "bottomSafeHeight": Const.bottomSafeHeight,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier
        ]
        callback.onSuccess(deviceInfo)
    }
    
    /// 获取网络信息
    private func handleGetNetworkInfo(callback: JDBridgeCallBack) {
        let networkInfo = NetworkInfoManager.shared.getNetworkInfo()
        callback.onSuccess(networkInfo)
    }
    
    /// 获取电池信息
    private func handleGetBatteryInfo(callback: JDBridgeCallBack) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let batteryInfo = [
            "batteryLevel": UIDevice.current.batteryLevel,
            "batteryState": batteryStateToString(UIDevice.current.batteryState)
        ]
        
        callback.onSuccess(batteryInfo)
    }
    
    /// 获取存储信息
    private func handleGetStorageInfo(callback: JDBridgeCallBack) {
        let storageInfo = StorageInfoManager.shared.getStorageInfo()
        callback.onSuccess(storageInfo)
    }
    
    /// 震动
    private func handleVibrate(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        let duration = params["duration"] as? Double ?? 0.1
        
        if #available(iOS 10.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        // 系统震动
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        callback.onSuccess(["success": true, "duration": duration])
    }
    
    /// 电池状态转字符串
    private func batteryStateToString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .unplugged: return "unplugged"
        case .charging: return "charging"
        case .full: return "full"
        @unknown default: return "unknown"
        }
    }
}

/// 网络信息管理器
class NetworkInfoManager {
    static let shared = NetworkInfoManager()
    
    private init() {}
    
    func getNetworkInfo() -> [String: Any] {
        var networkInfo: [String: Any] = [:]
        
        // 网络类型
        networkInfo["connectionType"] = getConnectionType()
        
        // 运营商信息
        if let carrierInfo = getCarrierInfo() {
            networkInfo["carrier"] = carrierInfo
        }
        
        return networkInfo
    }
    
    private func getConnectionType() -> String {
        // 这里可以添加更详细的网络类型检测
        return "wifi" // 简化实现
    }
    
    private func getCarrierInfo() -> [String: String]? {
        let networkInfo = CTTelephonyNetworkInfo()
        guard let carrier = networkInfo.subscriberCellularProvider else { return nil }
        
        return [
            "carrierName": carrier.carrierName ?? "",
            "mobileCountryCode": carrier.mobileCountryCode ?? "",
            "mobileNetworkCode": carrier.mobileNetworkCode ?? ""
        ]
    }
}

/// 存储信息管理器
class StorageInfoManager {
    static let shared = StorageInfoManager()
    
    private init() {}
    
    func getStorageInfo() -> [String: Any] {
        var storageInfo: [String: Any] = [:]
        
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let totalSize = systemAttributes[.systemSize] as? NSNumber {
                storageInfo["totalSpace"] = totalSize.int64Value
            }
            if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
                storageInfo["freeSpace"] = freeSize.int64Value
            }
        } catch {
            Logger.shared.error("获取存储信息失败: \(error)")
        }
        
        return storageInfo
    }
}
