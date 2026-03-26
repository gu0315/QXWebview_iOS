import UIKit
import AVFoundation
import AudioToolbox
import Photos

/// 底部功能按钮版（手电筒+相册） 二维码扫描视图控制器
class QXScannerViewController: UIViewController {
    
    // MARK: - 常量定义（扫描线颜色在这里配置！）
    private enum Constants {
        static let scanRegionRatio: CGFloat = 0.65
        static let scanLineHeight: CGFloat = 3.0
        static let scanLineSpeed: TimeInterval = 0.015
        static let cornerLineLength: CGFloat = 20
        static let cornerLineWidth: CGFloat = 3
        
        // 扫描线 + 四角边框 主色 #236982
        static let scanThemeColor = UIColor(hex: "#236982")!
        
        static let buttonSize: CGFloat = 56 // 按钮尺寸
        static let bottomMargin: CGFloat = 30 // 距底部安全区距离
        static let tipFontSize: CGFloat = 15
        static let buttonBgColor = UIColor.darkGray // 按钮背景色
    }
    
    // MARK: - 回调
    typealias ScanCompletion = (String?) -> Void
    private var completion: ScanCompletion?
    
    // MARK: - 核心属性
    private let sessionQueue = DispatchQueue(label: "QXScanner.session.queue")
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanView: UIView!
    private var scanLineView: UIImageView!
    private var maskView: UIView!
    private var isScanning = false
    private var scanLineTimer: Timer?
    private var torchButton: UIButton! // 手电
    private var albumButton: UIButton! // 相册
    private var isTorchOn = false
    
    // MARK: - 初始化
    convenience init(completion: @escaping ScanCompletion) {
        self.init()
        self.completion = completion
        self.modalPresentationStyle = .fullScreen
    }
    
    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWechatAlipayUI()
        checkCameraPermission()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
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
        closeTorch()
    }
    
    deinit {
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        scanLineTimer?.invalidate()
        scanLineTimer = nil
    }
}

// MARK: - 微信/支付宝 UI 实现
extension QXScannerViewController {
    private func setupWechatAlipayUI() {
        view.backgroundColor = .black
        
        // 相机预览层
        previewLayer = AVCaptureVideoPreviewLayer(session: AVCaptureSession())
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        view.layer.insertSublayer(previewLayer!, at: 0)
        
        setupMaskView()
        setupScanRegionView()
        setupTopBackButton()
        setupBottomFunctionButtons() // 已修改为左右布局
        setupTipLabel()
    }
    
    /// 半透明遮罩 + 中心镂空
    private func setupMaskView() {
        maskView = UIView(frame: view.bounds)
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(maskView)
        
        let scanWidth = view.bounds.width * Constants.scanRegionRatio
        let scanX = (view.bounds.width - scanWidth) / 2
        let scanY = (view.bounds.height - scanWidth) / 2
        let scanRect = CGRect(x: scanX, y: scanY, width: scanWidth, height: scanWidth)
        
        let path = UIBezierPath(rect: maskView.bounds)
        path.append(UIBezierPath(rect: scanRect).reversing())
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskView.layer.mask = maskLayer
    }
    
