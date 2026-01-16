//
//  ModernLoadingView.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import UIKit
import SnapKit

/// 现代化加载视图
class ModernLoadingView: UIView {
    
    private let containerView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let messageLabel = UILabel()
    
    private var progressTimer: Timer?
    private var currentProgress: Float = 0.0
    
    var title: String = "加载中..." {
        didSet {
            titleLabel.text = title
        }
    }
    
    var message: String = "" {
        didSet {
            messageLabel.text = message
            messageLabel.isHidden = message.isEmpty
        }
    }
    
    var showProgress: Bool = false {
        didSet {
            progressView.isHidden = !showProgress
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - 公共方法
    
    func show(in view: UIView) {
        view.addSubview(self)
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        startAnimation()
    }
    
    func hide() {
        stopAnimation()
        removeFromSuperview()
    }
    
    func setProgress(_ progress: Float, animated: Bool = true) {
        progressView.setProgress(progress, animated: animated)
    }
    
    func startProgressAnimation() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.currentProgress += 0.02
            self.progressView.setProgress(self.currentProgress, animated: true)
            
            if self.currentProgress >= 1.0 {
                self.progressTimer?.invalidate()
                self.progressTimer = nil
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // 设置容器视图
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 8
        addSubview(containerView)
        
        // 设置活动指示器
        activityIndicator.color = .systemBlue
        activityIndicator.hidesWhenStopped = true
        containerView.addSubview(activityIndicator)
        
        // 设置标题标签
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // 设置进度条
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = UIColor.systemGray5
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.isHidden = !showProgress
        containerView.addSubview(progressView)
        
        // 设置消息标签
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = .systemGray
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = message.isEmpty
        containerView.addSubview(messageLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(120)
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        
        progressView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(4)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(progressView.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
    }
    
    private func startAnimation() {
        activityIndicator.startAnimating()
        
        // 淡入动画
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    private func stopAnimation() {
        activityIndicator.stopAnimating()
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// MARK: - 便利方法
extension ModernLoadingView {
    
    /// 显示简单的加载视图
    static func showSimple(in view: UIView, title: String = "加载中...") -> ModernLoadingView {
        let loadingView = ModernLoadingView()
        loadingView.title = title
        loadingView.show(in: view)
        return loadingView
    }
    
    /// 显示带进度的加载视图
    static func showWithProgress(in view: UIView, title: String = "加载中...", message: String = "") -> ModernLoadingView {
        let loadingView = ModernLoadingView()
        loadingView.title = title
        loadingView.message = message
        loadingView.showProgress = true
        loadingView.show(in: view)
        return loadingView
    }
}
