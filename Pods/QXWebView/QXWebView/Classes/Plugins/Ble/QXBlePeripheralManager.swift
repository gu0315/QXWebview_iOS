//
//  QXBlePeripheralManager.swift
//  MJExtension
//
//  蓝牙外设管理器单例类
//  功能：负责蓝牙设备的服务/特征发现、数据读写、通知管理
//  遵循CBPeripheralDelegate协议，处理外设相关回调
//  作者：顾钱想
//  日期：2025/12/23
//

import Foundation
import CoreBluetooth

/// 蓝牙外设管理器（全局单例）- 负责服务/特征发现、数据读写
public class QXBlePeripheralManager: NSObject, CBPeripheralDelegate {
    // MARK: - 单例初始化
    /// 全局单例实例
    public static let shared = QXBlePeripheralManager()
    
    /// 私有化构造方法，确保单例唯一性
    private override init() { super.init() }
    
    // MARK: - 核心缓存
    /// 特征缓存（key: deviceId_serviceId）
    private(set) public var characteristicsCache: [String: [CBCharacteristic]] = [:]
    
    /// 服务缓存（key: deviceId）
    private(set) public var servicesCache: [String: [CBService]] = [:]
    
    // MARK: - 回调管理
    /// 回调字典，用于管理各种蓝牙操作的回调
    private var callbacks: [String: JDBridgeCallBack?] = [:]
    
    /// 特征值更新通知回调（用于持续接收特征值变化）
    private var characteristicValueUpdateCallback: JDBridgeCallBack?
    
    // MARK: - 回调管理方法
    /// 注册回调
    /// - Parameters:
    ///   - callback: 回调对象
    ///   - key: 回调键
    public func registerCallback(_ callback: JDBridgeCallBack?, forKey key: String) {
        callbacks[key] = callback
        
        // 如果是特征值更新回调，单独存储
        if key.hasPrefix(QXBleCallbackType.notifyCharacteristic.prefix) {
            characteristicValueUpdateCallback = callback
        }
    }
    
    /// 移除回调
    /// - Parameter key: 回调键
    public func removeCallback(forKey key: String) {
        callbacks.removeValue(forKey: key)
        
        // 如果是特征值更新回调，清空引用
        if key.hasPrefix(QXBleCallbackType.notifyCharacteristic.prefix) {
            characteristicValueUpdateCallback = nil
        }
    }
    
    // MARK: - 服务/特征发现
    /// 发现设备特征
    /// - Parameters:
    ///   - deviceId: 设备唯一标识
    ///   - peripheral: 蓝牙外设实例
    ///   - serviceUUIDs: 要发现的服务UUID数组
    ///   - callback: 发现结果回调
    public func discoverCharacteristics(
        deviceId: String,
        peripheral: CBPeripheral,
        serviceUUIDs: [CBUUID]?,
        callback: JDBridgeCallBack?
    ) {
        // 设备连接状态校验
        guard peripheral.state == .connected else {
            callback?.onFail(QXBleResult.failure(errorCode: .deviceNotFound, customMessage: "设备未连接"))
            return
        }
        
        // 生成回调key并注册
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.discoverCharacteristics.prefix, deviceId: deviceId)
        registerCallback(callback, forKey: callbackKey)
        
