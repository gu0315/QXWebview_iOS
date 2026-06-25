import Foundation
import CoreBluetooth
import UIKit

/// Central 侧蓝牙状态与连接协调器。
public class QXBleCentralManager: NSObject, CBCentralManagerDelegate {
    // MARK: - Lifecycle
    public static let shared = QXBleCentralManager()
    
    private override init() { super.init() }
    
    // MARK: - State
    /// CoreBluetooth 中央管理器实例。
    private(set) public var centralManager: CBCentralManager!
    
    /// 当前蓝牙适配器状态缓存。
    private(set) public var state: CBManagerState = .unknown
    
    /// 当前扫描阶段发现的设备。
    private(set) public var discoveredPeripherals: [CBPeripheral] = []
    
    /// 最近一次扫描到的 RSSI，按 deviceId 缓存。
    private var deviceRSSICache: [String: NSNumber] = [:]
    
    /// 单设备模式下当前持有的连接。
    private(set) public var currentConnectedPeripheral: CBPeripheral?
    
    /// 当前连接设备的标识，便于跨回调查询。
    private(set) public var currentConnectedDeviceId: String?
    
    // MARK: - Callbacks
    /// 一次性操作回调容器，统一处理注册 / 取出 / 超时。
    private let callbackStore = QXBleCallbackStore()

    /// 单次连接的默认超时（秒）；超时后给 JS 端 fail，避免 Promise 悬挂。
    private static let connectTimeoutSeconds: TimeInterval = 15.0

    /// 家充桩 BLE 主服务。用于补齐系统已连接但当前扫描不可见的设备。
    private static let defaultPileServiceUUIDs = [CBUUID(string: "FF00")]

    /// 权限弹窗串行返回，这里保留所有待完成的调用方。
    private var permissionCallbacks: [JDBridgeCallBack] = []
    
    // MARK: - Reconnection
    /// 按设备记录断开来源，避免异步断连回调误判。
    private var disconnectReasons: [String: DisconnectReason] = [:]
    
    private struct ReconnectionConfig {
        static let maxAttempts = 3
        static let initialDelay: TimeInterval = 2.0
        static let delayMultiplier: TimeInterval = 1.5
    }

    private enum DisconnectReason {
        case appInitiated
        case replaceConnection
        case closeAdapter
    }
    
    /// 每个设备当前处于第几次重连尝试。
    private var reconnectionAttempts: [String: Int] = [:]
    /// 延迟重连任务，便于取消和覆盖。
    private var reconnectionTimers: [String: DispatchWorkItem] = [:]
    
    /// 扫描超时控制，避免扫描无限悬挂。
    private var scanTimeoutWorkItem: DispatchWorkItem?
    
