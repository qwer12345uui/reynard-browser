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
        case content
        case external
        
        var text: SettingsSectionText {
            switch self {
            case .previews:
                return SettingsSectionText(headerTitle: NSLocalizedString("Previews", comment: "Browsing settings section title"))
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
    
    private enum ContentRow: CaseIterable {
        case allWebsites
        case pageZoom
    }
    
    private enum ExternalAppsRow: CaseIterable {
        case openLinks
    }
    
    private let showLinkPreviewsSwitch = UISwitch()
    private let showImagePreviewsSwitch = UISwitch()
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
        configureSwitch()
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
        
        switch Section.allCases[indexPath.section] {
        case .previews:
            guard PreviewsRow.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            switch PreviewsRow.allCases[indexPath.row] {
            case .showLinkPreviews:
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.text = NSLocalizedString("Show Link Previews", comment: "")
                cell.detailTextLabel?.textColor = .secondaryLabel
                cell.accessoryView = showLinkPreviewsSwitch
                return cell
            case .showImagePreviews:
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.text = NSLocalizedString("Show Image Previews", comment: "")
                cell.detailTextLabel?.textColor = .secondaryLabel
                cell.accessoryView = showImagePreviewsSwitch
                return cell
            }
        case .content:
            guard ContentRow.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            switch ContentRow.allCases[indexPath.row] {
            case .allWebsites:
                cell.textLabel?.text = NSLocalizedString("Request Desktop Website", comment: "")
            case .pageZoom:
                cell.textLabel?.text = NSLocalizedString("Page Zoom", comment: "")
            }
            cell.accessoryType = .disclosureIndicator
            return cell
        case .external:
            guard ExternalAppsRow.allCases.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = NSLocalizedString("Open Links in External Apps", comment: "")
            cell.selectionStyle = .none
            cell.accessoryView = openLinksInExternalAppsSwitch
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section.allCases.indices.contains(indexPath.section) else {
            return
        }
        
        switch Section.allCases[indexPath.section] {
        case .previews:
            return
        case .content:
            guard ContentRow.allCases.indices.contains(indexPath.row) else {
                return
            }
            switch ContentRow.allCases[indexPath.row] {
            case .allWebsites:
                navigationController?.pushViewController(RequestDesktopWebsitePreferencesViewController(), animated: true)
            case .pageZoom:
                navigationController?.pushViewController(PageZoomPreferencesViewController(), animated: true)
            }
        case .external:
            return
        }
    }
    
    private func configureSwitch() {
        showLinkPreviewsSwitch.addTarget(self, action: #selector(showLinkPreviewsSwitchDidChange(_:)), for: .valueChanged)
        showImagePreviewsSwitch.addTarget(self, action: #selector(showImagePreviewsSwitchDidChange(_:)), for: .valueChanged)
        openLinksInExternalAppsSwitch.addTarget(self, action: #selector(openLinksInExternalAppsSwitchDidChange(_:)), for: .valueChanged)
    }
    
    private func refreshDisplayedState() {
        showLinkPreviewsSwitch.isOn = Prefs.BrowsingSettings.showLinkPreviews
        showImagePreviewsSwitch.isOn = Prefs.BrowsingSettings.showImagePreviews
        openLinksInExternalAppsSwitch.isOn = Prefs.BrowsingSettings.openLinksInExternalApps
    }
    
    @objc private func showLinkPreviewsSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.showLinkPreviews = sender.isOn
    }
    
    @objc private func showImagePreviewsSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.showImagePreviews = sender.isOn
    }
    
    @objc private func openLinksInExternalAppsSwitchDidChange(_ sender: UISwitch) {
        Prefs.BrowsingSettings.openLinksInExternalApps = sender.isOn
    }
}
