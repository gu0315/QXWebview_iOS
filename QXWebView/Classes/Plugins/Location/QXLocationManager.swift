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
/// 默认可接受精度（米）：达到即进入收敛窗口
private let kDefaultAccuracy: Int = 80
/// 理想精度（米）：达到即立即返回，不再等待收敛
private let kPreferredAccuracy: CLLocationAccuracy = 25
/// 默认超时（秒）：GPS 冷启动首个有效点常需 10s 以上
private let kDefaultTimeout: TimeInterval = 12
/// 收敛窗口（秒）：拿到可接受精度后再等一小段，回调期间最优点
private let kConvergeWindow: TimeInterval = 2.5
/// 逆地理编码超时（秒）：到点先把坐标发出去，避免 H5 永久等待
private let kGeocodeTimeout: TimeInterval = 3
/// 仅授予「大致位置」时的目标精度（米），系统只给公里级模糊坐标
private let kReducedTargetAccuracy: Int = 3000
/// 临时精确定位授权的 purpose key，需与 Info.plist 中保持一致
private let kTemporaryAccuracyPurposeKey = "PreciseLocationForCharging"

private let kLocationServiceDisabledMsg = "系统定位服务未开启"
private let kPermissionDeniedMsg = "定位权限被拒绝"
private let kLocationTimeoutMsg = "定位超时，暂无有效定位信息"

// MARK: - 单例核心类
class QXLocationManager: NSObject {
    // MARK: - 对外属性
    static let manager = QXLocationManager()
    var paramsData: [String: Any]?

    // MARK: - 私有属性
    private var systemLocationManager: CLLocationManager!
    private var locationResultDict = [String: Any]()

    /// 单 block 会被后来的请求顶掉，导致前一个调用方永久 pending；
    /// 改为回调列表：在途请求的所有调用方共享同一次定位结果。
    private var locationBlocks: [([String: Any]) -> Void] = []

    private var isWaitingForAccuracy = false
    private var needReLocationWhenActive = false
    /// 是否正在等待用户在系统权限弹框上做选择
    private var isAwaitingAuthorization = false
    /// 定位是否在途。只在真正开始定位后置位——权限等待阶段不置位，
    /// 否则用户一直不理会权限弹框会把后续所有定位请求永久挡住。
    private var isLocating = false
    /// 本次请求是否已回调，保证结果只发一次
    private var isCallbackInvoked = false

    private var targetAccuracy = kDefaultAccuracy
    private var timeoutInterval = kDefaultTimeout
    private var waitInterval: TimeInterval = 0

    private var timeoutTimer: Timer?
    private var waitTimer: Timer?
    private var convergeTimer: Timer?
    private var bestLocation: CLLocation?

    // 私有化构造器 禁止外部实例化
    private override init() {
        super.init()
        self.systemLocationManager = CLLocationManager()
        self.systemLocationManager.delegate = self
        self.configBaseData()
        self.addNotificationObserver()
    }

    deinit {
        // 销毁时释放所有资源 内存安全
        NotificationCenter.default.removeObserver(self)
        self.stopAllLocationService()
        self.invalidateAllTimers()
        self.locationBlocks.removeAll()
        self.bestLocation = nil
    }
}

// MARK: - 基础配置 & 通知监听
extension QXLocationManager {
    /// 每次请求都回到默认值，避免上一笔调用的参数串到下一笔请求
    private func configBaseData() {
        locationResultDict.removeAll()
        targetAccuracy = kDefaultAccuracy
        timeoutInterval = kDefaultTimeout
        waitInterval = 0
        isWaitingForAccuracy = false
        isCallbackInvoked = false
        bestLocation = nil
    }

    private func addNotificationObserver() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func appDidBecomeActive() {
        // 权限弹框期间会走一次 resign/active，此时授权结果由 delegate 处理，这里不要抢跑
        if isAwaitingAuthorization { return }

        if self.currentLocationAuthorizationStatus == .denied {
            guard !locationBlocks.isEmpty else { return }
            self.handlePermissionDenied()
            return
        }

        if needReLocationWhenActive {
            needReLocationWhenActive = false
            self.startUpdatingLocation()
        }
    }

    @objc private func appWillResignActive() {
        if isAwaitingAuthorization { return }
        needReLocationWhenActive = !locationBlocks.isEmpty && self.currentLocationAuthorizationStatus != .denied
        self.stopAllLocationService()
    }
}

