import UIKit
import AVFoundation
import AudioToolbox
import Photos // 相册框架

/// 二维码扫描视图控制器
class QXScannerViewController: UIViewController {
    
    // MARK: - 常量定义（避免魔法值）
    private enum Constants {
        static let scanRegionRatio: CGFloat = 0.7     // 扫描框占屏幕宽度比例
        static let scanLineHeight: CGFloat = 2.0      // 扫描线高度
        static let scanLineSpeed: TimeInterval = 0.01 // 扫描线移动速度
        static let scanTipFontSize: CGFloat = 16.0
        static let backButtonSize: CGFloat = 40.0
        static let backButtonMargin: CGFloat = 10.0
        static let tipLabelMargin: CGFloat = 20.0
        static let scanBorderWidth: CGFloat = 2.0
        static let scanBorderColor = UIColor.green.cgColor
        static let albumButtonSpacing: CGFloat = 15.0 // 相册按钮和返回按钮间距
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
    
    // MARK: - 初始化方法 (你的原代码，完整保留，只修复了fullScreen的枚举前缀 ✔️)
    convenience init(completion: @escaping ScanCompletion) {
        self.init()
        self.completion = completion
        // 设置模态样式（优化弹出/关闭动画）- 修复：补全枚举前缀，解决报错
        self.modalPresentationStyle = UIModalPresentationStyle.fullScreen
    }
    
    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBaseUI()
        checkCameraPermission() // 优先检查权限，再初始化扫描
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        updateScanRegion()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanningIfAuthorized()
        startScanLineAnimation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
        stopScanLineAnimation()
    }
    
    deinit {
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        scanLineTimer?.invalidate()
        scanLineTimer = nil
        completion = nil
    }
    
    // MARK: - UI设置
    private func setupBaseUI() {
        view.backgroundColor = .black
        
        previewLayer = AVCaptureVideoPreviewLayer(session: AVCaptureSession())
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.layer.bounds
        view.layer.insertSublayer(previewLayer!, at: 0)
        
        setupTopFunctionButtons()
        setupScanRegionView()
        setupTipLabel()
    }
    
