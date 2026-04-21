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
    /// - Returns: 用于 JDBridge `onFail` 的 NSError（保留蓝牙原有错误码）
    ///
    /// 说明：JDBridge 底层只认 `NSError` 才会把 status 置为非 0，H5 才能走 catch；
    /// 如果返回字典，status 会保持 "0"，H5 会误判为成功。
    /// 这里继续保留 `{ code, message, data }` 的 JSON 结构下发，
    /// H5 侧 `JSON.parse(err.message)` 的字段与改造前完全一致。
    public static func failure(errorCode: QXBleErrorCode, customMessage: String? = nil) -> NSError {
        let message = customMessage ?? errorCode.message
        return QXBridgeError.make(
            code: errorCode.rawValue,
            message: message,
            domain: "QXBlePlugin",
            data: [:] as [String: Any]
        )
    }
}
