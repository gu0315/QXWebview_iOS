//
//  ViewController.swift
//  chery_ios
//
//  Created by 顾钱想 on 10/10/25.
//

import UIKit
import QXWebView
import SnapKit

class ViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var homeChargingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("家充桩", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(homeChargingAction), for: .touchUpInside)
        return button
    }()
    
    private lazy var publicChargingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("公充桩", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(publicChargingAction), for: .touchUpInside)
        return button
    }()

    private lazy var testPageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("测试", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(testPageAction), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    let homeChargingUrl = "http://192.168.31.137:5174//#/pages/bluetooth-test/index"
    
    let publicChargingUrl = "http://192.168.31.137:5174//#/pages/bluetooth-test/index"
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(homeChargingButton)
        view.addSubview(publicChargingButton)
        view.addSubview(testPageButton)
        
        homeChargingButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-60)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
        
        publicChargingButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(homeChargingButton.snp.bottom).offset(30)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }

        testPageButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(publicChargingButton.snp.bottom).offset(30)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
    }
    
    // MARK: - Actions
    @objc private func homeChargingAction() {
        let vc = QXWebViewController(url: homeChargingUrl)
        vc.hostDelegate = self
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func publicChargingAction() {
        let vc = QXWebViewController(url: publicChargingUrl)
        vc.hostDelegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func testPageAction() {
        guard let localURL = Bundle.main.url(forResource: "bridge_test", withExtension: "html") else {
            let alert = UIAlertController(title: "资源缺失", message: "未找到 bridge_test.html", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        let vc = QXWebViewController(url: localURL.absoluteString)
        vc.hostDelegate = self
        navigationController?.pushViewController(vc, animated: true)
    }
}


extension ViewController: QXWebViewHostDelegate {
    
    func webViewRequestOpenPage(
        url: String,
        params: [String: Any]?,
        completion: @escaping (Any?) -> Void
    ) {
        let safeParams = params ?? [:]
        switch url {
        case "app://pay":
            // 拉起支付功能
            // 需要宿主实现支付逻辑
            // 调用 completion 返回支付结果（成功 / 失败 / 错误信息）
            completion([
                "success": true,
                "action": "pay",
                "params": safeParams
            ])
        case "app://login":
            // 拉起登录功能
            // 需要宿主实现登录逻辑
            // 调用 completion 返回登录结果（成功 / 失败 / 错误信息）
            let result: [String: Any] = [
                      "phone": "xxx",
                      "list": [
                          ["vin": "vin1", "mac": "mac1"],
                          ["vin": "vin2", "mac": "mac2"],
                          ["vin": "vin3", "mac": "mac3"]
                      ],
                      "userId": "1232323232xxx",
                      "isLogin": true,
                      "userName": "xxx"
                  ]
                  completion(result)
        default:
            // 未注册或未处理的能力
            print("未处理的 URL: \(url)")
            completion([
                "success": false,
                "message": "未处理的 URL: \(url)",
                "params": safeParams
            ])
        }
    }
    
    func webViewRequestCustomMethod(methodName: String, params: [String : Any]?, completion: @escaping (Any?) -> Void) {
        switch methodName {
        case "getToken":
            completion(["token": "xxx"])
        case "getUserInfo":
            let result: [String: Any] = [
                      "phone": "xxx",
                      "list": [
                          ["vin": "vin1", "mac": "mac1"],
                          ["vin": "vin2", "mac": "mac2"],
                          ["vin": "vin3", "mac": "mac3"]
                      ],
                      "userId": "xxx",
                      "isLogin": false,
                      "userName": "xxx"
                  ]
                  completion(result)
        default:
            completion(["success": false, "message": "未知的方法: \(methodName)"])
        }
    }
}
