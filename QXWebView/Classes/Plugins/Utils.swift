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
