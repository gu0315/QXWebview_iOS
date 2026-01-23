//
//  QXBleDefine.swift
//  MJExtension
//
//  蓝牙常量定义文件
//  功能：定义蓝牙相关的枚举、错误码、工具类等
//  作者：顾钱想
//  日期：2025/12/23
//

import Foundation
import CoreBluetooth
import LocalAuthentication

// MARK: - 蓝牙事件类型枚举
/// 蓝牙事件类型，用于标识不同的蓝牙回调事件
@frozen public enum QXBLEventType: String {
    /// 发现蓝牙设备事件
    case onBluetoothDeviceFound = "onBluetoothDeviceFound"
    
    /// BLE连接状态变化事件
    case onBLEConnectionStateChange = "onBLEConnectionStateChange"
    
    /// BLE特征值变化事件（接收设备推送的数据）
    case onBLECharacteristicValueChange = "onBLECharacteristicValueChange"
    
    /// BLE通知状态变化事件
    case onBLENotificationStateChange = "onBLENotificationStateChange"
    
    /// BLE写入特征值结果事件
    case onBLEWriteCharacteristicValueResult = "onBLEWriteCharacteristicValueResult"
    
    /// 连接蓝牙设备事件
    case connectBluetoothDevice = "connectBluetoothDevice"
    
    /// 获取回调Key前缀（用于生成唯一的回调标识）
    var prefix: String {
        return self.rawValue
    }
}

// MARK: - 回调类型枚举
/// 蓝牙操作回调类型，用于区分不同的蓝牙操作回调
@frozen public enum QXBleCallbackType: String {
    /// 蓝牙设备发现回调
    case deviceFound = "deviceFound"
    
    /// 蓝牙设备连接回调
    case connectDevice = "connectDevice"
    
    /// 蓝牙设备断开回调
    case disconnectDevice = "disconnectDevice"
    
    /// 特征发现回调
    case discoverCharacteristics = "discoverCharacteristics"
    
    /// 特征写入回调
    case writeCharacteristic = "writeCharacteristic"
    
    /// 特征通知回调
    case notifyCharacteristic = "notifyCharacteristic"
    
    /// 服务发现回调
    case getBLEDeviceServices = "getBLEDeviceServices"
    
    /// 获取回调Key前缀（用于生成唯一的回调标识）
    var prefix: String {
        return self.rawValue
    }
}

// MARK: - 蓝牙错误码枚举
/// 蓝牙操作错误码，遵循uni-app标准错误码规范
public enum QXBleErrorCode: Int {
    // MARK: uni-app标准错误码（10000-10013）
    /// 操作成功
    case success = 0
    
    /// 未初始化蓝牙适配器
    case notInit = 10000
    
    /// 当前蓝牙适配器不可用（蓝牙未开启或不支持）
    case notAvailable = 10001
    
    /// 没有找到指定设备
    case noDevice = 10002
    
    /// 连接失败
    case connectionFail = 10003
    
    /// 没有找到指定服务
    case noService = 10004
    
    /// 没有找到指定特征值
    case noCharacteristic = 10005
    
    /// 当前连接已断开
    case noConnection = 10006
    
    /// 当前特征值不支持此操作
    case propertyNotSupport = 10007
    
    /// 其余所有系统上报的异常
    case systemError = 10008
    
    /// 系统版本不支持BLE（Android 4.3以下）
    case systemNotSupport = 10009
    
    /// 设备已连接
    case alreadyConnect = 10010
    
    /// 配对设备需要配对码
    case needPin = 10011
    
    /// 操作超时
    case operateTimeOut = 10012
    
    /// deviceId为空或格式不正确
    case invalidData = 10013
    
    // MARK: 自定义扩展错误码（负数区间）
    /// 蓝牙未开启
    case bluetoothNotOpen = -1
    
    /// 蓝牙权限被拒绝
    case permissionDenied = -2
    
    /// 设备未找到
    case deviceNotFound = -3
    
    /// 连接超时
    case connectTimeout = -4
    
    /// 特征值未找到
    case characteristicNotFound = -5
    
    /// 特征值不支持写入
    case writeNotSupported = -6
    
    /// 蓝牙权限未确定
    case permissionNotDetermined = -7
    
    /// 扫描不可用
    case scanNotAvailable = -8
    
    /// 外设对象为空
    case peripheralNil = -9
    
    /// 未知错误
    case unknownError = -99
    
