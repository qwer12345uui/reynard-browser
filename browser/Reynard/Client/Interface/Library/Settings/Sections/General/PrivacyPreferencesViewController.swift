//
//  PrivacyPreferencesViewController.swift
//  Reynard
//
//  Private browsing policy and cookie management.
//

import UIKit

final class PrivacyPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case privateBrowsing
        case cookies

        var text: SettingsSectionText {
            switch self {
            case .privateBrowsing:
                return SettingsSectionText(
                    headerTitle: "无痕模式",
                    footerTitle: "启用无痕模式不会影响已经打开的普通窗口。无痕 Cookie 与登录信息只保留在无痕会话中，关闭无痕窗口后会由浏览器清除。"
                )
            case .cookies:
                return SettingsSectionText(headerTitle: "站点数据")
            }
        }
    }

    private enum PrivateBrowsingRow: CaseIterable {
        case allowsCookies
        case remembersLoginState
    }

    private let cookiesSwitch = UISwitch()
    private let loginStateSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "隐私与无痕"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cookiesSwitch.addTarget(self, action: #selector(cookiesDidChange(_:)), for: .valueChanged)
        loginStateSwitch.addTarget(self, action: #selector(loginStateDidChange(_:)), for: .valueChanged)
        refreshState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshState()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else { return 0 }
        switch Section.allCases[section] {
        case .privateBrowsing: return PrivateBrowsingRow.allCases.count
        case .cookies: return 1
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else { return SettingsSectionText() }
        return Section.allCases[section].text
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel
        guard Section.allCases.indices.contains(indexPath.section) else { return cell }

        switch Section.allCases[indexPath.section] {
        case .privateBrowsing:
            switch PrivateBrowsingRow.allCases[indexPath.row] {
            case .allowsCookies:
                cell.textLabel?.text = "无痕模式下允许读写 Cookie"
                cell.detailTextLabel?.text = "让网站在当前无痕会话内正常运行"
                cell.selectionStyle = .none
                cell.accessoryView = cookiesSwitch
            case .remembersLoginState:
                cell.textLabel?.text = "无痕模式下可记住登录状态"
                cell.detailTextLabel?.text = "关闭无痕窗口后不会保留"
                cell.selectionStyle = .none
                cell.accessoryView = loginStateSwitch
            }
        case .cookies:
            cell.textLabel?.text = "Cookie 管理"
            cell.detailTextLabel?.text = "查看并清除本机保存的 Cookie"
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section), Section.allCases[indexPath.section] == .cookies else { return }
        navigationController?.pushViewController(CookieManagementPreferencesViewController(), animated: true)
    }

    private func refreshState() {
        cookiesSwitch.isOn = Prefs.PrivateBrowsingSettings.allowsCookies
        loginStateSwitch.isOn = Prefs.PrivateBrowsingSettings.remembersLoginState
    }

    @objc private func cookiesDidChange(_ sender: UISwitch) {
        Prefs.PrivateBrowsingSettings.allowsCookies = sender.isOn
        Prefs.PrivateBrowsingSettings.applyRuntimePolicy()
    }

    @objc private func loginStateDidChange(_ sender: UISwitch) {
        Prefs.PrivateBrowsingSettings.remembersLoginState = sender.isOn
        Prefs.PrivateBrowsingSettings.applyRuntimePolicy()
    }
}

private final class CookieManagementPreferencesViewController: SettingsTableViewController {
    private enum Row: CaseIterable {
        case storedCookies
        case clearAllCookies
    }

    init() {
        super.init(style: .insetGrouped)
        title = "Cookie 管理"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func sectionText(for section: Int) -> SettingsSectionText {
        SettingsSectionText(
            footerTitle: "清除操作会移除应用本机保存的 HTTP Cookie，并要求相应站点重新登录。无痕会话的 Cookie 不会被转存到普通窗口。"
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel
        switch Row.allCases[indexPath.row] {
        case .storedCookies:
            let count = HTTPCookieStorage.shared.cookies?.count ?? 0
            cell.textLabel?.text = "已保存 Cookie"
            cell.detailTextLabel?.text = "当前可管理 \(count) 项 Cookie"
            cell.selectionStyle = .none
        case .clearAllCookies:
            cell.textLabel?.text = "清除所有 Cookie"
            cell.textLabel?.textColor = .systemRed
            cell.detailTextLabel?.text = "清除后，网站可能要求重新登录"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Row.allCases[indexPath.row] == .clearAllCookies else { return }
        let alert = UIAlertController(
            title: "清除所有 Cookie",
            message: "这会移除本机保存的 Cookie。部分网站会要求重新登录。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }
}
