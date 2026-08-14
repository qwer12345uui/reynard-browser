//
//  DownloadPlaybackPreferencesViewControllers.swift
//  Reynard
//
//  Download and video playback preferences exposed from the downloads menu.
//

import UIKit

final class DownloadPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case downloads
        case retry
        case list
        case storage

        var text: SettingsSectionText {
            switch self {
            case .downloads: return SettingsSectionText(headerTitle: "下载任务")
            case .retry: return SettingsSectionText(headerTitle: "失败重试", footerTitle: "默认失败后最多自动重试 30 次；开启“一直重试”后，网络恢复时会持续重试。")
            case .list: return SettingsSectionText(headerTitle: "下载列表")
            case .storage: return SettingsSectionText(headerTitle: "保存与提醒")
            }
        }
    }

    private enum DownloadRow: CaseIterable {
        case confirmManualDownloads
        case allowsCellularDownloads
    }

    private enum RetryRow: CaseIterable {
        case automaticRetry
        case retryIndefinitely
        case retryCount
    }

    private enum ListRow: CaseIterable {
        case sortOrder
        case concurrency
    }

    private enum StorageRow: CaseIterable {
        case imageSaveLocation
        case automaticallyBookmarkVideos
        case completionSound
        case openDownloadsFolder
    }

    private let confirmManualDownloadsSwitch = UISwitch()
    private let allowsCellularDownloadsSwitch = UISwitch()
    private let automaticRetrySwitch = UISwitch()
    private let retryIndefinitelySwitch = UISwitch()
    private let automaticallyBookmarkVideosSwitch = UISwitch()
    private let completionSoundSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "下载设置"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        confirmManualDownloadsSwitch.addTarget(self, action: #selector(confirmManualDownloadsDidChange(_:)), for: .valueChanged)
        allowsCellularDownloadsSwitch.addTarget(self, action: #selector(allowsCellularDownloadsDidChange(_:)), for: .valueChanged)
        automaticRetrySwitch.addTarget(self, action: #selector(automaticRetryDidChange(_:)), for: .valueChanged)
        retryIndefinitelySwitch.addTarget(self, action: #selector(retryIndefinitelyDidChange(_:)), for: .valueChanged)
        automaticallyBookmarkVideosSwitch.addTarget(self, action: #selector(automaticallyBookmarkVideosDidChange(_:)), for: .valueChanged)
        completionSoundSwitch.addTarget(self, action: #selector(completionSoundDidChange(_:)), for: .valueChanged)
        refreshDisplayedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else { return 0 }
        switch Section.allCases[section] {
        case .downloads: return DownloadRow.allCases.count
        case .retry: return RetryRow.allCases.count
        case .list: return ListRow.allCases.count
        case .storage: return StorageRow.allCases.count
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else { return SettingsSectionText() }
        return Section.allCases[section].text
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel

        switch Section.allCases[indexPath.section] {
        case .downloads:
            switch DownloadRow.allCases[indexPath.row] {
            case .confirmManualDownloads:
                configureSwitchCell(cell, title: "确认新建下载任务", detail: "手动添加下载链接前显示确认", control: confirmManualDownloadsSwitch)
            case .allowsCellularDownloads:
                configureSwitchCell(cell, title: "允许移动网络下载", detail: "允许在蜂窝数据网络下创建新下载", control: allowsCellularDownloadsSwitch)
            }
        case .retry:
            switch RetryRow.allCases[indexPath.row] {
            case .automaticRetry:
                configureSwitchCell(cell, title: "失败后自动重试", detail: "下载因临时网络错误失败后自动重新尝试", control: automaticRetrySwitch)
            case .retryIndefinitely:
                configureSwitchCell(cell, title: "一直自动重试", detail: "开启后忽略重试次数，直到下载成功或手动取消", control: retryIndefinitelySwitch)
                retryIndefinitelySwitch.isEnabled = Prefs.DownloadSettings.automaticRetryEnabled
            case .retryCount:
                cell.textLabel?.text = "自动重试次数"
                cell.detailTextLabel?.text = "\(Prefs.DownloadSettings.maximumRetryCount) 次"
                cell.accessoryType = .disclosureIndicator
                cell.isUserInteractionEnabled = Prefs.DownloadSettings.automaticRetryEnabled && !Prefs.DownloadSettings.retryIndefinitely
                cell.textLabel?.textColor = cell.isUserInteractionEnabled ? .label : .secondaryLabel
            }
        case .list:
            switch ListRow.allCases[indexPath.row] {
            case .sortOrder:
                cell.textLabel?.text = "下载列表排序"
                cell.detailTextLabel?.text = Prefs.DownloadSettings.sortOrder.localizedTitle
                cell.accessoryType = .disclosureIndicator
            case .concurrency:
                cell.textLabel?.text = "下载并发数"
                cell.detailTextLabel?.text = "系统与 App 最多同时下载 \(Prefs.DownloadSettings.maximumConcurrentDownloads) 个任务"
                cell.accessoryType = .disclosureIndicator
            }
        case .storage:
            switch StorageRow.allCases[indexPath.row] {
            case .imageSaveLocation:
                cell.textLabel?.text = "图片保存位置"
                cell.detailTextLabel?.text = Prefs.DownloadSettings.imageSaveLocation.localizedTitle
                cell.accessoryType = .disclosureIndicator
            case .automaticallyBookmarkVideos:
                configureSwitchCell(cell, title: "自动加入收藏列表", detail: "将下载的视频网页自动添加到收藏列表", control: automaticallyBookmarkVideosSwitch)
            case .completionSound:
                configureSwitchCell(cell, title: "下载完成提示音", detail: "单个下载任务完成时播放系统提示音", control: completionSoundSwitch)
            case .openDownloadsFolder:
                cell.textLabel?.text = "打开下载文件夹"
                cell.detailTextLabel?.text = DownloadStore.shared.downloadsDirectory().lastPathComponent
                cell.accessoryType = .disclosureIndicator
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else { return }
        switch Section.allCases[indexPath.section] {
        case .retry where RetryRow.allCases[indexPath.row] == .retryCount:
            guard Prefs.DownloadSettings.automaticRetryEnabled, !Prefs.DownloadSettings.retryIndefinitely else { return }
            presentChoicePicker(title: "自动重试次数", values: [0, 5, 10, 30, 50, 99], current: Prefs.DownloadSettings.maximumRetryCount, from: tableView.cellForRow(at: indexPath)) { value in
                Prefs.DownloadSettings.maximumRetryCount = value
            }
        case .list where ListRow.allCases[indexPath.row] == .sortOrder:
            presentSortPicker(from: tableView.cellForRow(at: indexPath))
        case .list where ListRow.allCases[indexPath.row] == .concurrency:
            presentChoicePicker(title: "下载并发数", values: Array(1...8), current: Prefs.DownloadSettings.maximumConcurrentDownloads, from: tableView.cellForRow(at: indexPath)) { value in
                Prefs.DownloadSettings.maximumConcurrentDownloads = value
            }
        case .storage where StorageRow.allCases[indexPath.row] == .imageSaveLocation:
            presentImageLocationPicker(from: tableView.cellForRow(at: indexPath))
        case .storage where StorageRow.allCases[indexPath.row] == .openDownloadsFolder:
            let url = DownloadStore.shared.downloadsDirectory()
            let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            guard let filesURL = URL(string: "shareddocuments://\(encodedPath)") else { return }
            UIApplication.shared.open(filesURL, options: [:], completionHandler: nil)
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

    private func refreshDisplayedState() {
        confirmManualDownloadsSwitch.isOn = Prefs.DownloadSettings.confirmManualDownloads
        allowsCellularDownloadsSwitch.isOn = Prefs.DownloadSettings.allowsCellularDownloads
        automaticRetrySwitch.isOn = Prefs.DownloadSettings.automaticRetryEnabled
        retryIndefinitelySwitch.isOn = Prefs.DownloadSettings.retryIndefinitely
        automaticallyBookmarkVideosSwitch.isOn = Prefs.DownloadSettings.automaticallyBookmarkDownloadedVideos
        completionSoundSwitch.isOn = Prefs.DownloadSettings.playsCompletionSound
    }

    private func presentSortPicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "下载列表排序", message: nil, preferredStyle: .actionSheet)
        for order in DownloadSortOrder.allCases {
            controller.addAction(UIAlertAction(title: order.localizedTitle, style: .default) { [weak self] _ in
                Prefs.DownloadSettings.sortOrder = order
                self?.tableView.reloadData()
            })
        }
        present(controller, from: sourceView)
    }

    private func presentImageLocationPicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "图片保存位置", message: nil, preferredStyle: .actionSheet)
        for location in ImageSaveLocation.allCases {
            controller.addAction(UIAlertAction(title: location.localizedTitle, style: .default) { [weak self] _ in
                Prefs.DownloadSettings.imageSaveLocation = location
                self?.tableView.reloadData()
            })
        }
        present(controller, from: sourceView)
    }

    private func presentChoicePicker(title: String, values: [Int], current: Int, from sourceView: UIView?, completion: @escaping (Int) -> Void) {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for value in values {
            let suffix = value == current ? "  ✓" : ""
            controller.addAction(UIAlertAction(title: "\(value)\(suffix)", style: .default) { [weak self] _ in
                completion(value)
                self?.tableView.reloadData()
            })
        }
        present(controller, from: sourceView)
    }

    private func present(_ controller: UIAlertController, from sourceView: UIView?) {
        controller.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if let popover = controller.popoverPresentationController, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(controller, animated: true)
    }

    @objc private func confirmManualDownloadsDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.confirmManualDownloads = sender.isOn }
    @objc private func allowsCellularDownloadsDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.allowsCellularDownloads = sender.isOn }
    @objc private func automaticRetryDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.automaticRetryEnabled = sender.isOn; tableView.reloadData() }
    @objc private func retryIndefinitelyDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.retryIndefinitely = sender.isOn; tableView.reloadData() }
    @objc private func automaticallyBookmarkVideosDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.automaticallyBookmarkDownloadedVideos = sender.isOn }
    @objc private func completionSoundDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.playsCompletionSound = sender.isOn }
}

