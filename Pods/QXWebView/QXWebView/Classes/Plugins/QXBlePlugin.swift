//
//  QXBlePlugin.swift
//  MJExtension
//
//  蓝牙桥接插件核心类
//  功能：作为OC与Swift的桥接层，对外提供统一的蓝牙操作接口，适配JS/OC调用
//  作者：顾钱想
//  日期：2025/12/23
//

import Foundation
import CoreBluetooth

@objc(QXBlePlugin)
public class QXBlePlugin: JDBridgeBasePlugin {
    /// 错误域标识，用于区分蓝牙插件的错误来源
    private let errorDomain = "QXBlePlugin"
    
    // MARK: - 重写 OC 父类方法（关键：严格匹配签名）
    /// 执行蓝牙操作的核心入口方法
    /// - Parameters:
    ///   - action: 操作指令名称（如initBle、startBluetoothDevicesDiscovery）
    ///   - params: 操作参数字典
    ///   - callback: 结果回调对象（用于返回成功/失败结果）
    /// - Returns: 是否支持该操作指令
    @objc public override func excute(_ action: String, params: [AnyHashable : Any], callback: JDBridgeCallBack) -> Bool {
        print("QXBlePlugin-excute-action:\(action), params:\(params)")
        // 根据指令名称分发到对应处理方法
        switch action {
        case "initBle":
            // 初始化蓝牙管理器
            initBle(params: params, callback: callback)
            return true
        case "startBluetoothDevicesDiscovery":
            // 开始扫描蓝牙设备
            startBluetoothDevicesDiscovery(params: params, callback: callback)
            return true
        case "stopBluetoothDevicesDiscovery":
            // 停止扫描蓝牙设备
            stopBluetoothDevicesDiscovery(params: params, callback: callback)
            return true
        case "createBLEConnection":
            // 连接蓝牙设备
            createBLEConnection(params: params, callback: callback)
            return true
        case "getBLEDeviceServices":
            // 获取设备服务列表
            getBLEDeviceServices(params: params, callback: callback)
            return true
        case "getBLEDeviceCharacteristics":
            // 获取服务下的特征值列表
            getBLEDeviceCharacteristics(params: params, callback: callback)
            return true
        case "closeBLEConnection":
            // 断开蓝牙设备连接
            closeBLEConnection(params: params, callback: callback)
            return true
        case "writeBLECharacteristicValue":
            // 向特征值写入数据
            writeBLECharacteristicValue(params: params, callback: callback)
            return true
        case "notifyBLECharacteristicValueChange":
            // 开启/关闭特征值通知
            notifyBLECharacteristicValueChange(params: params, callback: callback)
            return true
        case "requestBluetoothPermission":
            // 请求蓝牙权限
            requestBluetoothPermission(params: params, callback: callback)
            return true
        case "checkBluetoothPermission":
            // 检查蓝牙权限状态
            checkBluetoothPermission(params: params, callback: callback)
            return true
        case "openAppSettings":
            // 打开应用设置页面
            openAppSettings(params: params, callback: callback)
            return true
        default:
            // 不支持的操作，返回失败
            callback.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: "不支持的操作：\(action)"))
            return false
        }
    }
    
    // MARK: - 权限相关
    /// 请求蓝牙权限
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 权限请求结果回调
    private func requestBluetoothPermission(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        QXBleCentralManager.shared.requestBluetoothPermission(callback: callback)
    }
    
    /// 检查蓝牙权限状态
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 权限检查结果回调
    private func checkBluetoothPermission(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        var permissionData: [String: Any] = [:]
        
        // 区分iOS版本处理权限检查
        if #available(iOS 13.1, *) {
            let auth = QXBleUtils.checkBluetoothPermission()
            permissionData["authorization"] = auth.rawValue          // 权限状态原始值
            permissionData["authorizationDesc"] = auth.description   // 权限状态描述
        } else {
            let status = QXBleUtils.checkBluetoothPermissionLegacy()
            permissionData["authorization"] = status.rawValue
            permissionData["authorizationDesc"] = status.description
        }
        
        // 封装权限状态便捷字段
        permissionData["isAuthorized"] = QXBleUtils.isBluetoothPermissionAuthorized()      // 是否已授权
        permissionData["isDenied"] = QXBleUtils.isBluetoothPermissionDenied()              // 是否被拒绝
        permissionData["isNotDetermined"] = QXBleUtils.isBluetoothPermissionNotDetermined()// 是否未确定
        
        // 返回权限检查结果
        let result = QXBleResult.success(
            data: permissionData,
            message: "权限检查完成"
        )
        callback.onSuccess(result)
    }
    
    /// 打开应用设置页面（用于用户手动开启蓝牙权限）
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 操作结果回调
    private func openAppSettings(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        QXBleUtils.openAppSettings()
        callback.onSuccess(QXBleResult.success(message: "已打开应用设置页面"))
    }
    
    // MARK: - 基础初始化
    /// 初始化蓝牙管理器
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 初始化结果回调
    private func initBle(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 初始化蓝牙中心管理器，并传递权限回调
        QXBleCentralManager.shared.setupCentralManager(permissionCallback: callback)
    }
    
    // MARK: - 设备扫描
    /// 开始扫描蓝牙设备
    /// - Parameters:
    ///   - params: 扫描参数
    ///             - services: 要过滤的服务UUID数组（可选）
    ///             - timeout: 扫描超时时间（默认10秒）
    ///   - callback: 扫描操作结果回调
    private func startBluetoothDevicesDiscovery(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 权限前置检查：已拒绝
        guard QXBleUtils.isBluetoothPermissionAuthorized() else {
            callback.onFail(QXBleResult.failure(errorCode: .permissionDenied))
            return
        }
        
        // 权限前置检查：未确定
        if (QXBleUtils.isBluetoothPermissionNotDetermined()) {
            callback.onFail(QXBleResult.failure(errorCode: .permissionNotDetermined))
            return
        }
        
        // 生成唯一回调Key，用于标识本次扫描的回调
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBLEventType.onBluetoothDeviceFound.rawValue)
        
        // 解析扫描过滤参数：服务UUID
        var serviceUUIDs: [CBUUID]? = nil
        if let uuids = params["services"] as? [String] {
            serviceUUIDs = uuids.map { CBUUID(string: $0) }
        }
        
        // 解析扫描超时时间（默认10秒）
        let timeout = params["timeout"] as? TimeInterval ?? 10.0
        
        // 调用中心管理器开始扫描
        QXBleCentralManager.shared.startScan(
            services: serviceUUIDs,
            timeout: timeout,
            callbackKey: callbackKey,
            callback: callback
        )
        
        // 立即返回扫描开始的成功提示
        callback.onSuccess(QXBleResult.success(message: "开始扫描蓝牙设备"))
    }
    
    /// 停止扫描蓝牙设备
    /// - Parameters:
    ///   - params: 停止扫描参数
    ///             - callbackKey: 扫描时生成的回调Key
    ///   - callback: 停止扫描结果回调
    private func stopBluetoothDevicesDiscovery(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 获取扫描时的回调Key（无则生成默认值）
        let callbackKey = params["callbackKey"] as? String ?? QXBleUtils.generateCallbackKey(prefix: QXBLEventType.onBluetoothDeviceFound.rawValue)
        
        // 调用中心管理器停止扫描
        QXBleCentralManager.shared.stopScan(callbackKey: callbackKey)
        
        // 返回停止成功结果
        callback.onSuccess(QXBleResult.success(message: "已停止扫描蓝牙设备"))
    }
    
    // MARK: - 设备连接
    /// 连接蓝牙设备
    /// - Parameters:
    ///   - params: 连接参数
    ///             - deviceId: 设备唯一标识（UUID字符串）
    ///   - callback: 连接结果回调
    private func createBLEConnection(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 必传参数校验：deviceId
        guard let deviceId = params["deviceId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId不能为空"
            ))
            return
        }
        
        // 生成连接操作的唯一回调Key
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBLEventType.connectBluetoothDevice.rawValue, deviceId: deviceId)
        
        // 调用中心管理器连接设备
        QXBleCentralManager.shared.connectPeripheral(
            deviceId: deviceId,
            callbackKey: callbackKey,
            callback: callback
        )
    }
    
    /// 断开蓝牙设备连接
    /// - Parameters:
    ///   - params: 断开连接参数
    ///             - deviceId: 设备唯一标识（UUID字符串）
    ///   - callback: 断开连接结果回调
    private func closeBLEConnection(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 必传参数校验：deviceId
        guard let deviceId = params["deviceId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId不能为空"
            ))
            return
        }
        
        // 生成断开连接操作的唯一回调Key
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: "disconnect", deviceId: deviceId)
        
        // 调用中心管理器断开设备连接
        QXBleCentralManager.shared.disconnectPeripheral(
            deviceId: deviceId,
            callbackKey: callbackKey,
            callback: callback
        )
    }
    
    // MARK: - 特征操作
    /// 向蓝牙设备特征值写入数据
    /// - Parameters:
    ///   - params: 写入参数
    ///             - deviceId: 设备唯一标识
    ///             - serviceId: 服务UUID
    ///             - characteristicId: 特征值UUID
    ///             - value: 字符串数据（可选）
    ///             - valueBase64: Base64编码数据（可选）
    ///             - valueHex: 16进制字符串数据（可选）
    ///   - callback: 写入结果回调
    private func writeBLECharacteristicValue(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 必传参数校验
        guard let deviceId = params["deviceId"] as? String,
              let serviceId = params["serviceId"] as? String,
              let characteristicId = params["characteristicId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId/serviceId/characteristicId不能为空"
            ))
            return
        }
        
        var valueData: Data?
        // 1. 取出基础参数
        guard let valueStr = params["value"] as? String, !valueStr.isEmpty else {
            print("数据解析失败：value参数为空")
            return
        }
        let valueType = (params["valueType"] as? String)?.uppercased() ?? "UTF8" // 默认UTF8
        // 2. 按类型解析
        switch valueType {
        case "BASE64":
            // Base64格式解析
            valueData = Data(base64Encoded: valueStr)
        case "HEX", "16进制":
            // 16进制格式解析（兼容空格、大小写）
            let cleanedHex = valueStr.replacingOccurrences(of: " ", with: "").uppercased()
            let length = cleanedHex.count / 2
            var data = Data(capacity: length)
            for i in 0..<length {
                let start = cleanedHex.index(cleanedHex.startIndex, offsetBy: i*2)
                let end = cleanedHex.index(start, offsetBy: 2)
                if let byte = UInt8(cleanedHex[start..<end], radix: 16) {
                    data.append(byte)
                } else {
                    data = Data()
                    break
                }
            }
            valueData = data.count > 0 ? data : nil
        case "UTF8", "TEXT":
            // UTF8/文本格式解析（默认）
            valueData = valueStr.data(using: .utf8)
        default:
            // 未知类型：默认按UTF8解析
            print("未知的valueType：\(valueType)，默认按UTF8解析")
            valueData = valueStr.data(using: .utf8)
        }

        // 3. 最终校验
        guard valueData != nil else {
            print("数据解析失败：value=\(valueStr)，type=\(valueType)")
            return
        }
        // 设备连接状态校验
        guard let peripheral = QXBleCentralManager.shared.connectedPeripherals[deviceId] else {
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound))
            return
        }
        // 调用外设管理器写入数据
        QXBlePeripheralManager.shared.writeValue(
            deviceId: deviceId,
            peripheral: peripheral,
            serviceId: serviceId,
            characteristicId: characteristicId,
            value: valueData!,
            callback: callback
        )
    }
    
    /// 获取蓝牙设备的服务列表
    /// - Parameters:
    ///   - params: 请求参数
    ///             - deviceId: 设备唯一标识
    ///   - callback: 服务获取结果回调
    private func getBLEDeviceServices(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 必传参数校验
        guard let deviceId = params["deviceId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId不能为空"
            ))
            return
        }
        
        // 设备连接状态校验
        guard let peripheral = QXBleCentralManager.shared.connectedPeripherals[deviceId] else {
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound))
            return
        }
        
        // 生成服务发现回调Key并注册
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.getBLEDeviceServices.prefix, deviceId: deviceId)
        QXBlePeripheralManager.shared.registerCallback(callback, forKey: callbackKey)
        
        // 主动发现设备所有服务（nil表示发现所有服务）
        peripheral.discoverServices(nil)
    }
    
    /// 获取蓝牙设备指定服务下的特征值列表
    /// - Parameters:
    ///   - params: 请求参数
    ///             - deviceId: 设备唯一标识
    ///             - serviceId: 服务UUID
    ///   - callback: 特征值获取结果回调
    private func getBLEDeviceCharacteristics(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 必传参数校验
        guard let deviceId = params["deviceId"] as? String,
              let serviceId = params["serviceId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId和serviceId不能为空"
            ))
            return
        }
        
        // 设备连接状态校验
        guard let peripheral = QXBleCentralManager.shared.connectedPeripherals[deviceId] else {
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound))
            return
        }
        
        // 生成特征发现回调Key并注册
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.discoverCharacteristics.prefix, deviceId: deviceId)
        QXBlePeripheralManager.shared.registerCallback(callback, forKey: callbackKey)
        
        // 转换服务UUID为CBUUID
        let serviceCBUUID = CBUUID(string: serviceId)
        
        // 检查服务是否已缓存
        if let services = QXBlePeripheralManager.shared.servicesCache[deviceId],
           let targetService = services.first(where: { $0.uuid == serviceCBUUID }) {
            // 服务已存在，直接发现该服务下的特征
            peripheral.discoverCharacteristics(nil, for: targetService)
        } else {
            // 服务未缓存，先发现服务再发现特征
            peripheral.discoverServices([serviceCBUUID])
        }
    }
    
    /// 开启/关闭特征值通知
    /// - Parameters:
    ///   - params: 通知参数
    ///             - deviceId: 设备唯一标识
    ///             - serviceId: 服务UUID
    ///             - characteristicId: 特征值UUID
    ///             - enabled: 是否开启通知（true/false）
    ///   - callback: 通知设置结果回调
    private func notifyBLECharacteristicValueChange(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 必传参数校验
        guard let deviceId = params["deviceId"] as? String,
              let serviceId = params["serviceId"] as? String,
              let characteristicId = params["characteristicId"] as? String,
              let enabled = params["enabled"] as? Bool else {
            
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "参数错误：deviceId/serviceId/characteristicId/enabled不能为空"
            ))
            return
        }
        
        // 设备连接状态校验
        guard let peripheral = QXBleCentralManager.shared.connectedPeripherals[deviceId] else {
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound))
            return
        }
        
        // 生成通知操作回调Key
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBleCallbackType.notifyCharacteristic.prefix, deviceId: deviceId)
        
        // 调用外设管理器设置通知状态
        QXBlePeripheralManager.shared.setNotifyValue(
            deviceId: deviceId,
            peripheral: peripheral,
            serviceId: serviceId,
            characteristicId: characteristicId,
            enabled: enabled,
            callbackKey: callbackKey,
            callback: callback
        )
    }
}

