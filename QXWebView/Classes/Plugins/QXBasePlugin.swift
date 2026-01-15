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
            handleLocation(callback: callback)
            return true
        case "downloadAndOpenFile":
            handleDownloadAndOpenFile(params: params, callback: callback)
            return true
        case "openMap":
            handleOpenMap(params: params, callback: callback)
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
            "navBarHeight": Const.navBarHeight,
            "bottomSafeHeight": Const.bottomSafeHeight,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier
        ] as [String : Any]
        callback.onSuccess(deviceInfo)
    }
    
    private func handleLocation(callback: JDBridgeCallBack) {
        DispatchQueue.global().async {
            if (!CLLocationManager.locationServicesEnabled()) {
                return
            }
        }
        QXLocationManager.manager.paramsData = ["accuracy":100, "timeout":3000, "requestPermission":true]
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