    // MARK: - Setup
    public func setupCentralManager(permissionCallback: JDBridgeCallBack? = nil) {
        enqueuePermissionCallback(permissionCallback)
        
        if QXBleUtils.isBluetoothPermissionDenied() {
            resolvePermissionCallbacks { callback in
                callback.onFail(QXBridgeError.bluetoothDenied())
                return true
            }
            return
        }

        if centralManager == nil {
            let options: [String: Any] = [CBCentralManagerOptionShowPowerAlertKey: true]
            centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: options)
        } else {
            if QXBleUtils.isBluetoothPermissionAuthorized() {
                resolvePermissionCallbacks { callback in
                    callback.onSuccess(QXBleResult.success(message: "蓝牙权限已授权"))
                    return true
                }
            } else if QXBleUtils.isBluetoothPermissionDenied() {
                resolvePermissionCallbacks { callback in
                    callback.onFail(QXBridgeError.bluetoothDenied())
                    return true
                }
            }
        }
    }

    // MARK: - Permission
    public func requestBluetoothPermission(callback: JDBridgeCallBack?) {
        enqueuePermissionCallback(callback)

        if QXBleUtils.isBluetoothPermissionAuthorized() {
            resolvePermissionCallbacks { callback in
                callback.onSuccess(QXBleResult.success(message: "蓝牙权限已授权"))
                return true
            }
            return
        }

        if QXBleUtils.isBluetoothPermissionDenied() {
            resolvePermissionCallbacks { callback in
                callback.onFail(QXBridgeError.bluetoothDenied())
                return true
            }
            return
        }

        setupCentralManager(permissionCallback: callback)
    }
    
    // MARK: - Scan
    @discardableResult
    public func startScan(services: [CBUUID]?, timeout: TimeInterval = 10.0, callbackKey: String, callback: JDBridgeCallBack?) -> Bool {
        guard let centralManager = centralManager else {
            callback?.onFail(QXBleResult.failure(errorCode: .notInit))
            return false
        }
        
        guard QXBleUtils.isBluetoothPermissionAuthorized() else {
            callback?.onFail(QXBridgeError.bluetoothDenied())
            return false
        }

        guard state == .poweredOn else {
            callback?.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen))
            return false
        }
        
        registerCallback(callback, forKey: callbackKey)
        discoveredPeripherals.removeAll()
        deviceRSSICache.removeAll()
        
        if centralManager.isScanning {
            centralManager.stopScan()
        }
        cancelScanTimeout()
        includeSystemConnectedPeripherals(services: services)
        
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ]
        
        centralManager.scanForPeripherals(withServices: services, options: scanOptions)
        
        scheduleScanTimeout(timeout: timeout, callbackKey: callbackKey)
        QXBleLogger.log("开始扫描蓝牙设备")
        return true
    }

    private func serviceUUIDsForSystemConnectedLookup(_ services: [CBUUID]?) -> [CBUUID] {
        guard let services = services, !services.isEmpty else {
            return Self.defaultPileServiceUUIDs
        }
        return services
    }
    
    private func cachePeripheral(_ peripheral: CBPeripheral, rssi: NSNumber? = nil) -> Bool {
        let deviceId = peripheral.identifier.uuidString
        let isNew = !discoveredPeripherals.contains { $0.identifier.uuidString == deviceId }
        if isNew {
            discoveredPeripherals.append(peripheral)
        }
        if let rssi = rssi {
            deviceRSSICache[deviceId] = rssi
        }
        return isNew
    }

    private func emitDeviceFound(_ peripheral: CBPeripheral, name: String? = nil, rssi: NSNumber = 0) {
        let deviceId = peripheral.identifier.uuidString
        let finalDeviceName = name ?? peripheral.name ?? ""
        withCallbacks(matchingPrefix: QXBLEventType.onBluetoothDeviceFound.prefix) { _, callback in
            let params: [String: Any] = [
                "name": finalDeviceName,
                "RSSI": rssi.intValue,
                "deviceId": deviceId,
                "eventName": "onBluetoothDeviceFound",
                "isSystemConnected": peripheral.state == .connected
            ]

            callback.callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
        }
    }

    private func includeSystemConnectedPeripherals(services: [CBUUID]?) {
        guard let centralManager = centralManager else { return }
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(
            withServices: serviceUUIDsForSystemConnectedLookup(services)
        )
        guard !connectedPeripherals.isEmpty else { return }

        QXBleLogger.log("发现系统已连接蓝牙设备：\(connectedPeripherals.count)台")
        connectedPeripherals.forEach { peripheral in
            peripheral.delegate = QXBlePeripheralManager.shared
            let isNew = cachePeripheral(peripheral, rssi: 0)
            if isNew {
                emitDeviceFound(peripheral, rssi: 0)
            }
        }
    }

    public func stopScan(callbackKey: String) {
        cancelScanTimeout()
        
        guard let centralManager = centralManager else {
            removeCallback(forKey: callbackKey)
            return
        }
        
        guard centralManager.isScanning else {
            QXBleLogger.log("当前未在扫描，无需停止")
            removeCallback(forKey: callbackKey)
            return
        }
        
        centralManager.stopScan()
        QXBleLogger.log("已停止扫描，共发现\(discoveredPeripherals.count)个设备")
        
        if let callback = callback(forKey: callbackKey) {
            let result = QXBleResult.success(
                data: ["devices": QXBleUtils.formatPeripherals(discoveredPeripherals, rssiCache: deviceRSSICache)],
                message: "已停止扫描，共发现\(discoveredPeripherals.count)个设备"
            )
            callback.onSuccess(result)
        }
        
        removeCallback(forKey: callbackKey)
    }
    
    private func scheduleScanTimeout(timeout: TimeInterval, callbackKey: String) {
        guard timeout > 0 else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard let centralManager = self.centralManager, centralManager.isScanning else { return }
            QXBleLogger.log("⏱️ 扫描超时，自动停止扫描")
            self.stopScan(callbackKey: callbackKey)
        }
        scanTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }
    
    private func cancelScanTimeout() {
        scanTimeoutWorkItem?.cancel()
        scanTimeoutWorkItem = nil
    }

    // MARK: - Callback Helpers
    private func registerCallback(_ callback: JDBridgeCallBack?, forKey key: String) {
        callbackStore.register(callback, forKey: key)
    }

    private func registerCallback(_ callback: JDBridgeCallBack?,
                                  forKey key: String,
                                  timeout: TimeInterval,
                                  onTimeout: @escaping (JDBridgeCallBack) -> Void) {
        callbackStore.register(callback, forKey: key, timeout: timeout, onTimeout: onTimeout)
    }

    private func callback(forKey key: String) -> JDBridgeCallBack? {
        callbackStore.callback(forKey: key)
    }

    @discardableResult
    private func takeCallback(forKey key: String) -> JDBridgeCallBack? {
        callbackStore.take(forKey: key)
    }

    private func removeCallback(forKey key: String) {
        callbackStore.remove(forKey: key)
    }

    /// 静默清理指定前缀的回调（不通知 JS）。
    public func clearCallbacks(matchingPrefix prefix: String) {
        callbackStore.takeAll(matchingPrefix: prefix) { _ in }
    }

    private func withCallbacks(matchingPrefix prefix: String, _ body: (String, JDBridgeCallBack) -> Void) {
        callbackStore.forEach(matchingPrefix: prefix, body)
    }

    private func enqueuePermissionCallback(_ callback: JDBridgeCallBack?) {
        guard let callback else { return }
        permissionCallbacks.append(callback)
    }

    private func resolvePermissionCallbacks(_ resolver: (JDBridgeCallBack) -> Bool) {
        guard !permissionCallbacks.isEmpty else { return }

        var pendingCallbacks: [JDBridgeCallBack] = []
        permissionCallbacks.forEach { callback in
            if !resolver(callback) {
                pendingCallbacks.append(callback)
            }
        }
        permissionCallbacks = pendingCallbacks
    }

    private func setDisconnectReason(_ reason: DisconnectReason, for deviceId: String) {
        disconnectReasons[deviceId] = reason
    }

    private func takeDisconnectReason(for deviceId: String) -> DisconnectReason? {
        let reason = disconnectReasons[deviceId]
        disconnectReasons.removeValue(forKey: deviceId)
        return reason
    }

    private func disconnectSourceDescription(for reason: DisconnectReason?) -> String {
        switch reason {
        case .appInitiated:
            return "app"
        case .replaceConnection:
            return "replaceConnection"
        case .closeAdapter:
            return "closeAdapter"
        case nil:
            return "system"
        }
    }
    
    // MARK: - Connection
    public func connectPeripheral(deviceId: String, callbackKey: String, callback: JDBridgeCallBack) {
        guard let centralManager = centralManager else {
            callback.onFail(QXBleResult.failure(errorCode: .notInit))
            return
        }
        
        guard QXBleUtils.isBluetoothPermissionAuthorized() else {
            callback.onFail(QXBridgeError.bluetoothDenied())
            return
        }

        guard state == .poweredOn else {
            callback.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen))
            return
        }

        guard let peripheral = resolvePeripheral(deviceId: deviceId) else {
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound, customMessage: "未找到指定设备"))
            return
        }

        if peripheral.state == .connected {
            updateCurrentConnectedPeripheral(peripheral)
            let result = QXBleResult.success(
                data: [
                    "deviceId": deviceId,
                    "name": peripheral.name ?? "未知设备"
                ],
                message: "设备已连接"
            )
            callback.onSuccess(result)
            return
        }

        // 系统不回调时兜底，避免 H5 Promise 永远悬挂。
        registerCallback(callback, forKey: callbackKey, timeout: Self.connectTimeoutSeconds) { callback in
            QXBleLogger.log("⏱️ 连接超时：\(deviceId)")
            callback.onFail(QXBleResult.failure(errorCode: .connectTimeout))
        }
        
        if let currentPeripheral = currentConnectedPeripheral, 
           currentPeripheral.identifier.uuidString != deviceId {
            QXBleLogger.log("🔄 检测到已有连接，先断开旧设备：\(currentPeripheral.name ?? "未知")")
            let oldDeviceId = currentPeripheral.identifier.uuidString
            setDisconnectReason(.replaceConnection, for: oldDeviceId)
            centralManager.cancelPeripheralConnection(currentPeripheral)
            cleanPeripheralConnectionState(deviceId: oldDeviceId)
            QXBleLogger.log("✅ 已断开旧设备，准备连接新设备")
        }
        
        QXBleLogger.log("📱 当前已连接设备：\(currentConnectedPeripheral?.name ?? "无")")
        peripheral.delegate = QXBlePeripheralManager.shared
    
        let connectOptions: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionStartDelayKey: 0
        ]
        
        QXBleLogger.log("🔗 开始连接设备：\(peripheral.name ?? "未知") (\(deviceId))")
        centralManager.connect(peripheral, options: connectOptions)
    }

    private func resolvePeripheral(deviceId: String) -> CBPeripheral? {
        if let currentPeripheral = currentConnectedPeripheral,
           currentPeripheral.identifier.uuidString == deviceId {
            return currentPeripheral
        }

        if let discoveredPeripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == deviceId }) {
            return discoveredPeripheral
        }

        let systemConnected = centralManager.retrieveConnectedPeripherals(
            withServices: serviceUUIDsForSystemConnectedLookup(nil)
        )
        if let connectedPeripheral = systemConnected.first(where: { $0.identifier.uuidString == deviceId }) {
            connectedPeripheral.delegate = QXBlePeripheralManager.shared
            cachePeripheral(connectedPeripheral, rssi: 0)
            QXBleLogger.log("命中系统已连接设备：\(connectedPeripheral.name ?? "未知") (\(deviceId))")
            return connectedPeripheral
        }

        if let uuid = UUID(uuidString: deviceId),
           let knownPeripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            knownPeripheral.delegate = QXBlePeripheralManager.shared
            cachePeripheral(knownPeripheral)
            QXBleLogger.log("命中系统已知设备：\(knownPeripheral.name ?? "未知") (\(deviceId))")
            return knownPeripheral
        }

        return nil
    }

    private func updateCurrentConnectedPeripheral(_ peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        
        currentConnectedPeripheral = peripheral
        currentConnectedDeviceId = deviceId
        QXBleLogger.log("✅ 设备已设为当前连接：\(peripheral.name ?? "未知") (\(deviceId))")
    }
    
    public func disconnectPeripheral(deviceId: String, callbackKey: String, callback: JDBridgeCallBack) {
        guard let centralManager = centralManager else {
            callback.onFail(QXBleResult.failure(errorCode: .notInit))
            return
        }
        
        registerCallback(callback, forKey: callbackKey)
        QXBleLogger.log("🔌 准备断开设备：\(deviceId)")
        setDisconnectReason(.appInitiated, for: deviceId)
        cancelReconnection(for: deviceId)
        if let peripheral = currentConnectedPeripheral, peripheral.identifier.uuidString == deviceId {
            if peripheral.state == .connected {
                QXBleLogger.log("🔗 设备已连接，发起断开请求：\(peripheral.name ?? "未知")")
                centralManager.cancelPeripheralConnection(peripheral)
            } else {
                QXBleLogger.log("⚠️ 设备未连接，直接清理状态")
                cleanPeripheralConnectionState(deviceId: deviceId)
                let result = QXBleResult.success(message: "设备未连接")
                callback.onSuccess(result)
                removeCallback(forKey: callbackKey)
            }
        } else {
            QXBleLogger.log("❌ 未找到设备：\(deviceId)")
            callback.onFail(QXBleResult.failure(
                errorCode: .deviceNotFound,
                customMessage: "未找到指定设备"
            ))
            removeCallback(forKey: callbackKey)
        }
    }
    
    private func cleanPeripheralConnectionState(deviceId: String) {
        if currentConnectedDeviceId == deviceId {
            currentConnectedPeripheral = nil
            currentConnectedDeviceId = nil
            QXBleLogger.log("📱 已清空当前设备")
        }
        
        reconnectionAttempts.removeValue(forKey: deviceId)
        cancelReconnection(for: deviceId)
        QXBleLogger.log("✅ 已清理设备连接状态：\(deviceId)")
    }
    
    // MARK: - 重连管理
    /// 尝试重新连接设备
    /// - Parameters:
    ///   - peripheral: 需要重连的外设
    ///   - attempt: 当前重连尝试次数
    private func attemptReconnection(peripheral: CBPeripheral, attempt: Int) {
        let deviceId = peripheral.identifier.uuidString
        // 检查是否超过最大重连次数
        guard attempt <= ReconnectionConfig.maxAttempts else {
            QXBleLogger.log("❌ 设备重连失败，已达最大重连次数：\(peripheral.name ?? "未知") (\(deviceId))")
            cancelReconnection(for: deviceId)
            // 通知JS端重连失败（使用 onBLEConnectionStateChange 事件）
            let params: [String: Any] = [
                "eventName": "onBLEConnectionStateChange",
                "deviceId": deviceId,
                "name": peripheral.name ?? "未知设备",
                "isConnected": false,
                "reconnectionFailed": true,
                "reason": "已达最大重连次数"
            ]
            callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
            return
        }
        // 计算延迟时间（指数退避）
        let delay = ReconnectionConfig.initialDelay * pow(ReconnectionConfig.delayMultiplier, Double(attempt - 1))
        QXBleLogger.log("🔄 准备第\(attempt)次重连设备：\(peripheral.name ?? "未知") (\(deviceId))，延迟\(String(format: "%.1f", delay))秒")
        // 创建延迟重连任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.reconnectionTimers.removeValue(forKey: deviceId)
            // 检查蓝牙状态
            guard self.state == .poweredOn else {
                QXBleLogger.log("⚠️ 蓝牙未开启，取消重连")
                self.cancelReconnection(for: deviceId)
                // 通知JS端重连失败
                let params: [String: Any] = [
                    "eventName": "onBLEConnectionStateChange",
                    "deviceId": deviceId,
                    "name": peripheral.name ?? "未知设备",
                    "isConnected": false,
                    "reconnectionFailed": true,
                    "reason": "蓝牙未开启"
                ]
                self.callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
                return
            }
            // 检查设备是否已连接（可能在延迟期间已手动连接）
            if peripheral.state == .connected {
                QXBleLogger.log("✅ 设备已连接，取消重连任务")
                self.cancelReconnection(for: deviceId)
                return
            }
            QXBleLogger.log("🔗 开始第\(attempt)次重连：\(peripheral.name ?? "未知")")
            // 更新重连次数
            self.reconnectionAttempts[deviceId] = attempt
            // 发起重连
            let connectOptions: [String: Any] = [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                CBConnectPeripheralOptionStartDelayKey: 0
            ]
            self.centralManager.connect(peripheral, options: connectOptions)
        }
        // 保存定时器引用
        if let existingTimer = reconnectionTimers[deviceId] {
            existingTimer.cancel()
        }
        reconnectionTimers[deviceId] = workItem
        // 延迟执行重连
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// 取消设备的重连任务
    /// - Parameter deviceId: 设备ID
    private func cancelReconnection(for deviceId: String) {
        if let timer = reconnectionTimers.removeValue(forKey: deviceId) {
            timer.cancel()
            QXBleLogger.log("✅ 已取消设备重连任务：\(deviceId)")
        }
        reconnectionAttempts.removeValue(forKey: deviceId)
    }
    
    /// 取消所有正在进行的重连任务
    public func cancelAllReconnections() {
        guard !reconnectionTimers.isEmpty else { return }
        QXBleLogger.log("🛑 取消所有重连任务（共\(reconnectionTimers.count)个）")
        reconnectionTimers.values.forEach { $0.cancel() }
        reconnectionTimers.removeAll()
        reconnectionAttempts.removeAll()
        QXBleLogger.log("✅ 已取消所有重连任务")
    }
    
    // MARK: - 蓝牙适配器管理
    /// 关闭蓝牙适配器，清理所有资源。
    /// 在清空内存之前，先把 pending 回调统一 fail，避免 H5 Promise 悬挂。
    public func closeBluetoothAdapter() {
        cancelScanTimeout()
        let pendingDisconnectDeviceId = currentConnectedDeviceId

        // 停止扫描
        if let centralManager = centralManager, centralManager.isScanning {
            centralManager.stopScan()
        }
        QXBleLogger.log("✅ 已取消连接超时任务")

        if let deviceId = pendingDisconnectDeviceId {
            setDisconnectReason(.closeAdapter, for: deviceId)
        }

        // 先把所有 pending callback fail 掉，再清空容器。
        let closeError = QXBleResult.failure(errorCode: .notInit, customMessage: "蓝牙适配器已关闭")
        callbackStore.takeAll { callback in
            callback.onFail(closeError)
        }
        permissionCallbacks.forEach { $0.onFail(closeError) }
        permissionCallbacks.removeAll()
        QXBlePeripheralManager.shared.failAllCallbacks(with: closeError)

        // 断开当前连接的设备
        if let manager = centralManager, let peripheral = currentConnectedPeripheral, peripheral.state == .connected {
            manager.cancelPeripheralConnection(peripheral)
        }
        currentConnectedPeripheral = nil
        currentConnectedDeviceId = nil
        discoveredPeripherals.removeAll()
        deviceRSSICache.removeAll()

        reconnectionAttempts.removeAll()
        reconnectionTimers.values.forEach { $0.cancel() }
        reconnectionTimers.removeAll()
        if pendingDisconnectDeviceId == nil {
            disconnectReasons.removeAll()
        }

        QXBlePeripheralManager.shared.clearAllCaches()
        state = .unknown

        QXBleLogger.log("✅ 蓝牙适配器已关闭，所有资源已清理")
    }
    
    public func getBluetoothAdapterState() -> [String: Any] {
        var result: [String: Any] = [:]
        var adapterState: [String: Any] = [:]
        
        if centralManager == nil {
            result["errorCode"] = QXBleErrorCode.notInit.rawValue
            result["errorMessage"] = QXBleErrorCode.notInit.message
            result["data"] = [
                "available": false,
                "discovering": false
            ]
            return result
        }
        
        let currentState = centralManager.state
        adapterState["discovering"] = centralManager.isScanning

        if currentState == .unsupported {
            result["errorCode"] = QXBleErrorCode.systemNotSupport.rawValue
            result["errorMessage"] = "设备不支持蓝牙"
            adapterState["available"] = false
        } else if currentState == .poweredOff {
            result["errorCode"] = QXBleErrorCode.notAvailable.rawValue
            result["errorMessage"] = QXBleErrorCode.notAvailable.message
            adapterState["available"] = false
        } else if currentState == .unauthorized {
            result["errorCode"] = QXBleErrorCode.notAvailable.rawValue
            result["errorMessage"] = "蓝牙权限未授权"
            adapterState["available"] = false
        } else if currentState == .poweredOn && QXBleUtils.isBluetoothPermissionAuthorized() {
            result["errorCode"] = QXBleErrorCode.success.rawValue
            result["errorMessage"] = QXBleErrorCode.success.message
            adapterState["available"] = true
        } else {
            result["errorCode"] = QXBleErrorCode.notAvailable.rawValue
            result["errorMessage"] = "蓝牙适配器状态异常: \(currentState.description)"
            adapterState["available"] = false
        }
        
        result["data"] = adapterState
        return result
    }
    
    /// 获取在蓝牙模块生效期间所有已发现的蓝牙设备
    /// - Returns: 包含已发现蓝牙设备列表的字典
    public func getBluetoothDevices() -> [String: Any] {
        var result: [String: Any] = [:]
        
        // 检查是否已初始化
        if centralManager == nil {
            result["errorCode"] = QXBleErrorCode.notInit.rawValue
            result["errorMessage"] = QXBleErrorCode.notInit.message
            result["data"] = ["devices": []]
            return result
        }
        
        // 检查蓝牙状态
        let currentState = centralManager.state
        if currentState != .poweredOn || !QXBleUtils.isBluetoothPermissionAuthorized() {
            result["errorCode"] = QXBleErrorCode.notAvailable.rawValue
            result["errorMessage"] = QXBleErrorCode.notAvailable.message
            result["data"] = ["devices": []]
            return result
        }

        includeSystemConnectedPeripherals(services: nil)

        // 格式化设备列表，符合 uni-app 文档标准
        let devices = discoveredPeripherals.map { peripheral -> [String: Any] in
            let deviceId = peripheral.identifier.uuidString
            let rssi = deviceRSSICache[deviceId]?.intValue ?? 0
            
            return [
                "name": peripheral.name ?? "",
                "deviceId": deviceId,
                "RSSI": rssi
            ]
        }
        
        result["errorCode"] = QXBleErrorCode.success.rawValue
        result["errorMessage"] = QXBleErrorCode.success.message
        result["data"] = ["devices": devices]
        
        return result
    }
    
    // MARK: - CBCentralManagerDelegate 实现
    /// 蓝牙中心管理器状态更新回调
    /// 当蓝牙硬件状态发生变化时调用（如蓝牙开启/关闭/未授权等）
    /// - Parameter central: 蓝牙中心管理器实例
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // 更新本地状态缓存
        state = central.state
        // 处理权限请求回调
        resolvePermissionCallbacks { [weak self] callback in
            guard let self = self else { return true }
            return self.handlePermissionCallback(permissionCallback: callback)
        }
        // 通知所有缓存的回调蓝牙状态变化
        notifyAllCallbacksForBluetoothStateChange()
    }
    
    /// 处理权限回调（内部方法）
    /// - Parameter permissionCallback: 权限回调对象
    @discardableResult
    private func handlePermissionCallback(permissionCallback: JDBridgeCallBack) -> Bool {
        let auth = QXBleUtils.checkBluetoothPermission()
        switch auth {
        case .allowedAlways:
            permissionCallback.onSuccess(QXBleResult.success(message: "蓝牙权限授权成功"))
            return true
        case .denied:
            permissionCallback.onFail(QXBridgeError.bluetoothDenied())
            return true
        case .notDetermined:
            return false
        case .restricted:
            permissionCallback.onFail(QXBridgeError.bluetoothRestricted())
            return true
        @unknown default:
            permissionCallback.onFail(QXBleResult.failure(errorCode: .unknownError))
            return true
        }
    }
    
    /// 通知所有缓存回调蓝牙状态变化（内部方法）。
    /// 蓝牙被关掉 / 权限丢失等异常状态下，把所有 pending 一次性失败返回，
    /// 避免 H5 Promise 永远悬挂。
    private func notifyAllCallbacksForBluetoothStateChange() {
        guard state != .poweredOn else { return }

        let errorMsg = "蓝牙状态异常：\(state.description)"
        let error = QXBleResult.failure(errorCode: .bluetoothNotOpen, customMessage: errorMsg)
        callbackStore.takeAll { callback in
            callback.onFail(error)
        }

        cancelScanTimeout()
        centralManager?.stopScan()
        QXBlePeripheralManager.shared.failAllCallbacks(with: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let broadcastName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let peripheralName = peripheral.name
        let finalDeviceName = broadcastName ?? peripheralName ?? ""
        let isExisted = !cachePeripheral(peripheral, rssi: RSSI)
        
        if !isExisted {
            emitDeviceFound(peripheral, name: finalDeviceName, rssi: RSSI)
        }
    }
    
    /// 设备连接成功回调
    /// 当成功连接到蓝牙设备时调用
    /// - Parameters:
    ///   - central: 蓝牙中心管理器实例
    ///   - peripheral: 已连接的蓝牙外设
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        
        // 检查是否为重连成功
        let isReconnection = reconnectionAttempts[deviceId] != nil
        let attemptCount = reconnectionAttempts[deviceId] ?? 0
        
        if isReconnection {
            QXBleLogger.log("✅ 设备重连成功（第\(attemptCount)次尝试）：\(peripheral.name ?? "未知") (\(deviceId))")
            // 通知JS端重连成功（使用 onBLEConnectionStateChange 事件）
            let params: [String: Any] = [
                "eventName": "onBLEConnectionStateChange",
                "deviceId": deviceId,
                "name": peripheral.name ?? "未知设备",
                "isConnected": true,
                "isReconnection": true,
                "attempt": attemptCount,
            ]
            callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
            // 清理重连状态
            reconnectionAttempts.removeValue(forKey: deviceId)
            cancelReconnection(for: deviceId)
        } else {
            QXBleLogger.log("✅ 设备连接成功：\(peripheral.name ?? "未知") (\(deviceId))")
        }
        QXBleLogger.log("📊 设备连接状态：\(peripheral.state.rawValue) (\(peripheral.state.description))")
        
        // 立即更新连接状态（确保后续操作能找到设备）
        updateCurrentConnectedPeripheral(peripheral)
        
        // 立即触发连接成功回调（不延迟，避免影响后续操作）
        triggerConnectionCallback(deviceId: deviceId, isSuccess: true, peripheral: peripheral)
    }
    
    /// 设备连接失败回调
    /// 当尝试连接蓝牙设备失败时调用
    /// - Parameters:
    ///   - central: 蓝牙中心管理器实例
    ///   - peripheral: 尝试连接的蓝牙外设
    ///   - error: 连接失败的错误信息
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        
        // 检查是否为重连失败
        if let currentAttempt = reconnectionAttempts[deviceId] {
            QXBleLogger.log("❌ 设备重连失败（第\(currentAttempt)次尝试）：\(peripheral.name ?? "未知") (\(deviceId))")
            if let error = error {
                QXBleLogger.log("❌ 失败原因：\(error.localizedDescription)")
            }
            // 继续尝试下一次重连
            attemptReconnection(peripheral: peripheral, attempt: currentAttempt + 1)
        } else {
            QXBleLogger.log("❌ 设备连接失败：\(peripheral.name ?? "未知") (\(deviceId))")
            if let error = error {
                QXBleLogger.log("❌ 失败原因：\(error.localizedDescription)")
            }
            QXBleLogger.log("✅ 已取消连接超时任务")
            // 查找并触发连接失败回调
            triggerConnectionCallback(deviceId: deviceId, isSuccess: false, error: error)
        }
    }
    
    /// 触发连接回调
    /// - Parameters:
    ///   - deviceId: 设备ID
    ///   - isSuccess: 是否连接成功
    ///   - peripheral: 连接成功的外设（成功时传）
    ///   - error: 连接失败的错误（失败时传）
    private func triggerConnectionCallback(deviceId: String, isSuccess: Bool, peripheral: CBPeripheral? = nil, error: Error? = nil) {
        // 查找目标回调
        let callbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBLEventType.connectBluetoothDevice.prefix,
            deviceId: deviceId
        )
        guard let callback = takeCallback(forKey: callbackKey) else { return }
        if isSuccess, let peripheral = peripheral {
            // 连接成功
            let result = QXBleResult.success(
                data: [
                    "deviceId": deviceId,
                    "name": peripheral.name ?? "未知设备"
                ],
                message: "设备连接成功"
            )
            callback.onSuccess(result)
        } else {
            // 连接失败
            let errorMsg = error?.localizedDescription ?? "设备连接失败"
            callback.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
        }
        let params: [String: Any] = [
            "eventName": "onBLEConnectionStateChange",
            "isConnected": isSuccess,
            "deviceId": deviceId,
            "name": peripheral?.name ?? "未知设备"
        ]
        callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
    }

    /// 触发断开连接回调
    /// - Parameters:
    ///   - deviceId: 设备ID
    ///   - isSuccess: 是否成功断开
    ///   - peripheral: 已断开的外设
    ///   - error: 断开错误（如有）
    private func triggerDisconnectCallback(deviceId: String, isSuccess: Bool, peripheral: CBPeripheral, error: Error? = nil) {
        let callbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.disconnectDevice.prefix,
            deviceId: deviceId
        )
        guard let callback = takeCallback(forKey: callbackKey) else { return }

        if isSuccess {
            callback.onSuccess(QXBleResult.success(
                data: [
                    "deviceId": deviceId,
                    "name": peripheral.name ?? "未知设备"
                ],
                message: "设备已断开连接"
            ))
        } else {
            let errorMsg = error?.localizedDescription ?? "设备断开连接失败"
            callback.onFail(QXBleResult.failure(
                errorCode: .systemError,
                customMessage: errorMsg
            ))
        }
    }
    
    /// 设备断开连接回调
    /// 当与蓝牙设备断开连接时调用
    /// - Parameters:
    ///   - central: 蓝牙中心管理器实例
    ///   - peripheral: 已断开连接的蓝牙外设
    ///   - error: 断开连接的错误信息（如果有）
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        let disconnectReason = takeDisconnectReason(for: deviceId)
        let wasIntentionalDisconnect = disconnectReason != nil
        // 只要不是 App 主动发起的断开，都视为异常断开，避免设备端主动断开但 error 为空时被误判为正常。
        let isUnexpectedDisconnect = !wasIntentionalDisconnect
        if let error = error {
            QXBleLogger.log("⚠️ 设备异常断开：\(peripheral.name ?? "未知") (\(deviceId)) \(error.localizedDescription)")
            
        } else {
            let disconnectType = isUnexpectedDisconnect ? "异常断开" : "正常断开"
            QXBleLogger.log("🔌 设备\(disconnectType)：\(peripheral.name ?? "未知") (\(deviceId))")
        }
        // 清理连接状态（但不清理重连状态，如果需要重连的话）
        if currentConnectedDeviceId == deviceId {
            currentConnectedPeripheral = nil
            currentConnectedDeviceId = nil
            QXBleLogger.log("📱 已清空当前设备")
        }
        // 主动断开时补齐 native closeBLEConnection 成功回调
        if wasIntentionalDisconnect {
            triggerDisconnectCallback(deviceId: deviceId, isSuccess: true, peripheral: peripheral)
        }
        // 断开后，外设侧 pending 的 discover/write/notify 不会再回调，统一 fail。
        let disconnectError = QXBleResult.failure(errorCode: .noConnection)
        QXBlePeripheralManager.shared.failCallbacks(for: deviceId, with: disconnectError)
        // 通知JS端连接状态变化
        let params: [String: Any] = [
            "eventName": "onBLEConnectionStateChange",
            "deviceId": deviceId,
            "name": peripheral.name ?? "未知设备",
            "isConnected": false,
            "isUnexpected": isUnexpectedDisconnect,
            "errorMessage": error?.localizedDescription ?? "",
            "disconnectSource": disconnectSourceDescription(for: disconnectReason)
        ]
        callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
        // 异常断开时尝试自动重连
        if isUnexpectedDisconnect {
            QXBleLogger.log("🔄 检测到异常断开，准备自动重连...")
            // 初始化重连计数
            reconnectionAttempts[deviceId] = 0
            // 开始第一次重连尝试
            attemptReconnection(peripheral: peripheral, attempt: 1)
        } else {
            // 正常断开，清理重连状态
            cancelReconnection(for: deviceId)
        }
    }
}

// MARK: - CBManagerState 扩展
/// 扩展CBManagerState，提供可读的蓝牙状态描述
extension CBManagerState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "未知状态"
        case .resetting: return "正在重置"
        case .unsupported: return "设备不支持蓝牙"
        case .unauthorized: return "蓝牙未授权"
        case .poweredOff: return "蓝牙已关闭"
        case .poweredOn: return "蓝牙已开启"
        @unknown default: return "未知状态(\(rawValue))"
        }
    }
}

// MARK: - CBPeripheralState 扩展
/// 扩展CBPeripheralState，提供可读的外设连接状态描述
extension CBPeripheralState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected: return "已断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .disconnecting: return "断开中"
        @unknown default: return "未知状态(\(rawValue))"
        }
    }
}
