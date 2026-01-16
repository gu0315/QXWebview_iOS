//
//  MemoryManager.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import UIKit

/// 内存管理器
class MemoryManager {
    static let shared = MemoryManager()
    
    private var memoryWarningObserver: NSObjectProtocol?
    private let memoryThreshold: Double = 100 * 1024 * 1024 // 100MB
    
    private init() {
        setupMemoryWarningObserver()
        startMemoryMonitoring()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - 公共方法
    
    /// 获取当前内存使用情况
    func getCurrentMemoryUsage() -> MemoryInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return MemoryInfo(
                residentSize: Double(info.resident_size),
                virtualSize: Double(info.virtual_size),
                timestamp: Date()
            )
        } else {
            return MemoryInfo(residentSize: 0, virtualSize: 0, timestamp: Date())
        }
    }
    
    /// 清理内存
    func cleanupMemory() {
        Logger.shared.info("开始清理内存")
        
        // 清理缓存
        CacheManager.shared.cleanExpiredCache()
        
        // 清理URL缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 强制垃圾回收
        autoreleasepool {
            // 这里可以添加其他清理逻辑
        }
        
        let beforeMemory = getCurrentMemoryUsage()
        Logger.shared.info("内存清理前: \(beforeMemory.residentSizeMB)MB")
        
        // 等待一段时间让系统回收内存
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let afterMemory = self.getCurrentMemoryUsage()
            Logger.shared.info("内存清理后: \(afterMemory.residentSizeMB)MB")
        }
    }
    
    /// 检查内存使用是否过高
    func isMemoryUsageHigh() -> Bool {
        let memoryInfo = getCurrentMemoryUsage()
        return memoryInfo.residentSize > memoryThreshold
    }
    
    // MARK: - 私有方法
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Logger.shared.warning("收到内存警告")
            self?.handleMemoryWarning()
        }
    }
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let memoryInfo = self.getCurrentMemoryUsage()
            
            if memoryInfo.residentSize > self.memoryThreshold {
                Logger.shared.warning("内存使用过高: \(memoryInfo.residentSizeMB)MB")
                self.cleanupMemory()
            }
        }
    }
    
    private func handleMemoryWarning() {
        cleanupMemory()
        
        // 通知其他组件进行内存清理
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryWarningReceived"),
            object: nil
        )
    }
}

/// 内存信息
struct MemoryInfo {
    let residentSize: Double
    let virtualSize: Double
    let timestamp: Date
    
    var residentSizeMB: Double {
        return residentSize / 1024 / 1024
    }
    
    var virtualSizeMB: Double {
        return virtualSize / 1024 / 1024
    }
    
    var formattedInfo: String {
        return """
        内存使用情况:
        - 物理内存: \(String(format: "%.2f", residentSizeMB))MB
        - 虚拟内存: \(String(format: "%.2f", virtualSizeMB))MB
        - 时间: \(DateFormatter.memoryFormatter.string(from: timestamp))
        """
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let memoryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