    private func setupTopFunctionButtons() {
        let backButton = createFunctionButton(imageName: "back", systemImage: "chevron.left", action: #selector(backButtonTapped))
        let albumButton = createFunctionButton(imageName: "album", systemImage: "photo", action: #selector(albumButtonTapped))
        
        view.addSubview(backButton)
        view.addSubview(albumButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,constant: Constants.backButtonMargin),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.backButtonMargin),
            backButton.widthAnchor.constraint(equalToConstant: Constants.backButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Constants.backButtonSize),
            
            albumButton.topAnchor.constraint(equalTo: backButton.topAnchor),
            albumButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -Constants.backButtonMargin),
            //albumButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: Constants.albumButtonSpacing),
            albumButton.widthAnchor.constraint(equalToConstant: Constants.backButtonSize),
            albumButton.heightAnchor.constraint(equalToConstant: Constants.backButtonSize)
        ])
    }
    
    private func createFunctionButton(imageName: String, systemImage: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: imageName) ?? UIImage(systemName: systemImage), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = Constants.backButtonSize / 2
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func setupScanRegionView() {
        scanRegionView = UIView()
        scanRegionView.backgroundColor = .clear
        scanRegionView.layer.borderColor = Constants.scanBorderColor
        scanRegionView.layer.borderWidth = Constants.scanBorderWidth
        scanRegionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanRegionView)
        
        scanLineView = UIView()
        scanLineView.backgroundColor = .green
        scanLineView.translatesAutoresizingMaskIntoConstraints = false
        scanRegionView.addSubview(scanLineView)
        
        NSLayoutConstraint.activate([
            scanRegionView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanRegionView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanRegionView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: Constants.scanRegionRatio),
            scanRegionView.heightAnchor.constraint(equalTo: scanRegionView.widthAnchor),
            
            scanLineView.leadingAnchor.constraint(equalTo: scanRegionView.leadingAnchor),
            scanLineView.trailingAnchor.constraint(equalTo: scanRegionView.trailingAnchor),
            scanLineView.topAnchor.constraint(equalTo: scanRegionView.topAnchor),
            scanLineView.heightAnchor.constraint(equalToConstant: Constants.scanLineHeight)
        ])
    }
    
    private func setupTipLabel() {
        let tipLabel = UILabel()
        tipLabel.text = "请将二维码对准扫描框｜也可从相册选择识别"
        tipLabel.textColor = .white
        tipLabel.font = UIFont.systemFont(ofSize: Constants.scanTipFontSize)
        tipLabel.textAlignment = .center
        tipLabel.layer.cornerRadius = 8.0
        tipLabel.clipsToBounds = true
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)
        
        NSLayoutConstraint.activate([
            tipLabel.topAnchor.constraint(equalTo: scanRegionView.bottomAnchor, constant: Constants.tipLabelMargin),
            tipLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.tipLabelMargin),
            tipLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.tipLabelMargin),
            tipLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - 权限处理
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: setupCaptureSession()
        case .notDetermined: requestCameraPermission()
        case .denied, .restricted: showPermissionDeniedAlert()
        @unknown default: showError(message: "未知的相机权限状态，请重试")
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.setupCaptureSession()
            }
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(title: "相机权限未开启", message: "需要访问相机才能扫描二维码，请前往设置开启权限", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.completion?(nil)
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
    
    private func checkPhotoPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited: completion(true)
            case .notDetermined: PHPhotoLibrary.requestAuthorization(for: .readWrite) { completion($0 == .authorized || $0 == .limited) }
            case .denied, .restricted: showPhotoPermissionDeniedAlert(); completion(false)
            @unknown default: completion(false)
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized: completion(true)
            case .notDetermined: PHPhotoLibrary.requestAuthorization { completion($0 == .authorized) }
            case .denied, .restricted: showPhotoPermissionDeniedAlert(); completion(false)
            case .limited: completion(true)  //允许访问“部分照片”
            @unknown default: completion(false)
            }
        }
    }
    
    private func showPhotoPermissionDeniedAlert() {
        let alert = UIAlertController(title: "相册权限未开启", message: "需要访问相册才能识别图片中的二维码，请前往设置开启权限", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
    
    // MARK: - 扫描会话配置
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showError(message: "未检测到后置摄像头，请检查设备")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            guard session.canAddInput(input) else { return }
            session.addInput(input)
            
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
            
            previewLayer?.session = session
            captureSession = session
            checkLowLightCondition(device: captureDevice)
        } catch {
            showError(message: "摄像头初始化失败：\(error.localizedDescription)")
        }
    }
    
    private func updateScanRegion() {
        guard let output = captureSession?.outputs.first as? AVCaptureMetadataOutput else { return }
        let scanRect = scanRegionView.frame
        let viewRect = view.bounds
        let x = scanRect.origin.y / viewRect.height
        let y = scanRect.origin.x / viewRect.width
        let width = scanRect.height / viewRect.height
        let height = scanRect.width / viewRect.width
        output.rectOfInterest = CGRect(x: max(0, x), y: max(0, y), width: min(1, width), height: min(1, height))
    }
    
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
    
    // MARK: - 扫描控制
    private func startScanningIfAuthorized() {
        guard !isScanning, let session = captureSession else { return }
        session.startRunning()
        isScanning = true
    }
    
    private func stopScanning() {
        guard isScanning, let session = captureSession else { return }
        session.stopRunning()
        isScanning = false
    }
    
    // MARK: - 扫描线动画
    private func startScanLineAnimation() {
        scanLineTimer?.invalidate()
        scanLineTimer = Timer.scheduledTimer(withTimeInterval: Constants.scanLineSpeed, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let maxY = self.scanRegionView.bounds.height - Constants.scanLineHeight
            self.scanLineView.frame.origin.y = self.scanLineView.frame.origin.y >= maxY ? 0 : self.scanLineView.frame.origin.y + 1
        }
    }
    
    private func stopScanLineAnimation() {
        scanLineTimer?.invalidate()
        scanLineTimer = nil
        scanLineView.frame.origin.y = 0
    }
    
    // MARK: - 结果处理
    private func handleScanResult(_ result: String?) {
        stopScanning()
        stopScanLineAnimation()
        if result != nil { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.completion?(result)
            self?.dismiss(animated: true)
        }
    }
    
    // MARK: - 辅助方法
    private func showError(message: String) {
        let alert = UIAlertController(title: "扫码错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.handleScanResult(nil)
        })
        present(alert, animated: true)
    }
    
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
        UIView.animate(withDuration: 2.0) { tipLabel.alpha = 0 } completion: { _ in tipLabel.removeFromSuperview() }
    }
    
    // MARK: - 事件处理
    @objc private func backButtonTapped() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    @objc private func albumButtonTapped() {
        checkPhotoPermission { [weak self] granted in
            guard let self = self, granted else { return }
            // 主线程
            DispatchQueue.main.async {
                let picker = UIImagePickerController()
                picker.sourceType = .photoLibrary
                picker.delegate = self
                picker.allowsEditing = false
                self.present(picker, animated: true)
            }
        }
    }
    
    private func detectQRCode(in image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return (detector?.features(in: ciImage) as? [CIQRCodeFeature])?.first?.messageString
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension QXScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning, !metadataObjects.isEmpty else { return }
        let result = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }.first?.stringValue
        if let qrCode = result, !qrCode.isEmpty {
            handleScanResult(qrCode)
        } else {
            showError(message: "无法识别二维码内容")
        }
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension QXScannerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else {
            showError(message: "无法获取选中的图片")
            return
        }
        if let qrStr = detectQRCode(in: image), !qrStr.isEmpty {
            handleScanResult(qrStr)
        } else {
            showError(message: "图片中未识别到有效的二维码")
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
