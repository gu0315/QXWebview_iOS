# API 文档

## JSBridge 插件 API

### StatusBarPlugin

控制状态栏和导航栏的显示状态。

#### 方法

##### setImmersiveStatusBar
设置沉浸式状态栏。

**参数:**
- `immersive` (boolean): 是否启用沉浸式状态栏

**示例:**
```javascript
JDBridge.callNative('StatusBarPlugin', {
    action: 'setImmersiveStatusBar',
    params: {immersive: true},
    success: function(result) {
        console.log('设置成功:', result);
    }
});
```

##### setNavigationBarHidden
设置导航栏隐藏状态。

**参数:**
- `hidden` (boolean): 是否隐藏导航栏
- `animated` (boolean, 可选): 是否使用动画，默认为 true

**示例:**
```javascript
JDBridge.callNative('StatusBarPlugin', {
    action: 'setNavigationBarHidden',
    params: {hidden: true, animated: true},
    success: function(result) {
        console.log('设置成功:', result);
    }
});
```

##### getStatusBarInfo
获取状态栏信息。

**返回:**
```javascript
{
    "navBarHeight": 44,
    "statusBarHeight": 44,
    "screenHeight": 812,
    "bottomSafeHeight": 34
}
```

##### getScreenInfo
获取屏幕信息。

**返回:**
```javascript
{
    "screenWidth": 375,
    "screenHeight": 812,
    "statusBarHeight": 44,
    "navBarHeight": 88,
    "bottomSafeHeight": 34,
    "isIphoneX": true,
    "deviceModel": "iPhone 13",
    "systemVersion": "15.0",
    "appVersion": "1.0.0",
    "deviceId": "unique-device-id"
}
```

### DeviceInfoPlugin

获取设备相关信息。

#### 方法

##### getDeviceInfo
获取设备基本信息。

**返回:**
```javascript
{
    "deviceModel": "iPhone 13",
    "systemVersion": "15.0",
    "appVersion": "1.0.0",
    "buildVersion": "1",
    "deviceId": "unique-device-id",
    "screenWidth": 375,
    "screenHeight": 812,
    "isIphoneX": true,
    "statusBarHeight": 44,
    "navBarHeight": 88,
    "bottomSafeHeight": 34,
    "locale": "zh-CN",
    "timezone": "Asia/Shanghai"
}
```

##### getNetworkInfo
获取网络信息。

**返回:**
```javascript
{
    "connectionType": "wifi",
    "carrier": {
        "carrierName": "中国移动",
        "mobileCountryCode": "460",
        "mobileNetworkCode": "00"
    }
}
```

##### getBatteryInfo
获取电池信息。

**返回:**
```javascript
{
    "batteryLevel": 0.8,
    "batteryState": "unplugged"
}
```

##### getStorageInfo
获取存储信息。

**返回:**
```javascript
{
    "totalSpace": 128000000000,
    "freeSpace": 64000000000
}
```

##### vibrate
设备震动。

**参数:**
- `duration` (number, 可选): 震动持续时间，默认为 0.1 秒

### MediaPlugin

处理媒体相关功能。

#### 方法

##### chooseImage
选择图片。

**参数:**
- `maxCount` (number, 可选): 最大选择数量，默认为 1
- `allowCamera` (boolean, 可选): 是否允许拍照，默认为 true

**返回:**
```javascript
{
    "type": "image",
    "data": "base64-encoded-image-data",
    "width": 1920,
    "height": 1080
}
```

##### chooseVideo
选择视频。

**参数:**
- `maxDuration` (number, 可选): 最大时长（秒），默认为 60

**返回:**
```javascript
{
    "type": "video",
    "path": "file://path/to/video"
}
```

##### takePhoto
拍照。

**返回:**
```javascript
{
    "type": "image",
    "data": "base64-encoded-image-data",
    "width": 1920,
    "height": 1080
}
```

##### recordVideo
录制视频。

**参数:**
- `maxDuration` (number, 可选): 最大时长（秒），默认为 60

**返回:**
```javascript
{
    "type": "video",
    "path": "file://path/to/video"
}
```

##### saveImageToAlbum
保存图片到相册。

**参数:**
- `imageData` (string): Base64 编码的图片数据

**返回:**
```javascript
{
    "success": true
}
```

##### saveVideoToAlbum
保存视频到相册。

**参数:**
- `videoPath` (string): 视频文件路径

**返回:**
```javascript
{
    "success": true
}
```

### NotificationPlugin

管理本地通知。

#### 方法

##### requestPermission
请求通知权限。

**返回:**
```javascript
{
    "granted": true
}
```

##### scheduleNotification
安排通知。

**参数:**
- `title` (string): 通知标题
- `body` (string): 通知内容
- `identifier` (string, 可选): 通知标识符
- `delay` (number, 可选): 延迟时间（秒），默认为 1
- `badge` (number, 可选): 角标数字
- `userInfo` (object, 可选): 用户信息

**返回:**
```javascript
{
    "success": true,
    "identifier": "notification-id"
}
```

##### cancelNotification
取消通知。

**参数:**
- `identifier` (string): 通知标识符

**返回:**
```javascript
{
    "success": true
}
```

##### getNotificationSettings
获取通知设置。

**返回:**
```javascript
{
    "authorizationStatus": "authorized",
    "alertSetting": "enabled",
    "badgeSetting": "enabled",
    "soundSetting": "enabled",
    "lockScreenSetting": "enabled",
    "notificationCenterSetting": "enabled"
}
```

##### clearAllNotifications
清除所有通知。

**返回:**
```javascript
{
    "success": true
}
```

## 错误处理

### 错误码

| 错误码 | 描述 |
|--------|------|
| 1001 | 未知操作 |
| 1002 | 缺少必要参数 |
| 1003 | 缺少通知标识符 |
| 1004 | 无效的图片数据 |
| 1005 | 保存失败 |
| 1006 | 没有相册权限 |
| 1007 | 无效的视频路径 |
| 1008 | 保存失败 |
| 1009 | 没有相册权限 |
| 1010 | 用户取消选择 |

### 错误处理示例

```javascript
JDBridge.callNative('MediaPlugin', {
    action: 'chooseImage',
    params: {},
    success: function(result) {
        console.log('成功:', result);
    },
    fail: function(error) {
        console.error('失败:', error);
        // 处理错误
        if (error.code === 1006) {
            // 没有相册权限，引导用户开启
            showPermissionDialog();
        }
    }
});
```

## 最佳实践

### 1. 错误处理
- 始终检查 API 调用的结果
- 提供用户友好的错误提示
- 实现重试机制

### 2. 性能优化
- 避免频繁的 API 调用
- 使用缓存减少重复请求
- 及时清理不需要的资源

### 3. 用户体验
- 提供加载状态指示
- 使用适当的动画效果
- 确保操作的响应性

### 4. 安全考虑
- 验证用户输入
- 保护敏感数据
- 遵循隐私政策

## 更新日志

### v1.0.0
- 初始版本发布
- 支持基本的 JSBridge 通信
- 实现状态栏和导航栏控制
- 添加设备信息获取功能
- 支持媒体处理
- 实现通知管理

---

**注意**: 本文档会随着功能更新而持续维护，请关注最新版本。