final class PlaybackPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case playback
        case background
        case customization

        var text: SettingsSectionText {
            switch self {
            case .playback: return SettingsSectionText(headerTitle: "播放设置")
            case .background: return SettingsSectionText(headerTitle: "后台与小窗")
            case .customization: return SettingsSectionText(headerTitle: "播放器自定义")
            }
        }
    }

    private enum PlaybackRow: CaseIterable {
        case multiplePlayers
        case autoplay
    }

    private enum BackgroundRow: CaseIterable {
        case pictureInPicture
        case startsPiPOnBackground
        case backgroundPlayback
    }

    private enum CustomizationRow: CaseIterable {
        case openVideosInNewTab
    }

    private let multiplePlayersSwitch = UISwitch()
    private let autoplaySwitch = UISwitch()
    private let pictureInPictureSwitch = UISwitch()
    private let startsPiPOnBackgroundSwitch = UISwitch()
    private let backgroundPlaybackSwitch = UISwitch()
    private let openVideosInNewTabSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "播放设置"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        [multiplePlayersSwitch, autoplaySwitch, pictureInPictureSwitch, startsPiPOnBackgroundSwitch, backgroundPlaybackSwitch, openVideosInNewTabSwitch].forEach { $0.addTarget(self, action: #selector(switchDidChange(_:)), for: .valueChanged) }
        refreshDisplayedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else { return 0 }
        switch Section.allCases[section] {
        case .playback: return PlaybackRow.allCases.count
        case .background: return BackgroundRow.allCases.count
        case .customization: return CustomizationRow.allCases.count
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        guard Section.allCases.indices.contains(section) else { return SettingsSectionText() }
        return Section.allCases[section].text
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section.allCases.indices.contains(indexPath.section) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel

        switch Section.allCases[indexPath.section] {
        case .playback:
            switch PlaybackRow.allCases[indexPath.row] {
            case .multiplePlayers:
                configureSwitchCell(cell, title: "播放器多开", detail: "与“新标签页中打开视频”同时开启时，可使用多个标签页并行播放", control: multiplePlayersSwitch)
            case .autoplay:
                configureSwitchCell(cell, title: "网页媒体自动播放", detail: "允许视频和音频自动播放；网站的单独权限仍优先生效", control: autoplaySwitch)
            }
        case .background:
            switch BackgroundRow.allCases[indexPath.row] {
            case .pictureInPicture:
                configureSwitchCell(cell, title: "允许系统小窗（画中画）", detail: "允许支持的视频进入系统画中画模式", control: pictureInPictureSwitch)
            case .startsPiPOnBackground:
                configureSwitchCell(cell, title: "切换后台时启用系统小窗模式", detail: "离开应用时尝试将当前视频移入画中画", control: startsPiPOnBackgroundSwitch)
                startsPiPOnBackgroundSwitch.isEnabled = Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled
            case .backgroundPlayback:
                configureSwitchCell(cell, title: "允许后台播放", detail: "支持的网站在系统允许时继续输出媒体音频", control: backgroundPlaybackSwitch)
            }
        case .customization:
            switch CustomizationRow.allCases[indexPath.row] {
            case .openVideosInNewTab:
                configureSwitchCell(cell, title: "新标签页中打开视频", detail: "保持当前网页不变并启动视频播放", control: openVideosInNewTabSwitch)
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else { return }
        switch Section.allCases[indexPath.section] {
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

    private func refreshDisplayedState() {
        multiplePlayersSwitch.isOn = Prefs.PlaybackSettings.allowsMultiplePlayers
        autoplaySwitch.isOn = Prefs.PlaybackSettings.allowsAutoplay
        pictureInPictureSwitch.isOn = Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled
        startsPiPOnBackgroundSwitch.isOn = Prefs.PlaybackSettings.startsPictureInPictureOnBackground
        backgroundPlaybackSwitch.isOn = Prefs.PlaybackSettings.allowsBackgroundPlayback
        openVideosInNewTabSwitch.isOn = Prefs.PlaybackSettings.openVideosInNewTab
    }

    @objc private func switchDidChange(_ sender: UISwitch) {
        if sender === multiplePlayersSwitch {
            Prefs.PlaybackSettings.allowsMultiplePlayers = sender.isOn
        } else if sender === autoplaySwitch {
            Prefs.PlaybackSettings.allowsAutoplay = sender.isOn
        } else if sender === pictureInPictureSwitch {
            Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled = sender.isOn
        } else if sender === startsPiPOnBackgroundSwitch {
            Prefs.PlaybackSettings.startsPictureInPictureOnBackground = sender.isOn
        } else if sender === backgroundPlaybackSwitch {
            Prefs.PlaybackSettings.allowsBackgroundPlayback = sender.isOn
        } else if sender === openVideosInNewTabSwitch {
            Prefs.PlaybackSettings.openVideosInNewTab = sender.isOn
        }
        tableView.reloadData()
    }
}
