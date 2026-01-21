# uni.closeBluetoothAdapter(OBJECT) API 文档

## 功能描述

关闭蓝牙适配器，清理所有蓝牙相关资源。此方法会：

1. 停止正在进行的蓝牙设备扫描
2. 断开所有已连接的蓝牙设备
3. 清理设备连接状态缓存
4. 清理已发现设备列表
5. 清理所有回调缓存
6. 清理外设管理器的服务和特征缓存
7. 重置蓝牙状态

## 参数说明

### OBJECT 参数

| 参数名   | 类型     | 必填 | 说明                 |
|----------|----------|------|----------------------|
| success  | function | 否   | 接口调用成功的回调函数 |
| fail     | function | 否   | 接口调用失败的回调函数 |
| complete | function | 否   | 接口调用结束的回调函数 |

## 返回值

### success 回调参数

```javascript
{
    code: 0,                    // 成功状态码
    message: "蓝牙适配器已关闭",  // 成功消息
    data: {}                    // 返回数据（空对象）
}
```

### fail 回调参数

```javascript
{
    code: -99,                  // 错误状态码
    message: "错误描述信息",     // 错误消息
    data: {}                    // 返回数据（空对象）
}
```

## 错误码说明

| 错误码 | 说明           |
|--------|----------------|
| 0      | 操作成功       |
| -99    | 未知错误       |

## 使用示例

### 基本用法

```javascript
uni.closeBluetoothAdapter({
    success: function(res) {
        console.log('蓝牙适配器关闭成功:', res);
    },
    fail: function(err) {
        console.error('蓝牙适配器关闭失败:', err);
    },
    complete: function() {
        console.log('操作完成');
    }
});
```

### Promise 封装

```javascript
function closeBluetoothAdapter() {
    return new Promise((resolve, reject) => {
        uni.closeBluetoothAdapter({
            success: resolve,
            fail: reject
        });
    });
}

// 使用
try {
    const result = await closeBluetoothAdapter();
    console.log('蓝牙适配器关闭成功:', result);
} catch (error) {
    console.error('蓝牙适配器关闭失败:', error);
}
```

### 完整的资源清理流程

```javascript
async function cleanupBluetooth() {
    try {
        // 1. 停止扫描
        uni.stopBluetoothDevicesDiscovery({});
        
        // 2. 断开所有连接（如果有的话）
        // 这里需要根据实际连接的设备进行断开
        
        // 3. 关闭蓝牙适配器
        await closeBluetoothAdapter();
        
        console.log('蓝牙资源清理完成');
    } catch (error) {
        console.error('蓝牙资源清理失败:', error);
    }
}
```

## 调用时机

### 推荐的调用场景

1. **应用退出时**
   ```javascript
   // 在应用生命周期的 onHide 或 onUnload 中调用
   onUnload() {
       uni.closeBluetoothAdapter({});
   }
   ```

2. **页面切换时**
   ```javascript
   // 离开蓝牙相关页面时
   onUnload() {
       this.cleanupBluetooth();
   }
   ```

3. **重新初始化蓝牙前**
   ```javascript
   async function reinitBluetooth() {
       // 先关闭现有适配器
       await closeBluetoothAdapter();
       
       // 等待资源释放
       await new Promise(resolve => setTimeout(resolve, 500));
       
       // 重新初始化
       uni.initBle({...});
   }
   ```

4. **错误恢复时**
   ```javascript
   // 当蓝牙操作出现异常时，重置蓝牙状态
   function handleBluetoothError() {
       uni.closeBluetoothAdapter({
           complete: function() {
               // 重新初始化蓝牙
               uni.initBle({...});
           }
       });
   }
   ```

## 注意事项

1. **资源清理**：调用此方法会清理所有蓝牙相关资源，包括连接、缓存、回调等
2. **异步操作**：虽然方法会立即返回，但实际的资源清理是异步进行的
3. **重新使用**：关闭适配器后，如需重新使用蓝牙功能，需要重新调用 `uni.initBle()`
4. **连接断开**：会自动断开所有已连接的设备，无需手动断开
5. **扫描停止**：会自动停止正在进行的设备扫描

## 与其他 API 的关系

- `uni.initBle()`: 初始化蓝牙适配器，与 `closeBluetoothAdapter` 相对应
- `uni.startBluetoothDevicesDiscovery()`: 开始扫描，会被 `closeBluetoothAdapter` 自动停止
- `uni.createBLEConnection()`: 创建连接，会被 `closeBluetoothAdapter` 自动断开
- `uni.closeBLEConnection()`: 断开单个连接，`closeBluetoothAdapter` 会断开所有连接

## 最佳实践

1. **配对使用**：每次调用 `uni.initBle()` 后，在适当时机调用 `uni.closeBluetoothAdapter()`
2. **错误处理**：即使调用失败，也不会影响系统蓝牙功能
3. **资源管理**：在不需要蓝牙功能时及时调用，避免资源泄漏
4. **状态管理**：调用后应更新应用内的蓝牙状态标识

## 兼容性

- iOS 9.0+
- 支持所有集成了 QXWebView 的应用
- 兼容 uni-app 框架的蓝牙 API 规范