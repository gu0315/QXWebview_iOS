import UIKit
import AVFoundation
import AudioToolbox

/// 二维码扫描视图控制器
class QXScannerViewController: UIViewController {
    
    // MARK: - 常量定义（避免魔法值）
    private enum Constants {
        static let scanRegionRatio: CGFloat = 0.7 // 扫描框占屏幕宽度比例
        static let scanLineHeight: CGFloat = 2.0  // 扫描线高度
        static let scanLineSpeed: TimeInterval = 0.01 // 扫描线移动速度
        static let scanTipFontSize: CGFloat = 16.0
        static let backButtonSize: CGFloat = 40.0
        static let backButtonMargin: CGFloat = 10.0
        static let tipLabelMargin: CGFloat = 20.0
        static let scanBorderWidth: CGFloat = 2.0
        static let scanBorderColor = UIColor.green.cgColor
    }
    
    // MARK: - 回调定义
    typealias ScanCompletion = (String?) -> Void
    private var completion: ScanCompletion?
    
    // MARK: - 核心属性（内存安全：添加weak/合理的强引用）
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanRegionView: UIView! // 扫描框
    private var scanLineView: UIView!   // 扫描线（动画）
    private var isScanning = false      // 扫描状态标记（防止重复回调）
    private var scanLineTimer: Timer?   // 扫描线动画定时器
    
