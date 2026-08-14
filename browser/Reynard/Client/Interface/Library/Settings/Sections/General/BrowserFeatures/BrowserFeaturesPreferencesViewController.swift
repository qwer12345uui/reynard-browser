//
//  BrowserFeaturesPreferencesViewController.swift
//  Reynard
//
//  Browser-wide behavior preferences exposed from General settings.
//

import UIKit

final class BrowserFeaturesPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case browser
        case downloads
        case toolbar
        case clipboard

        var text: SettingsSectionText {
            switch self {
            case .browser:
                return SettingsSectionText(headerTitle: "浏览器功能")
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

    private enum BrowserRow: CaseIterable {
        case backgroundBlur
        case keepScreenAwake
        case networkSpeedOverlay
        case touchFeedback
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

    private let backgroundBlurSwitch = UISwitch()
    private let keepScreenAwakeSwitch = UISwitch()
    private let networkSpeedOverlaySwitch = UISwitch()
    private let touchFeedbackSwitch = UISwitch()
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
        backgroundBlurSwitch.addTarget(self, action: #selector(backgroundBlurDidChange(_:)), for: .valueChanged)
        keepScreenAwakeSwitch.addTarget(self, action: #selector(keepScreenAwakeDidChange(_:)), for: .valueChanged)
        networkSpeedOverlaySwitch.addTarget(self, action: #selector(networkSpeedOverlayDidChange(_:)), for: .valueChanged)
        touchFeedbackSwitch.addTarget(self, action: #selector(touchFeedbackDidChange(_:)), for: .valueChanged)
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
        case .browser: return BrowserRow.allCases.count
        case .downloads: return DownloadRow.allCases.count
        case .toolbar: return ToolbarRow.allCases.count
        case .clipboard: return ClipboardRow.allCases.count
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
        case .browser:
            switch BrowserRow.allCases[indexPath.row] {
            case .backgroundBlur:
                configureSwitchCell(cell, title: "后台模糊遮罩", detail: "应用切换到后台时隐藏网页内容", control: backgroundBlurSwitch)
            case .keepScreenAwake:
                configureSwitchCell(cell, title: "保持屏幕常亮", detail: "浏览器使用期间禁止系统自动锁屏", control: keepScreenAwakeSwitch)
            case .networkSpeedOverlay:
                configureSwitchCell(cell, title: "网速浮窗", detail: "显示设备网卡的实时网络速率", control: networkSpeedOverlaySwitch)
            case .touchFeedback:
                configureSwitchCell(cell, title: "触控反馈", detail: "手势返回、下拉刷新等操作提供轻微震动", control: touchFeedbackSwitch)
            }
        case .downloads:
            switch DownloadRow.allCases[indexPath.row] {
            case .continuesInBackground:
                configureSwitchCell(cell, title: "允许后台下载", detail: "有下载任务时保持传输，直到时间用尽或系统回收资源", control: continuesInBackgroundSwitch)
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
                configureSwitchCell(cell, title: "长按快捷操作", detail: "长按底部按钮显示相关快捷操作", control: longPressQuickActionsSwitch)
            }
        case .clipboard:
            configureSwitchCell(cell, title: "自动解析剪切板网址", detail: "仅识别 HTTP 与 HTTPS 链接，不会自动打开", control: automaticallyParseURLsSwitch)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else {
            return
        }
        switch Section.allCases[indexPath.section] {
        case .downloads where DownloadRow.allCases[indexPath.row] == .timeLimit:
            presentBackgroundTimeLimitPicker(from: tableView.cellForRow(at: indexPath))
        case .toolbar where ToolbarRow.allCases[indexPath.row] == .buttonOrder:
            navigationController?.pushViewController(BottomToolbarOrderPreferencesViewController(), animated: true)
        default:
            break
        }
    }

    private func configureSwitchCell(_ cell: UITableViewCell, title: String, detail: String, control: UISwitch) {
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.selectionStyle = .none
        cell.accessoryView = control
    }

    private var formattedBackgroundTimeLimit: String {
        let seconds = Int(Prefs.DownloadSettings.backgroundTimeLimit)
        switch seconds {
        case 0: return "立即暂停"
        case 60: return "1 分钟"
        default: return "\(seconds / 60) 分钟"
        }
    }

    private func refreshDisplayedState() {
        backgroundBlurSwitch.isOn = Prefs.BrowserFeatureSettings.usesBackgroundBlur
        keepScreenAwakeSwitch.isOn = Prefs.BrowserFeatureSettings.keepsScreenAwake
        networkSpeedOverlaySwitch.isOn = Prefs.BrowserFeatureSettings.showsNetworkSpeedOverlay
        touchFeedbackSwitch.isOn = Prefs.BrowserFeatureSettings.touchFeedbackEnabled
        continuesInBackgroundSwitch.isOn = Prefs.DownloadSettings.continuesInBackground
        longPressQuickActionsSwitch.isOn = Prefs.ToolbarSettings.longPressQuickActions
        automaticallyParseURLsSwitch.isOn = Prefs.ClipboardSettings.automaticallyParseURLs
    }

    private func presentBackgroundTimeLimitPicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "后台运行时间", message: "系统可在任意时刻提前结束后台执行。", preferredStyle: .actionSheet)
        let options: [(String, TimeInterval)] = [("立即暂停", 0), ("1 分钟", 60), ("5 分钟", 300), ("10 分钟", 600), ("30 分钟", 1_800)]
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

    @objc private func backgroundBlurDidChange(_ sender: UISwitch) { Prefs.BrowserFeatureSettings.usesBackgroundBlur = sender.isOn }
    @objc private func keepScreenAwakeDidChange(_ sender: UISwitch) { Prefs.BrowserFeatureSettings.keepsScreenAwake = sender.isOn }
    @objc private func networkSpeedOverlayDidChange(_ sender: UISwitch) { Prefs.BrowserFeatureSettings.showsNetworkSpeedOverlay = sender.isOn }
    @objc private func touchFeedbackDidChange(_ sender: UISwitch) { Prefs.BrowserFeatureSettings.touchFeedbackEnabled = sender.isOn }
    @objc private func continuesInBackgroundDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.continuesInBackground = sender.isOn; tableView.reloadData() }
    @objc private func longPressQuickActionsDidChange(_ sender: UISwitch) { Prefs.ToolbarSettings.longPressQuickActions = sender.isOn }
    @objc private func automaticallyParseURLsDidChange(_ sender: UISwitch) { Prefs.ClipboardSettings.automaticallyParseURLs = sender.isOn; Prefs.ClipboardSettings.lastHandledChangeCount = UIPasteboard.general.changeCount }
}

final class BottomToolbarOrderPreferencesViewController: SettingsTableViewController {
    private var order = Prefs.ToolbarSettings.bottomButtonOrder

    private let titles: [String: String] = [
        "back": "后退", "forward": "前进", "share": "分享", "basket": "收纳框", "downloads": "下载管理", "tabs": "多窗口",
    ]

    init() {
        super.init(style: .insetGrouped)
        title = "按钮排序"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { order.count }
    override func sectionText(for section: Int) -> SettingsSectionText {
        SettingsSectionText(headerTitle: "显示顺序", footerTitle: "按住右侧排序控制并拖动。更改会立即应用到底部地址栏按钮。")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard order.indices.contains(indexPath.row) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = titles[order[indexPath.row]] ?? order[indexPath.row]
        cell.showsReorderControl = true
        return cell
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
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
