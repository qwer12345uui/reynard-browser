//
//  BrowserFeaturesPreferencesViewController.swift
//  Reynard
//
//  Settings for app protection, background downloads, the bottom toolbar and clipboard URL detection.
//

import CryptoKit
import LocalAuthentication
import Security
import UIKit

enum GesturePasswordStore {
    private static let service = "com.minh-ton.Reynard.gesture-password"
    private static let account = "pattern-hash"
    private static let fallbackKey = "com.minh-ton.Reynard.gesture-password.fallback-hash"

    static var hasPassword: Bool {
        return storedHash != nil
    }

    /// Returns false only if neither Keychain nor the local fallback can retain the password hash.
    @discardableResult
    static func save(pattern: [Int]) -> Bool {
        let hash = digest(for: pattern)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = hash
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: fallbackKey)
            return true
        }
        UserDefaults.standard.set(hash, forKey: fallbackKey)
        return UserDefaults.standard.data(forKey: fallbackKey) == hash
    }

    static func matches(pattern: [Int]) -> Bool {
        guard let storedHash else {
            return false
        }
        return storedHash == digest(for: pattern)
    }

    static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: fallbackKey)
    }

    private static var storedHash: Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let hash = result as? Data {
            return hash
        }
        return UserDefaults.standard.data(forKey: fallbackKey)
    }

    private static func digest(for pattern: [Int]) -> Data {
        var data = Data("ReynardGesturePassword-v1".utf8)
        for point in pattern {
            data.append(UInt8(point))
        }
        return Data(SHA256.hash(data: data))
    }

    static var biometricDisplayName: String? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return nil
        }
    }

    static func authenticateWithBiometrics(completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "使用手势密码"
        var capabilityError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &capabilityError) else {
            completion(false, capabilityError?.localizedDescription ?? "此设备未配置可用的生物识别方式")
            return
        }
        let name = context.biometryType == .faceID ? "Face ID" : "Touch ID"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "使用\(name) 解锁 Reynard") { success, error in
            DispatchQueue.main.async {
                completion(success, success ? nil : error?.localizedDescription)
            }
        }
    }
}