// MARK: - 对外暴露方法
extension QXLocationManager {
    /// 追加一个结果回调。并发请求会共享同一次定位结果，而不是互相顶掉。
    func setGetLocationBlock(_ block: (([String: Any]) -> Void)?) {
        guard let block = block else { return }
        runOnMain { self.locationBlocks.append(block) }
    }

    func startUpdatingLocation() {
        runOnMain { self.startRequest() }
    }

    private func startRequest() {
        // 已有定位在途：直接搭车复用同一结果，避免重复启动并清掉前一个请求的状态
        if isLocating { return }

        configBaseData()

        let authStatus = currentLocationAuthorizationStatus
        if authStatus == .denied || authStatus == .restricted {
            handlePermissionDenied()
            return
        }

        // locationServicesEnabled 是阻塞调用，放到子线程避免卡主线程
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
                    // 授权结果由 locationManagerDidChangeAuthorization 接管，
                    // 不接的话用户点「允许」之后不会有任何后续，H5 永久 pending。
                    self.isAwaitingAuthorization = true
                    self.systemLocationManager.requestWhenInUseAuthorization()
                    return
                }
                self.beginLocating()
            }
        }
    }

    private func beginLocating() {
        isLocating = true
        parseLocationParams()
        applyAccuracySettings()
        startSystemLocation()
        startLocationTimers()
    }

    /// 把解析出来的精度同步给 CoreLocation。
    /// 原来只在 init 里设过一次，H5 传的 accuracy 根本没生效，系统始终按 100m 工作。
    private func applyAccuracySettings() {
        // 仅授予「大致位置」时系统只返回公里级模糊坐标，按精确门槛会一直等到超时
        if !isPreciseLocationAuthorized {
            targetAccuracy = max(targetAccuracy, kReducedTargetAccuracy)
        }
        systemLocationManager.desiredAccuracy = convertAccuracyToCLLocationAccuracy(targetAccuracy)
        // 一次性定位期间不做距离过滤，否则设备不移动就收不到精度收敛的后续更新
        systemLocationManager.distanceFilter = kCLDistanceFilterNone
    }
}

// MARK: - 系统定位核心逻辑
extension QXLocationManager: CLLocationManagerDelegate {
    private func startSystemLocation() {
        systemLocationManager.startUpdatingLocation()
    }

    // MARK: 授权变更
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange(manager.authorizationStatus)
    }

    @available(iOS, deprecated: 14.0)
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if #available(iOS 14.0, *) { return } // iOS 14+ 走上面的新回调，避免重复处理
        handleAuthorizationChange(status)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        guard isAwaitingAuthorization else { return }
        switch status {
        case .notDetermined:
            return // 用户还没选，继续等
        case .authorizedWhenInUse, .authorizedAlways:
            isAwaitingAuthorization = false
            beginLocating()
        default:
            isAwaitingAuthorization = false
            handlePermissionDenied()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        // 这两类是可恢复的瞬时错误，继续等后续更新即可
        if clError?.code == .locationUnknown || clError?.code == .network {
            return
        }
        guard !isCallbackInvoked else { return }
        finishAll()
        callbackLocationResult(buildFailureResult(msg: error.localizedDescription,
                                                 hasPermission: true,
                                                 isEnable: true,
                                                 extra: ["errCode": -1]))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isCallbackInvoked, let newLocation = locations.last else { return }

        // 过滤无效结果：无效经纬度 / 精度异常 / 陈旧坐标
        guard newLocation.horizontalAccuracy > 0,
              newLocation.coordinate.latitude != 0,
              newLocation.coordinate.longitude != 0,
              abs(newLocation.timestamp.timeIntervalSinceNow) < 60 else {
            return
        }

        // 筛选最优结果：精度数值越小越好
        if bestLocation == nil || newLocation.horizontalAccuracy < bestLocation!.horizontalAccuracy {
            bestLocation = newLocation
        }
        guard let best = bestLocation else { return }

        let targetValue = CLLocationAccuracy(targetAccuracy)

        // 显式传了 wait：保持原有语义，精度没达标就等 waitTimer 到点
        if isWaitingForAccuracy && best.horizontalAccuracy > targetValue {
            return
        }

        // 已达理想精度：直接返回，无需再等收敛窗口
        if best.horizontalAccuracy <= kPreferredAccuracy {
            handleValidSystemLocation(best)
            return
        }

        // 达到可接受精度：不锁定第一个粗点，开一个短收敛窗口，
        // 让精度进一步收敛后回调窗口内最优点，避免过早返回导致坐标偏。
        if best.horizontalAccuracy <= targetValue {
            startConvergeWindow()
        }
    }
}

