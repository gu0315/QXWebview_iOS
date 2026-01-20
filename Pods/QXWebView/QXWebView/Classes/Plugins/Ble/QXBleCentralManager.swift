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
    
    /// 当前连接的设备（单设备连接模式）
    private(set) public var currentConnectedPeripheral: CBPeripheral?
    
    /// 当前连接设备的ID（方便快速访问）
    private(set) public var currentConnectedDeviceId: String?
    
    /// 已连接设备字典（key: deviceId, value: CBPeripheral）
    var connectedPeripherals: [String: CBPeripheral] = [:]
    
    // MARK: - 回调管理
    /// 回调缓存字典（key: callbackKey, value: 回调对象）
    private var callbacks: [String: JDBridgeCallBack?] = [:]
    
    /// 权限请求专用回调
    private var permissionCallback: JDBridgeCallBack?
    
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
    public func startScan(services: [CBUUID]?, timeout: TimeInterval = 10.0, callbackKey: String, callback: JDBridgeCallBack?) {
        // 权限检查
        guard QXBleUtils.isBluetoothPermissionAuthorized() else {
            callback?.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            return
        }
        
        // 蓝牙硬件状态检查
        guard state == .poweredOn else {
            callback?.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen))
            return
        }
        
        // 注册扫描回调
        callbacks[callbackKey] = callback
        
        // 清空历史扫描结果
        discoveredPeripherals.removeAll()
        
        // 配置扫描选项：不允许重复发现同一设备
        let scanOptions: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        
        // 开始扫描
        centralManager.scanForPeripherals(withServices: services, options: scanOptions)
        
        // 扫描超时处理
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            
            // 检查是否仍在扫描
            if self.centralManager.isScanning {
                self.stopScan(callbackKey: callbackKey)
                
                // 返回超时结果
                let result = QXBleResult.success(
                    data: ["devices": QXBleUtils.formatPeripherals(self.discoveredPeripherals)],
                    message: "扫描超时，已自动停止"
                )
                callback?.onSuccess(result)
            }
        }
    }
    
    /// 停止扫描蓝牙设备
    /// - Parameter callbackKey: 扫描时的回调标识
    public func stopScan(callbackKey: String) {
        // 停止扫描（双重校验）
        if centralManager.isScanning {
            centralManager.stopScan()
            
            // 触发扫描停止回调
            if let callback = callbacks[callbackKey] {
                let result = QXBleResult.success(
                    data: ["devices": QXBleUtils.formatPeripherals(discoveredPeripherals)],
                    message: "已停止扫描，共发现\(discoveredPeripherals.count)个设备"
                )
                callback?.onSuccess(result)
            }
            
            // 清理回调缓存
            callbacks.removeValue(forKey: callbackKey)
        }
    }
    
    // MARK: - 连接相关
    /// 连接蓝牙设备（单设备模式：自动断开已有连接）
    /// - Parameters:
    ///   - deviceId: 设备唯一标识（UUID字符串）
    ///   - callbackKey: 本次连接的回调标识
    ///   - callback: 连接结果回调
    public func connectPeripheral(deviceId: String, callbackKey: String, callback: JDBridgeCallBack) {
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
            return
        }
        
        // 单设备连接模式：断开已有连接
        if let currentPeripheral = currentConnectedPeripheral, currentPeripheral.identifier.uuidString != deviceId {
            centralManager.cancelPeripheralConnection(currentPeripheral)
            // 清理旧连接状态
            currentConnectedPeripheral = nil
            currentConnectedDeviceId = nil
            connectedPeripherals.removeValue(forKey: currentPeripheral.identifier.uuidString)
        }
        
        // 设置外设代理（处理服务/特征发现）
        peripheral.delegate = QXBlePeripheralManager.shared
        
        // 配置连接选项：开启连接/断开通知
        let connectOptions: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ]
        
        // 发起连接
        centralManager.connect(peripheral, options: connectOptions)
        
        // 连接超时处理（10秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            
            if peripheral.state != .connected {
                self.centralManager.cancelPeripheralConnection(peripheral)
                callback.onFail(QXBleResult.failure(errorCode: .connectTimeout))
                self.callbacks.removeValue(forKey: callbackKey)
            }
        }
    }
    
    /// 更新当前连接设备状态（内部方法）
    /// - Parameter peripheral: 新连接的外设
    private func updateCurrentConnectedPeripheral(_ peripheral: CBPeripheral) {
        currentConnectedPeripheral = peripheral
        currentConnectedDeviceId = peripheral.identifier.uuidString
        connectedPeripherals[peripheral.identifier.uuidString] = peripheral
    }
    
    /// 断开蓝牙设备连接
    /// - Parameters:
    ///   - deviceId: 设备唯一标识
    ///   - callbackKey: 本次断开操作的回调标识
    ///   - callback: 断开结果回调
    public func disconnectPeripheral(deviceId: String, callbackKey: String, callback: JDBridgeCallBack) {
        // 注册断开回调
        callbacks[callbackKey] = callback
        
        // 检查是否是当前连接的设备
        if let currentPeripheral = currentConnectedPeripheral, currentPeripheral.identifier.uuidString == deviceId {
            if currentPeripheral.state == .connected {
                // 发起断开连接请求
                centralManager.cancelPeripheralConnection(currentPeripheral)
            } else {
                // 设备未连接，直接返回成功
                cleanPeripheralConnectionState(deviceId: deviceId)
                let result = QXBleResult.success(message: "设备未连接")
                callback.onSuccess(result)
                callbacks.removeValue(forKey: callbackKey)
            }
        } else {
            // 未找到指定设备
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound))
            callbacks.removeValue(forKey: callbackKey)
        }
    }
    
    /// 清理外设连接状态（内部方法）
    /// - Parameter deviceId: 设备ID
    private func cleanPeripheralConnectionState(deviceId: String) {
        if currentConnectedDeviceId == deviceId {
            currentConnectedPeripheral = nil
            currentConnectedDeviceId = nil
        }
        connectedPeripherals.removeValue(forKey: deviceId)
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
        callbacks.forEach { (key, callback) in
            if state == .poweredOn {
                callback?.onSuccess(QXBleResult.success(message: "蓝牙已开启"))
            } else {
                let errorMsg = "蓝牙状态异常：\(state.description)"
                callback?.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen, customMessage: errorMsg))
            }
        }
    }
    
    /// 发现蓝牙设备回调
    /// 当扫描到附近的蓝牙设备时调用
    /// - Parameters:
    ///   - central: 蓝牙中心管理器实例
    ///   - peripheral: 发现的蓝牙外设
    ///   - advertisementData: 设备广播数据
    ///   - RSSI: 设备信号强度
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // 过滤空名称设备（可选）
        guard peripheral.name != nil else { return }
    
        // 去重添加设备到扫描结果列表
        let isExisted = discoveredPeripherals.contains { $0.identifier.uuidString == peripheral.identifier.uuidString }
        if !isExisted {
            discoveredPeripherals.append(peripheral)
            
            // 实时回调扫描结果给JS端
            callbacks.forEach { (key, callback) in
                if QXBleUtils.getCallbackTypePrefix(from: key) == QXBLEventType.onBluetoothDeviceFound.prefix {
                    let params: [String: Any] = [
                        "name": peripheral.name ?? "",
                        "rssi": RSSI,
                        "deviceId": peripheral.identifier.uuidString,
                        "eventName": "onBluetoothDeviceFound"
                    ]
                    callback?.callJSWithPluginName("QXBlePlugin", params: params) { _, _ in
                        print("发现设备回调执行：\(params)")
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
        
        // 更新连接状态
        updateCurrentConnectedPeripheral(peripheral)
        
        // 查找并触发连接成功回调
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
        
        // 查找并触发连接失败回调
        triggerConnectionCallback(deviceId: deviceId, isSuccess: false, error: error)
    }
    
    /// 触发连接回调（内部方法）
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
        
        // 清理连接状态
        cleanPeripheralConnectionState(deviceId: deviceId)
        
        // 查找并触发断开连接回调
        let targetCallback = callbacks.first { key, _ in
            let prefix = QXBleUtils.getCallbackTypePrefix(from: key)
            let extractedDeviceId = QXBleUtils.getDeviceId(from: key)
            return prefix == "disconnect" && extractedDeviceId == deviceId
        }
        
        guard let (key, callback) = targetCallback else { return }
        
        if let error = error {
            // 异常断开
            let errorMsg = "断开连接失败：\(error.localizedDescription)"
            callback?.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: errorMsg))
        } else {
            // 正常断开
            let result = QXBleResult.success(message: "设备已断开连接")
            callback?.onSuccess(result)
        }
        
        // 清理回调缓存
        callbacks.removeValue(forKey: key)
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
