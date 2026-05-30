import Foundation
import CoreBluetooth

@objc(QXBlePlugin)
public class QXBlePlugin: JDBridgeBasePlugin {
    private let errorDomain = "QXBlePlugin"
    
    // MARK: - Entry
    /// JS Bridge 的统一入口，签名需要与 OC 基类保持一致。
    @objc public override func excute(_ action: String, params: [AnyHashable : Any], callback: JDBridgeCallBack) -> Bool {
        switch action {
        case "openBluetoothAdapter":
            initBle(params: params, callback: callback)
            return true
        case "startBluetoothDevicesDiscovery":
            startBluetoothDevicesDiscovery(params: params, callback: callback)
            return true
        case "stopBluetoothDevicesDiscovery":
            stopBluetoothDevicesDiscovery(params: params, callback: callback)
            return true
        case "createBLEConnection":
            createBLEConnection(params: params, callback: callback)
            return true
        case "getBLEDeviceServices":
            getBLEDeviceServices(params: params, callback: callback)
            return true
        case "getBLEDeviceCharacteristics":
            getBLEDeviceCharacteristics(params: params, callback: callback)
            return true
        case "closeBLEConnection":
            closeBLEConnection(params: params, callback: callback)
            return true
        case "writeBLECharacteristicValue":
            writeBLECharacteristicValue(params: params, callback: callback)
            return true
        case "notifyBLECharacteristicValueChange":
            notifyBLECharacteristicValueChange(params: params, callback: callback)
            return true
        case "requestBluetoothPermission":
            requestBluetoothPermission(params: params, callback: callback)
            return true
        case "checkBluetoothPermission":
            checkBluetoothPermission(params: params, callback: callback)
            return true
        case "openAppSettings":
            openAppSettings(params: params, callback: callback)
            return true
        case "closeBluetoothAdapter":
            closeBluetoothAdapter(params: params, callback: callback)
            return true
        case "getBluetoothAdapterState":
            getBluetoothAdapterState(params: params, callback: callback)
            return true
        case "getBluetoothDevices":
            getBluetoothDevices(params: params, callback: callback)
            return true
        default:
            callback.onFail(QXBleResult.failure(errorCode: .unknownError, customMessage: "不支持的操作：\(action)"))
            return false
        }
    }
    
    // MARK: - Permission
    private func requestBluetoothPermission(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        QXBleCentralManager.shared.requestBluetoothPermission(callback: callback)
    }
    
    private func checkBluetoothPermission(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        var permissionData: [String: Any] = [:]
        
        let auth = QXBleUtils.checkBluetoothPermission()
        permissionData["authorization"] = auth.rawValue
        permissionData["authorizationDesc"] = auth.description
        
        permissionData["isAuthorized"] = QXBleUtils.isBluetoothPermissionAuthorized()
        permissionData["isDenied"] = QXBleUtils.isBluetoothPermissionDenied()
        permissionData["isNotDetermined"] = QXBleUtils.isBluetoothPermissionNotDetermined()
        
        let result = QXBleResult.success(
            data: permissionData,
            message: "权限检查完成"
        )
        callback.onSuccess(result)
    }
    
    private func openAppSettings(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        QXBleUtils.openAppSettings()
        callback.onSuccess(QXBleResult.success(message: "已打开应用设置页面"))
    }
    
    private func closeBluetoothAdapter(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        QXBleCentralManager.shared.closeBluetoothAdapter()
        callback.onSuccess(QXBleResult.success(message: "蓝牙适配器已关闭"))
    }
    
    private func getBluetoothAdapterState(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        let stateResult = QXBleCentralManager.shared.getBluetoothAdapterState()
        
        if let errorCode = stateResult["errorCode"] as? Int, errorCode != 0 {
            let errorMessage = stateResult["errorMessage"] as? String ?? "获取蓝牙适配器状态失败"
            callback.onFail(QXBridgeError.make(
                code: errorCode,
                message: errorMessage,
                domain: errorDomain,
                data: stateResult["data"] ?? [:]
            ))
        } else {
            callback.onSuccess([
                "code": 0,
                "message": "获取蓝牙适配器状态成功",
                "data": stateResult["data"] ?? [:]
            ])
        }
    }
    