// MARK: - 定位结果处理 & 坐标转换 & 逆地理编码
extension QXLocationManager {
    private func handleValidSystemLocation(_ location: CLLocation) {
        guard !isCallbackInvoked else { return }
        isCallbackInvoked = true
        finishAll()

        let gcjCoord = GCJ02Converter.wgs84ToGcj02(location.coordinate)

        // 逆地理编码可能一直不回调，加超时兜底：到点先把坐标发出去（地址字段留空）
        var addressEmitted = false
        let emit: ([CLPlacemark]?, Error?) -> Void = { [weak self] placemarks, error in
            guard let self = self, !addressEmitted else { return }
            addressEmitted = true
            self.fillLocationResultWithSystemLocation(location, gcjCoord: gcjCoord, placemarks: placemarks, error: error)
            self.successCallback()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + kGeocodeTimeout) {
            emit(nil, nil)
        }

        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async { emit(placemarks, error) }
        }
    }

    private func fillLocationResultWithSystemLocation(_ location: CLLocation, gcjCoord: CLLocationCoordinate2D, placemarks: [CLPlacemark]?, error: Error?) {
        let placemark = placemarks?.first

        locationResultDict["latitude"] = gcjCoord.latitude
        locationResultDict["longitude"] = gcjCoord.longitude
        locationResultDict["geopoint"] = String(format: "%.6f,%.6f", gcjCoord.latitude, gcjCoord.longitude)
        locationResultDict["altitude"] = location.altitude
        locationResultDict["accuracy"] = location.horizontalAccuracy
        locationResultDict["speed"] = location.speed
        locationResultDict["gcoord"] = "GCJ02"
        locationResultDict["hasPermission"] = true
        locationResultDict["isEnable"] = true
        locationResultDict["preciseLocation"] = isPreciseLocationAuthorized
        // 逆地理失败只影响地址字段，坐标本身仍是新鲜定位，不能标成 cache
        locationResultDict["locationType"] = "new"
        locationResultDict["timestamp"] = getNowTimeTimestamp()

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

        if let error = error {
            locationResultDict["reGeocodeError"] = error.localizedDescription
        }

        // 异步缓存到本地 性能优化
        let cacheSnapshot = locationResultDict
        DispatchQueue.global().async {
            var cacheDict = cacheSnapshot
            cacheDict["locationType"] = "cache"
            UserDefaults.standard.set(cacheDict, forKey: kSCCLocationPositioningCache)
        }
    }
}

// MARK: - 回调处理 & 定时器管理
extension QXLocationManager {
    private func successCallback() {
        if !locationResultDict.isEmpty {
            callbackLocationResult(locationResultDict)
        } else {
            errorCallback()
        }
        locationResultDict.removeAll()
        bestLocation = nil
    }

    private func errorCallback() {
        finishAll()
        if var cacheDict = UserDefaults.standard.dictionary(forKey: kSCCLocationPositioningCache) {
            cacheDict["locationType"] = "cache"
            cacheDict["preciseLocation"] = isPreciseLocationAuthorized
            callbackLocationResult(cacheDict)
        } else {
            callbackLocationResult(buildFailureResult(msg: kLocationTimeoutMsg,
                                                      hasPermission: true,
                                                      isEnable: true))
        }
    }

    /// 统一出口：把结果分发给本次定位的所有调用方，并结束在途状态
    private func callbackLocationResult(_ result: [String: Any]) {
        runOnMain {
            let blocks = self.locationBlocks
            self.locationBlocks.removeAll()
            self.isCallbackInvoked = true
            self.isLocating = false
            self.needReLocationWhenActive = false
            blocks.forEach { $0(result) }
        }
    }

    private func buildFailureResult(msg: String,
                                    hasPermission: Bool,
                                    isEnable: Bool,
                                    extra: [String: Any] = [:]) -> [String: Any] {
        var result: [String: Any] = ["locationType": "failure",
                                     "hasPermission": hasPermission,
                                     "isEnable": isEnable,
                                     "preciseLocation": isPreciseLocationAuthorized,
                                     "msg": msg]
        extra.forEach { result[$0.key] = $0.value }
        return result
    }

