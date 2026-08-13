//
//  UserScriptsPreferencesViewController.swift
//  Reynard
//
//  User script management with Greasy Fork/Sleazy Fork discovery and four import paths.
//

import UIKit
import MobileCoreServices

final class UserScriptsPreferencesViewController: SettingsTableViewController, UIDocumentPickerDelegate {
    private enum Section {
        case installed
        case add

        var text: SettingsSectionText {
            switch self {
            case .installed:
                return SettingsSectionText(
                    headerTitle: "用户脚本",
                    footerTitle: "已启用的脚本会按脚本中的 @match 或 @include 规则匹配网页。脚本由用户自行管理，请仅安装可信来源的脚本。"
                )
            case .add:
                return SettingsSectionText(headerTitle: "添加脚本")
            }
        }
    }

    private enum AddRow: CaseIterable {
        case greasyFork
        case sleazyFork
        case importFile
        case inputScript
        case importLink
    }

    private let store = UserScriptStore.shared
    private var scripts: [UserScriptSnapshot] = []
    private var isImportingFromLink = false

    init() {
        super.init(style: .insetGrouped)
        title = "用户脚本"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadScripts()
        NotificationCenter.default.addObserver(self, selector: #selector(userScriptsDidChange), name: .userScriptStoreDidChange, object: store)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadScripts()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return max(scripts.count, 1)
        case 1: return AddRow.allCases.count
        default: return 0
        }
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        switch section {
        case 0: return scripts.isEmpty ? SettingsSectionText() : Section.installed.text
        case 1: return Section.add.text
        default: return SettingsSectionText()
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            guard !scripts.isEmpty, scripts.indices.contains(indexPath.row) else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.text = "尚未添加用户脚本"
                cell.textLabel?.textColor = .secondaryLabel
                return cell
            }
            let script = scripts[indexPath.row]
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = script.name
            let version = script.version.map { "v\($0)" } ?? "未标注版本"
            cell.detailTextLabel?.text = "\(script.isEnabled ? "已启用" : "已停用") · \(version)"
            cell.detailTextLabel?.textColor = script.isEnabled ? .secondaryLabel : .tertiaryLabel
            cell.imageView?.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")
            cell.accessoryType = .disclosureIndicator
            return cell
        case 1:
            guard AddRow.allCases.indices.contains(indexPath.row) else { return UITableViewCell() }
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.textColor = view.tintColor
            cell.detailTextLabel?.textColor = .secondaryLabel
            switch AddRow.allCases[indexPath.row] {
            case .greasyFork:
                cell.textLabel?.text = "访问 greasyfork.org"
                cell.detailTextLabel?.text = "浏览通用用户脚本"
                cell.imageView?.image = UIImage(systemName: "safari")
            case .sleazyFork:
                cell.textLabel?.text = "访问 sleazyfork.org"
                cell.detailTextLabel?.text = "浏览成人内容相关脚本"
                cell.imageView?.image = UIImage(systemName: "safari")
            case .importFile:
                cell.textLabel?.text = "通过文件导入"
                cell.detailTextLabel?.text = "选择 .js、.user.js 或纯文本脚本文件"
                cell.imageView?.image = UIImage(systemName: "doc.badge.plus")
            case .inputScript:
                cell.textLabel?.text = "直接输入脚本"
                cell.detailTextLabel?.text = "粘贴或编写 JavaScript 用户脚本"
                cell.imageView?.image = UIImage(systemName: "square.and.pencil")
            case .importLink:
                cell.textLabel?.text = isImportingFromLink ? "正在通过链接导入…" : "通过链接导入"
                cell.detailTextLabel?.text = "输入脚本的直接下载链接"
                cell.imageView?.image = UIImage(systemName: "link.badge.plus")
                if isImportingFromLink {
                    cell.textLabel?.textColor = .secondaryLabel
                    cell.selectionStyle = .none
                }
            }
            return cell
        default:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        if indexPath.section == 0, scripts.indices.contains(indexPath.row) {
            navigationController?.pushViewController(UserScriptDetailsPreferencesViewController(script: scripts[indexPath.row], store: store), animated: true)
            return
        }
        guard indexPath.section == 1, AddRow.allCases.indices.contains(indexPath.row) else { return }
        switch AddRow.allCases[indexPath.row] {
        case .greasyFork:
            LibrarySharedUtils.openLinkInBrowser("https://greasyfork.org/", from: self)
        case .sleazyFork:
            LibrarySharedUtils.openLinkInBrowser("https://sleazyfork.org/", from: self)
        case .importFile:
            chooseScriptFile()
        case .inputScript:
            navigationController?.pushViewController(UserScriptEditorViewController { [weak self] source, name in
                self?.install(source: source, sourceURL: nil, preferredName: name)
            }, animated: true)
        case .importLink:
            guard !isImportingFromLink else { return }
            presentImportLinkPrompt()
        }
    }

