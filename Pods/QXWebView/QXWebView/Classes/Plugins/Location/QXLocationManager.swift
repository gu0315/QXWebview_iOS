//
//  QXLocationManager.swift
//  Pods
//
//  Created by 顾钱想 on 12/29/25.
//

import UIKit
import CoreLocation

// MARK: - 常量定义
private let kSCCLocationPositioningCache = "SCCLocationPositioningCache"
private let kDefaultAccuracy: Int = 100 // 默认定位精度（米）
private let kDefaultTimeout: TimeInterval = 3 // 默认超时时间（秒）
private let kLocationServiceDisabledMsg = "系统定位服务未开启"
private let kPermissionDeniedMsg = "定位权限被拒绝"

// MARK: - 单例核心类
class QXLocationManager: NSObject {
    // MARK: - 对外属性【只保留这1个回调！】
    static let manager = QXLocationManager()
    var paramsData: [String: Any]?
    /// 唯一回调：返回所有定位结果（成功/失败/缓存 都走这个），字典包含完整信息
    var locationBlock: (([String: Any])->())?
    
    // MARK: - 私有属性
    private var systemLocationManager: CLLocationManager!
    private var locationResultDict = [String: Any]()
    private var errorInfoDict = [String: Any]()
    
    private var isWaitingForAccuracy = false
    private var needReLocationWhenActive = false
    private var targetAccuracy = kDefaultAccuracy
    private var timeoutInterval = kDefaultTimeout
    private var waitInterval: TimeInterval = 0
    
    private var timeoutTimer: Timer?
    private var waitTimer: Timer?
    private var bestLocation: CLLocation?
    
    // 私有化构造器 禁止外部实例化
    private override init() {
        super.init()
        self.configBaseData()
        self.addNotificationObserver()
    }
    
    deinit {
        // 销毁时释放所有资源 内存安全
        NotificationCenter.default.removeObserver(self)
        self.stopAllLocationService()
        self.invalidateAllTimers()
        self.locationBlock = nil
        self.bestLocation = nil
    }
}

// MARK: - 基础配置 & 通知监听
extension QXLocationManager {
    private func configBaseData() {
        locationResultDict.removeAll()
        errorInfoDict.removeAll()
        targetAccuracy = kDefaultAccuracy
        timeoutInterval = kDefaultTimeout
        waitInterval = 0
    }
    
    private func addNotificationObserver() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func appDidBecomeActive() {
        let status = self.currentLocationAuthorizationStatus
        if status == .denied {
            self.callbackLocationResult(["locationType":"failure",
                                         "hasPermission":false,
                                         "isEnable":false,
                                         "msg":kPermissionDeniedMsg])
            return
        }
        
        if needReLocationWhenActive {
            needReLocationWhenActive = false
            self.startUpdatingLocation()
        }
    }
    
    @objc private func appWillResignActive() {
        needReLocationWhenActive = self.currentLocationAuthorizationStatus != .denied
        self.stopAllLocationService()
    }
}

// MARK: - 对外暴露方法【精简，只有一个回调设置】
extension QXLocationManager {
    func setGetLocationBlock(_ block: (([String: Any])->())?) {
        self.locationBlock = block
    }
    
    func startUpdatingLocation() {
        locationResultDict.removeAll()
        errorInfoDict.removeAll()
        bestLocation = nil
        if systemLocationManager == nil {
            systemLocationManager = CLLocationManager()
            systemLocationManager.delegate = self
        }
        
        // 1. 权限校验
        let authStatus = currentLocationAuthorizationStatus
        if authStatus == .denied {
            handlePermissionDenied()
            return
        }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let isSystemLocationOpen = CLLocationManager.locationServicesEnabled()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard isSystemLocationOpen else {
                    self.handleLocationServiceDisabled()
                    return
                }
                if authStatus == .notDetermined {
                    self.systemLocationManager.requestWhenInUseAuthorization()
                    return
                }
                self.parseLocationParams()
                self.startSystemLocation()
                self.startLocationTimers()
            }
        }
    }
}