    private func startLocationTimers() {
        invalidateAllTimers()

        if waitInterval > 0 {
            isWaitingForAccuracy = true
            waitTimer = Timer.scheduledTimer(timeInterval: waitInterval, target: self, selector: #selector(waitTimerFired), userInfo: nil, repeats: false)
        }

        timeoutTimer = Timer.scheduledTimer(timeInterval: timeoutInterval, target: self, selector: #selector(timeoutTimerFired), userInfo: nil, repeats: false)
    }

    /// 收敛窗口：拿到第一个达到可接受精度的点后不立即返回，
    /// 再等一小段让精度收敛，窗口结束时回调期间最优点。
    private func startConvergeWindow() {
        guard convergeTimer == nil else { return }
        convergeTimer = Timer.scheduledTimer(timeInterval: kConvergeWindow, target: self, selector: #selector(convergeTimerFired), userInfo: nil, repeats: false)
    }

    @objc private func convergeTimerFired() {
        convergeTimer = nil
        if let location = bestLocation {
            handleValidSystemLocation(location)
        }
    }

    @objc private func waitTimerFired() {
        isWaitingForAccuracy = false
        if let location = bestLocation {
            handleValidSystemLocation(location)
        }
    }

    @objc private func timeoutTimerFired() {
        guard !isCallbackInvoked else { return }
        // 超时兜底优先用已有候选点，完全没有才回落到本地缓存
        if let location = bestLocation {
            handleValidSystemLocation(location)
        } else {
            isCallbackInvoked = true
            errorCallback()
        }
    }

    /// 停止定位并清掉所有定时器
    private func finishAll() {
        stopAllLocationService()
        invalidateAllTimers()
    }

    private func invalidateAllTimers() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        waitTimer?.invalidate()
        waitTimer = nil
        convergeTimer?.invalidate()
        convergeTimer = nil
    }
}

// MARK: - 辅助工具方法
extension QXLocationManager {
    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }

    private func parseLocationParams() {
        guard let params = paramsData else { return }

        if let timeoutNum = params["timeout"] as? Int {
            timeoutInterval = max(1, TimeInterval(timeoutNum) / 1000.0)
        }
        if let waitNum = params["wait"] as? Int {
            waitInterval = TimeInterval(waitNum) / 1000.0
        }
        if let accuracyNum = params["accuracy"] as? Int {
            targetAccuracy = max(1, accuracyNum)
        }
        // 仅在 H5 显式要求时才申请临时精确定位，避免每次定位都弹系统框
        if let needPrecise = params["requestPreciseLocation"] as? Bool, needPrecise {
            requestTemporaryPreciseAccuracyIfNeeded()
        }
    }

    private func requestTemporaryPreciseAccuracyIfNeeded() {
        guard #available(iOS 14.0, *), !isPreciseLocationAuthorized else { return }
        systemLocationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: kTemporaryAccuracyPurposeKey)
    }

    private func handlePermissionDenied() {
        isCallbackInvoked = true
        finishAll()
        if var cacheDict = UserDefaults.standard.dictionary(forKey: kSCCLocationPositioningCache) {
            cacheDict["hasPermission"] = false
            cacheDict["isEnable"] = false
            cacheDict["preciseLocation"] = isPreciseLocationAuthorized
            callbackLocationResult(cacheDict)
        } else {
            callbackLocationResult(buildFailureResult(msg: kPermissionDeniedMsg,
                                                      hasPermission: false,
                                                      isEnable: false))
        }
    }

    private func handleLocationServiceDisabled() {
        isCallbackInvoked = true
        finishAll()
        if var cacheDict = UserDefaults.standard.dictionary(forKey: kSCCLocationPositioningCache) {
            cacheDict["isEnable"] = false
            cacheDict["hasPermission"] = true
            cacheDict["preciseLocation"] = isPreciseLocationAuthorized
            callbackLocationResult(cacheDict)
        } else {
            callbackLocationResult(buildFailureResult(msg: kLocationServiceDisabledMsg,
                                                      hasPermission: true,
                                                      isEnable: false))
        }
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

    /// 是否授予了「精确位置」。iOS 14+ 用户可只给「大致位置」，此时精度约为公里级。
    private var isPreciseLocationAuthorized: Bool {
        if #available(iOS 14.0, *) {
            return systemLocationManager?.accuracyAuthorization == .fullAccuracy
        }
        return true
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
