//
//  QXBasePlugin.swift
//  chery_ios
//
//  Created by 顾钱想 on 12/18/25.
//

import UIKit
import AVFoundation
import CoreTelephony
import CoreLocation
@objc(QXBasePlugin)
public class QXBasePlugin: JDBridgeBasePlugin {
    // 统一错误域（极简，仅标识来源）
    private let errorDomain = "QXBasePlugin"
    /// 执行JS调用
    @objc public override func excute(_ action: String, params: [AnyHashable : Any], callback: JDBridgeCallBack) -> Bool {
        print("QXBasePlugin-excute-action:\(action)")
        switch action {
        case "scanQRCode":
            handleScanQRCode(params: params, callback: callback)
            return true
        case "getDeviceInfo":
            handleGetDeviceInfo(callback: callback)
            return true
        case "goBack":
            handleGoBack(callback: callback)
            return true
        case "location":
            handleLocation(params: params, callback: callback)
            return true
        case "downloadAndOpenFile":
            handleDownloadAndOpenFile(params: params, callback: callback)
            return true
        case "openMap":
            handleOpenMap(params: params, callback: callback)
            return true
        case "setNavigationBarStyle":
            handleSetNavigationBarStyle(params: params, callback: callback)
            return true
        case "openWebView":
            handleOpenWebView(params: params, callback: callback)
            return true
        case "openUrl":
            handleOpenUrl(params: params, callback: callback)
            return true
        default:
            callback.onFail(NSError(domain: "DeviceInfoPlugin", code: 1001, userInfo: [NSLocalizedDescriptionKey: "未知操作"]))
            return false
        }
    }
    
