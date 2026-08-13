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
        case network
        case automation
        case storage

        var text: SettingsSectionText {
            switch self {
            case .downloads:
                return SettingsSectionText(headerTitle: "下载设置")
            case .network:
                return SettingsSectionText(headerTitle: "网络与并发")
            case .automation:
                return SettingsSectionText(
                    headerTitle: "自动化",
                    footerTitle: "失败后会按设定次数自动重试；开启“一直自动重试”后将不再受次数限制。"
                )
            case .storage:
                return SettingsSectionText(headerTitle: "存储")
            }
        }
    }

    private enum DownloadRow: CaseIterable {
        case confirmManualDownloads
        case listSortOrder
        case automaticallyMergeM3U8ToMP4
        case autoBookmarkDownloadedVideos
        case playsCompletionSound
    }

    private enum NetworkRow: CaseIterable {
        case maxConcurrentDownloads
        case allowsCellularDownloads
    }

    private enum AutomationRow: CaseIterable {
        case automaticRetryCount
        case retryIndefinitely
    }

    private enum StorageRow: CaseIterable {
        case imageSaveLocation
        case openDownloadsFolder
    }

    private let confirmManualDownloadsSwitch = UISwitch()
    private let mergeM3U8Switch = UISwitch()
    private let autoBookmarkVideosSwitch = UISwitch()
    private let completionSoundSwitch = UISwitch()
    private let cellularDownloadsSwitch = UISwitch()
    private let retryIndefinitelySwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "下载设置"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        confirmManualDownloadsSwitch.addTarget(self, action: #selector(confirmManualDownloadsDidChange(_:)), for: .valueChanged)
        mergeM3U8Switch.addTarget(self, action: #selector(mergeM3U8DidChange(_:)), for: .valueChanged)
        autoBookmarkVideosSwitch.addTarget(self, action: #selector(autoBookmarkVideosDidChange(_:)), for: .valueChanged)
        completionSoundSwitch.addTarget(self, action: #selector(completionSoundDidChange(_:)), for: .valueChanged)
        cellularDownloadsSwitch.addTarget(self, action: #selector(cellularDownloadsDidChange(_:)), for: .valueChanged)
        retryIndefinitelySwitch.addTarget(self, action: #selector(retryIndefinitelyDidChange(_:)), for: .valueChanged)
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
        guard Section.allCases.indices.contains(section) else { return 0 }
        switch Section.allCases[section] {
        case .downloads: return DownloadRow.allCases.count
        case .network: return NetworkRow.allCases.count
        case .automation: return AutomationRow.allCases.count
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
            guard DownloadRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch DownloadRow.allCases[indexPath.row] {
            case .confirmManualDownloads:
                configureSwitchCell(cell, title: "确认新下载", detail: "手动新增下载任务前请求确认", toggle: confirmManualDownloadsSwitch)
            case .listSortOrder:
                configureDisclosureCell(cell, title: "下载列表排序", detail: title(for: Prefs.DownloadSettings.listSortOrder))
            case .automaticallyMergeM3U8ToMP4:
                configureSwitchCell(cell, title: "m3u8 下载自动合成 MP4", detail: "下载完成后尝试输出通用 MP4 文件", toggle: mergeM3U8Switch)
            case .autoBookmarkDownloadedVideos:
                configureSwitchCell(cell, title: "自动加入收藏列表", detail: "将下载的视频网页自动加入收藏列表", toggle: autoBookmarkVideosSwitch)
            case .playsCompletionSound:
                configureSwitchCell(cell, title: "下载完成提示音", detail: "下载任务完成时播放系统提示音", toggle: completionSoundSwitch)
            }
        case .network:
            guard NetworkRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch NetworkRow.allCases[indexPath.row] {
            case .maxConcurrentDownloads:
                configureDisclosureCell(cell, title: "下载并发数", detail: "同时下载最多 \(Prefs.DownloadSettings.maxConcurrentDownloads) 个任务")
            case .allowsCellularDownloads:
                configureSwitchCell(cell, title: "允许移动网络下载", detail: "允许使用蜂窝移动数据传输下载任务", toggle: cellularDownloadsSwitch)
            }
        case .automation:
            guard AutomationRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch AutomationRow.allCases[indexPath.row] {
            case .automaticRetryCount:
                let value = Prefs.DownloadSettings.automaticRetryCount
                configureDisclosureCell(cell, title: "默认自动重试", detail: value == 0 ? "不自动重试" : "失败后自动重试 \(value) 次")
                cell.isUserInteractionEnabled = !Prefs.DownloadSettings.retryIndefinitely
                cell.textLabel?.textColor = cell.isUserInteractionEnabled ? .label : .secondaryLabel
            case .retryIndefinitely:
                configureSwitchCell(cell, title: "失败后一直自动重试", detail: "开启后将持续重试，直到任务成功或手动取消", toggle: retryIndefinitelySwitch)
            }
        case .storage:
            guard StorageRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch StorageRow.allCases[indexPath.row] {
            case .imageSaveLocation:
                configureDisclosureCell(cell, title: "图片保存位置", detail: title(for: Prefs.DownloadSettings.imageSaveLocation))
            case .openDownloadsFolder:
                configureDisclosureCell(cell, title: "打开下载文件夹", detail: DownloadStore.shared.downloadsDirectory().lastPathComponent)
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else { return }
        switch Section.allCases[indexPath.section] {
        case .downloads where DownloadRow.allCases.indices.contains(indexPath.row):
            if DownloadRow.allCases[indexPath.row] == .listSortOrder {
                presentChoicePicker(title: "下载列表排序", sourceView: tableView.cellForRow(at: indexPath), options: DownloadListSortOrder.allCases, selected: Prefs.DownloadSettings.listSortOrder, title: title(for:)) { value in
                    Prefs.DownloadSettings.listSortOrder = value
                    self.tableView.reloadData()
                }
            }
        case .network where NetworkRow.allCases.indices.contains(indexPath.row):
            if NetworkRow.allCases[indexPath.row] == .maxConcurrentDownloads {
                presentConcurrentDownloadsPicker(from: tableView.cellForRow(at: indexPath))
            }
        case .automation where AutomationRow.allCases.indices.contains(indexPath.row):
            if AutomationRow.allCases[indexPath.row] == .automaticRetryCount, !Prefs.DownloadSettings.retryIndefinitely {
                presentRetryCountPicker(from: tableView.cellForRow(at: indexPath))
            }
        case .storage where StorageRow.allCases.indices.contains(indexPath.row):
            switch StorageRow.allCases[indexPath.row] {
            case .imageSaveLocation:
                presentChoicePicker(title: "图片保存位置", sourceView: tableView.cellForRow(at: indexPath), options: ImageSaveLocation.allCases, selected: Prefs.DownloadSettings.imageSaveLocation, title: title(for:)) { value in
                    Prefs.DownloadSettings.imageSaveLocation = value
                    self.tableView.reloadData()
                }
            case .openDownloadsFolder:
                openDownloadsFolder()
            }
        default:
            break
        }
    }

    private func configureSwitchCell(_ cell: UITableViewCell, title: String, detail: String, toggle: UISwitch) {
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.selectionStyle = .none
        cell.accessoryView = toggle
    }

    private func configureDisclosureCell(_ cell: UITableViewCell, title: String, detail: String) {
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.accessoryType = .disclosureIndicator
    }

    private func refreshDisplayedState() {
        confirmManualDownloadsSwitch.isOn = Prefs.DownloadSettings.confirmManualDownloads
        mergeM3U8Switch.isOn = Prefs.DownloadSettings.automaticallyMergeM3U8ToMP4
        autoBookmarkVideosSwitch.isOn = Prefs.DownloadSettings.autoBookmarkDownloadedVideos
        completionSoundSwitch.isOn = Prefs.DownloadSettings.playsCompletionSound
        cellularDownloadsSwitch.isOn = Prefs.DownloadSettings.allowsCellularDownloads
        retryIndefinitelySwitch.isOn = Prefs.DownloadSettings.retryIndefinitely
    }

    private func openDownloadsFolder() {
        let url = DownloadStore.shared.downloadsDirectory()
        let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        guard let filesURL = URL(string: "shareddocuments://\(encodedPath)") else { return }
        UIApplication.shared.open(filesURL, options: [:], completionHandler: nil)
    }

    private func presentConcurrentDownloadsPicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "下载并发数", message: "同时运行的下载任务数量。", preferredStyle: .actionSheet)
        for value in 1...8 {
            controller.addAction(UIAlertAction(title: "\(value) 个任务", style: .default) { [weak self] _ in
                Prefs.DownloadSettings.maxConcurrentDownloads = value
                self?.tableView.reloadData()
            })
        }
        present(controller, from: sourceView)
    }

    private func presentRetryCountPicker(from sourceView: UIView?) {
        let controller = UIAlertController(title: "默认自动重试", message: "下载失败后的最大自动重试次数。", preferredStyle: .actionSheet)
        for value in [0, 3, 10, 30, 50, 100] {
            let title = value == 0 ? "不自动重试" : "重试 \(value) 次"
            controller.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                Prefs.DownloadSettings.automaticRetryCount = value
                self?.tableView.reloadData()
            })
        }
        present(controller, from: sourceView)
    }

    private func presentChoicePicker<T: CaseIterable & Equatable>(
        title: String,
        sourceView: UIView?,
        options: T.AllCases,
        selected: T,
        title titleProvider: @escaping (T) -> String,
        selection: @escaping (T) -> Void
    ) where T.AllCases: RandomAccessCollection {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let prefix = option == selected ? "✓ " : ""
            controller.addAction(UIAlertAction(title: prefix + titleProvider(option), style: .default) { _ in selection(option) })
        }
        present(controller, from: sourceView)
    }

    private func present(_ controller: UIAlertController, from sourceView: UIView?) {
        controller.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = controller.popoverPresentationController, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(controller, animated: true)
    }

    private func title(for order: DownloadListSortOrder) -> String {
        switch order {
        case .newestFirst: return "最近添加的靠前"
        case .oldestFirst: return "最早添加的靠前"
        case .fileName: return "按文件名"
        }
    }

    private func title(for location: ImageSaveLocation) -> String {
        switch location {
        case .downloads: return "下载文件夹"
        case .photoLibrary: return "系统相册"
        }
    }

    @objc private func confirmManualDownloadsDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.confirmManualDownloads = sender.isOn }
    @objc private func mergeM3U8DidChange(_ sender: UISwitch) { Prefs.DownloadSettings.automaticallyMergeM3U8ToMP4 = sender.isOn }
    @objc private func autoBookmarkVideosDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.autoBookmarkDownloadedVideos = sender.isOn }
    @objc private func completionSoundDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.playsCompletionSound = sender.isOn }
    @objc private func cellularDownloadsDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.allowsCellularDownloads = sender.isOn }
    @objc private func retryIndefinitelyDidChange(_ sender: UISwitch) { Prefs.DownloadSettings.retryIndefinitely = sender.isOn; tableView.reloadData() }
}

