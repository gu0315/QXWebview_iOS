//
//  LaunchScreenViewController.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import UIKit
import SnapKit

/// 启动屏幕控制器
class LaunchScreenViewController: UIViewController {
    
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let loadingLabel = UILabel()
    
    private var progressTimer: Timer?
    private var currentProgress: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startLoadingAnimation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateProgress()
    }
    
    // MARK: - 私有方法
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)
        
        // 设置渐变背景
        setupGradientBackground()
        
        // 配置Logo
        setupLogo()
        
        // 配置标题
        setupTitle()
        
        // 配置进度条
        setupProgressView()
        
        // 配置加载标签
        setupLoadingLabel()
    }
    
    private func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupLogo() {
        logoImageView.image = UIImage(systemName: "car.fill")
        logoImageView.tintColor = .white
        logoImageView.contentMode = .scaleAspectFit
        view.addSubview(logoImageView)
        
        logoImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-50)
            make.width.height.equalTo(120)
        }
    }
    
    private func setupTitle() {
        titleLabel.text = "奇瑞绿能"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(logoImageView.snp.bottom).offset(20)
        }
    }
    
    private func setupProgressView() {
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        view.addSubview(progressView)
        
        progressView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(40)
            make.width.equalTo(200)
            make.height.equalTo(4)
        }
    }
    
    private func setupLoadingLabel() {
        loadingLabel.text = "正在加载..."
        loadingLabel.font = UIFont.systemFont(ofSize: 16)
        loadingLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        loadingLabel.textAlignment = .center
        view.addSubview(loadingLabel)
        
        loadingLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(progressView.snp.bottom).offset(20)
        }
    }
    
    private func startLoadingAnimation() {
        // Logo动画
        logoImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.8, delay: 0.2, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            self.logoImageView.transform = .identity
        }
        
        // 标题动画
        titleLabel.alpha = 0
        UIView.animate(withDuration: 0.6, delay: 0.5) {
            self.titleLabel.alpha = 1
        }
        
        // 进度条动画
        progressView.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0.8) {
            self.progressView.alpha = 1
        }
        
        // 加载标签动画
        loadingLabel.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 1.0) {
            self.loadingLabel.alpha = 1
        }
    }
    
    private func animateProgress() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.currentProgress += 0.02
            self.progressView.setProgress(self.currentProgress, animated: true)
            
            if self.currentProgress >= 1.0 {
                self.progressTimer?.invalidate()
                self.progressTimer = nil
                self.completeLoading()
            }
        }
    }
    
    private func completeLoading() {
        UIView.animate(withDuration: 0.5, animations: {
            self.view.alpha = 0
        }) { _ in
            self.dismiss(animated: false) {
                // 通知应用启动完成
                NotificationCenter.default.post(
                    name: NSNotification.Name("LaunchScreenCompleted"),
                    object: nil
                )
            }
        }
    }
}
