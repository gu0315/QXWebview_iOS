//
//  UIView+Extensions.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import UIKit
import SnapKit

// MARK: - UIView Extensions
extension UIView {
    
    /// 添加圆角
    func addCornerRadius(_ radius: CGFloat) {
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
    
    /// 添加阴影
    func addShadow(color: UIColor = .black, 
                  opacity: Float = 0.1, 
                  offset: CGSize = CGSize(width: 0, height: 2), 
                  radius: CGFloat = 4) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
    
    /// 添加渐变背景
    func addGradientBackground(colors: [UIColor], 
                              startPoint: CGPoint = CGPoint(x: 0, y: 0), 
                              endPoint: CGPoint = CGPoint(x: 1, y: 1)) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.frame = bounds
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// 添加边框
    func addBorder(color: UIColor, width: CGFloat) {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
    }
    
    /// 添加点击动画
    func addTapAnimation(scale: CGFloat = 0.95, duration: TimeInterval = 0.1) {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapAnimation))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTapAnimation() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
    }
    
    /// 移除所有子视图
    func removeAllSubviews() {
        subviews.forEach { $0.removeFromSuperview() }
    }
    
    /// 截图
    func takeScreenshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - UIViewController Extensions
extension UIViewController {
    
    /// 显示加载指示器
    func showLoadingIndicator(message: String = "加载中...") {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.startAnimating()
        
        alert.setValue(loadingIndicator, forKey: "accessoryView")
        present(alert, animated: true)
    }
    
    /// 隐藏加载指示器
    func hideLoadingIndicator() {
        if let alert = presentedViewController as? UIAlertController {
            alert.dismiss(animated: true)
        }
    }
    
    /// 显示错误提示
    func showError(_ message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    /// 显示成功提示
    func showSuccess(_ message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "成功", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    /// 安全区域顶部约束
    var safeAreaTop: ConstraintItem {
        if #available(iOS 11.0, *) {
            return view.safeAreaLayoutGuide.snp.top
        } else {
            return view.snp.top
        }
    }
    
    /// 安全区域底部约束
    var safeAreaBottom: ConstraintItem {
        if #available(iOS 11.0, *) {
            return view.safeAreaLayoutGuide.snp.bottom
        } else {
            return view.snp.bottom
        }
    }
}
