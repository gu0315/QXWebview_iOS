//
//  Utils.swift
//  QXWebView
//
//  Created by 顾钱想 on 1/13/26.
//

import UIKit

class Utils {

    func openThirdPartyApp(url: String) {
        guard let url = URL(string: url) else {
            return
        }
        if (UIApplication.shared.canOpenURL(url)) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}



// MARK: - Data Hex Conversion (Standard Implementation)
extension Data {
    /// 【标准】将 Data 转换为十六进制字符串
    /// - Parameter uppercase: 是否大写
    /// - Returns: 纯十六进制字符串，示例：Data([0x68, 0x65]) → "6865"
    func hexEncodedString(uppercase: Bool = false) -> String {
        let format = uppercase ? "%02hhX" : "%02hhx"
        // 补充 & 0xFF：对齐安卓/Kotlin 的 bytes[i] & 255
        return self.map { String(format: format, $0 & 0xFF) }.joined()
    }
    
    /// 转换为带格式的十六进制数组字符串（[xx, xx, xx]）
    /// - Parameter uppercase: 是否大写（默认 false，日志更易读）
    /// - Returns: 格式化字符串，示例：Data([0x68, 0x65]) → "[68, 65]"
    func hexArrayEncodedString(uppercase: Bool = false) -> String {
        guard !isEmpty else { return "[]" }
        let format = uppercase ? "%02hhX" : "%02hhx"
        // 补充 & 0xFF：对齐安卓/Kotlin 的数值处理逻辑
        let hexComponents = self.map { String(format: format, $0 & 0xFF) }
        return "[\(hexComponents.joined(separator: ", "))]"
    }
    
    /// 【反向转换】从纯十六进制字符串解析为 Data（标准方法）
    /// - Parameter hexString: 纯十六进制字符串（无空格/符号），示例："6865"
    /// - Returns: 解析后的 Data，解析失败返回 nil
    static func fromHexEncodedString(_ hexString: String) -> Data? {
        let cleanedString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedString.count % 2 == 0 else { return nil } // 确保字符数为偶数
        var data = Data()
        var index = cleanedString.startIndex
        
        while index < cleanedString.endIndex {
            let endIndex = cleanedString.index(index, offsetBy: 2)
            // 转小写：兼容安卓端的大小写输入
            let hexSub = cleanedString[index..<endIndex].lowercased()
            guard let byte = UInt8(hexSub, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = endIndex
        }
        
        return data
    }
}

// MARK: - 便捷属性（简化调用）
extension Data {
    var hexString: String { hexEncodedString(uppercase: false) }
    var hexArrayString: String { hexArrayEncodedString(uppercase: false) }
}