    // MARK: - 扫码处理（仅保留code+文案）
    private func handleScanQRCode(params: [AnyHashable : Any]!, callback: JDBridgeCallBack!) {
        guard let callback = callback else { return }
        // 检查相机权限
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            startQRScanning(callback: callback)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.startQRScanning(callback: callback)
                    } else {
                        callback.onFail( callback.onFail(["message": "没有相机权限","success": false]))
                    }
                }
            }
            
        case .denied, .restricted:
            callback.onFail( callback.onFail(["message": "没有相机权限","success": false]))
        @unknown default:
            callback.onFail( callback.onFail(["message": "未知错误","success": false]))
        }
    }
    
    private func startQRScanning(callback: JDBridgeCallBack!) {
        guard let callback = callback else { return }
        let scannerVC = QXScannerViewController { result in
            if let qrResult = result, !qrResult.isEmpty {
                callback.onSuccess(["data": qrResult, "success": true])
            } else {
                callback.onFail(["message": "扫描结果为空","success": false])
            }
        }
        guard let topVC = UIApplication.shared.topViewController else {
            callback.onFail( callback.onFail(["message": "无法获取页面","success": false]))
            return
        }
        
        let nav = UINavigationController(rootViewController: scannerVC)
        nav.modalPresentationStyle = .fullScreen
        nav.navigationBar.isHidden = true
        topVC.present(nav, animated: true)
    }
    
    /// 获取设备信息
    private func handleGetDeviceInfo(callback: JDBridgeCallBack) {
        let deviceInfo = [
            "deviceModel": Const.appPlatform(),
            "systemVersion": Const.OSVersion(),
            "appVersion": Const.appVersion(),
            "buildVersion": Const.appBuildVersionCode(),
            "screenWidth": Const.screenWidth,
            "screenHeight": Const.screenHeight,
            "isIphoneX": Const.isIphoneX,
            "statusBarHeight": Const.statusBarHeight,
            "navHeight": Const.navBarHeight,
            "navBarHeight": Const.realNavBarHeight,
            "bottomSafeHeight": Const.bottomSafeHeight,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier
        ] as [String : Any]
        callback.onSuccess(deviceInfo)
    }
    
    private func handleLocation(params: [AnyHashable : Any]!, callback: JDBridgeCallBack) {
        DispatchQueue.global().async {
            if (!CLLocationManager.locationServicesEnabled()) {
                return
            }
        }
        // 默认值兜底：H5 未传时使用
        var locationParams: [String: Any] = [
            "accuracy": 100,
            "timeout": 3000,
            "requestPermission": true
        ]
        // 透传 H5 传入的参数（支持 accuracy / timeout / wait / requestPermission）
        if let params = params {
            if let accuracy = (params["accuracy"] as? NSNumber)?.intValue {
                locationParams["accuracy"] = accuracy
            }
            if let timeout = (params["timeout"] as? NSNumber)?.intValue {
                locationParams["timeout"] = timeout
            }
            if let wait = (params["wait"] as? NSNumber)?.intValue {
                locationParams["wait"] = wait
            }
            if let requestPermission = params["requestPermission"] as? Bool {
                locationParams["requestPermission"] = requestPermission
            } else if let requestPermission = (params["requestPermission"] as? NSNumber)?.boolValue {
                locationParams["requestPermission"] = requestPermission
            }
        }
        QXLocationManager.manager.paramsData = locationParams
        QXLocationManager.manager.setGetLocationBlock { res in
            callback.onSuccess(res)
        }
        QXLocationManager.manager.startUpdatingLocation()
    }
    

    private func handleGoBack(callback: JDBridgeCallBack) {
        guard let topVC = UIApplication.shared.topViewController else {
            callback.onFail(["code": -1, "msg": "未找到顶层视图控制器"])
            return
        }
        guard let jdWebViewContainer = callback.findJDWebViewContainer(in: topVC.view) else {
            callback.onFail(["code": -2, "msg": "未找到WebView容器"])
            return
        }
        if (jdWebViewContainer.canGoBack()) {
            jdWebViewContainer.goBack()
            callback.onSuccess(["code": 0, "msg": "WebView回退成功"])
        } else {
            if let nav = topVC.navigationController, nav.viewControllers.count > 1 {
                // 导航栈控制器数量>1 → pop返回上一级
                nav.popViewController(animated: true)
                callback.onSuccess([
                    "code": 1,
                    "msg": "WebView无回退历史，执行pop返回上一级",
                    "action": "popViewController"
                ])
            } else {
                // 导航栈只有当前VC → dismiss关闭模态
                topVC.dismiss(animated: true, completion: nil)
                callback.onSuccess([
                    "code": 2,
                    "msg": "WebView无回退历史，执行dismiss关闭页面",
                    "action": "dismissViewController"
                ])
            }
        }
    }
    
    private func handleDownloadAndOpenFile(params: [AnyHashable : Any]!, callback: JDBridgeCallBack!) {
        let urlString: String = params["url"] as? String ?? ""
        let isOpen: Bool = params["isOpen"] as? Bool ?? true
        guard let url = URL(string: urlString) else { return }
        let task = URLSession.shared.downloadTask(with: url) { tempLocalURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    callback.onSuccess([
                        "code": 500,
                        "msg": "文件下载失败：\(error.localizedDescription)"
                    ])
                }
                return
            }
        
            guard let tempLocalURL = tempLocalURL, let response = response else {
                DispatchQueue.main.async {
                    callback.onSuccess([
                        "code": 400,
                        "msg": "文件下载失败，无文件数据"
                    ])
                }
                return
            }
            
            let originalFileName = (response as? HTTPURLResponse)?.suggestedFilename ?? urlString
            let fallbackFileName = url.lastPathComponent
            let fileName = originalFileName.isEmpty ? fallbackFileName : originalFileName
            
            let documentsDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let permanentFilePath = documentsDir + "/" + fileName
            let permanentFileURL = URL(fileURLWithPath: permanentFilePath)
            do {
                if FileManager.default.fileExists(atPath: permanentFilePath) {
                    try FileManager.default.removeItem(at: permanentFileURL)
                }
                try FileManager.default.copyItem(at: tempLocalURL, to: permanentFileURL)
                DispatchQueue.main.async {
                    if isOpen {
                        let vc = callback.findWebViewController()
                        vc?.openFile(fileURL: permanentFileURL)
                    }
                    
                    callback.onSuccess([
                        "code": 200,
                        "msg": "文件下载成功",
                        "filePath": permanentFilePath
                    ])
                }
                
            } catch {
                // 文件拷贝失败的错误处理
                DispatchQueue.main.async {
                    callback.onSuccess([
                        "code": 500,
                        "msg": "文件保存失败：\(error.localizedDescription)"
                    ])
                }
            }
        }
        task.resume()
    }
    
    private func handleOpenMap(params: [AnyHashable : Any]!, callback: JDBridgeCallBack!) {
        guard let params = params else {
            callback?.onFail("参数不能为空")
            return
        }
        // 使用 String(describing:) 可以确保无论是数字还是字符串都能安全转为 String
        let lat = String(describing: params["latitude"] ?? "")
        let lng = String(describing: params["longitude"] ?? "")
        let name = params["name"] as? String ?? "目的地"
        // 3. 校验关键坐标是否有效
        guard !lat.isEmpty, !lng.isEmpty, lat != "<nil>", lng != "<nil>" else {
            callback?.onFail("经纬度解析失败")
            return
        }
        guard let topVC = UIApplication.shared.topViewController else {
            callback.onFail(["code": -1, "msg": "未找到顶层视图控制器"])
            return
        }
        // 确保在主线程调用 UI
        DispatchQueue.main.async {
            OpenMapAppUtils.shared.showMapSelectSheet(
                parentVC: topVC,
                lat: lat,
                lng: lng,
                name: name
            )
        }
    }

    private func handleSetNavigationBarStyle(params: [AnyHashable : Any]!, callback: JDBridgeCallBack!) {
        guard let callback = callback else { return }
        guard let style = resolveNavigationBarStyle(from: params) else {
            callback.onFail([
                "code": -1,
                "msg": "barStyle 参数无效，支持 default/black 或 0/1"
            ])
            return
        }
        DispatchQueue.main.async {
            guard let webViewController = callback.findWebViewController() else {
                callback.onFail([
                    "code": -2,
                    "msg": "未找到WebViewController"
                ])
                return
            }
            webViewController.setNavigationBarStyleOverride(style)
            callback.onSuccess([
                "code": 0,
                "msg": "navigationBar.barStyle 设置成功",
                "style": self.navigationBarStyleName(for: style),
                "rawValue": style.rawValue
            ])
        }
    }

    private func resolveNavigationBarStyle(from params: [AnyHashable : Any]?) -> UIBarStyle? {
        guard let params = params else { return nil }

        if let styleName = (params["style"] as? String ?? params["barStyle"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            switch styleName {
            case "default", "light":
                return .default
            case "black", "dark":
                return .black
            default:
                break
            }
        }

        if let rawValue = params["style"] as? NSNumber ?? params["barStyle"] as? NSNumber {
            switch rawValue.intValue {
            case UIBarStyle.default.rawValue:
                return .default
            case UIBarStyle.black.rawValue:
                return .black
            default:
                break
            }
        }

        return nil
    }

    private func navigationBarStyleName(for style: UIBarStyle) -> String {
        switch style {
        case .black:
            return "black"
        default:
            return "default"
        }
    }

    // MARK: - 打开新的 WebView 页面
    /// H5 调用示例:
    /// QXBasePlugin.openWebView({
    ///   url: "https://xxx.com/page",
    ///   query: { id: 1, from: "h5" },   // 可选 会自动拼到 url 的 query 上
    ///   navHidden: true,                  // 可选 是否隐藏导航栏
    ///   immersive: true,                  // 可选 是否沉浸式状态栏
    ///   presentStyle: "push"              // 可选 push / present，默认 push
    /// })
    private func handleOpenWebView(params: [AnyHashable : Any]!, callback: JDBridgeCallBack!) {
        guard let callback = callback else { return }
        guard let params = params,
              let rawUrl = (params["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawUrl.isEmpty else {
            callback.onFail(["code": -1, "msg": "url 不能为空"])
            return
        }

        let finalUrl = Self.appendQueryParams(to: rawUrl, params: params["query"] as? [String: Any])
        let navHidden = (params["navHidden"] as? Bool)
            ?? (params["navHidden"] as? NSNumber)?.boolValue
        let immersive = (params["immersive"] as? Bool)
            ?? (params["immersive"] as? NSNumber)?.boolValue
        let presentStyle = (params["presentStyle"] as? String)?.lowercased() ?? "push"

        DispatchQueue.main.async {
            guard let topVC = UIApplication.shared.topViewController else {
                callback.onFail(["code": -2, "msg": "未找到顶层视图控制器"])
                return
            }
            let webVC = QXWebViewController(url: finalUrl)
            if let navHidden = navHidden { webVC.isNavigationBarHidden = navHidden }
            if let immersive = immersive { webVC.isImmersiveStatusBar = immersive }

            if presentStyle == "present" {
                let wrapper = UINavigationController(rootViewController: webVC)
                wrapper.modalPresentationStyle = .fullScreen
                wrapper.navigationBar.isHidden = webVC.isNavigationBarHidden
                topVC.present(wrapper, animated: true)
            } else if let navController = topVC.navigationController {
                navController.pushViewController(webVC, animated: true)
            } else if let navController = topVC as? UINavigationController {
                navController.pushViewController(webVC, animated: true)
            } else {
                // 兜底：没有导航栈时用 present
                let wrapper = UINavigationController(rootViewController: webVC)
                wrapper.modalPresentationStyle = .fullScreen
                wrapper.navigationBar.isHidden = webVC.isNavigationBarHidden
                topVC.present(wrapper, animated: true)
            }
            callback.onSuccess([
                "code": 0,
                "msg": "打开 WebView 成功",
                "url": finalUrl
            ])
        }
    }

    // MARK: - 打开 URL（系统设置、定位、蓝牙、电话、邮件、第三方 App 等）
    /// H5 调用示例:
    /// QXBasePlugin.openUrl({ type: "settings" })                  // 打开本 App 的设置页
    /// QXBasePlugin.openUrl({ type: "location" })                  // 尝试打开定位设置
    /// QXBasePlugin.openUrl({ type: "notification" })              // 通知设置
    /// QXBasePlugin.openUrl({ type: "bluetooth" })                 // 蓝牙
    /// QXBasePlugin.openUrl({ type: "wifi" })                      // 无线局域网
    /// QXBasePlugin.openUrl({ url: "tel:10086" })                  // 拨号
    /// QXBasePlugin.openUrl({ url: "mailto:a@b.com" })             // 发邮件
    /// QXBasePlugin.openUrl({ url: "https://xxx.com", query: {a:1} }) // 任意 URL + 拼参数
    private func handleOpenUrl(params: [AnyHashable : Any]!, callback: JDBridgeCallBack!) {
        guard let callback = callback else { return }
        let typeString = (params?["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let inputUrl = (params?["url"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let queryParams = (params?["query"] as? [String: Any])
            ?? (params?["params"] as? [String: Any])

        let resolvedUrl = resolveSystemUrl(for: typeString, fallback: inputUrl)
        guard !resolvedUrl.isEmpty else {
            callback.onFail(["code": -1, "msg": "url 或 type 不能同时为空"])
            return
        }
        let finalUrl = Self.appendQueryParams(to: resolvedUrl, params: queryParams)
        guard let url = URL(string: finalUrl) else {
            callback.onFail(["code": -2, "msg": "url 格式错误: \(finalUrl)"])
            return
        }
        DispatchQueue.main.async {
            guard UIApplication.shared.canOpenURL(url) else {
                callback.onFail([
                    "code": -3,
                    "msg": "当前设备无法打开此 URL",
                    "url": finalUrl
                ])
                return
            }
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    callback.onSuccess([
                        "code": 0,
                        "msg": "打开成功",
                        "url": finalUrl
                    ])
                } else {
                    callback.onFail([
                        "code": -4,
                        "msg": "打开失败",
                        "url": finalUrl
                    ])
                }
            }
        }
    }

    /// 根据 type 解析系统页面 URL（未匹配则返回 fallback）
    private func resolveSystemUrl(for type: String, fallback: String) -> String {
        switch type {
        case "", "url", "custom":
            return fallback
        case "settings", "app-settings", "appsettings":
            return UIApplication.openSettingsURLString
        case "notification", "notifications", "notification-settings":
            if #available(iOS 16.0, *) {
                return UIApplication.openNotificationSettingsURLString
            } else {
                return UIApplication.openSettingsURLString
            }
        case "location", "location-settings":
            // iOS 未提供官方定位设置深链，部分系统版本 App-Prefs 可生效，失败时调用方可改用 settings
            return "App-Prefs:LOCATION_SERVICES"
        case "bluetooth", "ble":
            return "App-Prefs:Bluetooth"
        case "wifi", "wlan":
            return "App-Prefs:WIFI"
        case "cellular", "mobile-data":
            return "App-Prefs:MOBILE_DATA_SETTINGS_ID"
        case "general":
            return "App-Prefs:General"
        case "privacy":
            return "App-Prefs:Privacy"
        default:
            return fallback
        }
    }

    /// 将字典参数拼到已有 URL 的 query 上（保留原 query，自动做百分号编码）
    private static func appendQueryParams(to urlString: String, params: [String: Any]?) -> String {
        guard let params = params, !params.isEmpty else { return urlString }
        guard var components = URLComponents(string: urlString) else { return urlString }
        var items = components.queryItems ?? []
        for (key, value) in params {
            items.append(URLQueryItem(name: key, value: String(describing: value)))
        }
        components.queryItems = items
        return components.url?.absoluteString ?? urlString
    }
}

extension UIViewController {
    func topMostViewController() -> UIViewController? {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let tabBar = self as? UITabBarController {
            return tabBar.selectedViewController?.topMostViewController() ?? self
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostViewController() ?? self
        }
        return self
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        if #available(iOS 13.0, *) {
            let window = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?
                .windows
                .first(where: { $0.isKeyWindow })
            return window?.rootViewController?.topMostViewController()
        } else {
            return keyWindow?.rootViewController?.topMostViewController()
        }
    }
}

extension UIView {
    var viewController: UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let vc = responder as? UIViewController {
                return vc
            }
            responder = responder?.next
        }
        return nil
    }
}