final class BrowserFeaturesPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case security
        case downloads
        case toolbar
        case clipboard

        var text: SettingsSectionText {
            switch self {
            case .security:
                return SettingsSectionText(headerTitle: "安全")
            case .downloads:
                return SettingsSectionText(
                    headerTitle: "后台下载",
                    footerTitle: "后台执行时间由系统控制；到达所选时间或系统提前回收资源时，未完成的下载会自动暂停。"
                )
            case .toolbar:
                return SettingsSectionText(headerTitle: "底部按钮")
            case .clipboard:
                return SettingsSectionText(
                    headerTitle: "剪切板",
                    footerTitle: "开启后，浏览器回到前台时会识别新的 HTTP 或 HTTPS 网址，并让你选择是否打开。"
                )
            }
        }
    }

    private enum SecurityRow: CaseIterable {
        case gesturePassword
    }

    private enum DownloadRow: CaseIterable {
        case continuesInBackground
        case timeLimit
    }

    private enum ToolbarRow: CaseIterable {
        case buttonOrder
        case longPressQuickActions
    }

    private enum ClipboardRow: CaseIterable {
        case automaticallyParseURLs
    }

    private let continuesInBackgroundSwitch = UISwitch()
    private let longPressQuickActionsSwitch = UISwitch()
    private let automaticallyParseURLsSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "浏览器功能"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        continuesInBackgroundSwitch.addTarget(self, action: #selector(continuesInBackgroundDidChange(_:)), for: .valueChanged)
        longPressQuickActionsSwitch.addTarget(self, action: #selector(longPressQuickActionsDidChange(_:)), for: .valueChanged)
        automaticallyParseURLsSwitch.addTarget(self, action: #selector(automaticallyParseURLsDidChange(_:)), for: .valueChanged)
        refreshDisplayedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }
        switch Section.allCases[section] {
        case .security:
            return SecurityRow.allCases.count
        case .downloads:
            return DownloadRow.allCases.count
        case .toolbar:
            return ToolbarRow.allCases.count
        case .clipboard:
            return ClipboardRow.allCases.count
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        return Section.allCases[section].text
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section) else {
            return UITableViewCell()
        }

        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel

        switch Section.allCases[indexPath.section] {
        case .security:
            cell.textLabel?.text = "手势密码"
            cell.detailTextLabel?.text = Prefs.SecuritySettings.gesturePasswordEnabled ? "已启用" : "未设置"
            cell.accessoryType = .disclosureIndicator
        case .downloads:
            switch DownloadRow.allCases[indexPath.row] {
            case .continuesInBackground:
                cell.textLabel?.text = "允许后台下载"
                cell.detailTextLabel?.text = "有下载任务时保持传输，直到时间用尽或系统回收资源"
                cell.selectionStyle = .none
                cell.accessoryView = continuesInBackgroundSwitch
            case .timeLimit:
                cell.textLabel?.text = "后台运行时间"
                cell.detailTextLabel?.text = formattedBackgroundTimeLimit
                cell.accessoryType = .disclosureIndicator
            }
        case .toolbar:
            switch ToolbarRow.allCases[indexPath.row] {
            case .buttonOrder:
                cell.textLabel?.text = "按钮排序"
                cell.detailTextLabel?.text = "拖动以调整底部按钮显示顺序"
                cell.accessoryType = .disclosureIndicator
            case .longPressQuickActions:
                cell.textLabel?.text = "长按快捷操作"
                cell.detailTextLabel?.text = "长按底部按钮显示相关快捷操作"
                cell.selectionStyle = .none
                cell.accessoryView = longPressQuickActionsSwitch
            }
        case .clipboard:
            cell.textLabel?.text = "自动解析剪切板网址"
            cell.detailTextLabel?.text = "仅识别 HTTP 与 HTTPS 链接，不会自动打开"
            cell.selectionStyle = .none
            cell.accessoryView = automaticallyParseURLsSwitch
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else {
            return
        }

        switch Section.allCases[indexPath.section] {
        case .security:
            navigationController?.pushViewController(GesturePasswordPreferencesViewController(), animated: true)
        case .downloads where DownloadRow.allCases[indexPath.row] == .timeLimit:
            presentBackgroundTimeLimitPicker(from: tableView.cellForRow(at: indexPath))
        case .toolbar where ToolbarRow.allCases[indexPath.row] == .buttonOrder:
            navigationController?.pushViewController(BottomToolbarOrderPreferencesViewController(), animated: true)
        default:
            break
        }
    }

    private var formattedBackgroundTimeLimit: String {
        let seconds = Int(Prefs.DownloadSettings.backgroundTimeLimit)
        switch seconds {
        case 0:
            return "立即暂停"
        case 60:
            return "1 分钟"
        default:
            return "\(seconds / 60) 分钟"
        }
    }

    private func refreshDisplayedState() {
        continuesInBackgroundSwitch.isOn = Prefs.DownloadSettings.continuesInBackground
        longPressQuickActionsSwitch.isOn = Prefs.ToolbarSettings.longPressQuickActions
        automaticallyParseURLsSwitch.isOn = Prefs.ClipboardSettings.automaticallyParseURLs
    }

    private func presentBackgroundTimeLimitPicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "后台运行时间", message: "系统可在任意时刻提前结束后台执行。", preferredStyle: .actionSheet)
        let options: [(String, TimeInterval)] = [
            ("立即暂停", 0),
            ("1 分钟", 60),
            ("5 分钟", 300),
            ("10 分钟", 600),
            ("30 分钟", 1_800),
        ]
        for (title, value) in options {
            controller.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                Prefs.DownloadSettings.backgroundTimeLimit = value
                self?.tableView.reloadData()
            })
        }
        controller.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if let popover = controller.popoverPresentationController, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(controller, animated: true)
    }

    @objc private func continuesInBackgroundDidChange(_ sender: UISwitch) {
        Prefs.DownloadSettings.continuesInBackground = sender.isOn
        tableView.reloadData()
    }

    @objc private func longPressQuickActionsDidChange(_ sender: UISwitch) {
        Prefs.ToolbarSettings.longPressQuickActions = sender.isOn
    }

    @objc private func automaticallyParseURLsDidChange(_ sender: UISwitch) {
        Prefs.ClipboardSettings.automaticallyParseURLs = sender.isOn
        Prefs.ClipboardSettings.lastHandledChangeCount = UIPasteboard.general.changeCount
    }
}

