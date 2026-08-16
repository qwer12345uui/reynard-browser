//
//  CompatibilityPreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import UIKit

final class CompatibilityPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case userAgent

        var text: SettingsSectionText {
            SettingsSectionText(
                headerTitle: "自定义浏览器标识（UA）",
                footerTitle: "默认标识兼容大多数网站；遇到登录、验证码或页面兼容问题时，可改用 Android 兼容标识，或仅为特定网站添加规则。"
            )
        }
    }

    private enum Row: CaseIterable {
        case userAgentMode
        case userAgentOverrides
    }

    private var displayedRows: [Row] {
        Prefs.CompatibilitySettings.useAndroidUserAgent ? [.userAgentMode] : Row.allCases
    }

    private var userAgentModeTitle: String {
        Prefs.CompatibilitySettings.useAndroidUserAgent ? "兼容模式（Android）" : "默认"
    }

    init() {
        super.init(style: .insetGrouped)
        title = NSLocalizedString("Compatibility", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else { return 0 }
        return displayedRows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section),
              displayedRows.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }

        switch displayedRows[indexPath.row] {
        case .userAgentMode:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "自定义浏览器标识（UA）"
            cell.detailTextLabel?.text = userAgentModeTitle
            cell.accessoryType = .disclosureIndicator
            return cell
        case .userAgentOverrides:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("User Agent Overrides", comment: "")
            cell.detailTextLabel?.text = "为指定网站使用 Android 兼容标识"
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section),
              displayedRows.indices.contains(indexPath.row) else {
            return
        }

        switch displayedRows[indexPath.row] {
        case .userAgentMode:
            presentUserAgentModePicker(from: tableView.cellForRow(at: indexPath))
        case .userAgentOverrides:
            navigationController?.pushViewController(UserAgentOverridesPreferencesViewController(), animated: true)
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else {
            return SettingsSectionText()
        }
        return Section.allCases[section].text
    }

    private func presentUserAgentModePicker(from sourceView: UIView?) {
        let controller = UIAlertController(
            title: "自定义浏览器标识（UA）",
            message: "选择所有网站使用的默认浏览器标识。",
            preferredStyle: .actionSheet
        )
        controller.addAction(UIAlertAction(title: "默认", style: .default) { [weak self] _ in
            Prefs.CompatibilitySettings.useAndroidUserAgent = false
            self?.tableView.reloadData()
        })
        controller.addAction(UIAlertAction(title: "兼容模式（Android）", style: .default) { [weak self] _ in
            Prefs.CompatibilitySettings.useAndroidUserAgent = true
            self?.tableView.reloadData()
        })
        controller.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if let popover = controller.popoverPresentationController, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(controller, animated: true)
    }
}