// MARK: - 系统定位核心逻辑
extension QXLocationManager: CLLocationManagerDelegate {
    private func startSystemLocation() {
        if systemLocationManager == nil {
            systemLocationManager = CLLocationManager()
            systemLocationManager.delegate = self
            systemLocationManager.desiredAccuracy = convertAccuracyToCLLocationAccuracy(targetAccuracy)
            systemLocationManager.distanceFilter = CLLocationDistance(targetAccuracy)
        }
        systemLocationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        if clError?.code == .locationUnknown || clError?.code == .network {
            return
        }
        
        stopAllLocationService()
        invalidateAllTimers()
        // 失败信息也走统一回调
        callbackLocationResult(["locationType":"failure",
                                "Error":"定位失败",
                                "errCode": -1,
                                "msg":error.localizedDescription,
                                "hasPermission":true,
                                "isEnable":true])
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.first else { return }
        
        // 过滤无效定位结果：超时/无效经纬度/精度异常
        let timeInterval = Date().timeIntervalSince(newLocation.timestamp)
        guard timeInterval <= 5,
              newLocation.horizontalAccuracy > 0,
              newLocation.coordinate.latitude != 0,
              newLocation.coordinate.longitude != 0 else {
            return
        }
        
        // 筛选最优定位结果：精度越高(数值越小)越好
        if bestLocation == nil || newLocation.horizontalAccuracy < bestLocation!.horizontalAccuracy {
            bestLocation = newLocation
        }
        
        let currentAccuracy = bestLocation?.horizontalAccuracy ?? Double.greatestFiniteMagnitude
        let targetAccuracyValue = CLLocationAccuracy(targetAccuracy)
        let isAccuracyMeet = currentAccuracy <= targetAccuracyValue
        
        if !isWaitingForAccuracy || isAccuracyMeet {
            handleValidSystemLocation(bestLocation!)
            invalidateAllTimers()
            stopAllLocationService()
            return
        }
    }
}

// MARK: - 定位结果处理 & 坐标转换 & 逆地理编码
extension QXLocationManager {
    private func handleValidSystemLocation(_ location: CLLocation) {
        // 2. WGS84 -> GCJ02 火星坐标转换
        let gcjCoord = GCJ02Converter.wgs84ToGcj02(location.coordinate)
        
        // 3. 逆地理编码 - 异步处理 不阻塞主线程
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            self.fillLocationResultWithSystemLocation(location, gcjCoord: gcjCoord, placemarks: placemarks, error: error)
            self.successCallback()
        }
    }
    
    private func fillLocationResultWithSystemLocation(_ location: CLLocation, gcjCoord: CLLocationCoordinate2D, placemarks: [CLPlacemark]?, error: Error?) {
        let placemark = placemarks?.first
        
        // 基础核心字段 - 完整数据，和原OC版一致
        locationResultDict["latitude"] = gcjCoord.latitude
        locationResultDict["longitude"] = gcjCoord.longitude
        locationResultDict["geopoint"] = String(format: "%.6f,%.6f", gcjCoord.latitude, gcjCoord.longitude)
        locationResultDict["altitude"] = location.altitude
        locationResultDict["accuracy"] = location.horizontalAccuracy
        locationResultDict["speed"] = location.speed
        locationResultDict["gcoord"] = "GCJ02"
        locationResultDict["hasPermission"] = true
        locationResultDict["isEnable"] = true
        locationResultDict["locationType"] = error == nil ? "new" : "cache"
        locationResultDict["timestamp"] = getNowTimeTimestamp()
        
        // ✅ Swift安全取值 无崩溃 - 修复原OC空值问题
        let administrativeArea = placemark?.administrativeArea ?? ""
        let locality = placemark?.locality ?? ""
        let subLocality = placemark?.subLocality ?? ""
        let thoroughfare = placemark?.thoroughfare ?? ""
        let subThoroughfare = placemark?.subThoroughfare ?? ""
        
        locationResultDict["state"] = administrativeArea
        // 直辖市兼容：locality为空时用省级填充城市
        locationResultDict["city"] = !locality.isEmpty ? locality : administrativeArea
        locationResultDict["district"] = subLocality
        locationResultDict["street"] = thoroughfare
        locationResultDict["streetNum"] = subThoroughfare
        
        // 逆地理编码失败容错，错误信息也塞到字典里
        if let error = error {
            locationResultDict["reGeocodeError"] = error.localizedDescription
        }
        
        // 异步缓存到本地 性能优化
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            var cacheDict = self.locationResultDict
            cacheDict["locationType"] = "last"
            UserDefaults.standard.set(cacheDict, forKey: kSCCLocationPositioningCache)
            UserDefaults.standard.synchronize()
        }
    }
}

// MARK: - 回调处理 & 定时器管理【精简，只有一个统一回调】
extension QXLocationManager {
    private func successCallback() {
        stopAllLocationService()
        if !locationResultDict.isEmpty {
            callbackLocationResult(locationResultDict)
        } else {
            errorCallback()
        }
        locationResultDict.removeAll()
        bestLocation = nil
    }
    