final class GesturePasswordPreferencesViewController: SettingsTableViewController {
    private enum Row: CaseIterable {
        case configure
        case enabled
        case biometrics
        case remove
    }

    private let enabledSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "手势密码"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        enabledSwitch.addTarget(self, action: #selector(enabledDidChange(_:)), for: .valueChanged)
        refreshDisplayedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        return SettingsSectionText(
            headerTitle: "应用保护",
            footerTitle: "手势密码仅保存在本机钥匙串中。启用后，应用从后台返回时可使用 Face ID、Touch ID 或手势密码解锁。"
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Row.allCases.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel

        switch Row.allCases[indexPath.row] {
        case .configure:
            cell.textLabel?.text = GesturePasswordStore.hasPassword ? "更改手势密码" : "设置手势密码"
            cell.detailTextLabel?.text = "连接至少四个圆点"
            cell.accessoryType = .disclosureIndicator
        case .enabled:
            cell.textLabel?.text = "启用手势密码"
            cell.detailTextLabel?.text = GesturePasswordStore.hasPassword ? "在应用回到前台时要求验证" : "请先设置手势密码"
            cell.selectionStyle = .none
            enabledSwitch.isEnabled = GesturePasswordStore.hasPassword
            cell.accessoryView = enabledSwitch
        case .biometrics:
            if let biometricName = GesturePasswordStore.biometricDisplayName {
                cell.textLabel?.text = "\(biometricName) 解锁"
                cell.detailTextLabel?.text = "返回应用时优先使用 \(biometricName) 验证"
            } else {
                cell.textLabel?.text = "生物识别解锁"
                cell.detailTextLabel?.text = "此设备未配置可用的 Face ID 或 Touch ID"
                cell.textLabel?.textColor = .secondaryLabel
            }
            cell.selectionStyle = .none
        case .remove:
            cell.textLabel?.text = "移除手势密码"
            cell.textLabel?.textColor = GesturePasswordStore.hasPassword ? .systemRed : .tertiaryLabel
            cell.selectionStyle = GesturePasswordStore.hasPassword ? .default : .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Row.allCases.indices.contains(indexPath.row) else {
            return
        }
        switch Row.allCases[indexPath.row] {
        case .configure:
            let controller = GesturePatternEntryViewController { [weak self] in
                self?.refreshDisplayedState()
                self?.tableView.reloadData()
            }
            navigationController?.pushViewController(controller, animated: true)
        case .remove where GesturePasswordStore.hasPassword:
            let alert = UIAlertController(title: "移除手势密码", message: "移除后，应用回到前台时将不再要求手势验证。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
            alert.addAction(UIAlertAction(title: "移除", style: .destructive) { [weak self] _ in
                GesturePasswordStore.remove()
                Prefs.SecuritySettings.gesturePasswordEnabled = false
                self?.refreshDisplayedState()
                self?.tableView.reloadData()
            })
            present(alert, animated: true)
        default:
            break
        }
    }

    private func refreshDisplayedState() {
        enabledSwitch.isOn = Prefs.SecuritySettings.gesturePasswordEnabled
        enabledSwitch.isEnabled = GesturePasswordStore.hasPassword
    }

    @objc private func enabledDidChange(_ sender: UISwitch) {
        if sender.isOn && !GesturePasswordStore.hasPassword {
            sender.isOn = false
            return
        }
        Prefs.SecuritySettings.gesturePasswordEnabled = sender.isOn
    }
}

final class BottomToolbarOrderPreferencesViewController: SettingsTableViewController {
    private var order = Prefs.ToolbarSettings.bottomButtonOrder

    private let titles: [String: String] = [
        "back": "后退",
        "forward": "前进",
        "share": "分享",
        "basket": "收纳框",
        "downloads": "下载管理",
        "tabs": "多窗口",
    ]

    init() {
        super.init(style: .insetGrouped)
        title = "按钮排序"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "还原", style: .plain, target: self, action: #selector(resetOrder))
        setEditing(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Prefs.ToolbarSettings.bottomButtonOrder = order
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return order.count
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        return SettingsSectionText(headerTitle: "显示顺序", footerTitle: "按住右侧排序控制并拖动。更改会立即应用到底部地址栏按钮。")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard order.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = titles[order[indexPath.row]] ?? order[indexPath.row]
        cell.showsReorderControl = true
        return cell
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        let item = order.remove(at: sourceIndexPath.row)
        order.insert(item, at: destinationIndexPath.row)
        Prefs.ToolbarSettings.bottomButtonOrder = order
    }

    @objc private func resetOrder() {
        order = Prefs.ToolbarSettings.defaultBottomButtonOrder
        Prefs.ToolbarSettings.bottomButtonOrder = order
        tableView.reloadData()
    }
}

final class GesturePatternEntryViewController: UIViewController {
    private let completion: () -> Void
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let patternView = GesturePatternView()
    private var firstPattern: [Int]?

    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        title = "设置手势密码"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLabels()
        patternView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        view.addSubview(detailLabel)
        view.addSubview(patternView)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 34),
            titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            patternView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            patternView.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 42),
            patternView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.68),
            patternView.heightAnchor.constraint(equalTo: patternView.widthAnchor),
        ])
        patternView.onPatternCompleted = { [weak self] pattern in
            self?.handle(pattern: pattern)
        }
    }

    private func configureLabels() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.text = "绘制手势密码"
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0
        detailLabel.textColor = .secondaryLabel
        detailLabel.text = "请连续连接至少四个圆点"
    }

    private func handle(pattern: [Int]) {
        guard pattern.count >= 4 else {
            detailLabel.text = "请至少连接四个圆点后再试"
            patternView.reset(after: 0.65)
            return
        }
        guard let firstPattern else {
            self.firstPattern = pattern
            detailLabel.text = "请再次绘制相同手势以确认"
            patternView.reset(after: 0.45)
            return
        }
        guard firstPattern == pattern else {
            self.firstPattern = nil
            detailLabel.text = "两次手势不一致，请重新设置"
            patternView.reset(after: 0.65)
            return
        }
        guard GesturePasswordStore.save(pattern: pattern), GesturePasswordStore.hasPassword else {
            self.firstPattern = nil
            detailLabel.text = "无法保存手势密码，请重试"
            patternView.reset(after: 0.65)
            return
        }
        Prefs.SecuritySettings.gesturePasswordEnabled = true
        completion()
        navigationController?.popViewController(animated: true)
    }
}