    // MARK: - 初始化方法
    convenience init(completion: @escaping ScanCompletion) {
        self.init()
        self.completion = completion
        // 设置模态样式（优化弹出/关闭动画）
        self.modalPresentationStyle = .fullScreen
    }
    
    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBaseUI()
        checkCameraPermission() // 优先检查权限，再初始化扫描
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 布局完成后更新预览图层和扫描区域（解决布局未完成导致的区域计算错误）
        previewLayer?.frame = view.layer.bounds
        updateScanRegion()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanningIfAuthorized()
        startScanLineAnimation() // 启动扫描线动画
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
        stopScanLineAnimation() // 停止扫描线动画
    }
    
    deinit {
        // 清理资源，避免内存泄漏
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        scanLineTimer?.invalidate()
        scanLineTimer = nil
        completion = nil
    }
    
    // MARK: - UI设置（拆分模块，更易维护）
    /// 基础UI搭建
    private func setupBaseUI() {
        view.backgroundColor = .black
        
        // 1. 预览图层（先占位，后续在viewDidLayoutSubviews更新frame）
        previewLayer = AVCaptureVideoPreviewLayer(session: AVCaptureSession())
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer!, at: 0)
        
        // 2. 返回按钮
        setupBackButton()
        
        // 3. 扫描框 + 扫描线
        setupScanRegionView()
        
        // 4. 提示标签
        setupTipLabel()
    }
    
    /// 返回按钮
    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(named: "back") ?? UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backButton.layer.cornerRadius = Constants.backButtonSize / 2
        backButton.clipsToBounds = true
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.backButtonMargin),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.backButtonMargin),
            backButton.widthAnchor.constraint(equalToConstant: Constants.backButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Constants.backButtonSize)
        ])
    }
    
    /// 扫描框 + 扫描线
    private func setupScanRegionView() {
        // 扫描框
        scanRegionView = UIView()
        scanRegionView.backgroundColor = .clear
        scanRegionView.layer.borderColor = Constants.scanBorderColor
        scanRegionView.layer.borderWidth = Constants.scanBorderWidth
        scanRegionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanRegionView)
        
        // 扫描线
        scanLineView = UIView()
        scanLineView.backgroundColor = .green
        scanLineView.translatesAutoresizingMaskIntoConstraints = false
        scanRegionView.addSubview(scanLineView)
        
        NSLayoutConstraint.activate([
            // 扫描框约束
            scanRegionView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanRegionView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanRegionView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: Constants.scanRegionRatio),
            scanRegionView.heightAnchor.constraint(equalTo: scanRegionView.widthAnchor), // 正方形
            
            // 扫描线初始约束（顶部对齐）
            scanLineView.leadingAnchor.constraint(equalTo: scanRegionView.leadingAnchor),
            scanLineView.trailingAnchor.constraint(equalTo: scanRegionView.trailingAnchor),
            scanLineView.topAnchor.constraint(equalTo: scanRegionView.topAnchor),
            scanLineView.heightAnchor.constraint(equalToConstant: Constants.scanLineHeight)
        ])
    }
    
    /// 提示标签
    private func setupTipLabel() {
        let tipLabel = UILabel()
        tipLabel.text = "请将二维码对准扫描框"
        tipLabel.textColor = .white
        tipLabel.font = UIFont.systemFont(ofSize: Constants.scanTipFontSize)
        tipLabel.textAlignment = .center
        // tipLabel.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        tipLabel.layer.cornerRadius = 8.0
        tipLabel.clipsToBounds = true
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)
        
        NSLayoutConstraint.activate([
            tipLabel.topAnchor.constraint(equalTo: scanRegionView.bottomAnchor, constant: Constants.tipLabelMargin),
            tipLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.tipLabelMargin),
            tipLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.tipLabelMargin),
            tipLabel.heightAnchor.constraint(equalToConstant: 40) // 固定高度，优化显示
        ])
    }
    
    // MARK: - 权限处理（核心优化：补充完整的权限检查）
    /// 检查相机权限
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            setupCaptureSession() // 已授权，初始化扫描会话
        case .notDetermined:
            requestCameraPermission() // 未决定，请求授权
        case .denied, .restricted:
            showPermissionDeniedAlert() // 拒绝/受限，引导去设置
        @unknown default:
            showError(message: "未知的相机权限状态，请重试")
        }
    }
    
    /// 请求相机授权
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if granted {
                    self.setupCaptureSession()
                } else {
                    self.showPermissionDeniedAlert()
                }
            }
        }
    }
    
    /// 权限拒绝提示（引导去设置）
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "相机权限未开启",
            message: "需要访问相机才能扫描二维码，请前往设置开启权限",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.completion?(nil)
            self?.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settingsURL) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - 扫描会话配置（优化健壮性）
    /// 初始化捕获会话
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        
        // 1. 配置摄像头（优先使用后置摄像头）
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showError(message: "未检测到后置摄像头，请检查设备")
            return
        }
        
        do {
            // 2. 创建输入流
            let input = try AVCaptureDeviceInput(device: captureDevice)
            guard session.canAddInput(input) else {
                showError(message: "无法添加摄像头输入")
                return
            }
            session.addInput(input)
            
            // 3. 创建输出流（二维码识别）
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                showError(message: "无法添加扫码输出")
                return
            }
            session.addOutput(output)
            
            // 4. 配置输出流
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr] // 仅识别二维码，提升性能
            
            // 5. 关联会话到预览图层
            previewLayer?.session = session
            captureSession = session
            
            // 6. 检查弱光环境（优化体验）
            checkLowLightCondition(device: captureDevice)
            
        } catch {
            showError(message: "摄像头初始化失败：\(error.localizedDescription)")
        }
    }
    
    /// 更新扫描区域（修复原代码区域计算错误）
    private func updateScanRegion() {
        guard let output = captureSession?.outputs.first as? AVCaptureMetadataOutput else { return }
        
        // AVCaptureMetadataOutput的rectOfInterest是归一化坐标，且坐标系与UI相反：
        // - UI坐标系：原点左上角，y轴向下
        // - 视频坐标系：原点左上角，y轴向右（需转换）
        let scanRect = scanRegionView.frame
        let viewRect = view.bounds
        
        let x = scanRect.origin.y / viewRect.height
        let y = scanRect.origin.x / viewRect.width
        let width = scanRect.height / viewRect.height
        let height = scanRect.width / viewRect.width
        
        // 确保区域在0~1范围内（避免无效值）
        let normalizedRect = CGRect(
            x: max(0, x),
            y: max(0, y),
            width: min(1, width),
            height: min(1, height)
        )
        output.rectOfInterest = normalizedRect
    }
    
    /// 检查弱光环境
    private func checkLowLightCondition(device: AVCaptureDevice) {
        guard device.isLowLightBoostSupported else { return }
        DispatchQueue.global().async {
            if device.isLowLightBoostEnabled {
                DispatchQueue.main.async { [weak self] in
                    self?.showTip(message: "当前光线较暗，建议开启补光")
                }
            }
        }
    }
    
    // MARK: - 扫描控制（优化状态管理）
    /// 授权后启动扫描
    private func startScanningIfAuthorized() {
        guard !isScanning, let session = captureSession else { return }
        if !session.isRunning {
            session.startRunning()
            isScanning = true
        }
    }
    
    /// 停止扫描
    private func stopScanning() {
        guard isScanning, let session = captureSession else { return }
        if session.isRunning {
            session.stopRunning()
            isScanning = false
        }
    }
    
    // MARK: - 扫描线动画（优化用户体验）
    /// 启动扫描线动画
    private func startScanLineAnimation() {
        scanLineTimer?.invalidate()
        scanLineTimer = Timer.scheduledTimer(withTimeInterval: Constants.scanLineSpeed, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let maxY = self.scanRegionView.bounds.height - Constants.scanLineHeight
            let currentY = self.scanLineView.frame.origin.y
            
            if currentY >= maxY {
                self.scanLineView.frame.origin.y = 0
            } else {
                self.scanLineView.frame.origin.y += 1
            }
        }
    }
    
    /// 停止扫描线动画
    private func stopScanLineAnimation() {
        scanLineTimer?.invalidate()
        scanLineTimer = nil
        scanLineView.frame.origin.y = 0 // 重置扫描线位置
    }
    
    // MARK: - 结果处理（优化回调逻辑）
    /// 处理扫描结果
    private func handleScanResult(_ result: String?) {
        stopScanning()
        stopScanLineAnimation()
        
        // 扫描成功震动反馈（提升体验）
        if result != nil {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        
        // 延迟回调（避免动画卡顿）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.completion?(result)
            self?.dismiss(animated: true)
        }
    }
    
    // MARK: - 辅助方法（优化提示/错误处理）
    /// 显示错误提示
    private func showError(message: String) {
        let alert = UIAlertController(title: "扫码错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.handleScanResult(nil)
        })
        present(alert, animated: true)
    }
    
    /// 显示临时提示
    private func showTip(message: String) {
        let tipLabel = UILabel()
        tipLabel.text = message
        tipLabel.textColor = .white
        tipLabel.font = UIFont.systemFont(ofSize: 14)
        tipLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        tipLabel.layer.cornerRadius = 4
        tipLabel.clipsToBounds = true
        tipLabel.textAlignment = .center
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)
        
        NSLayoutConstraint.activate([
            tipLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tipLabel.bottomAnchor.constraint(equalTo: scanRegionView.topAnchor, constant: -20),
            tipLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            tipLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // 2秒后自动消失
        UIView.animate(withDuration: 2.0, animations: {
            tipLabel.alpha = 0
        }) { _ in
            tipLabel.removeFromSuperview()
        }
    }
    
    // MARK: - 事件处理
    @objc private func backButtonTapped() {
        handleScanResult(nil)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate（优化结果解析）
extension QXScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // 过滤空数据/重复扫描
        guard isScanning, !metadataObjects.isEmpty else { return }
        
        // 解析二维码内容
        let result = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .first?.stringValue
        
        if let qrCode = result, !qrCode.isEmpty {
            handleScanResult(qrCode)
        } else {
            showError(message: "无法识别二维码内容")
        }
    }
}
