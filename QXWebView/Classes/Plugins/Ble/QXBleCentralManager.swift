//
//  QXBleCentralManager.swift
//  MJExtension
//
//  蓝牙中心管理器单例类
//  功能：负责蓝牙设备的扫描、连接、状态管理、权限处理
//  遵循CBCentralManagerDelegate协议，处理蓝牙核心回调
//  作者：顾钱想
//  日期：2025/12/23
//

import Foundation
import CoreBluetooth
import UIKit

/// 蓝牙中心管理器（全局单例）- 负责扫描、连接、蓝牙状态管理
public class QXBleCentralManager: NSObject, CBCentralManagerDelegate {
    // MARK: - 单例初始化
    /// 全局单例实例
    public static let shared = QXBleCentralManager()
    
    /// 私有化构造方法，确保单例唯一性
    private override init() { super.init() }
    
    // MARK: - 核心属性
    /// 蓝牙中心管理器核心实例
    private(set) public var centralManager: CBCentralManager!
    
    /// 当前蓝牙硬件状态
    private(set) public var state: CBManagerState = .unknown
    
    /// 已发现的蓝牙设备列表
    private(set) public var discoveredPeripherals: [CBPeripheral] = []
    
    /// 设备 RSSI 缓存（key: deviceId, value: RSSI）
    private var deviceRSSICache: [String: NSNumber] = [:]
    
    /// 当前连接的设备（单设备连接模式）
    private(set) public var currentConnectedPeripheral: CBPeripheral?
    
    /// 当前连接设备的ID（方便快速访问）
    private(set) public var currentConnectedDeviceId: String?
    
    // MARK: - 回调管理
    /// 回调缓存字典（key: callbackKey, value: 回调对象）
    /// internal 访问级别，允许同模块内的其他类访问
    internal var callbacks: [String: JDBridgeCallBack?] = [:]
    

    /// 权限请求专用回调
    private var permissionCallback: JDBridgeCallBack?
    
    // MARK: - 重连管理
    /// 是否为主动断开连接（用于区分主动断开和异常断开）
    private var isIntentionalDisconnect: Bool = false
    
    /// 重连配置
    private struct ReconnectionConfig {
        static let maxAttempts = 3                      // 最大重连次数
        static let initialDelay: TimeInterval = 2.0     // 首次重连延迟（秒）
        static let delayMultiplier: TimeInterval = 1.5  // 延迟倍增系数
    }
    
    /// 重连状态跟踪
    private var reconnectionAttempts: [String: Int] = [:]             // key: deviceId, value: 当前重连次数
    private var reconnectionTimers: [String: DispatchWorkItem] = [:]  // key: deviceId, value: 重连定时器
    
    /// 扫描超时任务
    private var scanTimeoutWorkItem: DispatchWorkItem?
    
