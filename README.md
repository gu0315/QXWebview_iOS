# 奇瑞绿能 Hybrid 容器 iOS 应用

## 项目概述

这是一个基于 JDBridge 的混合开发 iOS 应用，支持 Web 和 Native 之间的双向通信。应用采用现代化的架构设计，提供了丰富的功能和优秀的用户体验。

## 主要特性

### 🚀 核心功能
- **混合开发支持**: 基于 JDBridge 的 Web-Native 通信
- **现代化 UI**: 支持沉浸式状态栏和导航栏控制
- **性能优化**: 内存管理、缓存优化、WebView 性能调优
- **插件系统**: 可扩展的 JSBridge 插件架构

### 📱 设备功能
- **设备信息获取**: 设备型号、系统版本、屏幕信息等
- **媒体处理**: 图片选择、拍照、视频录制、相册保存
- **通知管理**: 本地通知的创建、管理和权限控制
- **网络监控**: 网络状态检测和性能监控

### 🎨 用户体验
- **启动屏幕**: 现代化的应用启动界面
- **加载动画**: 优雅的加载指示器
- **错误处理**: 完善的错误提示和重试机制
- **响应式设计**: 适配不同屏幕尺寸

## 项目结构

```
chery_ios/
├── Common/                    # 公共组件
│   ├── Cache/               # 缓存管理
│   ├── Extensions/           # 扩展方法
│   ├── Memory/               # 内存管理
│   ├── Monitoring/           # 性能监控
│   ├── Network/              # 网络管理
│   ├── UI/                   # UI 组件
│   └── Utils/                # 工具类
├── WebView/                  # WebView 相关
│   ├── Plugins/              # JSBridge 插件
│   └── QRWebViewController.swift
└── Assets.xcassets/          # 资源文件
```

## 技术栈

### 开发语言
- **Swift 5.0+**: 主要开发语言
- **Objective-C**: JDBridge 相关代码

### 依赖库
- **SnapKit**: 自动布局
- **SDWebImage**: 图片加载和缓存
- **MJExtension**: JSON 序列化
- **TheRouter**: 路由管理

### 系统要求
- **iOS 15.0+**: 最低支持版本
- **Xcode 14.0+**: 开发环境

## 快速开始

### 环境配置

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd chery_ios
   ```

2. **安装依赖**
   ```bash
   pod install
   ```

3. **打开项目**
   ```bash
   open chery_ios.xcworkspace
   ```

### 基本使用

1. **启动应用**
   - 应用会自动显示启动屏幕
   - 加载完成后进入主界面

2. **WebView 控制**
   - 支持沉浸式状态栏
   - 支持导航栏显示/隐藏
   - 支持底部安全区处理

3. **JSBridge 通信**
   ```javascript
   // 获取设备信息
   JDBridge.callNative('DeviceInfoPlugin', {
       action: 'getDeviceInfo',
       params: {},
       success: function(result) {
           console.log('设备信息:', result);
       }
   });
   
   // 设置沉浸式状态栏
   JDBridge.callNative('StatusBarPlugin', {
       action: 'setImmersiveStatusBar',
       params: {immersive: true},
       success: function(result) {
           console.log('设置成功:', result);
       }
   });
   ```

## 插件开发

### 创建自定义插件

1. **继承基类**
   ```swift
   @objc class CustomPlugin: JDBridgeBasePlugin {
       override func excute(_ action: String, params: [AnyHashable : Any], callback: JDBridgeCallBack) -> Bool {
           switch action {
           case "customAction":
               handleCustomAction(params: params, callback: callback)
               return true
           default:
               callback.onFail(NSError(domain: "CustomPlugin", code: 1001, userInfo: [NSLocalizedDescriptionKey: "未知操作"]))
               return false
           }
       }
   }
   ```

2. **注册插件**
   ```swift
   let customPlugin = CustomPlugin()
   webView.jsBridgeManager.registerDefaultPlugin(customPlugin)
   ```

### 可用插件

- **StatusBarPlugin**: 状态栏和导航栏控制
- **DeviceInfoPlugin**: 设备信息获取
- **MediaPlugin**: 媒体处理
- **NotificationPlugin**: 通知管理

## 性能优化

### 内存管理
- 自动内存监控和清理
- 缓存过期机制
- WebView 内存优化

### 网络优化
- 请求缓存策略
- 图片懒加载
- 资源预加载

### 用户体验
- 启动屏幕优化
- 加载动画
- 错误重试机制

## 测试

### 运行测试
```bash
# 运行所有测试
xcodebuild test -workspace chery_ios.xcworkspace -scheme chery_ios

# 运行特定测试
xcodebuild test -workspace chery_ios.xcworkspace -scheme chery_ios -only-testing:chery_iosTests/NetworkManagerTests
```

### 测试覆盖
- 网络管理器测试
- 缓存管理器测试
- 内存管理测试
- 性能监控测试

## 部署

### 开发环境
1. 配置开发证书
2. 设置 Bundle Identifier
3. 配置开发服务器地址

### 生产环境
1. 配置生产证书
2. 更新服务器地址
3. 优化性能设置
4. 测试所有功能

## 贡献指南

### 代码规范
- 使用 Swift 官方代码规范
- 添加必要的注释和文档
- 编写单元测试

### 提交流程
1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 联系方式

如有问题或建议，请联系开发团队。

---

**注意**: 本项目基于 JDBridge 框架开发，请确保遵守相关开源协议。
