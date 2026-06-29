//
//  Utils.swift
//  QXWebView
//
//  Created by 顾钱想 on 1/13/26.
//

import UIKit

class Utils {

    func openThirdPartyApp(url: String) {
        guard let url = URL(string: url) else {
            return
        }
        if (UIApplication.shared.canOpenURL(url)) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - JDBridge onFail 统一错误构造

/// 与 H5 / Android 对齐的 JSBridge 错误码。
/// JDBridge 底层只认 NSError 才会把 status 置为非 0，H5 才能走 catch，
/// 所以所有 `callback.onFail(...)` 必须传 `NSError`，通过本工具统一生成。
@objc public enum QXBridgeErrorCode: Int {
    /// 未知错误
    case unknown = -1
    /// 通用失败
    case failure = 1
    /// 参数错误 / 非法参数
    case invalidParams = 1000
    /// 没有权限（相机 / 定位 / 蓝牙 / 通知 等统一用这个）
    case noPermission = 1001
    /// 用户取消
    case cancelled = 1002
    /// 目标资源 / 页面 / 设备未找到
    case notFound = 1003
    /// 超时
    case timeout = 1004
    /// 功能未实现 / 不支持
    case unsupported = 1005
}

/// JDBridge `onFail` 参数构造工具
///
/// 用法:
/// ```swift
/// callback.onFail(QXBridgeError.make(.noPermission, message: "没有相机权限"))
/// callback.onFail(QXBridgeError.noPermission("没有相机权限"))
/// ```
@objc public class QXBridgeError: NSObject {

    /// 默认的错误 domain（可在各 plugin 里自行传入覆盖）
    public static let defaultDomain = "QXBridgeError"

    /// 生成 NSError，`userInfo` 会同时写入 `message / success / data`，
    /// 并把 `{ "code": ..., "message": ..., "success": false, "data": ... }` 的 JSON 字符串写到
    /// `NSLocalizedDescriptionKey`，这样 JDBridge 底层取 `error.description` 下发给 H5 时，
    /// H5 侧 `JSON.parse(err.message)` 就能拿到结构化字段，与 Android 对齐。
    public static func make(_ code: QXBridgeErrorCode,
                            message: String,
                            domain: String = defaultDomain,
                            data: Any? = nil) -> NSError {
        return make(code: code.rawValue, message: message, domain: domain, data: data)
    }

    /// 直接传原始 Int 错误码的重载，供 BLE 这类有自定义错误码体系的插件使用。
    public static func make(code: Int,
                            message: String,
                            domain: String = defaultDomain,
                            data: Any? = nil) -> NSError {
        var payload: [String: Any] = [
            "code": code,
            "message": message,
            "success": false
        ]
        if let data = data, JSONSerialization.isValidJSONObject(data) {
            payload["data"] = data
        }

        let jsonString: String = {
            if JSONSerialization.isValidJSONObject(payload),
               let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
               let str = String(data: jsonData, encoding: .utf8) {
                return str
            }
            return message
        }()

        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: jsonString,
            "code": code,
            "message": message,
            "success": false
        ]
        if let data = data { userInfo["data"] = data }

        return NSError(domain: domain, code: code, userInfo: userInfo)
    }

    /// 没有权限（相机 / 定位 / 蓝牙 / 通知 等）的快捷方法
    public static func noPermission(_ message: String = "没有权限",
                                    domain: String = defaultDomain,
                                    data: Any? = nil) -> NSError {
        return make(.noPermission, message: message, domain: domain, data: data)
    }

    /// 参数非法
    public static func invalidParams(_ message: String = "参数错误",
                                     domain: String = defaultDomain,
                                     data: Any? = nil) -> NSError {
        return make(.invalidParams, message: message, domain: domain, data: data)
    }

    /// 未找到（VC / 设备 / 资源 等）
    public static func notFound(_ message: String = "资源未找到",
                                domain: String = defaultDomain,
                                data: Any? = nil) -> NSError {
        return make(.notFound, message: message, domain: domain, data: data)
    }

    /// 通用失败
    public static func failure(_ message: String,
                               domain: String = defaultDomain,
                               data: Any? = nil) -> NSError {
        return make(.failure, message: message, domain: domain, data: data)
    }
}



// MARK: - Data Hex Conversion (Standard Implementation)
extension Data {
    /// 【标准】将 Data 转换为十六进制字符串
    /// - Parameter uppercase: 是否大写
    /// - Returns: 纯十六进制字符串，示例：Data([0x68, 0x65]) → "6865"
    func hexEncodedString(uppercase: Bool = false) -> String {
        let format = uppercase ? "%02hhX" : "%02hhx"
        // 补充 & 0xFF：对齐安卓/Kotlin 的 bytes[i] & 255
        return self.map { String(format: format, $0 & 0xFF) }.joined()
    }
    
    /// 转换为带格式的十六进制数组字符串（[xx, xx, xx]）
    /// - Parameter uppercase: 是否大写（默认 false，日志更易读）
    /// - Returns: 格式化字符串，示例：Data([0x68, 0x65]) → "[68, 65]"
    func hexArrayEncodedString(uppercase: Bool = false) -> String {
        guard !isEmpty else { return "[]" }
        let format = uppercase ? "%02hhX" : "%02hhx"
        // 补充 & 0xFF：对齐安卓/Kotlin 的数值处理逻辑
        let hexComponents = self.map { String(format: format, $0 & 0xFF) }
        return "[\(hexComponents.joined(separator: ", "))]"
    }
    
    /// 【反向转换】从纯十六进制字符串解析为 Data（标准方法）
    /// - Parameter hexString: 纯十六进制字符串（无空格/符号），示例："6865"
    /// - Returns: 解析后的 Data，解析失败返回 nil
    static func fromHexEncodedString(_ hexString: String) -> Data? {
        let cleanedString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedString.count % 2 == 0 else { return nil } // 确保字符数为偶数
        var data = Data()
        var index = cleanedString.startIndex
        
        while index < cleanedString.endIndex {
            let endIndex = cleanedString.index(index, offsetBy: 2)
            // 转小写：兼容安卓端的大小写输入
            let hexSub = cleanedString[index..<endIndex].lowercased()
            guard let byte = UInt8(hexSub, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = endIndex
        }
        
        return data
    }
}

// MARK: - 便捷属性（简化调用）
extension Data {
    var hexString: String { hexEncodedString(uppercase: false) }
    var hexArrayString: String { hexArrayEncodedString(uppercase: false) }
}