    private func errorCallback() {
        stopAllLocationService()
        if let cacheDict = UserDefaults.standard.dictionary(forKey: kSCCLocationPositioningCache) {
            callbackLocationResult(cacheDict)
        } else {
            callbackLocationResult(["locationType":"failure",
                                    "isEnable":true,
                                    "hasPermission":true,
                                    "msg":"定位失败，无缓存数据"])
        }
        errorInfoDict.removeAll()
    }
    
    private func callbackLocationResult(_ result: [String: Any]) {
        // 主线程回调 防止UI崩溃
        DispatchQueue.main.async { [weak self] in
            self?.locationBlock?(result)
            self?.locationBlock = nil // 清空回调 防止重复调用
        }
    }
    
    private func startLocationTimers() {
        invalidateAllTimers()
        
        if waitInterval > 0 {
            isWaitingForAccuracy = true
            waitTimer = Timer.scheduledTimer(timeInterval: waitInterval, target: self, selector: #selector(waitTimerFired), userInfo: nil, repeats: false)
        }
        
        timeoutTimer = Timer.scheduledTimer(timeInterval: timeoutInterval, target: self, selector: #selector(timeoutTimerFired), userInfo: nil, repeats: false)
    }
    
    @objc private func waitTimerFired() {
        isWaitingForAccuracy = false
        if let location = bestLocation {
            handleValidSystemLocation(location)
        }
    }
    
    @objc private func timeoutTimerFired() {
        stopAllLocationService()
        if let location = bestLocation {
            handleValidSystemLocation(location)
        } else {
            errorCallback()
        }
    }
    
    private func invalidateAllTimers() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        waitTimer?.invalidate()
        waitTimer = nil
    }
}

// MARK: - 辅助工具方法
extension QXLocationManager {
    private func parseLocationParams() {
        guard let params = paramsData else { return }
        
        if let timeoutNum = params["timeout"] as? Int {
            timeoutInterval = TimeInterval(timeoutNum) / 1000.0
        }
        if let waitNum = params["wait"] as? Int {
            waitInterval = TimeInterval(waitNum) / 1000.0
        }
        if let accuracyNum = params["accuracy"] as? Int {
            targetAccuracy = accuracyNum
        }
    }
    
    private func handlePermissionDenied() {
        let cacheDict = UserDefaults.standard.dictionary(forKey: kSCCLocationPositioningCache)
        let requestPermission = paramsData?["requestPermission"] as? Bool ?? false
        
        if let cacheDict = cacheDict {
            var result = cacheDict
            result["isEnable"] = false
            result["hasPermission"] = false
            callbackLocationResult(result)
        } else if requestPermission {
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            }
        } else {
            callbackLocationResult(["locationType":"failure","hasPermission":false,"isEnable":false,"msg":kPermissionDeniedMsg])
        }
        locationBlock = nil
    }
    
    private func handleLocationServiceDisabled() {
        let cacheDict = UserDefaults.standard.dictionary(forKey: kSCCLocationPositioningCache)
        
        if let cacheDict = cacheDict {
            var result = cacheDict
            result["isEnable"] = false
            result["hasPermission"] = true
            callbackLocationResult(result)
        } else {
            callbackLocationResult(["locationType":"failure","hasPermission":true,"isEnable":false,"msg":kLocationServiceDisabledMsg])
        }
        locationBlock = nil
    }
    
    func stopAllLocationService() {
        systemLocationManager?.stopUpdatingLocation()
    }
    
    private var currentLocationAuthorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return systemLocationManager?.authorizationStatus ?? CLLocationManager.authorizationStatus()
        } else {
            // iOS14以下 固定走类方法，无任何问题
            return CLLocationManager.authorizationStatus()
        }
    }
    
    private func convertAccuracyToCLLocationAccuracy(_ accuracy: Int) -> CLLocationAccuracy {
        switch accuracy {
        case ..<10: return kCLLocationAccuracyBest
        case 10..<100: return kCLLocationAccuracyNearestTenMeters
        case 100..<1000: return kCLLocationAccuracyHundredMeters
        case 1000..<3000: return kCLLocationAccuracyKilometer
        default: return kCLLocationAccuracyThreeKilometers
        }
    }
    
    private func getNowTimeTimestamp() -> String {
        let timeInterval = Date().timeIntervalSince1970
        return String(format: "%.0f", timeInterval * 1000)
    }
}
