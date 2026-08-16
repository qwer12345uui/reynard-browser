//
//  BrowsingPreferencesViewController.swift
//  Reynard
//
//  Created by Minh Ton on 15/5/26.
//

import UIKit

final class BrowsingPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case previews
        case interaction
        case content
        case external

        var text: SettingsSectionText {
            switch self {
            case .previews:
                return SettingsSectionText(headerTitle: NSLocalizedString("Previews", comment: "Browsing settings section title"))
            case .interaction:
                return SettingsSectionText(
                    headerTitle: "网页手势",
                    footerTitle: "系统键盘或苹果原生手写输入打开时，网页返回和下拉刷新手势会自动暂停，避免抢占笔画触摸。"
                )
            case .content:
                return SettingsSectionText(headerTitle: NSLocalizedString("Content", comment: "Browsing settings section title"))
            case .external:
                return SettingsSectionText()
            }
        }
    }

    private enum PreviewsRow: CaseIterable {
        case showLinkPreviews
        case showImagePreviews
    }

    private enum InteractionRow: CaseIterable {
        case hidesChromeOnScroll
        case historyGestureMode
        case pullToRefresh
        case twoFingerLongPressDismissesKeyboard
    }

    private enum ContentRow: CaseIterable {
        case allWebsites
        case pageZoom
    }

    private enum ExternalAppsRow: CaseIterable {
        case openLinks
    }

    private let showLinkPreviewsSwitch = UISwitch()
    private let showImagePreviewsSwitch = UISwitch()
    private let hidesChromeOnScrollSwitch = UISwitch()
    private let pullToRefreshSwitch = UISwitch()
    private let twoFingerLongPressDismissesKeyboardSwitch = UISwitch()
    private let openLinksInExternalAppsSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = NSLocalizedString("Browsing", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSwitches()
        refreshDisplayedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }

        switch Section.allCases[section] {
        case .previews:
            return PreviewsRow.allCases.count
        case .interaction:
            return InteractionRow.allCases.count
        case .content:
            return ContentRow.allCases.count
        case .external:
            return ExternalAppsRow.allCases.count
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
        case .previews:
            switch PreviewsRow.allCases[indexPath.row] {
            case .showLinkPreviews:
                configureSwitchCell(cell, title: NSLocalizedString("Show Link Previews", comment: ""), control: showLinkPreviewsSwitch)
            case .showImagePreviews:
                configureSwitchCell(cell, title: NSLocalizedString("Show Image Previews", comment: ""), control: showImagePreviewsSwitch)
            }
        case .interaction:
            switch InteractionRow.allCases[indexPath.row] {
            case .hidesChromeOnScroll:
                configureSwitchCell(cell, title: "滑动进入全屏模式", detail: "向下浏览网页时自动收起导航栏", control: hidesChromeOnScrollSwitch)
            case .historyGestureMode:
                cell.textLabel?.text = "网页手势返回"
                cell.detailTextLabel?.text = Prefs.BrowsingSettings.historyGestureMode.localizedTitle
                cell.accessoryType = .disclosureIndicator
            case .pullToRefresh:
                configureSwitchCell(cell, title: "网页下拉刷新", detail: "页面位于顶部时下拉即可重新加载", control: pullToRefreshSwitch)
            case .twoFingerLongPressDismissesKeyboard:
                configureSwitchCell(cell, title: "双指长按关闭键盘", detail: "在网页中双指长按以关闭当前系统键盘", control: twoFingerLongPressDismissesKeyboardSwitch)
            }
        case .content:
            switch ContentRow.allCases[indexPath.row] {
            case .allWebsites:
                cell.textLabel?.text = NSLocalizedString("Request Desktop Website", comment: "")
            case .pageZoom:
                cell.textLabel?.text = NSLocalizedString("Page Zoom", comment: "")
            }
            cell.accessoryType = .disclosureIndicator
        case .external:
            configureSwitchCell(cell, title: NSLocalizedString("Open Links in External Apps", comment: ""), control: openLinksInExternalAppsSwitch)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else {
            return
        }

        switch Section.allCases[indexPath.section] {
        case .previews, .external:
            return
        case .interaction:
            guard InteractionRow.allCases.indices.contains(indexPath.row) else { return }
            if InteractionRow.allCases[indexPath.row] == .historyGestureMode {
                presentHistoryGestureModePicker(from: tableView.cellForRow(at: indexPath))
            }
        case .content:
            guard ContentRow.allCases.indices.contains(indexPath.row) else { return }
            switch ContentRow.allCases[indexPath.row] {
            case .allWebsites:
                navigationController?.pushViewController(RequestDesktopWebsitePreferencesViewController(), animated: true)
            case .pageZoom:
                navigationController?.pushViewController(PageZoomPreferencesViewController(), animated: true)
            }
        }
    }

    private func configureSwitches() {
        showLinkPreviewsSwitch.addTarget(self, action: #selector(showLinkPreviewsSwitchDidChange(_:)), for: .valueChanged)
        showImagePreviewsSwitch.addTarget(self, action: #selector(showImagePreviewsSwitchDidChange(_:)), for: .valueChanged)
        hidesChromeOnScrollSwitch.addTarget(self, action: #selector(hidesChromeOnScrollSwitchDidChange(_:)), for: .valueChanged)
        pullToRefreshSwitch.addTarget(self, action: #selector(pullToRefreshSwitchDidChange(_:)), for: .valueChanged)
        twoFingerLongPressDismissesKeyboardSwitch.addTarget(self, action: #selector(twoFingerLongPressDismissesKeyboardSwitchDidChange(_:)), for: .valueChanged)
        openLinksInExternalAppsSwitch.addTarget(self, action: #selector(openLinksInExternalAppsSwitchDidChange(_:)), for: .valueChanged)
    }

    private func refreshDisplayedState() {
        showLinkPreviewsSwitch.isOn = Prefs.BrowsingSettings.showLinkPreviews
        showImagePreviewsSwitch.isOn = Prefs.BrowsingSettings.showImagePreviews
        hidesChromeOnScrollSwitch.isOn = Prefs.BrowsingSettings.hidesChromeOnScroll
        pullToRefreshSwitch.isOn = Prefs.BrowsingSettings.pullToRefreshEnabled
        twoFingerLongPressDismissesKeyboardSwitch.isOn = Prefs.BrowsingSettings.twoFingerLongPressDismissesKeyboard
        openLinksInExternalAppsSwitch.isOn = Prefs.BrowsingSettings.openLinksInExternalApps
    }

    private func configureSwitchCell(_ cell: UITableViewCell, title: String, detail: String? = nil, control: UISwitch) {
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.selectionStyle = .none
        cell.accessoryView = control
    }

    private func presentHistoryGestureModePicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "网页手势返回", message: "选择从网页触发前进与后退的方式。", preferredStyle: .actionSheet)
        for mode in HistoryGestureMode.allCases {
            controller.addAction(UIAlertAction(title: mode.localizedTitle, style: .default) { [weak self] _ in
                Prefs.BrowsingSettings.historyGestureMode = mode
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

    @objc private func showLinkPreviewsSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.showLinkPreviews = sender.isOn
    }

    @objc private func showImagePreviewsSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.showImagePreviews = sender.isOn
    }

    @objc private func hidesChromeOnScrollSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.hidesChromeOnScroll = sender.isOn
    }

    @objc private func pullToRefreshSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.pullToRefreshEnabled = sender.isOn
    }

    @objc private func twoFingerLongPressDismissesKeyboardSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.twoFingerLongPressDismissesKeyboard = sender.isOn
    }

    @objc private func openLinksInExternalAppsSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.openLinksInExternalApps = sender.isOn
    }
}
