//
//  CacheManager.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import UIKit

/// 缓存管理器
class CacheManager {
    static let shared = CacheManager()
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // 设置内存缓存限制
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // 创建缓存目录
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("AppCache")
        
        createCacheDirectoryIfNeeded()
    }
    
    // MARK: - 公共方法
    
    /// 设置缓存
    func setCache<T: Codable>(_ object: T, forKey key: String, expirationTime: TimeInterval? = nil) {
        let cacheKey = NSString(string: key)
        
        // 内存缓存
        let cacheObject = CacheObject(object: object, expirationTime: expirationTime)
        memoryCache.setObject(cacheObject as AnyObject, forKey: cacheKey)
        
        // 磁盘缓存
        saveToDisk(object, forKey: key, expirationTime: expirationTime)
    }
    
    /// 获取缓存
    func getCache<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let cacheKey = NSString(string: key)
        
        // 先从内存缓存获取
        if let cacheObject = memoryCache.object(forKey: cacheKey) as? CacheObject<T> {
            if cacheObject.isValid {
                return cacheObject.object
            } else {
                memoryCache.removeObject(forKey: cacheKey)
            }
        }
        
        // 从磁盘缓存获取
        return loadFromDisk(type, forKey: key)
    }
    
    /// 删除缓存
    func removeCache(forKey key: String) {
        let cacheKey = NSString(string: key)
        memoryCache.removeObject(forKey: cacheKey)
        
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// 清除所有缓存
    func clearAllCache() {
        memoryCache.removeAllObjects()
        
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
    }
    
    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    /// 清理过期缓存
    func cleanExpiredCache() {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        
        let now = Date()
        for case let fileURL as URL in enumerator {
            if let modificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                // 如果文件超过7天未修改，删除它
                if now.timeIntervalSince(modificationDate) > 7 * 24 * 3600 {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func saveToDisk<T: Codable>(_ object: T, forKey key: String, expirationTime: TimeInterval?) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        let cacheObject = CacheObject(object: object, expirationTime: expirationTime)
        
        do {
            let data = try JSONEncoder().encode(cacheObject)
            try data.write(to: fileURL)
        } catch {
            Logger.shared.error("保存缓存到磁盘失败: \(error)")
        }
    }
    
    private func loadFromDisk<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        
        do {
            let cacheObject = try JSONDecoder().decode(CacheObject<T>.self, from: data)
            if cacheObject.isValid {
                return cacheObject.object
            } else {
                // 缓存已过期，删除文件
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        } catch {
            Logger.shared.error("从磁盘加载缓存失败: \(error)")
            return nil
        }
    }
}

/// 缓存对象
private struct CacheObject<T: Codable>: Codable {
    let object: T
    let expirationTime: TimeInterval?
    let creationTime: Date
    
    init(object: T, expirationTime: TimeInterval?) {
        self.object = object
        self.expirationTime = expirationTime
        self.creationTime = Date()
    }
    
    var isValid: Bool {
        guard let expirationTime = expirationTime else { return true }
        return Date().timeIntervalSince(creationTime) < expirationTime
    }
}
