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
    
    /// 生成回调Key（前缀+设备ID+服务ID）
    /// - Parameters:
    ///   - prefix: 回调类型前缀
    ///   - deviceId: 设备唯一标识
    ///   - serviceId: 服务UUID
    /// - Returns: 回调Key字符串
    public static func generateCallbackKey(prefix: String, deviceId: String, serviceId: String) -> String {
        return "\(generateCallbackKey(prefix: prefix, deviceId: deviceId))_\(serviceId)"
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
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization
        }
        return legacyBluetoothPermission()
    }

    @available(iOS, introduced: 2.0, deprecated: 13.0)
    private static func legacyBluetoothPermission() -> CBManagerAuthorization {
        switch CBPeripheralManager.authorizationStatus() {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .allowedAlways
        @unknown default:
            return .notDetermined
        }
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
            QXBleLogger.log("无法打开设置页面：URL无效")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl, options: [:]) { success in
                if success {
                    QXBleLogger.log("已成功打开应用设置页面")
                } else {
                    QXBleLogger.log("打开应用设置页面失败")
                }
            }
        } else {
            QXBleLogger.log("无法打开设置页面：系统不支持")
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
            QXBleLogger.log("❌ 数据为空")
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
            QXBleLogger.log("❌ Base64数据为空")
            return nil
        }
        
        guard let data = Data(base64Encoded: valueStr) else {
            QXBleLogger.log("❌ Base64数据解析失败：\(valueStr)")
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
            QXBleLogger.log("❌ BUFFER数据解析后为空/类型不支持：\(type(of: value))")
            return nil
        }
        
        // Uint8范围校验（0-255）+ 转Data
        var bufferData = Data(capacity: intArray.count)
        for (index, intVal) in intArray.enumerated() {
            guard intVal >= 0 && intVal <= 255 else {
                QXBleLogger.log("❌ BUFFER第\(index)位值\(intVal)超出Uint8范围(0-255)")
                return nil
            }
            bufferData.append(UInt8(intVal))
        }
        
        return bufferData
    }
    
    /// 解析16进制格式数据（兼容空格、大小写）
    private static func parseHex(_ value: Any) -> Data? {
        guard let valueStr = value as? String, !valueStr.isEmpty else {
            QXBleLogger.log("❌ 16进制数据为空")
            return nil
        }
        
        let cleanedHex = valueStr.replacingOccurrences(of: " ", with: "").uppercased()
        
        guard cleanedHex.count % 2 == 0 else {
            QXBleLogger.log("❌ 16进制数据长度不合法（非偶数）：\(valueStr)")
            return nil
        }
        
        let length = cleanedHex.count / 2
        var hexData = Data(capacity: length)
        
        for i in 0..<length {
            let start = cleanedHex.index(cleanedHex.startIndex, offsetBy: i * 2)
            let end = cleanedHex.index(start, offsetBy: 2)
            guard let byte = UInt8(cleanedHex[start..<end], radix: 16) else {
                QXBleLogger.log("❌ 16进制解析失败：\(cleanedHex[start..<end])")
                return nil
            }
            hexData.append(byte)
        }
        
        return hexData
    }
    
    /// 解析UTF8/文本格式数据
    private static func parseUTF8(_ value: Any) -> Data? {
        guard let valueStr = value as? String, !valueStr.isEmpty else {
            QXBleLogger.log("❌ UTF8数据为空")
            return nil
        }
        
        guard let data = valueStr.data(using: .utf8) else {
            QXBleLogger.log("❌ UTF8数据解析失败：\(valueStr)")
            return nil
        }

        return data
    }
}

// MARK: - 回调容器
/// 统一封装蓝牙模块的回调容器：注册、查找、取出、按前缀批量处理，
/// 并提供可选的超时兜底，避免 CoreBluetooth 不回调时 JS 端 Promise 永远悬挂。
///
/// 说明：所有调用都在 CBCentralManager 注册时指定的队列上（目前是 main 队列），
/// 因此内部不做线程同步，调用方保证单线程访问。
public final class QXBleCallbackStore {
    private var callbacks: [String: JDBridgeCallBack] = [:]
    private var timeoutItems: [String: DispatchWorkItem] = [:]

    public init() {}

    public var isEmpty: Bool { callbacks.isEmpty }

    /// 注册回调；nil 会被忽略。覆盖旧 key 时会同时取消旧的超时。
    public func register(_ callback: JDBridgeCallBack?, forKey key: String) {
        guard let callback else { return }
        cancelTimeout(forKey: key)
        callbacks[key] = callback
    }

