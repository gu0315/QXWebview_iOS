//
//  GCJ02Converter.swift
//  Pods
//
//  Created by 顾钱想 on 12/29/25.
//

import CoreLocation

class GCJ02Converter: NSObject {
    /// WGS84 转 GCJ02 火星坐标
    class func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let a = 6378245.0
        let ee = 0.00669342162296594323
        let pi = Double.pi
        
        var lat = coordinate.latitude
        var lon = coordinate.longitude
        
        if outOfChina(lat, lon) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        var dLat = transformLat(lon - 105.0, lat - 35.0)
        var dLon = transformLon(lon - 105.0, lat - 35.0)
        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        
        return CLLocationCoordinate2D(latitude: lat + dLat, longitude: lon + dLon)
    }
    
    private class func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    private class func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
    
    private class func outOfChina(_ lat: Double, _ lon: Double) -> Bool {
        if (lon < 72.004 || lon > 137.8347) { return true }
        if (lat < 0.8293 || lat > 55.8271) { return true }
        return false
    }
}
