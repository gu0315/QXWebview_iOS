# BLE写入数据返回值修复说明

## 问题描述

在 `didWriteValueFor` 回调中，`characteristic.value` 经常为 `nil`，导致写入成功后无法返回实际写入的数据。

### 原因分析

根据 CoreBluetooth 的文档：
- 当使用 `writeValue(_:for:type:)` 方法写入数据时
- 如果写入类型是 `.withResponse`，系统会触发 `didWriteValueFor` 回调
- 但是 `characteristic.value` 并不保证包含刚写入的数据
- 这个属性通常只在 **读取** 或 **接收通知** 时才会更新

## 解决方案

### 1. 添加写入数据缓存

在 `QXBlePeripheralManager` 中添加一个字典来缓存写入的数据：

```swift
/// 最后写入的数据缓存（key: deviceId_characteristicId, value: Data）
/// 用于在写入回调中返回写入的数据，因为characteristic.value可能为nil
private var lastWrittenDataCache: [String: Data] = [:]
```

### 2. 写入时缓存数据

在 `writeValue` 方法中，写入前先缓存数据：

```swift
// 4. 缓存写入的数据（用于回调时返回）
let dataCacheKey = "\(deviceId)_\(characteristicId)"
lastWrittenDataCache[dataCacheKey] = value
print("💾 缓存写入数据：\(dataCacheKey) -> \(value.hexString)")
```

### 3. 回调时使用缓存数据

在 `didWriteValueFor` 回调中，优先使用缓存的数据：

```swift
// 优先使用缓存的数据，因为characteristic.value可能为nil
let dataCacheKey = "\(deviceId)_\(characteristicId)"
let writtenData = lastWrittenDataCache[dataCacheKey]

let result = QXBleResult.success(
    data: [
        "characteristicId": characteristicId,
        "value": writtenData?.hexString ?? "[]"  // 使用缓存的数据
    ],
    message: "写入特征值成功"
)

// 清理缓存的写入数据
lastWrittenDataCache.removeValue(forKey: dataCacheKey)
```

### 4. 清理缓存

在 `clearAllCaches` 方法中清理写入数据缓存：

```swift
// 清理写入数据缓存
lastWrittenDataCache.removeAll()
print("🧹 已清理写入数据缓存")
```

## 优化效果

### 修复前
```json
{
  "code": 0,
  "message": "写入特征值成功",
  "data": {
    "characteristicId": "0000FFE1-0000-1000-8000-00805F9B34FB",
    "value": "[]"  // ❌ 总是空数组
  }
}
```

### 修复后
```json
{
  "code": 0,
  "message": "写入特征值成功",
  "data": {
    "characteristicId": "0000FFE1-0000-1000-8000-00805F9B34FB",
    "value": "[01, a3, ff]"  // ✅ 返回实际写入的数据
  }
}
```

## 数据流程

```
1. JS调用写入 → writeBLECharacteristicValue
   ↓
2. 解析数据 → Data对象
   ↓
3. 缓存数据 → lastWrittenDataCache[deviceId_characteristicId] = data
   ↓
4. 执行写入 → peripheral.writeValue(data, for: char, type: .withResponse)
   ↓
5. 系统回调 → didWriteValueFor (characteristic.value可能为nil)
   ↓
6. 读取缓存 → lastWrittenDataCache[deviceId_characteristicId]
   ↓
7. 返回结果 → JS端收到实际写入的数据
   ↓
8. 清理缓存 → lastWrittenDataCache.removeValue(forKey: key)
```

## 注意事项

### 1. 缓存Key的设计
使用 `deviceId_characteristicId` 作为缓存Key，确保：
- 多设备场景下不会冲突
- 同一设备的不同特征值不会冲突

### 2. 内存管理
- 写入成功后立即清理缓存，避免内存泄漏
- 关闭蓝牙适配器时清理所有缓存

### 3. 并发写入
如果同时向同一特征值写入多次：
- 缓存会被覆盖为最新的数据
- 建议在业务层控制写入频率，避免并发写入

### 4. 无响应写入
对于 `.withoutResponse` 类型的写入：
- 不会触发 `didWriteValueFor` 回调
- 直接在 `writeValue` 方法中返回成功
- 不需要缓存数据

## 测试建议

### 测试用例1：有响应写入
```javascript
// 写入数据（有响应）
uni.writeBLECharacteristicValue({
  deviceId: 'xxx',
  serviceId: 'xxx',
  characteristicId: 'xxx',
  value: '01A3FF',
  valueType: 'HEX',
  success: (res) => {
    console.log('写入成功', res.data.value); // 应该返回 "[01, a3, ff]"
  }
});
```

### 测试用例2：无响应写入
```javascript
// 写入数据（无响应）
uni.writeBLECharacteristicValue({
  deviceId: 'xxx',
  serviceId: 'xxx',
  characteristicId: 'xxx',
  value: 'Hello',
  valueType: 'UTF8',
  success: (res) => {
    console.log('写入成功', res.data.value); // 应该返回实际数据
  }
});
```

### 测试用例3：连续写入
```javascript
// 连续写入多次
for (let i = 0; i < 5; i++) {
  uni.writeBLECharacteristicValue({
    deviceId: 'xxx',
    serviceId: 'xxx',
    characteristicId: 'xxx',
    value: `${i}`,
    valueType: 'UTF8',
    success: (res) => {
      console.log(`第${i}次写入成功`, res.data.value);
    }
  });
}
```

## 总结

通过添加 `lastWrittenDataCache` 缓存机制，成功解决了 `characteristic.value` 为 `nil` 的问题，确保写入成功后能够返回实际写入的数据，提升了用户体验和调试便利性。
