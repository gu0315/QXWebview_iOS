//
//  QXBleUtils.swift
//  MJExtension
//
//  蓝牙工具类
//  功能：提供数据格式化、权限检查、回调Key、数据转换等通用能力
//  作者：顾钱想
//  日期：2025/12/23
//

import Foundation
import CoreBluetooth
import UIKit

/// 蓝牙工具类，提供数据格式化、权限检查、回调管理等通用功能
public class QXBleUtils {
    
    // MARK: - 数据格式化方法
    
    /// 格式化外设数据为字典数组
    /// - Parameters:
    ///   - peripherals: 蓝牙外设数组
    ///   - rssiCache: RSSI缓存（key: deviceId, value: RSSI）
    /// - Returns: 格式化后的字典数组
    public static func formatPeripherals(_ peripherals: [CBPeripheral], rssiCache: [String: NSNumber] = [:]) -> [[String: Any?]] {
        return peripherals.map { peripheral in
            let deviceId = peripheral.identifier.uuidString
            return [
                "deviceId": deviceId,                          // 设备唯一标识
                "name": peripheral.name,                       // 设备名称
                "rssi": rssiCache[deviceId]?.intValue,         // 信号强度（来源于扫描回调缓存）
                "state": peripheral.state.rawValue             // 连接状态
            ]
        }
    }
    
    /// 格式化服务数据为字典数组
    /// - Parameter services: 蓝牙服务数组
    /// - Returns: 格式化后的字典数组
    public static func formatServices(_ services: [CBService]) -> [[String: Any]] {
        return services.map { service in
            [
                "serviceId": service.uuid.uuidString,          // 服务UUID
                "isPrimary": service.isPrimary,                // 是否为主服务
                "characteristicIds": [] as [String]            // 特征值ID列表（预留）
            ]
        }
    }
    
    /// 格式化特征数据为字典数组
    /// - Parameters:
    ///   - chars: 蓝牙特征数组
    ///   - serviceId: 所属服务的UUID
    /// - Returns: 格式化后的字典数组
    public static func formatCharacteristics(_ chars: [CBCharacteristic], serviceId: String) -> [[String: Any]] {
        return chars.map { char in
            [
                "serviceId": serviceId,                                        // 所属服务UUID
                "characteristicId": char.uuid.uuidString,                      // 特征值UUID
                "properties": formatCharacteristicProperties(char.properties), // 特征值属性列表
                "isNotifying": char.isNotifying                                // 是否已开启通知
            ]
        }
    }
    
    /// 格式化特征属性为字符串数组
    /// - Parameter properties: 特征属性位掩码
    /// - Returns: 属性名称数组
    private static func formatCharacteristicProperties(_ properties: CBCharacteristicProperties) -> [String] {
        var props: [String] = []
        
        // 检查各种属性并添加到数组
        if properties.contains(.read) { props.append("read") }
        if properties.contains(.write) { props.append("write") }
        if properties.contains(.writeWithoutResponse) { props.append("writeWithoutResponse") }
        if properties.contains(.notify) { props.append("notify") }
        if properties.contains(.indicate) { props.append("indicate") }
        if properties.contains(.broadcast) { props.append("broadcast") }
        if properties.contains(.authenticatedSignedWrites) { props.append("authenticatedSignedWrites") }
        if properties.contains(.extendedProperties) { props.append("extendedProperties") }
        
        return props
    }
    
    // MARK: - 回调Key管理方法
    
    /// 生成回调Key（仅前缀）
    /// - Parameter prefix: 回调类型前缀
    /// - Returns: 回调Key字符串
    public static func generateCallbackKey(prefix: String) -> String {
        return "\(prefix)"
    }
    
    /// 生成回调Key（前缀+设备ID）
    /// - Parameters:
    ///   - prefix: 回调类型前缀
    ///   - deviceId: 设备唯一标识（可选）
    /// - Returns: 回调Key字符串
    public static func generateCallbackKey(prefix: String, deviceId: String = "") -> String {
        guard !deviceId.isEmpty else {
            return prefix
        }
        return "\(prefix)_\(deviceId)"
    }
    
    /// 生成回调Key（使用枚举类型）
    /// - Parameters:
    ///   - type: 回调类型枚举
    ///   - deviceId: 设备唯一标识（可选）
    /// - Returns: 回调Key字符串
    public static func generateCallbackKey(type: QXBleCallbackType, deviceId: String = "") -> String {
        return generateCallbackKey(prefix: type.prefix, deviceId: deviceId)
    }
    
    /// 从回调Key中提取类型前缀
    /// - Parameter key: 回调Key字符串
    /// - Returns: 类型前缀（如果存在）
    public static func getCallbackTypePrefix(from key: String) -> String? {
        return key.components(separatedBy: "_").first
    }
    
    /// 从回调Key中提取设备ID
    /// - Parameter key: 回调Key字符串
    /// - Returns: 设备ID（如果存在）
    public static func getDeviceId(from key: String) -> String? {
        let components = key.components(separatedBy: "_")
        return components.count >= 2 ? components[1] : nil
    }
    
    // MARK: - 蓝牙权限检查方法
    /// 检查蓝牙权限状态。
    public static func checkBluetoothPermission() -> CBManagerAuthorization {
        return CBCentralManager.authorization
    }