    private func chooseScriptFile() {
        let picker = UIDocumentPickerViewController(
            documentTypes: [kUTTypeJavaScript as String, kUTTypeText as String, kUTTypeData as String],
            in: .import
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await self.store.install(fromFile: url)
                self.showResult(title: "脚本已安装", message: "已从文件导入并启用。匹配网页会自动执行该脚本。")
            } catch {
                self.showResult(title: "无法导入脚本", message: error.localizedDescription)
            }
        }
    }

    private func presentImportLinkPrompt() {
        let alert = UIAlertController(title: "通过链接导入", message: "请输入脚本文件的 HTTP 或 HTTPS 直链。", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://example.com/script.user.js"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "导入", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: value) else {
                return
            }
            self.importScript(from: url)
        })
        present(alert, animated: true)
    }

    private func importScript(from url: URL) {
        isImportingFromLink = true
        tableView.reloadData()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isImportingFromLink = false
                self.tableView.reloadData()
            }
            do {
                _ = try await self.store.install(fromRemoteURL: url)
                self.showResult(title: "脚本已安装", message: "已通过链接导入并启用。匹配网页会自动执行该脚本。")
            } catch {
                self.showResult(title: "无法导入脚本", message: error.localizedDescription)
            }
        }
    }

    private func install(source: String, sourceURL: URL?, preferredName: String?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await self.store.install(source: source, sourceURL: sourceURL, preferredName: preferredName)
                self.showResult(title: "脚本已安装", message: "已保存、启用并转换为可执行的用户脚本。")
            } catch {
                self.showResult(title: "无法安装脚本", message: error.localizedDescription)
            }
        }
    }

    private func reloadScripts() {
        scripts = store.currentScripts()
        if isViewLoaded { tableView.reloadData() }
    }

    private func showResult(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    @objc private func userScriptsDidChange() { reloadScripts() }
}

private final class UserScriptDetailsPreferencesViewController: SettingsTableViewController {
    private enum Row: CaseIterable {
        case enabled
        case matchRules
        case sourceURL
        case logs
        case delete
    }

    private let script: UserScriptSnapshot
    private let store: UserScriptStore
    private let enabledSwitch = UISwitch()