// MARK: - 权限状态扩展（iOS 13+）
/// 扩展CBManagerAuthorization，提供可读的权限状态描述
@available(iOS 13.0, *)
extension CBManagerAuthorization: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "未确定"
        case .restricted: return "受限制（系统策略限制）"
        case .denied: return "已拒绝"
        case .allowedAlways: return "始终允许"
        @unknown default: return "未知权限状态(\(rawValue))"
        }
    }
}

/// 扩展CBPeripheralManagerAuthorizationStatus，提供可读的权限状态描述（iOS < 13）
extension CBPeripheralManagerAuthorizationStatus: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "未确定"
        case .restricted: return "受限制（系统策略限制）"
        case .denied: return "已拒绝"
        case .authorized: return "已授权"
        @unknown default: return "未知权限状态(\(rawValue))"
        }
    }
}

// MARK: - Data 16进制扩展
/// 扩展Data，支持从16进制字符串初始化
extension Data {
    /// 从16进制字符串初始化Data
    /// - Parameter hexString: 16进制字符串（如"01A3FF"）
    init?(hexString: String) {
        // 移除可能的空格和分隔符
        let cleanHex = hexString.replacingOccurrences(of: " ", with: "").uppercased()
        
        // 校验字符串长度是否为偶数
        guard cleanHex.count % 2 == 0 else { return nil }
        
        let len = cleanHex.count / 2
        var data = Data(capacity: len)
        
        // 逐字节解析16进制字符串
        for i in 0..<len {
            let start = cleanHex.index(cleanHex.startIndex, offsetBy: i*2)
            let end = cleanHex.index(start, offsetBy: 2)
            let byteString = String(cleanHex[start..<end])
            
            // 转换为UInt8字节
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
        }
        
        self = data
    }
}