    /// 扫描框 + 四角定位角
    private func setupScanRegionView() {
        let scanWidth = view.bounds.width * Constants.scanRegionRatio
        scanView = UIView(frame: CGRect(
            x: (view.bounds.width - scanWidth)/2,
            y: (view.bounds.height - scanWidth)/2,
            width: scanWidth,
            height: scanWidth
        ))
        scanView.backgroundColor = .clear
        view.addSubview(scanView)
        
        // 四角角标
        addCornerLayers()
        
        // 渐变扫描线（使用配置颜色）
        scanLineView = UIImageView(frame: CGRect(
            x: 0, y: 0,
            width: scanWidth,
            height: Constants.scanLineHeight
        ))
        scanLineView.backgroundColor = .clear
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = scanLineView.bounds
        gradientLayer.colors = [
            Constants.scanThemeColor.withAlphaComponent(0).cgColor,
            Constants.scanThemeColor.cgColor,
            Constants.scanThemeColor.withAlphaComponent(0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        scanLineView.layer.addSublayer(gradientLayer)
        scanView.addSubview(scanLineView)
    }
    
    /// 四角定位角（使用配置颜色）
    private func addCornerLayers() {
        let w = Constants.cornerLineLength
        let t = Constants.cornerLineWidth
        let color = Constants.scanThemeColor.cgColor
        let size = scanView.bounds.size
        
        let corners = [
            CGRect(x: 0, y: 0, width: w, height: t),
            CGRect(x: 0, y: 0, width: t, height: w),
            CGRect(x: size.width-w, y: 0, width: w, height: t),
            CGRect(x: size.width-t, y: 0, width: t, height: w),
            CGRect(x: 0, y: size.height-t, width: w, height: t),
            CGRect(x: 0, y: size.height-w, width: t, height: w),
            CGRect(x: size.width-w, y: size.height-t, width: w, height: t),
            CGRect(x: size.width-t, y: size.height-w, width: t, height: w)
        ]
        
        corners.forEach { rect in
            let layer = CALayer()
            layer.frame = rect
            layer.backgroundColor = color
            scanView.layer.addSublayer(layer)
        }
    }
    
    /// 顶部返回按钮
    private func setupTopBackButton() {
        let backBtn = UIButton(type: .system)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backBtn.tintColor = .white
        backBtn.addTarget(self, action: #selector(backBtnTap), for: .touchUpInside)
        view.addSubview(backBtn)
        
        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
            backBtn.widthAnchor.constraint(equalToConstant: 44),
            backBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    /// 底部：手电（左） + 相册（右），带灰色圆形背景（参考图样式）
    private func setupBottomFunctionButtons() {
        // 手电筒按钮（左）
        torchButton = createBottomButton(
            imageName: "flashlight.off.fill",
            action: #selector(torchBtnTap)
        )
        view.addSubview(torchButton)
        
        // 相册按钮（右）
        albumButton = createBottomButton(
            imageName: "photo.fill",
            action: #selector(albumBtnTap)
        )
        view.addSubview(albumButton)
        
        NSLayoutConstraint.activate([
            // 手电筒：居左
            torchButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            torchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.bottomMargin),
            torchButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            torchButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            
            // 相册：居右
            albumButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            albumButton.bottomAnchor.constraint(equalTo: torchButton.bottomAnchor),
            albumButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            albumButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize)
        ])
    }
    
    /// 生成底部圆形按钮（带灰色背景）
    private func createBottomButton(imageName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = .white
        button.backgroundColor = Constants.buttonBgColor
        button.layer.cornerRadius = Constants.buttonSize / 2 // 圆形
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    /// 提示文字（在按钮上方居中）
    private func setupTipLabel() {
        let tip = UILabel()
        tip.translatesAutoresizingMaskIntoConstraints = false
        tip.text = "将二维码放入框内，即可自动扫描" // 和参考图文案一致
        tip.textColor = .white
        tip.font = UIFont.systemFont(ofSize: Constants.tipFontSize)
        tip.textAlignment = .center
        view.addSubview(tip)
        
        NSLayoutConstraint.activate([
            tip.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tip.bottomAnchor.constraint(equalTo: torchButton.topAnchor, constant: -30),
            tip.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            tip.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
}

// MARK: - 扫描逻辑（完全不变）
extension QXScannerViewController {
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async { self?.setupCaptureSession() }
            }
        default: showPermissionAlert(title: "相机权限未开启", msg: "需要访问相机才能扫描二维码，请前往设置开启权限")
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) { session.addOutput(output) }
            
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            
            previewLayer?.session = session
            captureSession = session
        } catch {
            showAlert(title: "错误", msg: "相机初始化失败：\(error.localizedDescription)")
        }
    }
    
    private func updateScanRegion() {
        guard let output = captureSession?.outputs.first as? AVCaptureMetadataOutput else { return }
        let rect = scanView.frame
        let x = rect.origin.y / view.bounds.height
        let y = rect.origin.x / view.bounds.width
        let w = rect.height / view.bounds.height
        let h = rect.width / view.bounds.width
        output.rectOfInterest = CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func startScanningIfAuthorized() {
        guard !isScanning, let session = captureSession else { return }
        isScanning = true
        sessionQueue.async { session.startRunning() }
    }
    
    private func stopScanning() {
        guard isScanning, let session = captureSession else { return }
        isScanning = false
        sessionQueue.async { session.stopRunning() }
    }
    
    private func startScanLineAnimation() {
        scanLineTimer?.invalidate()
        let maxY = scanView.bounds.height - Constants.scanLineHeight
        scanLineView.frame.origin.y = 0
        
        scanLineTimer = Timer.scheduledTimer(withTimeInterval: Constants.scanLineSpeed, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let y = self.scanLineView.frame.origin.y
            self.scanLineView.frame.origin.y = y >= maxY ? 0 : y + 1
        }
    }
    
    private func stopScanLineAnimation() {
        scanLineTimer?.invalidate()
        scanLineTimer = nil
    }
    
    private func handleResult(_ str: String?) {
        stopScanning()
        stopScanLineAnimation()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.completion?(str)
            self?.navigationController?.dismiss(animated: true) ?? self?.dismiss(animated: true)
        }
    }
}

// MARK: - 手电筒功能
extension QXScannerViewController {
    @objc private func torchBtnTap() {
        isTorchOn.toggle()
        let imageName = isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill"
        torchButton.setImage(UIImage(systemName: imageName), for: .normal)
        isTorchOn ? openTorch() : closeTorch()
    }
    
    private func openTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = .on
            device.unlockForConfiguration()
        } catch {}
    }
    
    private func closeTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {}
    }
}

// MARK: - 相册识别功能
extension QXScannerViewController {
    @objc private func albumBtnTap() {
        checkPhotoPermission(completion: { [weak self] granted in
            guard let self = self, granted else { return }
            DispatchQueue.main.async {
                let picker = UIImagePickerController()
                picker.sourceType = .photoLibrary
                picker.delegate = self
                self.present(picker, animated: true)
            }
        })
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
            case .authorized, .limited: completion(true)
            case .notDetermined: PHPhotoLibrary.requestAuthorization { completion($0 == .authorized) }
            case .denied, .restricted: showPhotoPermissionDeniedAlert(); completion(false)
            @unknown default: completion(false)
            }
        }
    }
    
    private func detectQRCode(_ image: UIImage) -> String? {
        guard let ci = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return (detector?.features(in: ci) as? [CIQRCodeFeature])?.first?.messageString
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
}

// MARK: - 代理实现
extension QXScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning, !metadataObjects.isEmpty else { return }
        let result = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }.first?.stringValue
        if let res = result { handleResult(res) }
    }
}

extension QXScannerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let img = info[.originalImage] as? UIImage else { return }
        handleResult(detectQRCode(img))
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - 点击事件与弹窗
extension QXScannerViewController {
    @objc private func backBtnTap() { dismiss(animated: true) }
    
    private func showAlert(title: String, msg: String) {
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showPermissionAlert(title: String, msg: String) {
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in self?.dismiss(animated: true) })
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })
        present(alert, animated: true)
    }
}

// MARK: - Hex 颜色扩展（支持 #236982 格式）
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
