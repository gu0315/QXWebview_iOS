//
//  ViewController.swift
//  chery_ios
//
//  Created by 顾钱想 on 10/10/25.
//

import UIKit
import QXWebView
import SnapKit

// MARK: - 用户会话
/// 保存用户在主界面输入的信息，H5 通过桥接（getUserInfo / app://login）读取这里的数据
final class UserSession {
    static let shared = UserSession()
    private init() {}

    struct Vehicle {
        var vin: String
        var mac: String
    }

    var phone: String = ""
    var userId: String = "appUser"
    var userName: String = "App用户"
    var isLogin: Bool = true
    var vehicles: [Vehicle] = []

    /// H5 通过桥接获取的用户信息数据结构
    func userInfoPayload() -> [String: Any] {
        let list = vehicles.map { ["vin": $0.vin, "mac": $0.mac] }
        return [
            "phone": phone,
            "list": list,
            "userId": userId,
            "isLogin": isLogin,
            "userName": userName
        ]
    }
}

class ViewController: UIViewController {

    // 默认 H5 地址（可在界面上修改）
    private let defaultH5Url = "http://172.20.10.4:5173/"

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        return stack
    }()

    private lazy var phoneField = Self.makeTextField(placeholder: "请输入手机号", keyboard: .phonePad)

    private let vehicleListStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    private var vehicleRows: [VehicleRowView] = []

    private lazy var urlField = Self.makeTextField(placeholder: "H5 地址", keyboard: .URL)

    private lazy var addVehicleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("+ 添加车辆", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(addVehicleAction), for: .touchUpInside)
        return button
    }()

    private lazy var enterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("进入 H5", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(enterH5Action), for: .touchUpInside)
        return button
    }()

    // MARK: - Initialization
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "家充桩"
        setupUI()
        // 默认填充一行车辆输入，并预置默认 URL
        addVehicleRow()
        urlField.text = defaultH5Url
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalTo(view).inset(16)
            make.bottom.equalToSuperview().offset(-20)
        }

        contentStack.addArrangedSubview(makeSectionLabel("手机号"))
        contentStack.addArrangedSubview(phoneField)

        contentStack.addArrangedSubview(makeSectionLabel("车辆列表（VIN / MAC）"))
        contentStack.addArrangedSubview(vehicleListStack)
        contentStack.addArrangedSubview(addVehicleButton)

        contentStack.addArrangedSubview(makeSectionLabel("H5 地址"))
        contentStack.addArrangedSubview(urlField)

        contentStack.addArrangedSubview(enterButton)
        enterButton.snp.makeConstraints { make in
            make.height.equalTo(50)
        }

        // 点击空白收起键盘
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .darkGray
        return label
    }

    private static func makeTextField(placeholder: String, keyboard: UIKeyboardType) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 16)
        field.keyboardType = keyboard
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.clearButtonMode = .whileEditing
        field.backgroundColor = .white
        field.text = "15755336837" //18352537909
        field.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        return field
    }

    // MARK: - 车辆行管理
    private func addVehicleRow(vin: String = "", mac: String = "") {
        let row = VehicleRowView()
        row.vinField.text = vin
        row.macField.text = mac
        row.onDelete = { [weak self, weak row] in
            guard let self = self, let row = row else { return }
            self.removeVehicleRow(row)
        }
        vehicleRows.append(row)
        vehicleListStack.addArrangedSubview(row)
        updateRowTitles()
    }

    private func removeVehicleRow(_ row: VehicleRowView) {
        // 至少保留一行
        guard vehicleRows.count > 1 else { return }
        if let index = vehicleRows.firstIndex(where: { $0 === row }) {
            vehicleRows.remove(at: index)
        }
        vehicleListStack.removeArrangedSubview(row)
        row.removeFromSuperview()
        updateRowTitles()
    }

    private func updateRowTitles() {
        for (index, row) in vehicleRows.enumerated() {
            row.setTitle("车辆 \(index + 1)")
        }
    }

    // MARK: - Actions
    @objc private func addVehicleAction() {
        addVehicleRow()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func enterH5Action() {
        view.endEditing(true)

        let phone = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !phone.isEmpty else {
            showAlert(title: "提示", message: "请输入手机号")
            return
        }

        var vehicles: [UserSession.Vehicle] = []
        for row in vehicleRows {
            let vin = row.vinText
            let mac = row.macText
            if vin.isEmpty && mac.isEmpty { continue }
            vehicles.append(UserSession.Vehicle(vin: vin, mac: mac))
        }

        // 写入会话，供 H5 通过桥接读取
        UserSession.shared.phone = phone
        UserSession.shared.vehicles = vehicles
        UserSession.shared.isLogin = true

        let trimmedUrl = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let url = trimmedUrl.isEmpty ? defaultH5Url : trimmedUrl

        let vc = QXWebViewController(url: url)
        vc.hostDelegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - 车辆输入行
final class VehicleRowView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    let vinField: UITextField = {
        let field = UITextField()
        field.placeholder = "VIN"
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 15)
        field.autocorrectionType = .no
        field.text = ""
        field.autocapitalizationType = .allCharacters
        field.backgroundColor = .white
        return field
    }()

    let macField: UITextField = {
        let field = UITextField()
        field.placeholder = "MAC"
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 15)
        field.autocorrectionType = .no
        field.autocapitalizationType = .allCharacters
        field.backgroundColor = .white
        return field
    }()

    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("删除", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.addTarget(self, action: #selector(deleteAction), for: .touchUpInside)
        return button
    }()

    var onDelete: (() -> Void)?

    var vinText: String { vinField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    var macText: String { macField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func setTitle(_ text: String) {
        titleLabel.text = text
    }

    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.6)
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor

        let header = UIStackView(arrangedSubviews: [titleLabel, deleteButton])
        header.axis = .horizontal
        header.distribution = .equalSpacing

        let fieldStack = UIStackView(arrangedSubviews: [vinField, macField])
        fieldStack.axis = .vertical
        fieldStack.spacing = 8

        let container = UIStackView(arrangedSubviews: [header, fieldStack])
        container.axis = .vertical
        container.spacing = 8

        addSubview(container)
        container.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }
        vinField.snp.makeConstraints { make in make.height.equalTo(40) }
        macField.snp.makeConstraints { make in make.height.equalTo(40) }
    }

    @objc private func deleteAction() {
        onDelete?()
    }
}

// MARK: - 桥接：把用户输入的数据返回给 H5
// 说明：A 打开 B、B 回传值的能力已下沉到 SDK（QXBasePlugin 的
// openWebViewForResult / closeWithResult），宿主无需再处理，这里只负责用户信息。
extension ViewController: QXWebViewHostDelegate {

    func webViewRequestOpenPage(url: String, params: [String: Any]?, completion: @escaping (Any?) -> Void) {
        let safeParams = params ?? [:]
        switch url {
        case "app://pay":
            completion(["success": true, "action": "pay", "params": safeParams])
        case "app://login":
            completion(UserSession.shared.userInfoPayload())
        default:
            print("未处理的 URL: \(url)")
            completion(["success": false, "message": "未处理的 URL: \(url)", "params": safeParams])
        }
    }

    func webViewRequestCustomMethod(methodName: String, params: [String: Any]?, completion: @escaping (Any?) -> Void) {
        switch methodName {
        case "getToken":
            completion(["token": "xxx"])
        case "getUserInfo":
            completion(UserSession.shared.userInfoPayload())
        default:
            completion(["success": false, "message": "未知的方法: \(methodName)"])
        }
    }
}