    /// 获取在蓝牙模块生效期间所有已发现的蓝牙设备
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 获取设备列表结果回调
    private func getBluetoothDevices(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 调用中心管理器获取已发现的蓝牙设备
        let devicesResult = QXBleCentralManager.shared.getBluetoothDevices()
        
        // 根据结果返回相应的响应
        if let errorCode = devicesResult["errorCode"] as? Int, errorCode != 0 {
            // 有错误，返回失败结果
            let errorMessage = devicesResult["errorMessage"] as? String ?? "获取蓝牙设备列表失败"
            callback.onFail(QXBridgeError.make(
                code: errorCode,
                message: errorMessage,
                domain: errorDomain,
                data: devicesResult["data"] ?? [:]
            ))
        } else {
            callback.onSuccess([
                "code": 0,
                "message": "获取蓝牙设备列表成功",
                "data": devicesResult["data"] ?? [:]
            ])
        }
    }
    
    // MARK: - 基础初始化
    /// 初始化蓝牙管理器
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 初始化结果回调
    private func initBle(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        if QXBleUtils.isBluetoothPermissionAuthorized() {
            QXBleCentralManager.shared.setupCentralManager(permissionCallback: callback)
            return
        }
        
        if QXBleUtils.isBluetoothPermissionDenied() {
            callback.onFail(bluetoothPermissionError("蓝牙权限被拒绝，请前往设置开启", data: [
                "isAuthorized": false,
                "isDenied": true,
                "isNotDetermined": false
            ]))
            return
        }
        
        // 首次未授权时先初始化 CBCentralManager，交给系统触发蓝牙权限弹窗。
        QXBleCentralManager.shared.setupCentralManager(permissionCallback: callback)
    }

    private func bluetoothPermissionError(_ message: String, data: [String: Any] = [:]) -> NSError {
        print("bluetoothPermissionError", message)
        return QXBridgeError.noPermission(message, domain: errorDomain, data: data)
    }
    
    // MARK: - 设备扫描
    /// 开始扫描蓝牙设备
    private func startBluetoothDevicesDiscovery(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        let central = QXBleCentralManager.shared
        
        guard central.centralManager != nil else {
            callback.onFail(QXBleResult.failure(errorCode: .notInit))
            return
        }
        
        if QXBleUtils.isBluetoothPermissionNotDetermined() {
            callback.onFail(bluetoothPermissionError("蓝牙权限未授权，请先授权", data: [
                "isAuthorized": false,
                "isDenied": false,
                "isNotDetermined": true
            ]))
            return
        }
        
        guard QXBleUtils.isBluetoothPermissionAuthorized() else {
            callback.onFail(bluetoothPermissionError("蓝牙权限被拒绝，请前往设置开启", data: [
                "isAuthorized": false,
                "isDenied": true,
                "isNotDetermined": false
            ]))
            return
        }
        
        guard central.state == .poweredOn else {
            callback.onFail(QXBleResult.failure(errorCode: .bluetoothNotOpen))
            return
        }
        
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBLEventType.onBluetoothDeviceFound.rawValue)
        
        var serviceUUIDs: [CBUUID]? = nil
        if let uuids = params["services"] as? [String] {
            serviceUUIDs = uuids.map { CBUUID(string: $0) }
        }
        
        let timeout = params["timeout"] as? TimeInterval ?? 10.0
        
        let started = central.startScan(
            services: serviceUUIDs,
            timeout: timeout,
            callbackKey: callbackKey,
            callback: callback
        )
        