        // 开始发现服务
        peripheral.discoverServices(serviceUUIDs)
    }
    
    // MARK: - 特征值操作
    /// 写入特征值
    /// - Parameters:
    ///   - deviceId: 设备唯一标识
    ///   - peripheral: 蓝牙外设实例
    ///   - serviceId: 服务UUID
    ///   - characteristicId: 特征值UUID
    ///   - value: 要写入的数据
    ///   - callback: 写入结果回调
    public func writeValue(
        deviceId: String,
        peripheral: CBPeripheral,
        serviceId: String,
        characteristicId: String,
        value: Data,
        callback: JDBridgeCallBack?
    ) {
        // 设备连接状态校验
        guard peripheral.state == .connected else {
            callback?.onFail(QXBleResult.failure(errorCode: .deviceNotFound, customMessage: "设备未连接"))
            return
        }
        
        // 查找目标特征
        let cacheKey = "\(deviceId)_\(serviceId)"
        guard let chars = characteristicsCache[cacheKey],
              let char = chars.first(where: { $0.uuid.uuidString == characteristicId }) else {
            callback?.onFail(QXBleResult.failure(errorCode: .characteristicNotFound))
            return
        }
        
        // 检查写入权限
        guard char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) else {
            callback?.onFail(QXBleResult.failure(errorCode: .writeNotSupported))
            return
        }
        
        // 生成回调key并注册
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.writeCharacteristic.prefix, deviceId: deviceId)
        registerCallback(callback, forKey: callbackKey)
        
        // 选择写入类型（优先无响应写入）
        let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        
        // 执行写入操作
        peripheral.writeValue(value, for: char, type: writeType)
        
        // 无响应写入直接返回成功（无回调）
        if writeType == .withoutResponse {
            let result = QXBleResult.success(
                data: ["characteristicId": characteristicId],
                message: "已发送写入指令（无响应）"
            )
            callback?.onSuccess(result)
            removeCallback(forKey: callbackKey)
        }
    }
    
    /// 启用/禁用特征通知
    /// - Parameters:
    ///   - deviceId: 设备唯一标识
    ///   - peripheral: 蓝牙外设实例
    ///   - serviceId: 服务UUID
    ///   - characteristicId: 特征值UUID
    ///   - enabled: 是否开启通知
    ///   - callbackKey: 回调标识
    ///   - callback: 操作结果回调
    public func setNotifyValue(
        deviceId: String,
        peripheral: CBPeripheral,
        serviceId: String,
        characteristicId: String,
        enabled: Bool,
        callbackKey: String,
        callback: JDBridgeCallBack?
    ) {
        // 设备连接状态校验
        guard peripheral.state == .connected else {
            callback?.onFail(QXBleResult.failure(errorCode: .deviceNotFound, customMessage: "设备未连接"))
            return
        }
        
        // 查找目标特征
        let cacheKey = "\(deviceId)_\(serviceId)"
        guard let chars = characteristicsCache[cacheKey],
              let char = chars.first(where: { $0.uuid.uuidString == characteristicId }) else {
            callback?.onFail(QXBleResult.failure(errorCode: .characteristicNotFound))
            return
        }
        
        // 检查通知权限
        guard char.properties.contains(.notify) || char.properties.contains(.indicate) else {
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: "特征不支持通知/指示"))
            return
        }
        
        // 注册回调
        registerCallback(callback, forKey: callbackKey)
        
        // 设置通知状态
        peripheral.setNotifyValue(enabled, for: char)
    }
    
    // MARK: - CBPeripheralDelegate 实现
    /// 发现服务回调
    /// 当成功发现设备的蓝牙服务时调用
    /// - Parameters:
    ///   - peripheral: 蓝牙外设实例
    ///   - error: 发现服务的错误信息（如果有）
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.getBLEDeviceServices.prefix, deviceId: deviceId)
        
        // 获取回调对象
        guard let callback = callbacks[callbackKey] else { return }
        
        // 错误处理
        if let error = error {
            let errorMsg = "发现服务失败：\(error.localizedDescription)"
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
            removeCallback(forKey: callbackKey)
            return
        }
        
        // 空服务校验
        guard let services = peripheral.services, !services.isEmpty else {
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: "未发现任何服务"))
            removeCallback(forKey: callbackKey)
            return
        }
        
        // 缓存服务列表
        servicesCache[deviceId] = services
        
        // 发现所有服务的特征
        services.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
        // 格式化服务数据并返回
        let formattedServices = QXBleUtils.formatServices(services)
        callback?.onSuccess(QXBleResult.success(
            data: ["services": formattedServices],
            message: "发现服务成功，共\(services.count)个服务"
        ))
        
        // 清理回调
        removeCallback(forKey: callbackKey)
    }
    
    /// 发现特征回调
    /// 当成功发现服务的蓝牙特征时调用
    /// - Parameters:
    ///   - peripheral: 蓝牙外设实例
    ///   - service: 包含特征的蓝牙服务
    ///   - error: 发现特征的错误信息（如果有）
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        let serviceId = service.uuid.uuidString
        let cacheKey = "\(deviceId)_\(serviceId)"
        
        // 生成回调key
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.discoverCharacteristics.prefix, deviceId: deviceId)
        
        // 获取回调对象
        guard let callback = callbacks[callbackKey] else { return }
        
        // 错误处理
        if let error = error {
            let errorMsg = "发现特征失败：\(error.localizedDescription)"
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
            removeCallback(forKey: callbackKey)
            return
        }
        
        // 空特征校验
        guard let chars = service.characteristics, !chars.isEmpty else {
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: "服务\(serviceId)未发现任何特征"))
            removeCallback(forKey: callbackKey)
            return
        }
        
        // 缓存特征列表
        characteristicsCache[cacheKey] = chars
        
        // 检查是否所有服务都已发现特征
        let allServices = servicesCache[deviceId] ?? []
        let discoveredServiceIds = characteristicsCache.keys
            .filter { $0.hasPrefix("\(deviceId)_") }
            .map { $0.replacingOccurrences(of: "\(deviceId)_", with: "") }
        
        let isAllDiscovered = allServices.allSatisfy { discoveredServiceIds.contains($0.uuid.uuidString) }
        
        // 所有特征发现完成后统一回调
        if isAllDiscovered {
            // 整理所有特征数据
            var allCharacteristics: [[String: Any]] = []
            characteristicsCache.forEach { (cacheKey, chars) in
                let serviceId = cacheKey.replacingOccurrences(of: "\(deviceId)_", with: "")
                allCharacteristics.append(contentsOf: QXBleUtils.formatCharacteristics(chars, serviceId: serviceId))
            }
            
            // 返回特征数据
            let result = QXBleResult.success(
                data: ["characteristics": allCharacteristics],
                message: "获取特征成功，共\(allCharacteristics.count)个特征"
            )
            callback?.onSuccess(result)
            removeCallback(forKey: callbackKey)
        }
    }
    
    /// 写入特征值回调
    /// 当成功写入数据到特征值或写入失败时调用
    /// - Parameters:
    ///   - peripheral: 蓝牙外设实例
    ///   - characteristic: 写入的特征
    ///   - error: 写入操作的错误信息（如果有）
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.writeCharacteristic.prefix, deviceId: deviceId)
        // 获取回调对象
        guard let callback = callbacks[callbackKey] else { return }
        // 处理写入结果
        if let error = error {
            let errorMsg = "写入特征值失败：\(error.localizedDescription)"
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
        } else {
            let result = QXBleResult.success(
                data: [
                    "characteristicId": characteristic.uuid.uuidString,
                    "value": characteristic.value?.base64EncodedString() ?? ""
                ],
                message: "写入特征值成功"
            )
            callback?.onSuccess(result)
        }
        // 清理回调
        removeCallback(forKey: callbackKey)
    }
    
    /// 特征值更新回调
    /// 当特征值发生变化时调用（通常由设备的通知或指示触发）
    /// - Parameters:
    ///   - peripheral: 蓝牙外设实例
    ///   - characteristic: 更新的特征
    ///   - error: 特征值更新的错误信息（如果有）
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // 获取通知回调
        guard let callback = characteristicValueUpdateCallback else { return }
        
        // 处理特征值更新
        if let error = error {
            let errorMsg = "特征值更新失败：\(error.localizedDescription)"
            callback.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
        } else {
            let result = QXBleResult.success(
                data: [
                    "deviceId": peripheral.identifier.uuidString,
                    "characteristicId": characteristic.uuid.uuidString,
                    "value": characteristic.value?.base64EncodedString() ?? "",
                    "hexValue": characteristic.value?.hexString ?? "",
                    "rawValue": characteristic.value ?? Data()
                ],
                message: "特征值已更新"
            )
            callback.onSuccess(result)
        }
    }
    
    /// 通知状态更新回调
    /// 当特征的通知或指示状态发生变化时调用
    /// - Parameters:
    ///   - peripheral: 蓝牙外设实例
    ///   - characteristic: 通知状态变化的特征
    ///   - error: 通知状态更新的错误信息（如果有）
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.notifyCharacteristic.prefix, deviceId: deviceId)
        
        // 获取回调对象
        guard let callback = callbacks[callbackKey] else { return }
        
        // 处理通知状态更新
        if let error = error {
            let errorMsg = "通知状态更新失败：\(error.localizedDescription)"
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
        } else {
            let status = characteristic.isNotifying ? "已开启" : "已关闭"
            let result = QXBleResult.success(
                data: [
                    "deviceId": deviceId,
                    "characteristicId": characteristic.uuid.uuidString,
                    "isNotifying": characteristic.isNotifying
                ],
                message: "特征通知\(status)"
            )
            callback?.onSuccess(result)
        }
        
        // 清理回调（保留特征值更新回调）
        if !callbackKey.hasPrefix(QXBleCallbackType.notifyCharacteristic.prefix) {
            removeCallback(forKey: callbackKey)
        }
    }
}

// MARK: - Data 扩展
/// 扩展Data，提供16进制字符串转换
extension Data {
    /// 转换为16进制字符串
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