final class GesturePasswordUnlockViewController: UIViewController {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let patternView = GesturePatternView()
    private let biometricButton = UIButton(type: .system)
    private let onUnlocked: () -> Void
    private var hasRequestedBiometrics = false
    private var isAuthenticating = false
    private var hasUnlocked = false

    init(onUnlocked: @escaping () -> Void) {
        self.onUnlocked = onUnlocked
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
        preferredContentSize = CGSize(width: 340, height: 520)
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureViews()
        view.addSubview(titleLabel)
        view.addSubview(detailLabel)
        view.addSubview(patternView)
        view.addSubview(biometricButton)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            patternView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            patternView.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 28),
            patternView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.68),
            patternView.widthAnchor.constraint(equalToConstant: 210),
            patternView.heightAnchor.constraint(equalTo: patternView.widthAnchor),
            biometricButton.topAnchor.constraint(equalTo: patternView.bottomAnchor, constant: 22),
            biometricButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            biometricButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        patternView.onPatternCompleted = { [weak self] pattern in
            self?.verify(pattern: pattern)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasRequestedBiometrics, GesturePasswordStore.biometricDisplayName != nil else { return }
        hasRequestedBiometrics = true
        authenticateWithBiometrics()
    }

    private func configureViews() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.text = "请输入手势密码"

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textAlignment = .center
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.text = GesturePasswordStore.biometricDisplayName.map { "可使用 \($0) 或绘制手势解锁" } ?? "绘制已设置的解锁手势"

        patternView.translatesAutoresizingMaskIntoConstraints = false

        biometricButton.translatesAutoresizingMaskIntoConstraints = false
        biometricButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        biometricButton.setTitleColor(view.tintColor, for: .normal)
        biometricButton.addTarget(self, action: #selector(biometricButtonTapped), for: .touchUpInside)
        if let biometricName = GesturePasswordStore.biometricDisplayName {
            biometricButton.setTitle("使用 \(biometricName) 解锁", for: .normal)
            let symbol = biometricName == "Face ID" ? "faceid" : "touchid"
            biometricButton.setImage(UIImage(systemName: symbol), for: .normal)
            biometricButton.imageView?.contentMode = .scaleAspectFit
            biometricButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
            biometricButton.semanticContentAttribute = .forceLeftToRight
        } else {
            biometricButton.isHidden = true
        }
    }

    @objc private func biometricButtonTapped() {
        authenticateWithBiometrics()
    }

    private func authenticateWithBiometrics() {
        guard !isAuthenticating, !hasUnlocked else { return }
        isAuthenticating = true
        biometricButton.isEnabled = false
        GesturePasswordStore.authenticateWithBiometrics { [weak self] success, message in
            guard let self else { return }
            self.isAuthenticating = false
            self.biometricButton.isEnabled = true
            guard success else {
                self.detailLabel.text = message ?? "生物识别未完成，请绘制手势密码解锁"
                return
            }
            self.unlock()
        }
    }

    private func verify(pattern: [Int]) {
        guard GesturePasswordStore.matches(pattern: pattern) else {
            detailLabel.text = "手势不正确，请重试"
            patternView.reset(after: 0.65)
            return
        }
        unlock()
    }

    private func unlock() {
        guard !hasUnlocked else { return }
        hasUnlocked = true
        dismiss(animated: true) { [onUnlocked] in
            onUnlocked()
        }
    }
}

