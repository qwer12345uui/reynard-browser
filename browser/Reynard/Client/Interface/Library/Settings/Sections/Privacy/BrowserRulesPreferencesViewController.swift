//
//  BrowserRulesPreferencesViewController.swift
//  Reynard
//
//  Advertising and privacy rule controls.
//

import UIKit

final class BrowserRulesPreferencesViewController: SettingsTableViewController {
    private enum Section: Int, CaseIterable {
        case protection
        case blockedDomains
        case allowedDomains

        var text: SettingsSectionText {
            switch self {
            case .protection:
                return SettingsSectionText(
                    headerTitle: "广告拦截与隐私保护",
                    footerTitle: "规则会在新页面加载时生效。修改后请重新加载当前网页；白名单优先于拦截规则。"
                )
            case .blockedDomains:
                return SettingsSectionText(headerTitle: "自定义拦截域名")
            case .allowedDomains:
                return SettingsSectionText(headerTitle: "白名单")
            }
        }
    }

    private enum ProtectionRow: CaseIterable {
        case advertising
        case privacy
        case cosmetic
    }

    private let store = BrowserRuleStore.shared
    private let advertisingSwitch = UISwitch()
    private let privacySwitch = UISwitch()
    private let cosmeticSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "广告与隐私规则"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        advertisingSwitch.addTarget(self, action: #selector(advertisingDidChange(_:)), for: .valueChanged)
        privacySwitch.addTarget(self, action: #selector(privacyDidChange(_:)), for: .valueChanged)
        cosmeticSwitch.addTarget(self, action: #selector(cosmeticDidChange(_:)), for: .valueChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(rulesDidChange), name: .browserRuleStoreDidChange, object: store)
        refreshSwitches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshSwitches()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .protection: return ProtectionRow.allCases.count
        case .blockedDomains: return store.snapshot.blockedDomains.count + 1
        case .allowedDomains: return store.snapshot.allowedDomains.count + 1
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        Section(rawValue: section)?.text ?? SettingsSectionText()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel
        switch section {
        case .protection:
            switch ProtectionRow.allCases[indexPath.row] {
            case .advertising:
                cell.textLabel?.text = "拦截常见广告网络"
                cell.detailTextLabel?.text = "阻止常见广告请求和嵌入内容"
                cell.accessoryView = advertisingSwitch
            case .privacy:
                cell.textLabel?.text = "隐私保护规则"
                cell.detailTextLabel?.text = "阻止分析追踪并移除常见跟踪参数"
                cell.accessoryView = privacySwitch
            case .cosmetic:
                cell.textLabel?.text = "隐藏广告元素"
                cell.detailTextLabel?.text = "隐藏网页上的常见广告占位区域"
                cell.accessoryView = cosmeticSwitch
            }
            cell.selectionStyle = .none
        case .blockedDomains:
            let domains = store.snapshot.blockedDomains
            if indexPath.row < domains.count {
                cell.textLabel?.text = domains[indexPath.row]
                cell.detailTextLabel?.text = "阻止该域名及其子域名"
            } else {
                cell.textLabel?.text = "添加拦截域名"
                cell.textLabel?.textColor = view.tintColor
                cell.imageView?.image = UIImage(systemName: "plus.circle")
            }
        case .allowedDomains:
            let domains = store.snapshot.allowedDomains
            if indexPath.row < domains.count {
                cell.textLabel?.text = domains[indexPath.row]
                cell.detailTextLabel?.text = "不对该域名应用本地规则"
            } else {
                cell.textLabel?.text = "添加白名单域名"
                cell.textLabel?.textColor = view.tintColor
                cell.imageView?.image = UIImage(systemName: "plus.circle")
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .protection:
            return
        case .blockedDomains:
            let domains = store.snapshot.blockedDomains
            guard indexPath.row == domains.count else { return }
            presentDomainPrompt(title: "添加拦截域名", placeholder: "ads.example.com") { [weak self] value in
                do { try self?.store.addBlockedDomain(value) } catch { self?.showError(error) }
            }
        case .allowedDomains:
            let domains = store.snapshot.allowedDomains
            guard indexPath.row == domains.count else { return }
            presentDomainPrompt(title: "添加白名单域名", placeholder: "example.com") { [weak self] value in
                do { try self?.store.addAllowedDomain(value) } catch { self?.showError(error) }
            }
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let section = Section(rawValue: indexPath.section) else { return nil }
        let domain: String?
        switch section {
        case .protection: return nil
        case .blockedDomains: domain = store.snapshot.blockedDomains.indices.contains(indexPath.row) ? store.snapshot.blockedDomains[indexPath.row] : nil
        case .allowedDomains: domain = store.snapshot.allowedDomains.indices.contains(indexPath.row) ? store.snapshot.allowedDomains[indexPath.row] : nil
        }
        guard let domain else { return nil }
        let action = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            if section == .blockedDomains { self?.store.removeBlockedDomain(domain) }
            if section == .allowedDomains { self?.store.removeAllowedDomain(domain) }
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func refreshSwitches() {
        let snapshot = store.snapshot
        advertisingSwitch.isOn = snapshot.advertisingEnabled
        privacySwitch.isOn = snapshot.privacyEnabled
        cosmeticSwitch.isOn = snapshot.cosmeticFilteringEnabled
    }

    @objc private func advertisingDidChange(_ sender: UISwitch) { store.setAdvertisingEnabled(sender.isOn) }
    @objc private func privacyDidChange(_ sender: UISwitch) { store.setPrivacyEnabled(sender.isOn) }
    @objc private func cosmeticDidChange(_ sender: UISwitch) { store.setCosmeticFilteringEnabled(sender.isOn) }
    @objc private func rulesDidChange() { refreshSwitches(); tableView.reloadData() }

    private func presentDomainPrompt(title: String, placeholder: String, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: "规则会作用于该域名及其子域名。", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = placeholder
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak alert] _ in
            guard let value = alert?.textFields?.first?.text else { return }
            completion(value)
        })
        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "无法添加规则", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
