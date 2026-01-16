//
//  NotificationPlugin.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import UserNotifications
import UIKit

/// 通知插件
@objc class NotificationPlugin: JDBridgeBasePlugin {
    
    override func excute(_ action: String, params: [AnyHashable : Any], callback: JDBridgeCallBack) -> Bool {
        switch action {
        case "requestPermission":
            handleRequestPermission(callback: callback)
            return true
        case "scheduleNotification":
            handleScheduleNotification(params: params, callback: callback)
            return true
        case "cancelNotification":
            handleCancelNotification(params: params, callback: callback)
            return true
        case "getNotificationSettings":
            handleGetNotificationSettings(callback: callback)
            return true
        case "clearAllNotifications":
            handleClearAllNotifications(callback: callback)
            return true
        default:
            callback.onFail(NSError(domain: "NotificationPlugin", code: 1001, userInfo: [NSLocalizedDescriptionKey: "未知操作"]))
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 请求通知权限
    private func handleRequestPermission(callback: JDBridgeCallBack) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    callback.onFail(error)
                } else {
                    callback.onSuccess(["granted": granted])
                }
            }
        }
    }
    
    /// 安排通知
    private func handleScheduleNotification(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        guard let title = params["title"] as? String,
              let body = params["body"] as? String else {
            callback.onFail(NSError(domain: "NotificationPlugin", code: 1002, userInfo: [NSLocalizedDescriptionKey: "缺少必要参数"]))
            return
        }
        
        let identifier = params["identifier"] as? String ?? UUID().uuidString
        let delay = params["delay"] as? Double ?? 1.0
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let badge = params["badge"] as? Int {
            content.badge = NSNumber(value: badge)
        }
        
        if let userInfo = params["userInfo"] as? [String: Any] {
            content.userInfo = userInfo
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    callback.onFail(error)
                } else {
                    callback.onSuccess(["success": true, "identifier": identifier])
                }
            }
        }
    }
    
    /// 取消通知
    private func handleCancelNotification(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        guard let identifier = params["identifier"] as? String else {
            callback.onFail(NSError(domain: "NotificationPlugin", code: 1003, userInfo: [NSLocalizedDescriptionKey: "缺少通知标识符"]))
            return
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        
        callback.onSuccess(["success": true])
    }
    
    /// 获取通知设置
    private func handleGetNotificationSettings(callback: JDBridgeCallBack) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let settingsInfo = [
                    "authorizationStatus": self.authorizationStatusToString(settings.authorizationStatus),
                    "alertSetting": self.alertSettingToString(settings.alertSetting),
                    "badgeSetting": self.alertSettingToString(settings.badgeSetting),
                    "soundSetting": self.alertSettingToString(settings.soundSetting),
                    "lockScreenSetting": self.alertSettingToString(settings.lockScreenSetting),
                    "notificationCenterSetting": self.alertSettingToString(settings.notificationCenterSetting)
                ]
                callback.onSuccess(settingsInfo)
            }
        }
    }
    
    /// 清除所有通知
    private func handleClearAllNotifications(callback: JDBridgeCallBack) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        // 清除应用角标
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        callback.onSuccess(["success": true])
    }
    
    // MARK: - 辅助方法
    
    private func authorizationStatusToString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
    
    private func alertSettingToString(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "notSupported"
        case .disabled: return "disabled"
        case .enabled: return "enabled"
        @unknown default: return "unknown"
        }
    }
}
