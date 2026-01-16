//
//  PerformanceMonitor.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import UIKit

/// 性能监控器
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var startTime: CFTimeInterval = 0
    private var memoryUsage: [String: Double] = [:]
    private var cpuUsage: [String: Double] = [:]
    
    private init() {
        startMemoryMonitoring()
    }
    
    // MARK: - 公共方法
    
    /// 开始性能监控
    func startMonitoring() {
        startTime = CACurrentMediaTime()
        Logger.shared.info("性能监控开始")
    }
    
    /// 结束性能监控
    func endMonitoring() -> PerformanceReport {
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        
        let report = PerformanceReport(
            duration: duration,
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: getCurrentCPUUsage(),
            timestamp: Date()
        )
        
        Logger.shared.info("性能监控结束，耗时: \(duration)秒")
        return report
    }
    
    /// 记录内存使用
    func recordMemoryUsage(for key: String) {
        memoryUsage[key] = getCurrentMemoryUsage()
    }
    
    /// 记录CPU使用
    func recordCPUUsage(for key: String) {
        cpuUsage[key] = getCurrentCPUUsage()
    }
    
    /// 获取性能报告
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            duration: 0,
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: getCurrentCPUUsage(),
            timestamp: Date()
        )
    }
    
    // MARK: - 私有方法
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let memory = self.getCurrentMemoryUsage()
            if memory > 100 * 1024 * 1024 { // 100MB
                Logger.shared.warning("内存使用过高: \(memory / 1024 / 1024)MB")
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
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
            return Double(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        if result == KERN_SUCCESS {
            let cpuInfo = info.withMemoryRebound(to: processor_cpu_load_info_t.self, capacity: 1) { $0 }
            let cpuLoad = cpuInfo.pointee
            
            let user = Double(cpuLoad.cpu_ticks.0)
            let system = Double(cpuLoad.cpu_ticks.1)
            let idle = Double(cpuLoad.cpu_ticks.2)
            let nice = Double(cpuLoad.cpu_ticks.3)
            
            let total = user + system + idle + nice
            let usage = (user + system + nice) / total * 100
            
            info.deallocate()
            return usage
        }
        
        info.deallocate()
        return 0
    }
}

/// 性能报告
struct PerformanceReport: Codable {
    let duration: Double
    let memoryUsage: Double
    let cpuUsage: Double
    let timestamp: Date
    
    var memoryUsageMB: Double {
        return memoryUsage / 1024 / 1024
    }
    
    var formattedReport: String {
        return """
        性能报告:
        - 耗时: \(String(format: "%.3f", duration))秒
        - 内存使用: \(String(format: "%.2f", memoryUsageMB))MB
        - CPU使用: \(String(format: "%.2f", cpuUsage))%
        - 时间: \(DateFormatter.performanceFormatter.string(from: timestamp))
        """
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let performanceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
