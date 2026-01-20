import UIKit
import CoreLocation
import MapKit

class OpenMapAppUtils: NSObject {

    static let shared = OpenMapAppUtils()
    
    // MARK: - 核心入口：展示地图选择弹窗
    /// 逻辑与 Android 保持一致：始终显示选项，无 App 则降级网页
    func showMapSelectSheet(parentVC: UIViewController, lat: String, lng: String, name: String) {
        let alertVC = UIAlertController(title: "选择导航地图", message: nil, preferredStyle: .actionSheet)
        
        // 1. 高德地图
        alertVC.addAction(UIAlertAction(title: "高德地图", style: .default) { _ in
            self.openMap(type: .amap, lat: lat, lng: lng, name: name, parentVC: parentVC)
        })
        
        // 2. 百度地图
        alertVC.addAction(UIAlertAction(title: "百度地图", style: .default) { _ in
            self.openMap(type: .baidu, lat: lat, lng: lng, name: name, parentVC: parentVC)
        })
        
        // 3. 腾讯地图
        alertVC.addAction(UIAlertAction(title: "腾讯地图", style: .default) { _ in
            self.openMap(type: .tencent, lat: lat, lng: lng, name: name, parentVC: parentVC)
        })
        
        // 4. 苹果地图
        alertVC.addAction(UIAlertAction(title: "苹果地图", style: .default) { _ in
            self.openAppleMap(lat: Double(lat) ?? 0, lng: Double(lng) ?? 0, name: name)
        })

        alertVC.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))

        // iPad 适配
        if let popover = alertVC.popoverPresentationController {
            popover.sourceView = parentVC.view
            popover.sourceRect = CGRect(x: parentVC.view.bounds.midX, y: parentVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        parentVC.present(alertVC, animated: true)
    }

    // MARK: - 统一唤起/降级逻辑
    
    private enum MapType {
        case amap, baidu, tencent
        var name: String {
            switch self { case .amap: return "高德地图"; case .baidu: return "百度地图"; case .tencent: return "腾讯地图" }
        }
    }

    private func openMap(type: MapType, lat: String, lng: String, name: String, parentVC: UIViewController) {
        // 1. URL 编码目的地名称
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // 去除经纬度可能存在的空格
        let cleanLat = lat.trimmingCharacters(in: .whitespaces)
        let cleanLng = lng.trimmingCharacters(in: .whitespaces)

        var schemeString = ""
        var webString = ""

        switch type {
        case .amap:
            // App: 路径规划 (dname=终点名)
            schemeString = "iosamap://navi?sourceApplication=app_name&poiname=\(encodedName)&lat=\(cleanLat)&lon=\(cleanLng)&dev=0&style=2"
            webString = "https://uri.amap.com/navigation?to=\(cleanLng),\(cleanLat),\(encodedName)&mode=car"
            
        case .baidu:
            // App: 路径规划 (destination=名称及坐标)
            schemeString = "baidumap://map/navi?location=\(cleanLat),\(cleanLng)&title=\(encodedName)&coord_type=gcj02&src=ios.jd.plugin"
            webString = "https://api.map.baidu.com/direction?destination=latlng:\(cleanLat),\(cleanLng)|name:\(encodedName)&mode=driving&output=html&coord_type=gcj02"
        case .tencent:
            // App: 路径规划 (to=名称, tocoord=坐标)
            schemeString = "qqmap://map/routeplan?type=drive&to=\(encodedName)&tocoord=\(cleanLat),\(cleanLng)&referer=QXHybrid"
            // Web: 路径规划
            webString = "https://apis.map.qq.com/uri/v1/routeplan?type=drive&to=\(encodedName)&tocoord=\(cleanLat),\(cleanLng)&referer=QXHybrid"
        }

        guard let schemeURL = URL(string: schemeString), let webURL = URL(string: webString) else {
            self.showToast(in: parentVC, message: "地址解析失败")
            return
        }

        // 尝试唤起 App
        UIApplication.shared.open(schemeURL, options: [:]) { success in
            if !success {
                // 唤起失败，降级跳转网页版导航
                UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                self.showToast(in: parentVC, message: "未安装\(type.name)，已跳转网页版导航")
            }
        }
    }

    private func openAppleMap(lat: Double, lng: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - 私有辅助 UI
    
    private func showToast(in vc: UIViewController, message: String) {
        let toastWidth: CGFloat = 250
        let toastLabel = UILabel(frame: CGRect(x: vc.view.bounds.width/2 - toastWidth/2, y: vc.view.bounds.height - 150, width: toastWidth, height: 40))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 13)
        toastLabel.text = message
        toastLabel.layer.cornerRadius = 20
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0
        
        vc.view.addSubview(toastLabel)
        
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 2.0, options: .curveEaseIn, animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
}
