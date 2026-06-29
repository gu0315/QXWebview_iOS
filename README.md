# QXWebView

基于 JDBridge 的 iOS WebView SDK，支持 H5 与原生 APP 双向通信。

## 功能特性

- WebView 容器封装
- JSBridge 通信
- 蓝牙设备管理（BLE）
- 宿主 APP 回调（Protocol + Delegate）

## 系统要求

- iOS 15.0+
- Xcode 14.0+
- Swift 5.0+

## 安装

### CocoaPods

```ruby
pod 'QXWebView', :path => './QXWebView'
```

## 使用

### 基本使用

```swift
import QXWebView

// 创建 WebView
let webVC = QXWebViewController(url: "https://example.com")

// 设置 delegate（可选）
let delegate = MyHostDelegate(viewController: webVC)
webVC.hostDelegate = delegate

// 显示
navigationController?.pushViewController(webVC, animated: true)
```

### 宿主 APP 回调

实现 `QXWebViewHostDelegate` 协议：

```swift
class MyHostDelegate: NSObject, QXWebViewHostDelegate {
    
    // 打开页面
    func webViewRequestOpenPage(url: String, params: [String: Any]?, completion: @escaping (Any?) -> Void) {
        // 处理页面跳转
        completion(["success": true])
    }
    
    // 自定义方法
    func webViewRequestCustomMethod(methodName: String, params: [String: Any]?, completion: @escaping (Any?) -> Void) {
        switch methodName {
        case "getUserInfo":
            completion(["userId": "123", "userName": "张三"])
        default:
            completion(["success": false])
        }
    }
}
```

### H5 调用原生

```javascript
// 打开页面
window.QXHostBridgePlugin.openPage({
    // SDK 同时兼容 url / pageName，推荐优先使用 url
    url: 'app://home',
    params: { userId: '123' }
}, function(result, error) {
    console.log(result);
});

// 调用自定义方法
window.QXHostBridgePlugin.callCustomMethod({
    methodName: 'getUserInfo',
    params: {}
}, function(result, error) {
    console.log(result);
});
```

### 蓝牙功能

```javascript
// 扫描设备
window.QXBlePlugin.startScan({}, function(result, error) {
    console.log('扫描到设备:', result);
});

// 连接设备
window.QXBlePlugin.connect({
    deviceId: 'xxx'
}, function(result, error) {
    console.log('连接结果:', result);
});
```

## 项目结构

```
QXWebView/
├── Classes/
│   ├── JDBridge/           # JSBridge 核心
│   ├── JDWebView/          # WebView 容器
│   ├── Plugins/            # 插件
│   │   ├── Ble/           # 蓝牙插件
│   │   ├── QXBlePlugin.swift
│   │   ├── QXBasePlugin.swift
│   │   └── QXHostBridgePlugin.swift
│   └── QXWebViewHostDelegate.swift
└── Assets/                 # 资源文件
```

## 依赖

- SnapKit
- SDWebImage
- MJExtension

## 许可证

MIT License