        if started {
            callback.onSuccess(["errMsg": "startBluetoothDevicesDiscovery:ok"])
        }
    }
    
    private func stopBluetoothDevicesDiscovery(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        let callbackKey = params["callbackKey"] as? String ?? QXBleUtils.generateCallbackKey(prefix: QXBLEventType.onBluetoothDeviceFound.rawValue)
        QXBleCentralManager.shared.stopScan(callbackKey: callbackKey)
        callback.onSuccess(QXBleResult.success(message: "已停止扫描蓝牙设备"))
    }
    
    // MARK: - Connection
    private func createBLEConnection(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        guard let deviceId = params["deviceId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId不能为空"
            ))
            return
        }
        
        let centralManager = QXBleCentralManager.shared
        guard let manager = centralManager.centralManager else {
            callback.onFail(QXBleResult.failure(errorCode: .notInit))
            return
        }
        
        centralManager.cancelAllReconnections()
        
        if manager.isScanning {
            print("🛑 检测到正在扫描，先停止扫描再连接设备")
            manager.stopScan()
            centralManager.clearCallbacks(matchingPrefix: QXBLEventType.onBluetoothDeviceFound.prefix)
            print("✅ 已停止扫描，准备连接设备")
        }
        
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBLEventType.connectBluetoothDevice.rawValue, deviceId: deviceId)
        
        centralManager.connectPeripheral(
            deviceId: deviceId,
            callbackKey: callbackKey,
            callback: callback
        )
    }
    
    private func closeBLEConnection(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        guard let deviceId = params["deviceId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId不能为空"
            ))
            return
        }
        
        let callbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.disconnectDevice.prefix,
            deviceId: deviceId
        )
        
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
    ///             - value: 字符串数据
    ///             - valueType: 数据类型（UTF8/BASE64/HEX，默认UTF8）
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
        
        // 获取数据和类型
        let value = params["value"]
        let valueTypeStr = params["valueType"] as? String
        let dataType = QXBleUtils.DataType.from(valueTypeStr)
        
        guard let finalData = QXBleUtils.convertToData(value: value, type: dataType), !finalData.isEmpty else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "数据解析失败：value=\(String(describing: value))，type=\(valueTypeStr ?? "UTF8")"
            ))
            return
        }
        print("🔍 检查设备连接状态，deviceId: \(deviceId)")
        print("🔍 当前连接设备：\(QXBleCentralManager.shared.currentConnectedPeripheral?.name ?? "无")")
        guard let peripheral = QXBleCentralManager.shared.currentConnectedPeripheral,
              peripheral.identifier.uuidString == deviceId else {
            print("❌ 设备未连接或未找到：\(deviceId)")
            callback.onFail(QXBleResult.failure(
                errorCode: .deviceNotFound,
                customMessage: "设备未连接，请先连接设备"
            ))
            return
        }
        print("✅ 找到已连接设备：\(peripheral.name ?? "未知设备")")
        
        QXBlePeripheralManager.shared.writeValue(
            deviceId: deviceId,
            peripheral: peripheral,
            serviceId: serviceId,
            characteristicId: characteristicId,
            value: finalData,
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
        
        guard let peripheral = QXBleCentralManager.shared.currentConnectedPeripheral,
              peripheral.identifier.uuidString == deviceId else {
            print("❌ 获取服务失败：设备未连接 (\(deviceId))")
            callback.onFail(QXBleResult.failure(
                errorCode: .deviceNotFound,
                customMessage: "设备未连接，请先连接设备"
            ))
            return
        }
        
        print("🔍 开始获取设备服务：\(peripheral.name ?? "未知") (\(deviceId))")
        
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
        
        guard let peripheral = QXBleCentralManager.shared.currentConnectedPeripheral,
              peripheral.identifier.uuidString == deviceId else {
            callback.onFail(QXBleResult.failure(errorCode: .deviceNotFound))
            return
        }
        
        // 转换服务UUID为CBUUID
        let serviceCBUUID = CBUUID(string: serviceId)
        
        // 如果特征已缓存，直接返回，避免 iOS 不重复触发 discover 回调导致调用悬挂。
        let cacheKey = "\(deviceId)_\(serviceCBUUID.uuidString)"
        if let chars = QXBlePeripheralManager.shared.characteristicsCache[cacheKey] {
            callback.onSuccess(QXBleResult.success(
                data: ["characteristics": QXBleUtils.formatCharacteristics(chars, serviceId: serviceCBUUID.uuidString)],
                message: "获取特征成功，共\(chars.count)个特征"
            ))
            return
        }
        
        // 生成服务粒度特征发现回调Key并注册，避免等待其它服务的特征发现结果。
        let callbackKey = QXBleUtils.generateCallbackKey(
            prefix: QXBleCallbackType.discoverCharacteristics.prefix,
            deviceId: deviceId,
            serviceId: serviceCBUUID.uuidString
        )
        QXBlePeripheralManager.shared.registerCallback(callback, forKey: callbackKey)
        
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
              let enabled = params["enable"] as? Bool else {
            
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "参数错误：deviceId/serviceId/characteristicId/enabled不能为空"
            ))
            return
        }
        
        guard let peripheral = QXBleCentralManager.shared.currentConnectedPeripheral,
              peripheral.identifier.uuidString == deviceId else {
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

// MARK: - 权限状态扩展
/// 扩展CBManagerAuthorization，提供可读的权限状态描述
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
