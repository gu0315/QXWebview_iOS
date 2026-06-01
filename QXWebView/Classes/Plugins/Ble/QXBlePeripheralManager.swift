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
    
    /// 最后写入的数据缓存（key: deviceId_characteristicId, value: Data）
    /// 用于在写入回调中返回写入的数据，因为characteristic.value可能为nil
    private var lastWrittenDataCache: [String: Data] = [:]
    
    // MARK: - 回调管理
    /// 统一回调容器（支持可选超时兜底）
    private let callbackStore = QXBleCallbackStore()

    /// 特征值更新通知回调（用于持续接收特征值变化）
    private var characteristicValueUpdateCallback: JDBridgeCallBack?

    /// 默认操作超时（秒）：discover / write(withResponse) / setNotify。
    private static let operationTimeoutSeconds: TimeInterval = 15.0

    // MARK: - 回调管理方法

    /// 注册回调
    /// - Parameters:
    ///   - callback: 回调对象
    ///   - key: 回调键（用于标识不同的操作）
    public func registerCallback(_ callback: JDBridgeCallBack?, forKey key: String) {
        callbackStore.register(callback, forKey: key)
        QXBleLogger.log("📝 注册回调：\(key)")

        // 如果是特征值更新回调，单独存储（用于持续接收通知）
        if key.hasPrefix(QXBleCallbackType.notifyCharacteristic.prefix) {
            characteristicValueUpdateCallback = callback
        }
    }

    /// 注册回调，并附带操作超时；超时后 fail 调用方。
    private func registerCallback(_ callback: JDBridgeCallBack?,
                                  forKey key: String,
                                  timeout: TimeInterval,
                                  timeoutMessage: String) {
        callbackStore.register(callback, forKey: key, timeout: timeout) { callback in
            QXBleLogger.log("⏱️ 操作超时：\(key)")
            callback.onFail(QXBleResult.failure(errorCode: .operateTimeOut, customMessage: timeoutMessage))
        }
        if key.hasPrefix(QXBleCallbackType.notifyCharacteristic.prefix) {
            characteristicValueUpdateCallback = callback
        }
    }

    /// 注册「发现服务 / 发现特征」回调，使用默认操作超时兜底。
    /// 供 plugin 侧 getBLEDeviceServices / getBLEDeviceCharacteristics 使用，
    /// 避免设备连接后迟迟不返回 GATT 结果导致 H5 Promise 永远悬挂。
    public func registerDiscoverCallback(_ callback: JDBridgeCallBack?,
                                         forKey key: String,
                                         timeoutMessage: String) {
        registerCallback(
            callback,
            forKey: key,
            timeout: Self.operationTimeoutSeconds,
            timeoutMessage: timeoutMessage
        )
    }

    /// 移除回调
    /// - Parameter key: 回调键
    public func removeCallback(forKey key: String) {
        callbackStore.remove(forKey: key)
        QXBleLogger.log("🗑️ 移除回调：\(key)")
        // 如果是特征值更新回调，清空引用
        if key.hasPrefix(QXBleCallbackType.notifyCharacteristic.prefix) {
            characteristicValueUpdateCallback = nil
        }
    }

    private func discoverCharacteristicsCallbackKeys(deviceId: String) -> [String] {
        let prefix = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.discoverCharacteristics.prefix,
            deviceId: deviceId
        )
        return callbackStore.keysSnapshot().filter { $0 == prefix || $0.hasPrefix("\(prefix)_") }
    }

    /// 蓝牙状态异常 / 适配器关闭时，把所有外设侧 pending 回调统一 fail。
    public func failAllCallbacks(with error: NSError) {
        callbackStore.takeAll { callback in
            callback.onFail(error)
        }
        characteristicValueUpdateCallback = nil
    }

    /// 设备断开时，把该设备相关的 pending 回调统一 fail。
    public func failCallbacks(for deviceId: String, with error: NSError) {
        let suffix = "_\(deviceId)"
        callbackStore.takeAll(matching: { key in
            // discover/write/notify/getServices 的 key 都是 prefix_<deviceId>(_...)
            QXBleUtils.getDeviceId(from: key) == deviceId
                || key.hasSuffix(suffix)
        }) { callback in
            callback.onFail(error)
        }
        // 通知回调通常是持续订阅，没有 deviceId 区分粒度，这里不动 characteristicValueUpdateCallback。
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
        // 1. 设备连接状态校验
        guard peripheral.state == .connected else {
            callback?.onFail(QXBleResult.failure(errorCode: .noConnection, customMessage: "当前连接已断开"))
            return
        }

        // 2. 查找目标特征
        let normalizedServiceId = CBUUID(string: serviceId).uuidString
        let normalizedCharacteristicId = CBUUID(string: characteristicId).uuidString
        let cacheKey = "\(deviceId)_\(normalizedServiceId)"
        guard let chars = characteristicsCache[cacheKey],
              let char = chars.first(where: { $0.uuid.uuidString == normalizedCharacteristicId }) else {
            callback?.onFail(QXBleResult.failure(errorCode: .characteristicNotFound))
            return
        }

        // 3. 检查写入权限
        guard char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) else {
            callback?.onFail(QXBleResult.failure(errorCode: .propertyNotSupport, customMessage: "当前特征值不支持写入"))
            return
        }

        // 4. 缓存写入的数据（用于回调时返回）
        let dataCacheKey = "\(deviceId)_\(normalizedCharacteristicId)"
        lastWrittenDataCache[dataCacheKey] = value

        // 5. 生成回调key
        let callbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.writeCharacteristic.prefix,
            deviceId: deviceId,
            serviceId: normalizedCharacteristicId
        )

        let writeType: CBCharacteristicWriteType = char.properties.contains(.write) ? .withResponse : .withoutResponse

        // 6. 无响应写入：iOS 不回调，直接返回成功
        if writeType == .withoutResponse {
            peripheral.writeValue(value, for: char, type: writeType)
            let result = QXBleResult.success(
                data: [
                    "characteristicId": characteristicId,
                    "value": value.hexString
                ],
                message: "已发送写入指令（无响应）"
            )
            callback?.onSuccess(result)
            lastWrittenDataCache.removeValue(forKey: dataCacheKey)
            return
        }

        // 7. 有响应写入：注册回调（含超时兜底）后再发起
        registerCallback(
            callback,
            forKey: callbackKey,
            timeout: Self.operationTimeoutSeconds,
            timeoutMessage: "写入特征值超时"
        )
        peripheral.writeValue(value, for: char, type: writeType)
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
        let normalizedServiceId = CBUUID(string: serviceId).uuidString
        let normalizedCharacteristicId = CBUUID(string: characteristicId).uuidString
        let cacheKey = "\(deviceId)_\(normalizedServiceId)"
        guard let chars = characteristicsCache[cacheKey],
              let char = chars.first(where: { $0.uuid.uuidString == normalizedCharacteristicId }) else {
            callback?.onFail(QXBleResult.failure(errorCode: .characteristicNotFound))
            return
        }

        // 检查通知权限
        guard char.properties.contains(.notify) || char.properties.contains(.indicate) else {
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: "特征不支持通知/指示"))
            return
        }

        // 注册回调（含超时兜底）
        registerCallback(
            callback,
            forKey: callbackKey,
            timeout: Self.operationTimeoutSeconds,
            timeoutMessage: "设置通知状态超时"
        )

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
        let servicesCallbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.getBLEDeviceServices.prefix, deviceId: deviceId)
        let discoverCharsCallbackKeys = discoverCharacteristicsCallbackKeys(deviceId: deviceId)

        let hasServicesCallback = callbackStore.contains(servicesCallbackKey)
        guard hasServicesCallback || !discoverCharsCallbackKeys.isEmpty else { return }

        // 错误处理
        if let error = error {
            let errorMsg = "发现服务失败：\(error.localizedDescription)"
            let result = QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg)
            callbackStore.take(forKey: servicesCallbackKey)?.onFail(result)
            discoverCharsCallbackKeys.forEach { callbackStore.take(forKey: $0)?.onFail(result) }
            return
        }

        // 空服务校验
        guard let services = peripheral.services, !services.isEmpty else {
            let result = QXBleResult.failure(errorCode: .unknownError, customMessage: "未发现任何服务")
            callbackStore.take(forKey: servicesCallbackKey)?.onFail(result)
            discoverCharsCallbackKeys.forEach { callbackStore.take(forKey: $0)?.onFail(result) }
            return
        }

        // 缓存服务列表
        servicesCache[deviceId] = services

        // 发现所有服务的特征
        services.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }

        // 仅服务查询场景返回服务数据；特征查询场景在 didDiscoverCharacteristicsFor 中回调
        if let callback = callbackStore.take(forKey: servicesCallbackKey) {
            let formattedServices = QXBleUtils.formatServices(services)
            QXBleLogger.log("服务列表：\(formattedServices)")
            callback.onSuccess(QXBleResult.success(
                data: ["services": formattedServices],
                message: "发现服务成功，共\(services.count)个服务"
            ))
        }
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

        // 优先匹配服务粒度回调；保留设备粒度回调兼容旧的内部 discoverCharacteristics 调用。
        let serviceCallbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.discoverCharacteristics.prefix,
            deviceId: deviceId,
            serviceId: serviceId
        )
        let deviceCallbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.discoverCharacteristics.prefix,
            deviceId: deviceId
        )
        let callbackKey = callbackStore.contains(serviceCallbackKey) ? serviceCallbackKey : deviceCallbackKey

        // 错误处理：失败时直接取出回调
        if let error = error {
            let errorMsg = "发现特征失败：\(error.localizedDescription)"
            callbackStore.take(forKey: callbackKey)?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
            return
        }

        let chars = service.characteristics ?? []

        // 缓存特征列表
        characteristicsCache[cacheKey] = chars

        if callbackKey == serviceCallbackKey {
            guard let callback = callbackStore.take(forKey: callbackKey) else { return }
            let result = QXBleResult.success(
                data: ["characteristics": QXBleUtils.formatCharacteristics(chars, serviceId: serviceId)],
                message: "获取特征成功，共\(chars.count)个特征"
            )
            callback.onSuccess(result)
            return
        }

        // 设备粒度：等待所有服务都发现特征后再统一回调
        guard callbackStore.contains(deviceCallbackKey) else { return }

        let allServices = servicesCache[deviceId] ?? []
        let discoveredServiceIds = characteristicsCache.keys
            .filter { $0.hasPrefix("\(deviceId)_") }
            .map { $0.replacingOccurrences(of: "\(deviceId)_", with: "") }

        let isAllDiscovered = allServices.allSatisfy { discoveredServiceIds.contains($0.uuid.uuidString) }
        guard isAllDiscovered else { return }

        var allCharacteristics: [[String: Any]] = []
        characteristicsCache.forEach { (cacheKey, chars) in
            let serviceId = cacheKey.replacingOccurrences(of: "\(deviceId)_", with: "")
            allCharacteristics.append(contentsOf: QXBleUtils.formatCharacteristics(chars, serviceId: serviceId))
        }

        let result = QXBleResult.success(
            data: ["characteristics": allCharacteristics],
            message: "获取特征成功，共\(allCharacteristics.count)个特征"
        )
        callbackStore.take(forKey: deviceCallbackKey)?.onSuccess(result)
    }
    
    /// 写入特征值回调
    /// 当成功写入数据到特征值或写入失败时调用（仅withResponse类型会触发）
    /// - Parameters:
    ///   - peripheral: 蓝牙外设实例
    ///   - characteristic: 写入的特征
    ///   - error: 写入操作的错误信息（如果有）
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        let characteristicId = characteristic.uuid.uuidString
        let callbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.writeCharacteristic.prefix,
            deviceId: deviceId,
            serviceId: characteristicId
        )

        // 一次性取出（同时取消超时）
        guard let callback = callbackStore.take(forKey: callbackKey) else {
            QXBleLogger.log("⚠️ 未找到写入回调：\(callbackKey)")
            return
        }

        let dataCacheKey = "\(deviceId)_\(characteristicId)"
        defer { lastWrittenDataCache.removeValue(forKey: dataCacheKey) }

        if let error = error {
            let errorMsg = "写入特征值失败：\(error.localizedDescription)"
            QXBleLogger.log("❌ \(errorMsg)")
            callback.onFail(QXBleResult.failure(errorCode: .systemError, customMessage: errorMsg))
            return
        }

        // 优先使用缓存的数据，因为 characteristic.value 可能为 nil
        let writtenData = lastWrittenDataCache[dataCacheKey]
        let result = QXBleResult.success(
            data: [
                "characteristicId": characteristicId,
                "value": writtenData?.hexString ?? "[]"
            ],
            message: "写入特征值成功"
        )
        QXBleLogger.log("✅ 写入特征值成功：\(characteristicId), 数据：\(writtenData?.hexString ?? "[]")")
        callback.onSuccess(result)
    }
    
    /// 特征值更新回调
    /// 当特征值发生变化时调用（通常由设备的通知或指示触发）
    /// - Parameters:
    ///   - peripheral: 蓝牙外设实例
    ///   - characteristic: 更新的特征
    ///   - error: 特征值更新的错误信息（如果有）
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // 1. 错误处理
        if let error = error {
            QXBleLogger.log("❌ 特征值更新失败：\(error.localizedDescription)")
            return
        }
        // 2. 获取特征值数据
        guard let value = characteristic.value else {
            QXBleLogger.log("⚠️ 特征值为空")
            return
        }
        // 3. 构造回调参数
        let params: [String: Any] = [
            "eventName": "onBLECharacteristicValueChange",
            "deviceId": peripheral.identifier.uuidString,
            "characteristicId": characteristic.uuid.uuidString,
            "value": value.hexString,  // 转换为16进制字符串
        ]
        QXBleLogger.log("📡 收到特征值更新：\(characteristic.uuid.uuidString), 数据：\(value.hexString)")
        // 4. 调用JS回调通知前端
        callJSWithPluginName("QXBlePlugin", params: params) { _, _ in
            QXBleLogger.log("✅ 特征值变化事件已通知JS端")
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

        // 一次性取出（同时取消超时）
        guard let callback = callbackStore.take(forKey: callbackKey) else { return }

        if let error = error {
            let errorMsg = "通知状态更新失败：\(error.localizedDescription)"
            callback.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
            return
        }

        let status = characteristic.isNotifying ? "已开启" : "已关闭"
        let result = QXBleResult.success(
            data: [
                "deviceId": deviceId,
                "characteristicId": characteristic.uuid.uuidString,
                "isNotifying": characteristic.isNotifying
            ],
            message: "特征通知\(status)"
        )
        callback.onSuccess(result)
    }
    
    // MARK: - 缓存管理
    
    /// 清理所有缓存和回调
    /// 用于关闭蓝牙适配器或重置状态时调用
    public func clearAllCaches() {
        // 清理特征缓存
        characteristicsCache.removeAll()
        QXBleLogger.log("🧹 已清理特征缓存")

        // 清理服务缓存
        servicesCache.removeAll()
        QXBleLogger.log("🧹 已清理服务缓存")

        // 清理写入数据缓存
        lastWrittenDataCache.removeAll()
        QXBleLogger.log("🧹 已清理写入数据缓存")

        // 注意：pending 回调由 CentralManager 在调用本方法前统一 fail，
        // 这里只做静默清理，避免重复触发。
        callbackStore.removeAllSilently()
        characteristicValueUpdateCallback = nil
        QXBleLogger.log("🧹 已清理所有回调")
    }
}
