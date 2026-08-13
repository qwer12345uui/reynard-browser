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
        case storage

        var text: SettingsSectionText {
            switch self {
            case .downloads:
                return SettingsSectionText(headerTitle: NSLocalizedString("Downloads", comment: "Download settings section"))
            case .storage:
                return SettingsSectionText(headerTitle: NSLocalizedString("Storage", comment: "Download settings section"))
            }
        }
    }

    private enum DownloadRow: CaseIterable {
        case confirmManualDownloads
    }

    private enum StorageRow: CaseIterable {
        case openDownloadsFolder
    }

    private let confirmManualDownloadsSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = NSLocalizedString("Download Settings", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        confirmManualDownloadsSwitch.addTarget(self, action: #selector(confirmManualDownloadsDidChange(_:)), for: .valueChanged)
        refreshDisplayedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard Section.allCases.indices.contains(section) else {
            return 0
        }

        switch Section.allCases[section] {
        case .downloads:
            return DownloadRow.allCases.count
        case .storage:
            return StorageRow.allCases.count
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

        switch Section.allCases[indexPath.section] {
        case .downloads:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Confirm New Downloads", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Ask before a manually added download starts", comment: "")
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.selectionStyle = .none
            cell.accessoryView = confirmManualDownloadsSwitch
            return cell
        case .storage:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Open Downloads Folder", comment: "")
            cell.detailTextLabel?.text = DownloadStore.shared.downloadsDirectory().lastPathComponent
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section),
              Section.allCases[indexPath.section] == .storage else {
            return
        }

        let url = DownloadStore.shared.downloadsDirectory()
        let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        guard let filesURL = URL(string: "shareddocuments://\(encodedPath)") else {
            return
        }
        UIApplication.shared.open(filesURL, options: [:], completionHandler: nil)
    }

    private func refreshDisplayedState() {
        confirmManualDownloadsSwitch.isOn = Prefs.DownloadSettings.confirmManualDownloads
    }

    @objc private func confirmManualDownloadsDidChange(_ sender: UISwitch) {
        Prefs.DownloadSettings.confirmManualDownloads = sender.isOn
    }
}

final class PlaybackPreferencesViewController: SettingsTableViewController {
    private enum Section: CaseIterable {
        case playback

        var text: SettingsSectionText {
            SettingsSectionText(headerTitle: NSLocalizedString("Playback", comment: "Playback settings section"))
        }
    }

    private enum Row: CaseIterable {
        case openVideosInNewTab
        case pictureInPicture
    }

    private let openVideosInNewTabSwitch = UISwitch()
    private let pictureInPictureSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = NSLocalizedString("Playback Settings", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        openVideosInNewTabSwitch.addTarget(self, action: #selector(openVideosInNewTabDidChange(_:)), for: .valueChanged)
        pictureInPictureSwitch.addTarget(self, action: #selector(pictureInPictureDidChange(_:)), for: .valueChanged)
        refreshDisplayedState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDisplayedState()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section.allCases.indices.contains(section) ? Row.allCases.count : 0
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        Section.allCases.indices.contains(section) ? Section.allCases[section].text : SettingsSectionText()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Row.allCases.indices.contains(indexPath.row) else {
            return UITableViewCell()
        }

        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.detailTextLabel?.textColor = .secondaryLabel

        switch Row.allCases[indexPath.row] {
        case .openVideosInNewTab:
            cell.textLabel?.text = NSLocalizedString("Open Videos in New Tab", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Keep the current page open while starting playback", comment: "")
            cell.accessoryView = openVideosInNewTabSwitch
        case .pictureInPicture:
            cell.textLabel?.text = NSLocalizedString("Picture in Picture", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("Allow supported videos to continue in a floating window", comment: "")
            cell.accessoryView = pictureInPictureSwitch
        }

        return cell
    }

    private func refreshDisplayedState() {
        openVideosInNewTabSwitch.isOn = Prefs.PlaybackSettings.openVideosInNewTab
        pictureInPictureSwitch.isOn = Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled
    }

    @objc private func openVideosInNewTabDidChange(_ sender: UISwitch) {
        Prefs.PlaybackSettings.openVideosInNewTab = sender.isOn
    }

    @objc private func pictureInPictureDidChange(_ sender: UISwitch) {
        Prefs.ExperimentalSettings.isVideoPictureInPictureEnabled = sender.isOn
    }
}
