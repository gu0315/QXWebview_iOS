//
//  UserDefaultsManager.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation

/// 用户偏好设置管理器
class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - 通用方法
    
    /// 设置值
    func set<T>(_ value: T, forKey key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }
    
    /// 获取值
    func get<T>(_ type: T.Type, forKey key: String) -> T? {
        return userDefaults.object(forKey: key) as? T
    }
    
    /// 获取值，如果不存在则返回默认值
    func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T {
        return userDefaults.object(forKey: key) as? T ?? defaultValue
    }
    
    /// 删除值
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
    }
    
    /// 检查键是否存在
    func hasKey(_ key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
    
    // MARK: - 应用特定设置
    
    /// 应用首次启动
    var isFirstLaunch: Bool {
        get { get(Bool.self, forKey: "isFirstLaunch", defaultValue: true) }
        set { set(newValue, forKey: "isFirstLaunch") }
    }
    
    /// 用户偏好设置
    var userPreferences: [String: Any] {
        get { get([String: Any].self, forKey: "userPreferences", defaultValue: [:]) }
        set { set(newValue, forKey: "userPreferences") }
    }
    
    /// 缓存清理时间
    var lastCacheCleanup: Date? {
        get { get(Date.self, forKey: "lastCacheCleanup") }
        set { set(newValue, forKey: "lastCacheCleanup") }
    }
    
    /// 应用版本
    var appVersion: String {
        get { get(String.self, forKey: "appVersion", defaultValue: "") }
        set { set(newValue, forKey: "appVersion") }
    }
    
    /// 设备ID
    var deviceId: String {
        get {
            if let id = get(String.self, forKey: "deviceId"), !id.isEmpty {
                return id
            } else {
                let newId = UUID().uuidString
                set(newId, forKey: "deviceId")
                return newId
            }
        }
    }
}
