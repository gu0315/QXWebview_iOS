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
    
    // MARK: - Initialization
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    let homeChargingUrl = "http://192.168.31.137:5173/"
    
    let publicChargingUrl = "https://fr.dongxie.top/fr/#/?latitude=31.27109971007839&longitude=118.36288282976672"
    
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
    }
    
    // MARK: - Actions
    @objc private func homeChargingAction() {
        let vc = QXWebViewController(url: homeChargingUrl)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func publicChargingAction() {
        let vc = QXWebViewController(url: publicChargingUrl)
        navigationController?.pushViewController(vc, animated: true)
    }
}

