//
//  QXBleDefine.swift
//  MJExtension
//
//  Created by 顾钱想 on 12/23/25.
//

import Foundation
import CoreBluetooth
import LocalAuthentication

@frozen public enum QXBLEventType: String {
    /// 发现蓝牙设备
    case onBluetoothDeviceFound = "onBluetoothDeviceFound"
    /// BLE连接状态变化
    case onBLEConnectionStateChange = "onBLEConnectionStateChange"
    /// BLE特征值变化
    case onBLECharacteristicValueChange = "onBLECharacteristicValueChange"
    /// BLE通知状态变化
    case onBLENotificationStateChange = "onBLENotificationStateChange"
    /// BLE写入特征值结果
    case onBLEWriteCharacteristicValueResult = "onBLEWriteCharacteristicValueResult"
    
    case connectBluetoothDevice = "connectBluetoothDevice"
    
    /// 获取回调Key前缀
    var prefix: String {
        return self.rawValue
    }
}

// MARK: - 回调类型枚举
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
    
    /// 获取回调Key前缀
    var prefix: String {
        return self.rawValue
    }
}

// MARK: - 蓝牙错误码枚举
public enum QXBleErrorCode: Int {
    case success = 0
    case bluetoothNotOpen = -1
    case permissionDenied = -2
    case deviceNotFound = -3
    case connectTimeout = -4
    case characteristicNotFound = -5
    case writeNotSupported = -6
    case permissionNotDetermined = -7  // 权限未确定
    case scanNotAvailable = -8         // 扫描不可用
    case peripheralNil = -9            // 外设为空
    case unknownError = -99
    
    var message: String {
        switch self {
        case .success: return "操作成功"
        case .bluetoothNotOpen: return "蓝牙未开启"
        case .permissionDenied: return "蓝牙权限被拒绝，请前往设置开启"
        case .deviceNotFound: return "未找到指定设备"
        case .connectTimeout: return "设备连接超时"
        case .characteristicNotFound: return "未找到指定特征"
        case .writeNotSupported: return "特征不支持写入"
        case .permissionNotDetermined: return "蓝牙权限未授权，请先授权"
        case .scanNotAvailable: return "当前无法扫描蓝牙设备"
        case .peripheralNil: return "蓝牙外设对象为空"
        case .unknownError: return "未知错误"
        }
    }
}

// MARK: - 蓝牙权限类型
public enum QXBlePermissionType {
    case always  // 始终允许（iOS 13+）
    case whenInUse  // 使用期间允许（iOS 13+）
    case legacy  // 旧版权限（iOS < 13）
}

// MARK: - 蓝牙工具类
public class QXBleUtils {
    /// 格式化外设数据
    public static func formatPeripherals(_ peripherals: [CBPeripheral]) -> [[String: Any?]] {
        return peripherals.map { peripheral in
            [
                "deviceId": peripheral.identifier.uuidString,
                "name": peripheral.name,
                "rssi": peripheral.rssi,
                "state": peripheral.state.rawValue
            ]
        }
    }
    
    /// 格式化服务数据
    public static func formatServices(_ services: [CBService]) -> [[String: Any]] {
        return services.map { service in
            [
                "serviceId": service.uuid.uuidString,
                "isPrimary": service.isPrimary,
                "characteristicIds": [] as [String]
            ]
        }
    }
    
    /// 格式化特征数据
    public static func formatCharacteristics(_ chars: [CBCharacteristic], serviceId: String) -> [[String: Any]] {
        return chars.map { char in
            [
                "serviceId": serviceId,
                "characteristicId": char.uuid.uuidString,
                "properties": formatCharacteristicProperties(char.properties),
                "isNotifying": char.isNotifying
            ]
        }
    }
    
    /// 格式化特征属性
    private static func formatCharacteristicProperties(_ properties: CBCharacteristicProperties) -> [String] {
        var props: [String] = []
        if properties.contains(.read) { props.append("read") }
        if properties.contains(.write) { props.append("write") }
        if properties.contains(.writeWithoutResponse) { props.append("writeWithoutResponse") }
        if properties.contains(.notify) { props.append("notify") }
        if properties.contains(.indicate) { props.append("indicate") }
        return props
    }
    
    public static func generateCallbackKey(prefix: String) -> String {
        return "\(prefix)"
    }
    
    /// 生成回调Key
    public static func generateCallbackKey(prefix: String, deviceId: String = "") -> String {
        return "\(prefix)_\(deviceId)"
    }
    
    /// 生成回调Key（使用枚举类型）
    public static func generateCallbackKey(type: QXBleCallbackType, deviceId: String = "") -> String {
        return "\(type.prefix)_\(deviceId)"
    }
    
    /// 从回调Key中提取类型前缀
    public static func getCallbackTypePrefix(from key: String) -> String? {
        return key.components(separatedBy: "_").first
    }
    
    /// 从回调Key中提取设备ID
    public static func getDeviceId(from key: String) -> String? {
        let components = key.components(separatedBy: "_")
        return components.count >= 2 ? components[1] : nil
    }
    
    // MARK: - 蓝牙权限检查与请求
    /// 检查蓝牙权限状态
    @available(iOS 13.1, *)
    public static func checkBluetoothPermission() -> CBManagerAuthorization {
        return CBCentralManager.authorization
    }
    
    @available(iOS, deprecated: 13.0)
    public static func checkBluetoothPermissionLegacy() -> CBPeripheralManagerAuthorizationStatus {
        return CBPeripheralManager.authorizationStatus()
    }
    
    /// 判断蓝牙权限是否已授权
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
    public static func isBluetoothPermissionNotDetermined() -> Bool {
        if #available(iOS 13.1, *) {
            let auth = checkBluetoothPermission()
            return auth == .notDetermined
        } else {
            let status = checkBluetoothPermissionLegacy()
            return status == .notDetermined
        }
    }
    
    /// 打开应用设置页面
    public static func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - 回调结果构造器
public class QXBleResult {
    /// 构造成功结果
    public static func success(data: [String: Any] = [:], message: String = "操作成功") -> [String: Any] {
        return [
            "code": QXBleErrorCode.success.rawValue,
            "message": message,
            "data": data
        ]
    }
    
    /// 构造失败结果
    public static func failure(errorCode: QXBleErrorCode, customMessage: String? = nil) -> [String: Any] {
        return [
            "code": errorCode.rawValue,
            "message": customMessage ?? errorCode.message,
            "data": [:]
        ]
    }
}