final class PlaybackPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case decoder
        case playback
        case systemIntegration
        case interface

        var text: SettingsSectionText {
            switch self {
            case .decoder: return SettingsSectionText(headerTitle: "解码与手势")
            case .playback: return SettingsSectionText(headerTitle: "播放行为")
            case .systemIntegration: return SettingsSectionText(headerTitle: "系统集成")
            case .interface: return SettingsSectionText(headerTitle: "播放器界面")
            }
        }
    }

    private enum DecoderRow: CaseIterable {
        case videoDecoder
        case longPressPlaybackSpeed
        case seekGesture
    }

    private enum PlaybackRow: CaseIterable {
        case openVideosInNewTab
        case allowsMultiplePlayers
        case allowsWebMediaAutoplay
        case allowsBackgroundPlayback
        case mutesByDefault
        case remembersPlaybackPosition
    }

    private enum SystemRow: CaseIterable {
        case pictureInPicture
        case entersPictureInPictureInBackground
    }

    private enum InterfaceRow: CaseIterable {
        case swipeDownEntersMiniPlayer
        case triggerCorner
        case showsControls
    }

    private let openVideosInNewTabSwitch = UISwitch()
    private let multiplePlayersSwitch = UISwitch()
    private let autoplaySwitch = UISwitch()
    private let backgroundPlaybackSwitch = UISwitch()
    private let muteByDefaultSwitch = UISwitch()
    private let rememberPositionSwitch = UISwitch()
    private let pictureInPictureSwitch = UISwitch()
    private let backgroundPictureInPictureSwitch = UISwitch()
    private let swipeDownMiniPlayerSwitch = UISwitch()
    private let showsControlsSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "播放设置"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        openVideosInNewTabSwitch.addTarget(self, action: #selector(openVideosInNewTabDidChange(_:)), for: .valueChanged)
        multiplePlayersSwitch.addTarget(self, action: #selector(multiplePlayersDidChange(_:)), for: .valueChanged)
        autoplaySwitch.addTarget(self, action: #selector(autoplayDidChange(_:)), for: .valueChanged)
        backgroundPlaybackSwitch.addTarget(self, action: #selector(backgroundPlaybackDidChange(_:)), for: .valueChanged)
        muteByDefaultSwitch.addTarget(self, action: #selector(muteByDefaultDidChange(_:)), for: .valueChanged)
        rememberPositionSwitch.addTarget(self, action: #selector(rememberPositionDidChange(_:)), for: .valueChanged)
        pictureInPictureSwitch.addTarget(self, action: #selector(pictureInPictureDidChange(_:)), for: .valueChanged)
        backgroundPictureInPictureSwitch.addTarget(self, action: #selector(backgroundPictureInPictureDidChange(_:)), for: .valueChanged)
        swipeDownMiniPlayerSwitch.addTarget(self, action: #selector(swipeDownMiniPlayerDidChange(_:)), for: .valueChanged)
        showsControlsSwitch.addTarget(self, action: #selector(showsControlsDidChange(_:)), for: .valueChanged)
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
        case .decoder: return DecoderRow.allCases.count
        case .playback: return PlaybackRow.allCases.count
        case .systemIntegration: return SystemRow.allCases.count
        case .interface: return InterfaceRow.allCases.count
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
        case .decoder:
            guard DecoderRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch DecoderRow.allCases[indexPath.row] {
            case .videoDecoder:
                configureDisclosureCell(cell, title: "视频解码器", detail: title(for: Prefs.PlaybackSettings.videoDecoder))
            case .longPressPlaybackSpeed:
                configureDisclosureCell(cell, title: "长按播放速度", detail: "\(Prefs.PlaybackSettings.longPressPlaybackSpeed.rawValue, specifier: "%.1f")X")
            case .seekGesture:
                configureDisclosureCell(cell, title: "手势快进快退", detail: title(for: Prefs.PlaybackSettings.seekGesture))
            }
        case .playback:
            guard PlaybackRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch PlaybackRow.allCases[indexPath.row] {
            case .openVideosInNewTab:
                configureSwitchCell(cell, title: "在新标签页播放视频", detail: "保留当前页面并在新标签页开始播放", toggle: openVideosInNewTabSwitch)
            case .allowsMultiplePlayers:
                configureSwitchCell(cell, title: "播放器多开", detail: "可同时开启多个播放器，边看边找，无心理负担", toggle: multiplePlayersSwitch)
            case .allowsWebMediaAutoplay:
                configureSwitchCell(cell, title: "网页媒体自动播放", detail: "允许视频和音频自动播放", toggle: autoplaySwitch)
            case .allowsBackgroundPlayback:
                configureSwitchCell(cell, title: "允许后台播放", detail: "切换到后台后继续播放支持的媒体", toggle: backgroundPlaybackSwitch)
            case .mutesByDefault:
                configureSwitchCell(cell, title: "默认静音播放", detail: "新打开的媒体默认关闭声音", toggle: muteByDefaultSwitch)
            case .remembersPlaybackPosition:
                configureSwitchCell(cell, title: "记忆播放", detail: "下次打开时恢复上次播放位置", toggle: rememberPositionSwitch)
            }
        case .systemIntegration:
            guard SystemRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch SystemRow.allCases[indexPath.row] {
            case .pictureInPicture:
                configureSwitchCell(cell, title: "允许系统小窗（画中画）", detail: "允许支持的视频在系统小窗中继续播放", toggle: pictureInPictureSwitch)
            case .entersPictureInPictureInBackground:
                configureSwitchCell(cell, title: "切换后台时启用系统小窗模式", detail: "离开应用时优先进入画中画", toggle: backgroundPictureInPictureSwitch)
                cell.isUserInteractionEnabled = Prefs.PlaybackSettings.allowsPictureInPicture
                cell.textLabel?.textColor = cell.isUserInteractionEnabled ? .label : .secondaryLabel
            }
        case .interface:
            guard InterfaceRow.allCases.indices.contains(indexPath.row) else { return cell }
            switch InterfaceRow.allCases[indexPath.row] {
            case .swipeDownEntersMiniPlayer:
                configureSwitchCell(cell, title: "播放器下拉进入小窗口模式", detail: "在播放器内向下滑动进入小窗口", toggle: swipeDownMiniPlayerSwitch)
            case .triggerCorner:
                configureDisclosureCell(cell, title: "触发角设置", detail: title(for: Prefs.PlaybackSettings.triggerCorner))
            case .showsControls:
                configureSwitchCell(cell, title: "播放控制按钮（显示/隐藏）", detail: "显示或隐藏播放器控制按钮", toggle: showsControlsSwitch)
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else { return }
        switch Section.allCases[indexPath.section] {
        case .decoder where DecoderRow.allCases.indices.contains(indexPath.row):
            switch DecoderRow.allCases[indexPath.row] {
            case .videoDecoder:
                presentChoicePicker(title: "视频解码器", sourceView: tableView.cellForRow(at: indexPath), options: VideoDecoderPreference.allCases, selected: Prefs.PlaybackSettings.videoDecoder, title: title(for:)) { value in
                    Prefs.PlaybackSettings.videoDecoder = value
                    self.tableView.reloadData()
                }
            case .longPressPlaybackSpeed:
                presentChoicePicker(title: "长按播放速度", sourceView: tableView.cellForRow(at: indexPath), options: PlaybackSpeedPreference.allCases, selected: Prefs.PlaybackSettings.longPressPlaybackSpeed, title: title(for:)) { value in
                    Prefs.PlaybackSettings.longPressPlaybackSpeed = value
                    self.tableView.reloadData()
                }
            case .seekGesture:
                presentChoicePicker(title: "手势快进快退", sourceView: tableView.cellForRow(at: indexPath), options: PlaybackSeekGesturePreference.allCases, selected: Prefs.PlaybackSettings.seekGesture, title: title(for:)) { value in
                    Prefs.PlaybackSettings.seekGesture = value
                    self.tableView.reloadData()
                }
            }
        case .interface where InterfaceRow.allCases.indices.contains(indexPath.row):
            if InterfaceRow.allCases[indexPath.row] == .triggerCorner {
                presentChoicePicker(title: "触发角设置", sourceView: tableView.cellForRow(at: indexPath), options: PlaybackTriggerCorner.allCases, selected: Prefs.PlaybackSettings.triggerCorner, title: title(for:)) { value in
                    Prefs.PlaybackSettings.triggerCorner = value
                    self.tableView.reloadData()
                }
            }
        default:
            break
        }
    }

    private func configureSwitchCell(_ cell: UITableViewCell, title: String, detail: String, toggle: UISwitch) {
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.selectionStyle = .none
        cell.accessoryView = toggle
    }

    private func configureDisclosureCell(_ cell: UITableViewCell, title: String, detail: String) {
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.accessoryType = .disclosureIndicator
    }

    private func refreshDisplayedState() {
        openVideosInNewTabSwitch.isOn = Prefs.PlaybackSettings.openVideosInNewTab
        multiplePlayersSwitch.isOn = Prefs.PlaybackSettings.allowsMultiplePlayers
        autoplaySwitch.isOn = Prefs.PlaybackSettings.allowsWebMediaAutoplay
        backgroundPlaybackSwitch.isOn = Prefs.PlaybackSettings.allowsBackgroundPlayback
        muteByDefaultSwitch.isOn = Prefs.PlaybackSettings.mutesByDefault
        rememberPositionSwitch.isOn = Prefs.PlaybackSettings.remembersPlaybackPosition
        pictureInPictureSwitch.isOn = Prefs.PlaybackSettings.allowsPictureInPicture
        backgroundPictureInPictureSwitch.isOn = Prefs.PlaybackSettings.entersPictureInPictureInBackground
        backgroundPictureInPictureSwitch.isEnabled = Prefs.PlaybackSettings.allowsPictureInPicture
        swipeDownMiniPlayerSwitch.isOn = Prefs.PlaybackSettings.swipeDownEntersMiniPlayer
        showsControlsSwitch.isOn = Prefs.PlaybackSettings.showsControls
    }

    private func presentChoicePicker<T: CaseIterable & Equatable>(
        title: String,
        sourceView: UIView?,
        options: T.AllCases,
        selected: T,
        title titleProvider: @escaping (T) -> String,
        selection: @escaping (T) -> Void
    ) where T.AllCases: RandomAccessCollection {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let prefix = option == selected ? "✓ " : ""
            controller.addAction(UIAlertAction(title: prefix + titleProvider(option), style: .default) { _ in selection(option) })
        }
        controller.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = controller.popoverPresentationController, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(controller, animated: true)
    }

    private func title(for decoder: VideoDecoderPreference) -> String { "自动" }
    private func title(for speed: PlaybackSpeedPreference) -> String { "\(speed.rawValue, specifier: "%.1f")X" }

    private func title(for gesture: PlaybackSeekGesturePreference) -> String {
        switch gesture {
        case .adaptive: return "自适应，由视频时长决定"
        case .tenSeconds: return "每次 10 秒"
        case .fifteenSeconds: return "每次 15 秒"
        case .thirtySeconds: return "每次 30 秒"
        }
    }

    private func title(for corner: PlaybackTriggerCorner) -> String {
        switch corner {
        case .bottomRight: return "右下角"
        case .bottomLeft: return "左下角"
        }
    }

    @objc private func openVideosInNewTabDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.openVideosInNewTab = sender.isOn }
    @objc private func multiplePlayersDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.allowsMultiplePlayers = sender.isOn }
    @objc private func autoplayDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.allowsWebMediaAutoplay = sender.isOn }
    @objc private func backgroundPlaybackDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.allowsBackgroundPlayback = sender.isOn }
    @objc private func muteByDefaultDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.mutesByDefault = sender.isOn }
    @objc private func rememberPositionDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.remembersPlaybackPosition = sender.isOn }
    @objc private func pictureInPictureDidChange(_ sender: UISwitch) {
        Prefs.PlaybackSettings.allowsPictureInPicture = sender.isOn
        Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled = sender.isOn
        if !sender.isOn { Prefs.PlaybackSettings.entersPictureInPictureInBackground = false }
        refreshDisplayedState()
        tableView.reloadData()
    }
    @objc private func backgroundPictureInPictureDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.entersPictureInPictureInBackground = sender.isOn }
    @objc private func swipeDownMiniPlayerDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.swipeDownEntersMiniPlayer = sender.isOn }
    @objc private func showsControlsDidChange(_ sender: UISwitch) { Prefs.PlaybackSettings.showsControls = sender.isOn }
}
