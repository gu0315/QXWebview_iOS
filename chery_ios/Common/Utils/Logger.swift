//
//  Logger.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import os.log

/// 日志级别
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// 统一日志管理器
class Logger {
    static let shared = Logger()
    
    private let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "chery_ios", category: "App")
    
    private init() {}
    
    /// 记录日志
    func log(_ message: String, 
             level: LogLevel = .info,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        let logMessage = "\(level.emoji) [\(level.rawValue)] \(timestamp) \(fileName):\(line) \(function) - \(message)"
        
        print(logMessage)
        
        // 使用系统日志
        os_log("%{public}@", log: osLog, type: .default, logMessage)
        #endif
    }
    
    /// 调试日志
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    /// 信息日志
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    /// 警告日志
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    /// 错误日志
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