    /// 注册回调并附带超时兜底。
    /// - Parameters:
    ///   - timeout: <=0 表示不设超时。
    ///   - onTimeout: 超时时回调，参数是已经从字典移除的 callback。
    public func register(_ callback: JDBridgeCallBack?,
                         forKey key: String,
                         timeout: TimeInterval,
                         onTimeout: @escaping (JDBridgeCallBack) -> Void) {
        register(callback, forKey: key)
        guard callbacks[key] != nil, timeout > 0 else { return }
        armTimeout(forKey: key, after: timeout, onTimeout: onTimeout)
    }

    public func callback(forKey key: String) -> JDBridgeCallBack? {
        callbacks[key]
    }

    public func contains(_ key: String) -> Bool {
        callbacks[key] != nil
    }

    /// 拿到所有 key 的快照（数组），避免外部直接迭代字典时遭遇并发修改。
    public func keysSnapshot() -> [String] {
        Array(callbacks.keys)
    }

    /// 取出回调并从容器中移除，同时取消超时。
    @discardableResult
    public func take(forKey key: String) -> JDBridgeCallBack? {
        cancelTimeout(forKey: key)
        return callbacks.removeValue(forKey: key)
    }

    /// 仅移除，不触发回调。
    public func remove(forKey key: String) {
        cancelTimeout(forKey: key)
        callbacks.removeValue(forKey: key)
    }

    /// 仅遍历，不移除（适合"通知所有人"场景，由调用方决定是否 take）。
    public func forEach(matchingPrefix prefix: String, _ body: (String, JDBridgeCallBack) -> Void) {
        callbacks.forEach { key, callback in
            guard QXBleUtils.getCallbackTypePrefix(from: key) == prefix else { return }
            body(key, callback)
        }
    }

    /// 把命中前缀的回调全部取出并交给调用方处理。
    public func takeAll(matchingPrefix prefix: String, _ body: (JDBridgeCallBack) -> Void) {
        takeAll(matching: { QXBleUtils.getCallbackTypePrefix(from: $0) == prefix }, body)
    }

    /// 自定义条件批量取出。
    public func takeAll(matching predicate: (String) -> Bool, _ body: (JDBridgeCallBack) -> Void) {
        let matchedKeys = callbacks.keys.filter(predicate)
        matchedKeys.forEach { key in
            guard let callback = take(forKey: key) else { return }
            body(callback)
        }
    }

    /// 一次性取出全部回调（清空容器），常用于关闭适配器时统一 fail。
    public func takeAll(_ body: (JDBridgeCallBack) -> Void) {
        let snapshot = Array(callbacks.values)
        timeoutItems.values.forEach { $0.cancel() }
        timeoutItems.removeAll()
        callbacks.removeAll()
        snapshot.forEach(body)
    }

    /// 直接清空，不触发任何回调（极少用，仅在确定无需通知时使用）。
    public func removeAllSilently() {
        timeoutItems.values.forEach { $0.cancel() }
        timeoutItems.removeAll()
        callbacks.removeAll()
    }

    // MARK: - Private

    private func armTimeout(forKey key: String,
                            after delay: TimeInterval,
                            onTimeout: @escaping (JDBridgeCallBack) -> Void) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 取出回调（会自动 cancelTimeout，但此时 workItem 已经在执行）
            guard let callback = self.callbacks.removeValue(forKey: key) else { return }
            self.timeoutItems.removeValue(forKey: key)
            onTimeout(callback)
        }
        timeoutItems[key] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelTimeout(forKey key: String) {
        timeoutItems.removeValue(forKey: key)?.cancel()
    }
}

// MARK: - 蓝牙日志
/// 蓝牙模块统一日志入口。Release 包下编译为空实现，
/// 既保留 Debug 时排查问题的便利，又避免生产环境刷屏。
public enum QXBleLogger {
    #if DEBUG
    @inline(__always)
    public static func log(_ items: Any...,
                           file: String = #fileID,
                           line: Int = #line) {
        let message = items.map { "\($0)" }.joined(separator: " ")
        Swift.print(message)
    }
    #else
    @inline(__always)
    public static func log(_ items: Any...,
                           file: String = #fileID,
                           line: Int = #line) {
        // Release 构建：空实现，调用点被优化掉
    }
    #endif
}