    /// 错误码对应的描述信息
    var message: String {
        switch self {
        // uni-app标准错误码描述
        case .success:
            return "操作成功"
        case .notInit:
            return "未初始化蓝牙适配器"
        case .notAvailable:
            return "当前蓝牙适配器不可用"
        case .noDevice:
            return "没有找到指定设备"
        case .connectionFail:
            return "连接失败"
        case .noService:
            return "没有找到指定服务"
        case .noCharacteristic:
            return "没有找到指定特征值"
        case .noConnection:
            return "当前连接已断开"
        case .propertyNotSupport:
            return "当前特征值不支持此操作"
        case .systemError:
            return "系统上报异常"
        case .systemNotSupport:
            return "系统版本不支持BLE"
        case .alreadyConnect:
            return "设备已连接"
        case .needPin:
            return "配对设备需要配对码"
        case .operateTimeOut:
            return "操作超时"
        case .invalidData:
            return "deviceId为空或格式不正确"
            
        // 自定义错误码描述
        case .bluetoothNotOpen:
            return "蓝牙未开启"
        case .permissionDenied:
            return "蓝牙权限被拒绝，请前往设置开启"
        case .deviceNotFound:
            return "未找到指定设备"
        case .connectTimeout:
            return "设备连接超时"
        case .characteristicNotFound:
            return "未找到指定特征值"
        case .writeNotSupported:
            return "特征值不支持写入操作"
        case .permissionNotDetermined:
            return "蓝牙权限未授权，请先授权"
        case .scanNotAvailable:
            return "当前无法扫描蓝牙设备"
        case .peripheralNil:
            return "蓝牙外设对象为空"
        case .unknownError:
            return "未知错误"
        }
    }
}

// MARK: - 蓝牙权限类型枚举
/// 蓝牙权限类型，用于区分不同iOS版本的权限模式
public enum QXBlePermissionType {
    /// 始终允许（iOS 13+）
    case always
    
    /// 使用期间允许（iOS 13+）
    case whenInUse
    
    /// 旧版权限模式（iOS < 13）
    case legacy
}

// MARK: - 蓝牙工具类
/// 蓝牙工具类，提供数据格式化、权限检查、回调管理等通用功能
public class QXBleUtils {
    
    // MARK: - 数据格式化方法
    
    /// 格式化外设数据为字典数组
    /// - Parameter peripherals: 蓝牙外设数组
    /// - Returns: 格式化后的字典数组
    public static func formatPeripherals(_ peripherals: [CBPeripheral]) -> [[String: Any?]] {
        return peripherals.map { peripheral in
            [
                "deviceId": peripheral.identifier.uuidString,  // 设备唯一标识
                "name": peripheral.name,                       // 设备名称
                "rssi": peripheral.rssi,                       // 信号强度
                "state": peripheral.state.rawValue            // 连接状态
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
    
    /// 检查蓝牙权限状态（iOS 13.1+）
    /// - Returns: 蓝牙权限授权状态
    @available(iOS 13.1, *)
    public static func checkBluetoothPermission() -> CBManagerAuthorization {
        return CBCentralManager.authorization
    }
    
    /// 检查蓝牙权限状态（iOS 13以下）
    /// - Returns: 蓝牙权限授权状态
    @available(iOS, deprecated: 13.0, message: "使用 checkBluetoothPermission() 替代")
    public static func checkBluetoothPermissionLegacy() -> CBPeripheralManagerAuthorizationStatus {
        return CBPeripheralManager.authorizationStatus()
    }
    
    /// 判断蓝牙权限是否已授权
    /// - Returns: true表示已授权，false表示未授权
    public static func isBluetoothPermissionAuthorized() -> Bool {
        if #available(iOS 13.1, *) {
            let auth = checkBluetoothPermission()
            return auth == .allowedAlways
        } else {
            let status = checkBluetoothPermissionLegacy()
            return status == .authorized
        }
    }
    
    /// 判断蓝牙权限是否被拒绝
    /// - Returns: true表示已拒绝，false表示未拒绝
    public static func isBluetoothPermissionDenied() -> Bool {
        if #available(iOS 13.1, *) {
            let auth = checkBluetoothPermission()
            return auth == .denied
        } else {
            let status = checkBluetoothPermissionLegacy()
            return status == .denied
        }
    }
    
    /// 判断蓝牙权限是否未确定
    /// - Returns: true表示未确定，false表示已确定
    public static func isBluetoothPermissionNotDetermined() -> Bool {
        if #available(iOS 13.1, *) {
            let auth = checkBluetoothPermission()
            return auth == .notDetermined
        } else {
            let status = checkBluetoothPermissionLegacy()
            return status == .notDetermined
        }
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
}

// MARK: - 回调结果构造器
/// 蓝牙操作结果构造器，用于统一格式化成功/失败结果
public class QXBleResult {
    
    /// 构造成功结果
    /// - Parameters:
    ///   - data: 返回的数据字典（可选）
    ///   - message: 成功提示信息
    /// - Returns: 格式化的成功结果字典
    public static func success(data: [String: Any] = [:], message: String = "操作成功") -> [String: Any] {
        return [
            "code": QXBleErrorCode.success.rawValue,
            "message": message,
            "data": data
        ]
    }
    
    /// 构造失败结果
    /// - Parameters:
    ///   - errorCode: 错误码枚举
    ///   - customMessage: 自定义错误信息（可选，默认使用错误码对应的message）
    /// - Returns: 格式化的失败结果字典
    public static func failure(errorCode: QXBleErrorCode, customMessage: String? = nil) -> [String: Any] {
        return [
            "code": errorCode.rawValue,
            "message": customMessage ?? errorCode.message,
            "data": [:]
        ]
    }
}