private final class GesturePatternView: UIControl {
    var onPatternCompleted: (([Int]) -> Void)?

    private var selectedPoints: [Int] = []
    private var currentTouchPoint: CGPoint?
    private let feedback = UIImpactFeedbackGenerator(style: .light)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isMultipleTouchEnabled = false
        accessibilityLabel = "手势密码网格"
        accessibilityHint = "从一个圆点滑动连接至少四个圆点"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let centers = pointCenters
        let path = UIBezierPath()
        if let first = selectedPoints.first {
            path.move(to: centers[first])
            for point in selectedPoints.dropFirst() { path.addLine(to: centers[point]) }
            if let currentTouchPoint { path.addLine(to: currentTouchPoint) }
        }
        tintColor.setStroke()
        path.lineWidth = 4
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()

        for index in 0..<9 {
            let center = centers[index]
            let selected = selectedPoints.contains(index)
            let outerPath = UIBezierPath(ovalIn: CGRect(x: center.x - 23, y: center.y - 23, width: 46, height: 46))
            (selected ? tintColor : UIColor.systemGray3).setStroke()
            outerPath.lineWidth = 3
            outerPath.stroke()
            if selected {
                tintColor.setFill()
                UIBezierPath(ovalIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)).fill()
            }
        }
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        selectedPoints = []
        currentTouchPoint = touch.location(in: self)
        appendPoint(at: currentTouchPoint)
        setNeedsDisplay()
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        currentTouchPoint = touch.location(in: self)
        appendPoint(at: currentTouchPoint)
        setNeedsDisplay()
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if let touch {
            currentTouchPoint = touch.location(in: self)
            appendPoint(at: currentTouchPoint)
        }
        currentTouchPoint = nil
        setNeedsDisplay()
        onPatternCompleted?(selectedPoints)
    }

    override func cancelTracking(with event: UIEvent?) {
        reset(after: 0)
    }

    func reset(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.selectedPoints = []
            self?.currentTouchPoint = nil
            self?.setNeedsDisplay()
        }
    }

    private var pointCenters: [CGPoint] {
        let side = min(bounds.width, bounds.height)
        let origin = CGPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2)
        let inset = side * 0.16
        let spacing = (side - (inset * 2)) / 2
        return (0..<9).map { index in
            CGPoint(
                x: origin.x + inset + (CGFloat(index % 3) * spacing),
                y: origin.y + inset + (CGFloat(index / 3) * spacing)
            )
        }
    }

    private func appendPoint(at location: CGPoint?) {
        guard let location else { return }
        for (index, center) in pointCenters.enumerated() where !selectedPoints.contains(index) {
            guard hypot(location.x - center.x, location.y - center.y) <= 38 else { continue }
            selectedPoints.append(index)
            feedback.prepare()
            feedback.impactOccurred()
            break
        }
    }
}
