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
        case automaticallyMergeM3U8
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
    private let automaticallyMergeM3U8Switch = UISwitch()
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
        automaticallyMergeM3U8Switch.addTarget(self, action: #selector(automaticallyMergeM3U8DidChange(_:)), for: .valueChanged)
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
            case .automaticallyMergeM3U8:
                configureSwitchCell(cell, title: "m3u8 下载自动合成 MP4", detail: "下载兼容的媒体流时优先请求可保存的视频文件", control: automaticallyMergeM3U8Switch)
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
        automaticallyMergeM3U8Switch.isOn = Prefs.DownloadSettings.automaticallyMergeM3U8
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
    @objc private func automaticallyMergeM3U8DidChange(_ sender: UISwitch) { Prefs.DownloadSettings.automaticallyMergeM3U8 = sender.isOn }
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
        case decoder
        case longPressRate
        case multiplePlayers
        case autoplay
        case gestureSeeking
        case muteByDefault
        case rememberPosition
    }

    private enum BackgroundRow: CaseIterable {
        case pictureInPicture
        case startsPiPOnBackground
        case backgroundPlayback
        case swipeToMiniPlayer
    }

    private enum CustomizationRow: CaseIterable {
        case cornerTriggers
        case playerControls
        case openVideosInNewTab
    }

    private let multiplePlayersSwitch = UISwitch()
    private let autoplaySwitch = UISwitch()
    private let gestureSeekingSwitch = UISwitch()
    private let muteByDefaultSwitch = UISwitch()
    private let rememberPositionSwitch = UISwitch()
    private let pictureInPictureSwitch = UISwitch()
    private let startsPiPOnBackgroundSwitch = UISwitch()
    private let backgroundPlaybackSwitch = UISwitch()
    private let swipeToMiniPlayerSwitch = UISwitch()
    private let openVideosInNewTabSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "播放设置"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        [multiplePlayersSwitch, autoplaySwitch, gestureSeekingSwitch, muteByDefaultSwitch, rememberPositionSwitch, pictureInPictureSwitch, startsPiPOnBackgroundSwitch, backgroundPlaybackSwitch, swipeToMiniPlayerSwitch, openVideosInNewTabSwitch].forEach { $0.addTarget(self, action: #selector(switchDidChange(_:)), for: .valueChanged) }
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
            case .decoder:
                cell.textLabel?.text = "视频解码器"
                cell.detailTextLabel?.text = Prefs.PlaybackSettings.videoDecoder == "automatic" ? "自动" : Prefs.PlaybackSettings.videoDecoder
                cell.accessoryType = .disclosureIndicator
            case .longPressRate:
                cell.textLabel?.text = "长按播放速度"
                cell.detailTextLabel?.text = String(format: "%.1fX", Prefs.PlaybackSettings.longPressPlaybackRate)
                cell.accessoryType = .disclosureIndicator
            case .multiplePlayers:
                configureSwitchCell(cell, title: "播放器多开", detail: "可同时开启多个播放器，边看边找", control: multiplePlayersSwitch)
            case .autoplay:
                configureSwitchCell(cell, title: "网页媒体自动播放", detail: "允许视频和音频自动播放", control: autoplaySwitch)
            case .gestureSeeking:
                configureSwitchCell(cell, title: "手势快进快退", detail: "自适应，由视频时长决定", control: gestureSeekingSwitch)
            case .muteByDefault:
                configureSwitchCell(cell, title: "默认静音播放", detail: "新打开的播放器默认不输出声音", control: muteByDefaultSwitch)
            case .rememberPosition:
                configureSwitchCell(cell, title: "记忆播放", detail: "下次打开时恢复已播放位置", control: rememberPositionSwitch)
            }
        case .background:
            switch BackgroundRow.allCases[indexPath.row] {
            case .pictureInPicture:
                configureSwitchCell(cell, title: "允许系统小窗（画中画）", detail: "允许支持的视频进入系统画中画模式", control: pictureInPictureSwitch)
            case .startsPiPOnBackground:
                configureSwitchCell(cell, title: "切换后台时启用系统小窗模式", detail: "离开应用时尝试将当前视频移入画中画", control: startsPiPOnBackgroundSwitch)
                startsPiPOnBackgroundSwitch.isEnabled = Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled
            case .backgroundPlayback:
                configureSwitchCell(cell, title: "允许后台播放", detail: "支持的网站在后台继续输出媒体音频", control: backgroundPlaybackSwitch)
            case .swipeToMiniPlayer:
                configureSwitchCell(cell, title: "播放器下拉进入小窗口模式", detail: "在支持的播放器中向下拖动进入小窗口", control: swipeToMiniPlayerSwitch)
            }
        case .customization:
            switch CustomizationRow.allCases[indexPath.row] {
            case .cornerTriggers:
                cell.textLabel?.text = "触发角设置"
                cell.detailTextLabel?.text = "拖动播放器到对应区域，触发快捷操作"
                cell.accessoryType = .disclosureIndicator
            case .playerControls:
                cell.textLabel?.text = "播放控制按钮（显示/隐藏）"
                cell.detailTextLabel?.text = "选择是否在播放器上显示控制按钮"
                cell.accessoryType = .disclosureIndicator
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
        case .playback where PlaybackRow.allCases[indexPath.row] == .decoder:
            presentStringPicker(title: "视频解码器", options: [("自动", "automatic")], current: Prefs.PlaybackSettings.videoDecoder, from: tableView.cellForRow(at: indexPath)) { Prefs.PlaybackSettings.videoDecoder = $0 }
        case .playback where PlaybackRow.allCases[indexPath.row] == .longPressRate:
            presentRatePicker(from: tableView.cellForRow(at: indexPath))
        case .customization where CustomizationRow.allCases[indexPath.row] == .cornerTriggers:
            navigationController?.pushViewController(PlayerCornerPreferencesViewController(), animated: true)
        case .customization where CustomizationRow.allCases[indexPath.row] == .playerControls:
            navigationController?.pushViewController(PlayerControlsPreferencesViewController(), animated: true)
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
        gestureSeekingSwitch.isOn = Prefs.PlaybackSettings.allowsGestureSeeking
        muteByDefaultSwitch.isOn = Prefs.PlaybackSettings.mutesByDefault
        rememberPositionSwitch.isOn = Prefs.PlaybackSettings.remembersPlaybackPosition
        pictureInPictureSwitch.isOn = Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled
        startsPiPOnBackgroundSwitch.isOn = Prefs.PlaybackSettings.startsPictureInPictureOnBackground
        backgroundPlaybackSwitch.isOn = Prefs.PlaybackSettings.allowsBackgroundPlayback
        swipeToMiniPlayerSwitch.isOn = Prefs.PlaybackSettings.allowsSwipeToMiniPlayer
        openVideosInNewTabSwitch.isOn = Prefs.PlaybackSettings.openVideosInNewTab
    }

    private func presentRatePicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "长按播放速度", message: nil, preferredStyle: .actionSheet)
        for value in [1.25, 1.5, 1.75, 2.0, 2.5, 3.0] {
            controller.addAction(UIAlertAction(title: String(format: "%.2gX", value), style: .default) { [weak self] _ in
                Prefs.PlaybackSettings.longPressPlaybackRate = value
                self?.tableView.reloadData()
            })
        }
        present(controller, from: sourceView)
    }

    private func presentStringPicker(title: String, options: [(String, String)], current: String, from sourceView: UIView?, completion: @escaping (String) -> Void) {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let suffix = option.1 == current ? "  ✓" : ""
            controller.addAction(UIAlertAction(title: option.0 + suffix, style: .default) { [weak self] _ in
                completion(option.1)
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

    @objc private func switchDidChange(_ sender: UISwitch) {
        if sender === multiplePlayersSwitch {
            Prefs.PlaybackSettings.allowsMultiplePlayers = sender.isOn
        } else if sender === autoplaySwitch {
            Prefs.PlaybackSettings.allowsAutoplay = sender.isOn
        } else if sender === gestureSeekingSwitch {
            Prefs.PlaybackSettings.allowsGestureSeeking = sender.isOn
        } else if sender === muteByDefaultSwitch {
            Prefs.PlaybackSettings.mutesByDefault = sender.isOn
        } else if sender === rememberPositionSwitch {
            Prefs.PlaybackSettings.remembersPlaybackPosition = sender.isOn
        } else if sender === pictureInPictureSwitch {
            Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled = sender.isOn
        } else if sender === startsPiPOnBackgroundSwitch {
            Prefs.PlaybackSettings.startsPictureInPictureOnBackground = sender.isOn
        } else if sender === backgroundPlaybackSwitch {
            Prefs.PlaybackSettings.allowsBackgroundPlayback = sender.isOn
        } else if sender === swipeToMiniPlayerSwitch {
            Prefs.PlaybackSettings.allowsSwipeToMiniPlayer = sender.isOn
        } else if sender === openVideosInNewTabSwitch {
            Prefs.PlaybackSettings.openVideosInNewTab = sender.isOn
        }
        tableView.reloadData()
    }
}

final class PlayerCornerPreferencesViewController: SettingsTableViewController {
    private let rows: [(String, String)] = [
        ("左上角", "topLeftCornerAction"),
        ("右上角", "topRightCornerAction"),
        ("左下角", "bottomLeftCornerAction"),
        ("右下角", "bottomRightCornerAction"),
    ]

    init() { super.init(style: .insetGrouped); title = "触发角设置" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    override func sectionText(for section: Int) -> SettingsSectionText { SettingsSectionText(headerTitle: "播放器拖动触发角", footerTitle: "拖动播放器到对应区域时，将执行选定的快捷操作。") }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard rows.indices.contains(indexPath.row) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let row = rows[indexPath.row]
        cell.textLabel?.text = row.0
        cell.detailTextLabel?.text = Prefs.PlaybackSettings.cornerAction(for: row.1).localizedTitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard rows.indices.contains(indexPath.row) else { return }
        let row = rows[indexPath.row]
        let controller = UIAlertController(title: row.0, message: "选择触发操作", preferredStyle: .actionSheet)
        for action in PlayerCornerAction.allCases {
            controller.addAction(UIAlertAction(title: action.localizedTitle, style: .default) { [weak self] _ in
                Prefs.PlaybackSettings.setCornerAction(action, for: row.1)
                self?.tableView.reloadData()
            })
        }
        controller.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if let popover = controller.popoverPresentationController, let sourceView = tableView.cellForRow(at: indexPath) {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(controller, animated: true)
    }
}

final class PlayerControlsPreferencesViewController: SettingsTableViewController {
    private let rows: [(String, String)] = [
        ("显示播放器控制按钮", "showsPlayerControls"),
        ("音频模式", "showsAudioModeControl"),
        ("分享", "showsShareControl"),
        ("收藏", "showsBookmarkControl"),
        ("投屏", "showsCastControl"),
        ("倒计时", "showsTimerControl"),
        ("上一集", "showsPreviousControl"),
        ("下一集", "showsNextControl"),
        ("快退 15 秒", "showsSeekBackwardControl"),
        ("快进 15 秒", "showsSeekForwardControl"),
        ("定时关闭播放器", "showsSleepTimerControl"),
        ("镜像画面", "showsMirrorControl"),
        ("填充模式", "showsFillModeControl"),
    ]

    init() { super.init(style: .insetGrouped); title = "播放控制按钮" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    override func sectionText(for section: Int) -> SettingsSectionText { SettingsSectionText(headerTitle: "显示/隐藏", footerTitle: "选择是否在支持的播放器上显示这些控制按钮。") }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard rows.indices.contains(indexPath.row) else { return UITableViewCell() }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let row = rows[indexPath.row]
        let toggle = UISwitch()
        toggle.isOn = Prefs.PlaybackSettings.isControlVisible(row.1)
        toggle.accessibilityIdentifier = row.1
        toggle.addTarget(self, action: #selector(controlVisibilityDidChange(_:)), for: .valueChanged)
        cell.textLabel?.text = row.0
        cell.selectionStyle = .none
        cell.accessoryView = toggle
        return cell
    }

    @objc private func controlVisibilityDidChange(_ sender: UISwitch) {
        guard let key = sender.accessibilityIdentifier else { return }
        Prefs.PlaybackSettings.setControlVisible(sender.isOn, key: key)
    }
}
