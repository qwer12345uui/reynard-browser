//
//  BrowserFeaturesPreferencesViewController.swift
//  Reynard
//
//  Settings for app protection, background downloads, the bottom toolbar and clipboard URL detection.
//

import CryptoKit
import Security
import UIKit

/// Local numeric passcode storage for application foreground protection.
/// The passcode itself is never persisted; only a SHA-256 digest is retained.
enum GesturePasswordStore {
    private static let service = "com.minh-ton.Reynard.numeric-password"
    private static let account = "pin-hash"
    private static let fallbackKey = "com.minh-ton.Reynard.numeric-password.fallback-hash"

    static var hasPassword: Bool { storedHash != nil }

    static func isValid(passcode: String) -> Bool {
        let digits = CharacterSet.decimalDigits
        return (4...12).contains(passcode.count) && passcode.unicodeScalars.allSatisfy { digits.contains($0) }
    }

    @discardableResult
    static func save(passcode: String) -> Bool {
        guard isValid(passcode: passcode) else { return false }
        let hash = digest(for: passcode)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = hash
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        if SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: fallbackKey)
            return true
        }
        UserDefaults.standard.set(hash, forKey: fallbackKey)
        return UserDefaults.standard.data(forKey: fallbackKey) == hash
    }

    static func matches(passcode: String) -> Bool {
        guard isValid(passcode: passcode), let storedHash else { return false }
        return storedHash == digest(for: passcode)
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

    private static func digest(for passcode: String) -> Data {
        Data(SHA256.hash(data: Data("ReynardNumericPassword-v1:\(passcode)".utf8)))
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
            cell.textLabel?.text = "数字密码"
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
        case remove
    }

    private let enabledSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "数字密码"
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
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func sectionText(for section: Int) -> SettingsSectionText {
        SettingsSectionText(
            headerTitle: "应用保护",
            footerTitle: "数字密码仅保存为本机哈希值。设置 4 至 12 位数字后，应用从后台返回时将要求输入。"
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Row.allCases.indices.contains(indexPath.row) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel
        switch Row.allCases[indexPath.row] {
        case .configure:
            cell.textLabel?.text = GesturePasswordStore.hasPassword ? "更改数字密码" : "设置数字密码"
            cell.detailTextLabel?.text = "4 至 12 位数字"
            cell.accessoryType = .disclosureIndicator
        case .enabled:
            cell.textLabel?.text = "启用数字密码"
            cell.detailTextLabel?.text = GesturePasswordStore.hasPassword ? "应用回到前台时要求验证" : "请先设置数字密码"
            cell.selectionStyle = .none
            enabledSwitch.isEnabled = GesturePasswordStore.hasPassword
            cell.accessoryView = enabledSwitch
        case .remove:
            cell.textLabel?.text = "移除数字密码"
            cell.textLabel?.textColor = GesturePasswordStore.hasPassword ? .systemRed : .tertiaryLabel
            cell.selectionStyle = GesturePasswordStore.hasPassword ? .default : .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Row.allCases.indices.contains(indexPath.row) else { return }
        switch Row.allCases[indexPath.row] {
        case .configure:
            presentPasscodeSetup()
        case .remove where GesturePasswordStore.hasPassword:
            let alert = UIAlertController(title: "移除数字密码", message: "移除后，应用回到前台时将不再要求数字密码验证。", preferredStyle: .alert)
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

    private func presentPasscodeSetup() {
        let alert = UIAlertController(title: "设置数字密码", message: "请输入相同的 4 至 12 位数字密码两次。", preferredStyle: .alert)
        for placeholder in ["数字密码", "确认数字密码"] {
            alert.addTextField { field in
                field.placeholder = placeholder
                field.keyboardType = .numberPad
                field.isSecureTextEntry = true
            }
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let values = alert?.textFields?.map(\.text),
                  values.count == 2,
                  let first = values[0], let confirmation = values[1] else { return }
            guard first == confirmation, GesturePasswordStore.save(passcode: first) else {
                self.showPasscodeError()
                return
            }
            Prefs.SecuritySettings.gesturePasswordEnabled = true
            self.refreshDisplayedState()
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func showPasscodeError() {
        let alert = UIAlertController(title: "无法设置数字密码", message: "两次输入必须相同，且密码只能由 4 至 12 位数字组成。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
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
