---
inclusion: always
---

# QXWebView 设计系统规则

本文档定义了 QXWebView 项目的设计系统规则，用于指导 Figma 设计到代码的转换。

## 项目概述

- **项目类型**: iOS WebView SDK（Swift + Objective-C）
- **最低支持**: iOS 13.0+
- **主要框架**: UIKit
- **语言**: Swift 5.0+, Objective-C
- **架构**: JSBridge 通信、插件化设计

## 1. 设计令牌（Design Tokens）

### 颜色系统
项目目前没有统一的颜色令牌系统。建议在代码中使用以下方式定义：

```swift
// 推荐在 UIColor+Extension.swift 中定义
extension UIColor {
    static let primaryColor = UIColor(hex: "#007AFF")
    static let secondaryColor = UIColor(hex: "#5856D6")
    static let backgroundColor = UIColor.systemBackground
    static let textPrimary = UIColor.label
    static let textSecondary = UIColor.secondaryLabel
}
```

### 间距系统
建议使用 8pt 网格系统：

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}
```

### 字体系统
使用系统字体，建议定义标准字体样式：

```swift
extension UIFont {
    static let heading1 = UIFont.systemFont(ofSize: 28, weight: .bold)
    static let heading2 = UIFont.systemFont(ofSize: 22, weight: .semibold)
    static let body = UIFont.systemFont(ofSize: 16, weight: .regular)
    static let caption = UIFont.systemFont(ofSize: 14, weight: .regular)
}
```

## 2. 组件库结构

### 组件位置
- **核心组件**: `QXWebView/Classes/JDWebView/`
- **插件组件**: `QXWebView/Classes/Plugins/`
- **工具类**: `QXWebView/Classes/Plugins/Utils.swift`

### 主要组件

#### WebView 容器
- **文件**: `QXWebViewController.swift`
- **用途**: WebView 容器视图控制器
- **特点**: 支持 JSBridge 通信

#### 插件基类
- **文件**: `QXBasePlugin.swift`
- **用途**: 所有插件的基类
- **继承**: `JDBridgeBasePlugin`

#### 蓝牙插件
- **文件**: `QXBlePlugin.swift`
- **管理器**: `QXBleCentralManager.swift`, `QXBlePeripheralManager.swift`
- **用途**: 处理蓝牙设备扫描、连接、通信

## 3. 框架与库

### UI 框架
- **UIKit**: 主要 UI 框架
- **WKWebView**: Web 内容展示

### 依赖库
- **SnapKit**: 自动布局（如果使用）
- **SDWebImage**: 图片加载（如果使用）
- **MJExtension**: JSON 解析（如果使用）

### 构建系统
- **CocoaPods**: 依赖管理
- **Xcode**: 构建工具

## 4. 资源管理

### 资源位置
- **Assets**: `QXWebView/Assets/`
- **Bundle**: 使用 CocoaPods 资源 bundle

### 资源引用
```swift
// 从 bundle 中加载资源
let bundle = Bundle(for: QXWebViewController.self)
let image = UIImage(named: "icon_name", in: bundle, compatibleWith: nil)
```

## 5. 图标系统

### 图标来源
- **SF Symbols**: 优先使用系统图标
- **自定义图标**: 存放在 Assets 目录

### 图标使用
```swift
// 系统图标
let icon = UIImage(systemName: "chevron.right")

// 自定义图标
let customIcon = UIImage(named: "custom_icon", in: bundle, compatibleWith: nil)
```

## 6. 样式方法

### 布局方式
- **Auto Layout**: 使用约束布局
- **Frame**: 简单场景使用 frame

### 代码风格
```swift
// 推荐使用声明式布局
private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.font = .heading2
    label.textColor = .textPrimary
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
}()
```

### 响应式设计
```swift
// 使用 trait collection 处理不同设备
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    // 更新 UI
}
```

## 7. 项目结构

```
QXWebView/
├── Classes/
│   ├── JDBridge/              # JSBridge 核心通信层
│   │   ├── JDBridgeManager    # Bridge 管理器
│   │   └── JDBridgeBasePlugin # 插件基类
│   ├── JDWebView/             # WebView 容器
│   │   ├── JDWebViewContainer # WebView 容器
│   │   └── QXWebViewController # 视图控制器
│   ├── Plugins/               # 功能插件
│   │   ├── Ble/              # 蓝牙功能
│   │   ├── Location/         # 定位功能
│   │   ├── QXBlePlugin       # 蓝牙插件
│   │   └── QXHostBridgePlugin # 宿主桥接插件
│   └── QXWebViewHostDelegate  # 宿主代理协议
└── Assets/                    # 资源文件
```

## Figma 集成指南

### 从 Figma 生成代码时

1. **使用 UIKit 组件**
   - 将 Figma 的 Frame 转换为 UIView
   - 将 Text 转换为 UILabel
   - 将 Button 转换为 UIButton

2. **遵循项目约定**
   - 使用 lazy var 声明 UI 组件
   - 使用 Auto Layout 约束
   - 遵循 Swift 命名规范

3. **复用现有组件**
   - 优先使用项目中已有的组件
   - 保持与现有代码风格一致

4. **插件开发**
   - 继承 `QXBasePlugin`
   - 实现 JSBridge 方法
   - 添加到 `Plugins/` 目录

### 示例：从 Figma 创建按钮组件

```swift
class CustomButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 应用设计令牌
        backgroundColor = .primaryColor
        setTitleColor(.white, for: .normal)
        titleLabel?.font = .body
        layer.cornerRadius = 8
        
        // 添加约束
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
}
```

## 最佳实践

1. **保持一致性**: 使用统一的设计令牌和组件
2. **可维护性**: 代码清晰，注释完整
3. **可扩展性**: 使用插件化架构，便于功能扩展
4. **性能优化**: 注意 WebView 内存管理和性能
5. **安全性**: 验证 JSBridge 调用参数

## 注意事项

- 本项目是 iOS SDK，不是独立 App
- 主要通过 JSBridge 与 H5 交互
- 插件需要注册到 JDBridgeManager
- 遵循 CocoaPods 库开发规范