    /// 判断蓝牙权限是否已授权
    public static func isBluetoothPermissionAuthorized() -> Bool {
        let auth = checkBluetoothPermission()
        return auth == .allowedAlways
    }

    /// 判断蓝牙权限是否被拒绝
    public static func isBluetoothPermissionDenied() -> Bool {
        let auth = checkBluetoothPermission()
        return auth == .denied
    }

    /// 判断蓝牙权限是否未确定
    public static func isBluetoothPermissionNotDetermined() -> Bool {
        let auth = checkBluetoothPermission()
        return auth == .notDetermined
    }
    
    /// 打开应用设置页面（用于用户手动授权蓝牙权限）
    public static func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            print("无法打开设置页面：URL无效")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl, options: [:]) { success in
                if success {
                    print("已成功打开应用设置页面")
                } else {
                    print("打开应用设置页面失败")
                }
            }
        } else {
            print("无法打开设置页面：系统不支持")
        }
    }
    
    // MARK: - 数据类型转换方法
    
    /// 数据类型枚举
    public enum DataType: String {
        case base64 = "BASE64"
        case buffer = "BUFFER"
        case hex = "HEX"
        case hex16 = "16进制"
        case utf8 = "UTF8"
        case text = "TEXT"
        
        /// 从字符串创建数据类型（不区分大小写）
        public static func from(_ string: String?) -> DataType {
            guard let str = string?.uppercased() else { return .utf8 }
            return DataType(rawValue: str) ?? .utf8
        }
    }
    
    /// 将任意类型的value转换为Data
    /// - Parameters:
    ///   - value: 原始数据（可以是String、[Int]等）
    ///   - type: 数据类型（BASE64/BUFFER/HEX/UTF8等）
    /// - Returns: 转换后的Data，失败返回nil
    public static func convertToData(value: Any?, type: DataType) -> Data? {
        guard let value = value else {
            print("❌ 数据为空")
            return nil
        }
        
        switch type {
        case .base64:
            return parseBase64(value)
            
        case .buffer:
            return parseBuffer(value)
            
        case .hex, .hex16:
            return parseHex(value)
            
        case .utf8, .text:
            return parseUTF8(value)
        }
    }
    
    /// 解析Base64格式数据
    private static func parseBase64(_ value: Any) -> Data? {
        guard let valueStr = value as? String, !valueStr.isEmpty else {
            print("❌ Base64数据为空")
            return nil
        }
        
        guard let data = Data(base64Encoded: valueStr) else {
            print("❌ Base64数据解析失败：\(valueStr)")
            return nil
        }
        
        return data
    }
    
    /// 解析BUFFER格式数据（支持[Int]/JSON数组字符串/逗号分隔字符串）
    private static func parseBuffer(_ value: Any) -> Data? {
        var intArray = [Int]()
        
        // 处理数组类型：前端Array.from(Uint8Array)传入的[104,101]
        if let array = value as? [Int] {
            intArray = array
        }
        // 处理字符串类型：JSON数组"[104,101]" / 逗号分隔"104,101"
        else if let valueStr = value as? String, !valueStr.isEmpty {
            let trimmed = valueStr.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = trimmed.starts(with: "[") && trimmed.hasSuffix("]")
                ? String(trimmed.dropFirst().dropLast())
                : trimmed
            intArray = content.components(separatedBy: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
        }
        
        // 空数组/解析失败校验
        guard !intArray.isEmpty else {
            print("❌ BUFFER数据解析后为空/类型不支持：\(type(of: value))")
            return nil
        }
        
        // Uint8范围校验（0-255）+ 转Data
        var bufferData = Data(capacity: intArray.count)
        for (index, intVal) in intArray.enumerated() {
            guard intVal >= 0 && intVal <= 255 else {
                print("❌ BUFFER第\(index)位值\(intVal)超出Uint8范围(0-255)")
                return nil
            }
            bufferData.append(UInt8(intVal))
        }
        
        return bufferData
    }
    
    /// 解析16进制格式数据（兼容空格、大小写）
    private static func parseHex(_ value: Any) -> Data? {
        guard let valueStr = value as? String, !valueStr.isEmpty else {
            print("❌ 16进制数据为空")
            return nil
        }
        
        let cleanedHex = valueStr.replacingOccurrences(of: " ", with: "").uppercased()
        
        guard cleanedHex.count % 2 == 0 else {
            print("❌ 16进制数据长度不合法（非偶数）：\(valueStr)")
            return nil
        }
        
        let length = cleanedHex.count / 2
        var hexData = Data(capacity: length)
        
        for i in 0..<length {
            let start = cleanedHex.index(cleanedHex.startIndex, offsetBy: i * 2)
            let end = cleanedHex.index(start, offsetBy: 2)
            guard let byte = UInt8(cleanedHex[start..<end], radix: 16) else {
                print("❌ 16进制解析失败：\(cleanedHex[start..<end])")
                return nil
            }
            hexData.append(byte)
        }
        
        return hexData
    }
    
    /// 解析UTF8/文本格式数据
    private static func parseUTF8(_ value: Any) -> Data? {
        guard let valueStr = value as? String, !valueStr.isEmpty else {
            print("❌ UTF8数据为空")
            return nil
        }
        
        guard let data = valueStr.data(using: .utf8) else {
            print("❌ UTF8数据解析失败：\(valueStr)")
            return nil
        }
        
        return data
    }
}
