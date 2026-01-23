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
        case "openBluetoothAdapter":
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
        case "closeBluetoothAdapter":
            // 关闭蓝牙适配器
            closeBluetoothAdapter(params: params, callback: callback)
            return true
        case "getBluetoothAdapterState":
            // 获取蓝牙适配器状态
            getBluetoothAdapterState(params: params, callback: callback)
            return true
        case "getBluetoothDevices":
            // 获取已发现的蓝牙设备
            getBluetoothDevices(params: params, callback: callback)
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
    
    /// 关闭蓝牙适配器
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 关闭结果回调
    private func closeBluetoothAdapter(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 调用中心管理器关闭蓝牙适配器
        QXBleCentralManager.shared.closeBluetoothAdapter()
        // 返回关闭成功结果
        callback.onSuccess(QXBleResult.success(message: "蓝牙适配器已关闭"))
    }
    
    /// 获取本机蓝牙适配器状态
    /// - Parameters:
    ///   - params: 预留参数（暂无实际用途）
    ///   - callback: 获取状态结果回调
    private func getBluetoothAdapterState(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 调用中心管理器获取蓝牙适配器状态
        let stateResult = QXBleCentralManager.shared.getBluetoothAdapterState()
        
        // 根据状态返回相应的结果
        if let errorCode = stateResult["errorCode"] as? Int, errorCode != 0 {
            // 有错误，返回失败结果
            let errorMessage = stateResult["errorMessage"] as? String ?? "获取蓝牙适配器状态失败"
            callback.onFail([
                "code": errorCode,
                "message": errorMessage,
                "data": stateResult["data"] ?? [:]
            ])
        } else {
            // 正常，返回成功结果
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
            callback.onFail([
                "code": errorCode,
                "message": errorMessage,
                "data": devicesResult["data"] ?? [:]
            ])
        } else {
            // 正常，返回成功结果
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
        // 1. 必传参数校验：deviceId
        guard let deviceId = params["deviceId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId不能为空"
            ))
            return
        }
        
        // 2. 连接前先停止扫描（避免扫描和连接同时进行导致资源竞争）
        let centralManager = QXBleCentralManager.shared
        if centralManager.centralManager.isScanning {
            print("🛑 检测到正在扫描，先停止扫描再连接设备")
            // 停止扫描
            centralManager.centralManager.stopScan()
            // 清理扫描相关的回调（避免内存泄漏）
            let scanCallbackKey = QXBleUtils.generateCallbackKey(prefix: QXBLEventType.onBluetoothDeviceFound.rawValue)
            centralManager.callbacks.removeValue(forKey: scanCallbackKey)
            print("✅ 已停止扫描，准备连接设备")
        }
        
        // 3. 生成连接操作的唯一回调Key
        let callbackKey = QXBleUtils.generateCallbackKey(prefix: QXBLEventType.connectBluetoothDevice.rawValue, deviceId: deviceId)
        
        // 4. 调用中心管理器连接设备
        centralManager.connectPeripheral(
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
    ///             - value: 字符串数据
    ///             - valueType: 数据类型（UTF8/BASE64/HEX，默认UTF8）
    ///   - callback: 写入结果回调
    private func writeBLECharacteristicValue(params: [AnyHashable: Any]!, callback: JDBridgeCallBack) {
        // 1. 必传参数校验
        guard let deviceId = params["deviceId"] as? String,
              let serviceId = params["serviceId"] as? String,
              let characteristicId = params["characteristicId"] as? String else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "deviceId/serviceId/characteristicId不能为空"
            ))
            return
        }
        
        // 2. 获取数据和类型（BUFFER类型value非字符串，单独处理）
        let value = params["value"]
        let valueType = (params["valueType"] as? String)?.uppercased() ?? "UTF8"
        
        // 3. 根据类型解析数据
        var valueData: Data?
        switch valueType {
        case "BASE64":
            // Base64格式解析
            guard let valueStr = value as? String, !valueStr.isEmpty else {
                print("❌ Base64数据为空")
                valueData = nil
                break
            }
            valueData = Data(base64Encoded: valueStr)
            if valueData == nil {
                print("❌ Base64数据解析失败：\(valueStr)")
            }

        case "BUFFER":
            // BUFFER类型解析：支持[Int]/JSON数组字符串/逗号分隔字符串，内置Uint8范围校验
            guard let value = value else {
                print("❌ BUFFER数据为空")
                valueData = nil
                break
            }
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
                valueData = nil
                break
            }
            // Uint8范围校验（0-255）+ 转Data
            var bufferData = Data(capacity: intArray.count)
            var isLegal = true
            for (index, intVal) in intArray.enumerated() {
                guard intVal >= 0 && intVal <= 255 else {
                    print("❌ BUFFER第\(index)位值\(intVal)超出Uint8范围(0-255)")
                    isLegal = false
                    break
                }
                bufferData.append(UInt8(intVal))
            }
            valueData = isLegal ? bufferData : nil
            
        case "HEX", "16进制":
            // 16进制格式解析（兼容空格、大小写）
            guard let valueStr = value as? String, !valueStr.isEmpty else {
                print("❌ 16进制数据为空")
                valueData = nil
                break
            }
            let cleanedHex = valueStr.replacingOccurrences(of: " ", with: "").uppercased()
            guard cleanedHex.count % 2 == 0 else {
                print("❌ 16进制数据长度不合法（非偶数）：\(valueStr)")
                valueData = nil
                break
            }
            let length = cleanedHex.count / 2
            var hexData = Data(capacity: length)
            var isHexLegal = true
            for i in 0..<length {
                let start = cleanedHex.index(cleanedHex.startIndex, offsetBy: i*2)
                let end = cleanedHex.index(start, offsetBy: 2)
                guard let byte = UInt8(cleanedHex[start..<end], radix: 16) else {
                    print("❌ 16进制解析失败：\(cleanedHex[start..<end])")
                    isHexLegal = false
                    break
                }
                hexData.append(byte)
            }
            valueData = isHexLegal ? hexData : nil
            
        case "UTF8", "TEXT":
            // UTF8/文本格式解析
            guard let valueStr = value as? String, !valueStr.isEmpty else {
                print("❌ UTF8数据为空")
                valueData = nil
                break
            }
            valueData = valueStr.data(using: .utf8)
            if valueData == nil {
                print("❌ UTF8数据解析失败：\(valueStr)")
            }
            
        default:
            // 未知类型：默认按UTF8解析
            print("⚠️ 未知的valueType：\(valueType)，默认按UTF8解析")
            guard let valueStr = value as? String else {
                print("❌ 未知类型数据非字符串，解析失败")
                valueData = nil
                break
            }
            valueData = valueStr.data(using: .utf8)
        }

        // 4. 数据解析结果最终校验
        guard let finalData = valueData, !finalData.isEmpty else {
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "数据解析失败：value=\(String(describing: value))，type=\(valueType)"
            ))
            return
        }
        
        // 打印写入数据（转16进制，内置实现无需扩展）
        let hexStr = finalData.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📤 准备写入数据【\(valueType)】：\(hexStr)（长度：\(finalData.count)字节）")
        
        // 5. 设备连接状态校验
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
        
        // 6. 调用外设管理器写入数据
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
        
        // 设备连接状态校验
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
        
        // 设备连接状态校验
        guard let peripheral = QXBleCentralManager.shared.currentConnectedPeripheral,
              peripheral.identifier.uuidString == deviceId else {
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
              let enabled = params["enable"] as? Bool else {
            
            callback.onFail(QXBleResult.failure(
                errorCode: .unknownError,
                customMessage: "参数错误：deviceId/serviceId/characteristicId/enabled不能为空"
            ))
            return
        }
        
        // 设备连接状态校验
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