    init(script: UserScriptSnapshot, store: UserScriptStore) {
        self.script = script
        self.store = store
        super.init(style: .insetGrouped)
        title = script.name
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        enabledSwitch.isOn = script.isEnabled
        enabledSwitch.addTarget(self, action: #selector(enabledDidChange(_:)), for: .valueChanged)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? Row.allCases.count - 1 : 1
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        section == 0
            ? SettingsSectionText(headerTitle: "脚本设置")
            : SettingsSectionText(footerTitle: "删除后无法恢复，请确认不再需要该脚本。")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel
        if indexPath.section == 1 {
            cell.textLabel?.text = "删除脚本"
            cell.textLabel?.textColor = .systemRed
            return cell
        }
        guard Row.allCases.indices.contains(indexPath.row) else { return cell }
        switch Row.allCases[indexPath.row] {
        case .enabled:
            cell.textLabel?.text = "启用脚本"
            cell.detailTextLabel?.text = "关闭后不会在网页中运行"
            cell.selectionStyle = .none
            cell.accessoryView = enabledSwitch
        case .matchRules:
            cell.textLabel?.text = "匹配规则"
            cell.detailTextLabel?.text = script.matchPatterns.joined(separator: "\n")
            cell.detailTextLabel?.numberOfLines = 0
        case .sourceURL:
            cell.textLabel?.text = "脚本来源"
            cell.detailTextLabel?.text = script.sourceURL?.absoluteString ?? "直接输入"
            cell.detailTextLabel?.numberOfLines = 0
        case .logs:
            let logCount = store.logs(for: script.id).count
            cell.textLabel?.text = "运行日志与调试信息"
            cell.detailTextLabel?.text = logCount == 0 ? "尚无匹配、同步或启停记录" : "已记录 \(logCount) 条事件"
            cell.accessoryType = .disclosureIndicator
        case .delete:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        if indexPath.section == 0, Row.allCases.indices.contains(indexPath.row), Row.allCases[indexPath.row] == .logs {
            navigationController?.pushViewController(UserScriptDebugLogViewController(script: script, store: store), animated: true)
            return
        }
        guard indexPath.section == 1 else { return }
        let alert = UIAlertController(title: "删除脚本", message: "确定要删除“\(script.name)”吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            store.remove(id: script.id)
            navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func enabledDidChange(_ sender: UISwitch) {
        store.setEnabled(sender.isOn, for: script.id)
    }
}

private final class UserScriptDebugLogViewController: SettingsTableViewController {
    private let script: UserScriptSnapshot
    private let store: UserScriptStore
    private var entries: [UserScriptLogEntry] = []

    init(script: UserScriptSnapshot, store: UserScriptStore) {
        self.script = script
        self.store = store
        super.init(style: .insetGrouped)
        title = "运行日志"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearLogs))
        NotificationCenter.default.addObserver(self, selector: #selector(reloadEntries), name: .userScriptStoreDidChange, object: store)
        reloadEntries()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 3 : max(entries.count, 1)
    }

    override func sectionText(for section: Int) -> SettingsSectionText {
        section == 0
            ? SettingsSectionText(headerTitle: "调试状态", footerTitle: "日志记录脚本导入、扩展同步、启停和页面匹配。它不能替代网页 JavaScript 的 console 输出。")
            : SettingsSectionText(headerTitle: "事件")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.detailTextLabel?.textColor = .secondaryLabel
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "脚本"
                cell.detailTextLabel?.text = script.name
            case 1:
                cell.textLabel?.text = "状态"
                cell.detailTextLabel?.text = script.isEnabled ? "已启用；请重新加载匹配网页后查看事件。" : "已停用；不会运行。"
            default:
                cell.textLabel?.text = "匹配规则"
                cell.detailTextLabel?.text = script.matchPatterns.joined(separator: "\n")
                cell.detailTextLabel?.numberOfLines = 0
            }
            cell.selectionStyle = .none
            return cell
        }
        guard entries.indices.contains(indexPath.row) else {
            cell.textLabel?.text = "尚无调试事件"
            cell.detailTextLabel?.text = "打开一个符合匹配规则的网页后，事件将显示在这里。"
            cell.selectionStyle = .none
            return cell
        }
        let entry = entries[indexPath.row]
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        cell.textLabel?.text = entry.message
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = "\(entry.level.rawValue.uppercased()) · \(formatter.string(from: entry.timestamp))"
        switch entry.level {
        case .success: cell.textLabel?.textColor = .systemGreen
        case .warning: cell.textLabel?.textColor = .systemOrange
        case .error: cell.textLabel?.textColor = .systemRed
        case .info: break
        }
        cell.selectionStyle = .none
        return cell
    }

    @objc private func reloadEntries() {
        entries = store.logs(for: script.id)
        if isViewLoaded { tableView.reloadData() }
    }

    @objc private func clearLogs() {
        store.clearLogs(for: script.id)
        reloadEntries()
    }
}

private final class UserScriptEditorViewController: UIViewController {
    private let onSave: (String, String?) -> Void
    private let nameField = UITextField()
    private let sourceView = UITextView()

    init(onSave: @escaping (String, String?) -> Void) {
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        title = "直接输入脚本"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(save))
        configureNameField()
        configureSourceView()
        view.addSubview(nameField)
        view.addSubview(sourceView)
        NSLayoutConstraint.activate([
            nameField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            nameField.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            nameField.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            nameField.heightAnchor.constraint(equalToConstant: 44),
            sourceView.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            sourceView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            sourceView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            sourceView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func configureNameField() {
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.borderStyle = .roundedRect
        nameField.placeholder = "脚本名称（可选，优先读取 @name）"
        nameField.autocapitalizationType = .none
        nameField.autocorrectionType = .no
    }

    private func configureSourceView() {
        sourceView.translatesAutoresizingMaskIntoConstraints = false
        sourceView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        sourceView.backgroundColor = .secondarySystemBackground
        sourceView.layer.cornerRadius = 10
        sourceView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        sourceView.text = "// ==UserScript==\n// @name 示例脚本\n// @match *://*/*\n// ==/UserScript==\n\n"
        sourceView.autocapitalizationType = .none
        sourceView.autocorrectionType = .no
    }

    @objc private func save() {
        let source = sourceView.text ?? ""
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let alert = UIAlertController(title: "脚本内容不能为空", message: "请输入或粘贴 JavaScript 用户脚本。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            present(alert, animated: true)
            return
        }
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(source, name?.isEmpty == true ? nil : name)
        navigationController?.popViewController(animated: true)
    }
}