    // MARK: - 初始化
    /// 初始化蓝牙中心管理器
    /// - Parameter permissionCallback: 权限请求结果回调
    public func setupCentralManager(permissionCallback: JDBridgeCallBack? = nil) {
        self.permissionCallback = permissionCallback
        
        // 前置检查：权限已被拒绝
        if QXBleUtils.isBluetoothPermissionDenied() {
            permissionCallback?.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            return
        }
        
        // 初始化中心管理器（仅首次调用）
        if centralManager == nil {
            // 配置初始化选项：开启蓝牙关闭时的系统提示
            let options: [String: Any] = [CBCentralManagerOptionShowPowerAlertKey: true]
            
            // 在主线程队列初始化（确保UI相关回调在主线程）
            centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: options)
        } else {
            // 已初始化，直接返回当前权限状态
            if QXBleUtils.isBluetoothPermissionAuthorized() {
                permissionCallback?.onSuccess(QXBleResult.success(message: "蓝牙权限已授权"))
            } else if QXBleUtils.isBluetoothPermissionNotDetermined() {
                permissionCallback?.onFail(QXBleResult.failure(errorCode: .permissionNotDetermined))
            }
        }
    }
    
    // MARK: - 权限请求
    /// 请求蓝牙权限（自动触发系统权限弹窗）
    /// - Parameter callback: 权限请求结果回调
    public func requestBluetoothPermission(callback: JDBridgeCallBack?) {
        permissionCallback = callback
        
        // 权限状态快速判断
        if QXBleUtils.isBluetoothPermissionAuthorized() {
            callback?.onSuccess(QXBleResult.success(message: "蓝牙权限已授权"))
            return
        }
        
        if QXBleUtils.isBluetoothPermissionDenied() {
            callback?.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            return
        }
        
        // 初始化中心管理器触发权限请求
        setupCentralManager(permissionCallback: callback)
    }
    
    // MARK: - 扫描相关
    /// 开始扫描蓝牙设备
    /// - Parameters:
    ///   - services: 要过滤的服务UUID数组（nil表示扫描所有设备）
    ///   - timeout: 扫描超时时间（默认10秒）
    ///   - callbackKey: 本次扫描的回调标识
    ///   - callback: 扫描操作结果回调
    @discardableResult
    public func startScan(services: [CBUUID]?, timeout: TimeInterval = 10.0, callbackKey: String, callback: JDBridgeCallBack?) -> Bool {
        // 0. 初始化状态检查
        guard let centralManager = centralManager else {
            callback?.onFail(QXBleResult.failure(errorCode: .notInit))
            return false
        }
        
        // 1. 权限前置检查
        guard QXBleUtils.isBluetoothPermissionAuthorized() else {
            callback?.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            return false
        }
        
        // 2. 蓝牙硬件状态检查
        guard state == .poweredOn else {
            callback?.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen))
            return false
        }
        
        // 3. 注册扫描回调
        callbacks[callbackKey] = callback
        
        // 4. 清空历史扫描结果和RSSI缓存
        discoveredPeripherals.removeAll()
        deviceRSSICache.removeAll()
        
        // 若已有扫描任务，先停止旧扫描并清理旧超时任务
        if centralManager.isScanning {
            centralManager.stopScan()
        }
        cancelScanTimeout()
        
        // 5. 配置扫描选项：不允许重复发现同一设备
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ]
        
        // 6. 开始扫描
        centralManager.scanForPeripherals(withServices: services, options: scanOptions)
        
        // 7. 安排扫描超时自动停止
        scheduleScanTimeout(timeout: timeout, callbackKey: callbackKey)
        print("开始扫描蓝牙设备")
        return true
    }
    
    /// 停止扫描蓝牙设备
    /// - Parameter callbackKey: 扫描时的回调标识
    public func stopScan(callbackKey: String) {
        cancelScanTimeout()
        
        guard let centralManager = centralManager else {
            callbacks.removeValue(forKey: callbackKey)
            return
        }
        
        // 检查是否正在扫描
        guard centralManager.isScanning else {
            print("当前未在扫描，无需停止")
            callbacks.removeValue(forKey: callbackKey)
            return
        }
        
        // 停止扫描
        centralManager.stopScan()
        print("已停止扫描，共发现\(discoveredPeripherals.count)个设备")
        
        // 触发扫描停止回调（如果存在）
        if let callback = callbacks[callbackKey] {
            let result = QXBleResult.success(
                data: ["devices": QXBleUtils.formatPeripherals(discoveredPeripherals, rssiCache: deviceRSSICache)],
                message: "已停止扫描，共发现\(discoveredPeripherals.count)个设备"
            )
            callback?.onSuccess(result)
        }
        
        // 清理回调缓存
        callbacks.removeValue(forKey: callbackKey)
    }
    
    /// 安排扫描超时任务
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - callbackKey: 扫描回调Key
    private func scheduleScanTimeout(timeout: TimeInterval, callbackKey: String) {
        guard timeout > 0 else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard let centralManager = self.centralManager, centralManager.isScanning else { return }
            print("⏱️ 扫描超时，自动停止扫描")
            self.stopScan(callbackKey: callbackKey)
        }
        scanTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }
    
    /// 取消扫描超时任务
    private func cancelScanTimeout() {
        scanTimeoutWorkItem?.cancel()
        scanTimeoutWorkItem = nil
    }
    
    // MARK: - 连接相关
    /// 连接蓝牙设备（单设备模式：自动断开已有连接）
    /// - Parameters:
    ///   - deviceId: 设备唯一标识（UUID字符串）
    ///   - callbackKey: 本次连接的回调标识
    ///   - callback: 连接结果回调
    public func connectPeripheral(deviceId: String, callbackKey: String, callback: JDBridgeCallBack) {
        guard let centralManager = centralManager else {
            callback.onFail(QXBleResult.failure(errorCode: .notInit))
            return
        }
        
        // 权限检查
        guard QXBleUtils.isBluetoothPermissionAuthorized() else {
            callback.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            return
        }
        
        // 蓝牙硬件状态检查
        guard state == .poweredOn else {
            callback.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen))
            return
        }
        
        // 注册连接回调
        callbacks[callbackKey] = callback
        
        // 查找目标设备（从已发现设备列表中）
        guard let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == deviceId }) else {
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound, customMessage: "未找到指定设备"))
            callbacks.removeValue(forKey: callbackKey)
            return
        }
        // 已连接直接返回成功
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
            callbacks.removeValue(forKey: callbackKey)
            return
        }
        
        // 连接新设备前先断开旧设备
        if let currentPeripheral = currentConnectedPeripheral, 
           currentPeripheral.identifier.uuidString != deviceId {
            print("🔄 检测到已有连接，先断开旧设备：\(currentPeripheral.name ?? "未知")")
            // 标记为主动断开（防止触发重连）
            isIntentionalDisconnect = true
            // 断开旧设备
            let oldDeviceId = currentPeripheral.identifier.uuidString
            centralManager.cancelPeripheralConnection(currentPeripheral)
            // 清理旧设备状态
            cleanPeripheralConnectionState(deviceId: oldDeviceId)
            print("✅ 已断开旧设备，准备连接新设备")
        }
        
        print("📱 当前已连接设备：\(currentConnectedPeripheral?.name ?? "无")")
        // 设置外设代理（处理服务/特征发现）
        peripheral.delegate = QXBlePeripheralManager.shared
    
        // 配置连接选项
        let connectOptions: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,        // 连接成功时通知
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,     // 断开时通知
            CBConnectPeripheralOptionStartDelayKey: 0                    // 立即开始连接，不延迟
        ]
        
        print("🔗 开始连接设备：\(peripheral.name ?? "未知") (\(deviceId))")
        // 发起连接
        centralManager.connect(peripheral, options: connectOptions)
    
    }
    
    /// 更新当前连接设备状态（内部方法）
    /// 单设备连接模式：只保留一个连接设备
    /// - Parameter peripheral: 新连接的外设
    private func updateCurrentConnectedPeripheral(_ peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        
        // 更新当前连接设备
        currentConnectedPeripheral = peripheral
        currentConnectedDeviceId = deviceId
        print("✅ 设备已设为当前连接：\(peripheral.name ?? "未知") (\(deviceId))")
    }
    
    /// 断开蓝牙设备连接
    /// - Parameters:
    ///   - deviceId: 设备唯一标识
    ///   - callbackKey: 本次断开操作的回调标识
    ///   - callback: 断开结果回调
    public func disconnectPeripheral(deviceId: String, callbackKey: String, callback: JDBridgeCallBack) {
        guard let centralManager = centralManager else {
            callback.onFail(QXBleResult.failure(errorCode: .notInit))
            return
        }
        
        // 注册断开回调
        callbacks[callbackKey] = callback
        
        print("🔌 准备断开设备：\(deviceId)")
        
        // 标记为主动断开（防止自动重连）
        isIntentionalDisconnect = true
        
        // 取消该设备的重连任务
        cancelReconnection(for: deviceId)
        
        // 检查是否是当前连接的设备
        if let peripheral = currentConnectedPeripheral, peripheral.identifier.uuidString == deviceId {
            if peripheral.state == .connected {
                print("🔗 设备已连接，发起断开请求：\(peripheral.name ?? "未知")")
                // 发起断开连接请求
                centralManager.cancelPeripheralConnection(peripheral)
            } else {
                print("⚠️ 设备未连接，直接清理状态")
                // 设备未连接，直接返回成功
                cleanPeripheralConnectionState(deviceId: deviceId)
                let result = QXBleResult.success(message: "设备未连接")
                callback.onSuccess(result)
                callbacks.removeValue(forKey: callbackKey)
            }
        } else {
            // 未找到指定设备
            print("❌ 未找到设备：\(deviceId)")
            callback.onFail(QXBleResult.failure(
                errorCode: .deviceNotFound,
                customMessage: "未找到指定设备"
            ))
            callbacks.removeValue(forKey: callbackKey)
        }
    }
    
    /// 清理外设连接状态（内部方法）
    /// - Parameter deviceId: 设备ID
    private func cleanPeripheralConnectionState(deviceId: String) {
        // 如果是当前设备，清空当前设备引用
        if currentConnectedDeviceId == deviceId {
            currentConnectedPeripheral = nil
            currentConnectedDeviceId = nil
            print("📱 已清空当前设备")
        }
        
        // 清理重连状态
        reconnectionAttempts.removeValue(forKey: deviceId)
        cancelReconnection(for: deviceId)
        print("✅ 已清理设备连接状态：\(deviceId)")
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
            print("❌ 设备重连失败，已达最大重连次数：\(peripheral.name ?? "未知") (\(deviceId))")
            reconnectionAttempts.removeValue(forKey: deviceId)
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
        print("🔄 准备第\(attempt)次重连设备：\(peripheral.name ?? "未知") (\(deviceId))，延迟\(String(format: "%.1f", delay))秒")
        // 创建延迟重连任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 检查蓝牙状态
            guard self.state == .poweredOn else {
                print("⚠️ 蓝牙未开启，取消重连")
                self.reconnectionAttempts.removeValue(forKey: deviceId)
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
                print("✅ 设备已连接，取消重连任务")
                self.reconnectionAttempts.removeValue(forKey: deviceId)
                return
            }
            print("🔗 开始第\(attempt)次重连：\(peripheral.name ?? "未知")")
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
        reconnectionTimers[deviceId] = workItem
        // 延迟执行重连
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// 取消设备的重连任务
    /// - Parameter deviceId: 设备ID
    private func cancelReconnection(for deviceId: String) {
        if let timer = reconnectionTimers[deviceId] {
            timer.cancel()
            reconnectionTimers.removeValue(forKey: deviceId)
            print("✅ 已取消设备重连任务：\(deviceId)")
        }
        reconnectionAttempts.removeValue(forKey: deviceId)
    }
    
    /// 取消所有正在进行的重连任务
    public func cancelAllReconnections() {
        guard !reconnectionTimers.isEmpty else { return }
        print("🛑 取消所有重连任务（共\(reconnectionTimers.count)个）")
        reconnectionTimers.values.forEach { $0.cancel() }
        reconnectionTimers.removeAll()
        reconnectionAttempts.removeAll()
        print("✅ 已取消所有重连任务")
    }
    
    // MARK: - 蓝牙适配器管理
    /// 关闭蓝牙适配器，清理所有资源
    public func closeBluetoothAdapter() {
        cancelScanTimeout()
        
        // 停止扫描
        if let centralManager = centralManager, centralManager.isScanning {
            centralManager.stopScan()
        }
        print("✅ 已取消连接超时任务")
        
        // 标记为主动断开（防止触发重连）
        isIntentionalDisconnect = true
        
        // 断开当前连接的设备
        if let manager = centralManager, let peripheral = currentConnectedPeripheral, peripheral.state == .connected {
            manager.cancelPeripheralConnection(peripheral)
        }
        // 清理所有连接状态
        currentConnectedPeripheral = nil
        currentConnectedDeviceId = nil
        // 清理发现的设备列表
        discoveredPeripherals.removeAll()
        // 清理设备 RSSI 缓存
        deviceRSSICache.removeAll()
        // 清理所有回调缓存
        callbacks.removeAll()
        permissionCallback = nil
        
        // 清理所有重连任务
        reconnectionAttempts.removeAll()
        reconnectionTimers.values.forEach { $0.cancel() }
        reconnectionTimers.removeAll()
        
        // 重置主动断开标志
        isIntentionalDisconnect = false
        
        // 清理外设管理器的缓存
        QXBlePeripheralManager.shared.clearAllCaches()
        // 重置蓝牙状态
        state = .unknown
        
        print("✅ 蓝牙适配器已关闭，所有资源已清理")
    }
    
    /// 获取本机蓝牙适配器状态
    /// - Returns: 包含蓝牙适配器状态信息和错误码的字典
    public func getBluetoothAdapterState() -> [String: Any] {
        var result: [String: Any] = [:]
        var adapterState: [String: Any] = [:]
        
        // 检查是否已初始化
        if centralManager == nil {
            result["errorCode"] = QXBleErrorCode.notInit.rawValue
            result["errorMessage"] = QXBleErrorCode.notInit.message
            result["data"] = [
                "available": false,
                "discovering": false
            ]
            return result
        }
        
        // 获取当前蓝牙硬件状态
        let currentState = centralManager.state
        
        // 根据 uni-app 文档标准返回状态
        adapterState["discovering"] = centralManager.isScanning
        
        // 检查蓝牙适配器是否可用
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
            // 蓝牙正常可用
            result["errorCode"] = QXBleErrorCode.success.rawValue
            result["errorMessage"] = QXBleErrorCode.success.message
            adapterState["available"] = true
        } else {
            // 其他状态（unknown, resetting等）
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
        if let permissionCallback = permissionCallback {
            handlePermissionCallback(permissionCallback: permissionCallback)
            self.permissionCallback = nil // 清理回调引用
        }
        
        // 通知所有缓存的回调蓝牙状态变化
        notifyAllCallbacksForBluetoothStateChange()
    }
    
    /// 处理权限回调（内部方法）
    /// - Parameter permissionCallback: 权限回调对象
    private func handlePermissionCallback(permissionCallback: JDBridgeCallBack) {
        if #available(iOS 13.1, *) {
            let auth = QXBleUtils.checkBluetoothPermission()
            switch auth {
            case .allowedAlways:
                permissionCallback.onSuccess(QXBleResult.success(message: "蓝牙权限授权成功"))
            case .denied:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            case .notDetermined:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .permissionNotDetermined))
            case .restricted:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .permissionDenied, customMessage: "蓝牙权限受限制"))
            @unknown default:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .unknownError))
            }
        } else {
            let status = QXBleUtils.checkBluetoothPermissionLegacy()
            switch status {
            case .authorized:
                permissionCallback.onSuccess(QXBleResult.success(message: "蓝牙权限授权成功"))
            case .denied:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            case .notDetermined:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .permissionNotDetermined))
            case .restricted:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .permissionDenied, customMessage: "蓝牙权限受限制"))
            @unknown default:
                permissionCallback.onFail(QXBleResult.failure(errorCode: .unknownError))
            }
        }
    }
    
    /// 通知所有缓存回调蓝牙状态变化（内部方法）
    private func notifyAllCallbacksForBluetoothStateChange() {
        guard state != .poweredOn else { return }
        
        let scanCallbackKeys = callbacks.keys.filter {
            QXBleUtils.getCallbackTypePrefix(from: $0) == QXBLEventType.onBluetoothDeviceFound.prefix
        }
        
        let errorMsg = "蓝牙状态异常：\(state.description)"
        for key in scanCallbackKeys {
            let callback = callbacks[key] ?? nil
            callback?.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen, customMessage: errorMsg))
            callbacks.removeValue(forKey: key)
        }
        
        cancelScanTimeout()
        centralManager?.stopScan()
    }
    
    /// 发现蓝牙设备回调
    /// 当扫描到附近的蓝牙设备时调用
    /// - Parameters:
    ///   - central: 蓝牙中心管理器实例
    ///   - peripheral: 发现的蓝牙外设
    ///   - advertisementData: 设备广播数据
    ///   - RSSI: 设备信号强度（单位：dBm，负值越小信号越强）
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // 1. 过滤无名称设备（可选，根据业务需求决定是否过滤）
        guard peripheral.name != nil else {
            return
        }
        
        // 优先从广播数据中获取本地名称
        let broadcastName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        // 其次获取peripheral的name属性
        let peripheralName = peripheral.name
        // 最终使用的名称（优先级：广播名称 > peripheral.name > 兜底值）
        let finalDeviceName = broadcastName ?? peripheralName ?? "未知设备"
        // 2. 去重添加设备到扫描结果列表
        let deviceId = peripheral.identifier.uuidString
        let isExisted = discoveredPeripherals.contains { $0.identifier.uuidString == deviceId }
        
        if !isExisted {
            discoveredPeripherals.append(peripheral)
            print("发现新设备：\(peripheral.name ?? "未知") (\(deviceId)), RSSI: \(RSSI)")
        }
        
        // 3. 缓存或更新设备的RSSI值（用于信号强度排序）
        deviceRSSICache[deviceId] = RSSI
        
        // 4. 实时回调扫描结果给JS端（仅新设备）
        if !isExisted {
            callbacks.forEach { (key, callback) in
                // 检查是否为设备发现回调
                if QXBleUtils.getCallbackTypePrefix(from: key) == QXBLEventType.onBluetoothDeviceFound.prefix {
                    let params: [String: Any] = [
                        "name": finalDeviceName,
                        "RSSI": RSSI.intValue,
                        "deviceId": deviceId,
                        "eventName": "onBluetoothDeviceFound"
                    ]

                    // 调用JS回调
                    callback?.callJSWithPluginName("QXBlePlugin", params: params) { _, _ in
                        print("✅ 设备发现事件已通知JS端：\(peripheral.name ?? "未知")")
                    }
                }
            }
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
            print("✅ 设备重连成功（第\(attemptCount)次尝试）：\(peripheral.name ?? "未知") (\(deviceId))")
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
            print("✅ 设备连接成功：\(peripheral.name ?? "未知") (\(deviceId))")
        }
        print("📊 设备连接状态：\(peripheral.state.rawValue) (\(peripheral.state.description))")
        
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
            print("❌ 设备重连失败（第\(currentAttempt)次尝试）：\(peripheral.name ?? "未知") (\(deviceId))")
            if let error = error {
                print("❌ 失败原因：\(error.localizedDescription)")
            }
            // 继续尝试下一次重连
            attemptReconnection(peripheral: peripheral, attempt: currentAttempt + 1)
        } else {
            print("❌ 设备连接失败：\(peripheral.name ?? "未知") (\(deviceId))")
            if let error = error {
                print("❌ 失败原因：\(error.localizedDescription)")
            }
            print("✅ 已取消连接超时任务")
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
        let targetCallback = callbacks.first { key, _ in
            let prefix = QXBleUtils.getCallbackTypePrefix(from: key)
            let extractedDeviceId = QXBleUtils.getDeviceId(from: key)
            return prefix == QXBLEventType.connectBluetoothDevice.prefix && extractedDeviceId == deviceId
        }
        guard let (key, callback) = targetCallback else { return }
        if isSuccess, let peripheral = peripheral {
            // 连接成功
            let result = QXBleResult.success(
                data: [
                    "deviceId": deviceId,
                    "name": peripheral.name ?? "未知设备"
                ],
                message: "设备连接成功"
            )
            callback?.onSuccess(result)
        } else {
            // 连接失败
            let errorMsg = error?.localizedDescription ?? "设备连接失败"
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
        }
        let params: [String: Any] = [
            "eventName": "onBLEConnectionStateChange",
            "isConnected": isSuccess,
            "deviceId": deviceId,
            "name": peripheral?.name ?? "未知设备"
        ]
        callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
        // 清理回调缓存
        callbacks.removeValue(forKey: key)
    }
    
    /// 设备断开连接回调
    /// 当与蓝牙设备断开连接时调用
    /// - Parameters:
    ///   - central: 蓝牙中心管理器实例
    ///   - peripheral: 已断开连接的蓝牙外设
    ///   - error: 断开连接的错误信息（如果有）
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        // 判断是否为异常断开
        let isUnexpectedDisconnect = error != nil && !isIntentionalDisconnect
        if let error = error {
            print("⚠️ 设备异常断开：\(peripheral.name ?? "未知") (\(deviceId)) \(error.localizedDescription)")
        } else {
            print("🔌 设备正常断开：\(peripheral.name ?? "未知") (\(deviceId))")
        }
        // 清理连接状态（但不清理重连状态，如果需要重连的话）
        if currentConnectedDeviceId == deviceId {
            currentConnectedPeripheral = nil
            currentConnectedDeviceId = nil
            print("📱 已清空当前设备")
        }
        // 通知JS端连接状态变化
        let params: [String: Any] = [
            "eventName": "onBLEConnectionStateChange",
            "deviceId": deviceId,
            "name": peripheral.name ?? "未知设备",
            "isConnected": false,
            "isUnexpected": isUnexpectedDisconnect
        ]
        callJSWithPluginName("QXBlePlugin", params: params) { _, _ in }
        // 异常断开时尝试自动重连
        if isUnexpectedDisconnect {
            print("🔄 检测到异常断开，准备自动重连...")
            // 重置主动断开标志
            isIntentionalDisconnect = false
            // 初始化重连计数
            reconnectionAttempts[deviceId] = 0
            // 开始第一次重连尝试
            attemptReconnection(peripheral: peripheral, attempt: 1)
        } else {
            // 正常断开，清理重连状态
            reconnectionAttempts.removeValue(forKey: deviceId)
            cancelReconnection(for: deviceId)
            // 重置主动断开标志
            isIntentionalDisconnect = false
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
