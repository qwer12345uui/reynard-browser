//
//  UserScriptStore.swift
//  Reynard
//
//  Local storage, automatic .user.js installation and WebExtension-backed execution.
//

import Foundation
import GeckoView

struct UserScriptSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    let version: String?
    let sourceURL: URL?
    let isEnabled: Bool
    let updatedAt: Date
    let matchPatterns: [String]
}

struct UserScriptLogEntry: Identifiable, Codable, Equatable {
    enum Level: String, Codable {
        case info
        case success
        case warning
        case error
    }

    let id: UUID
    let timestamp: Date
    let level: Level
    let message: String
}

enum UserScriptStoreError: LocalizedError {
    case emptySource
    case sourceTooLarge
    case invalidEncoding
    case invalidRemoteURL
    case invalidPackage

    var errorDescription: String? {
        switch self {
        case .emptySource: return "脚本内容不能为空。"
        case .sourceTooLarge: return "脚本文件超过 3 MB 限制。"
        case .invalidEncoding: return "无法读取脚本文本，请使用 UTF-8 编码。"
        case .invalidRemoteURL: return "请输入有效的 HTTP 或 HTTPS 脚本链接。"
        case .invalidPackage: return "无法生成可执行的用户脚本包。"
        }
    }
}

final class UserScriptStore {
    static let shared = UserScriptStore()

    private static let maximumSourceSize = 3 * 1024 * 1024

    private struct PersistedScript: Codable {
        let id: UUID
        var name: String
        var version: String?
        var sourceURLString: String?
        var source: String
        var isEnabled: Bool
        var updatedAt: Date
        var matchPatterns: [String]
        var addonID: String?
        var logs: [UserScriptLogEntry]?
    }

    private let fileManager: FileManager
    private let stateQueue = DispatchQueue(label: "com.minh-ton.Reynard.UserScriptStore.Queue", qos: .userInitiated)
    private let storageURL: URL
    private let packagesDirectoryURL: URL
    private var scripts: [PersistedScript] = []

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        let appDataURL = applicationSupportURL.appendingPathComponent("AppData", isDirectory: true)
        storageURL = appDataURL.appendingPathComponent("UserScripts.json", isDirectory: false)
        packagesDirectoryURL = appDataURL.appendingPathComponent("UserScriptPackages", isDirectory: true)
        stateQueue.sync {
            try? fileManager.createDirectory(at: appDataURL, withIntermediateDirectories: true)
            try? fileManager.createDirectory(at: packagesDirectoryURL, withIntermediateDirectories: true)
            loadLocked()
        }
    }

    func currentScripts() -> [UserScriptSnapshot] {
        stateQueue.sync { snapshotsLocked() }
    }

    func source(for id: UUID) -> String? {
        stateQueue.sync { scripts.first(where: { $0.id == id })?.source }
    }

    @discardableResult
    func install(source: String, sourceURL: URL? = nil, preferredName: String? = nil) async throws -> UserScriptSnapshot {
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSource.isEmpty else { throw UserScriptStoreError.emptySource }
        guard normalizedSource.lengthOfBytes(using: .utf8) <= Self.maximumSourceSize else { throw UserScriptStoreError.sourceTooLarge }

        let metadata = parseMetadata(from: normalizedSource)
        let derivedName = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = derivedName?.isEmpty == false ? derivedName! : metadata.name ?? "未命名脚本"
        let script = PersistedScript(
            id: UUID(),
            name: name,
            version: metadata.version,
            sourceURLString: sourceURL?.absoluteString,
            source: normalizedSource,
            isEnabled: true,
            updatedAt: Date(),
            matchPatterns: metadata.matchPatterns,
            addonID: nil,
            logs: []
        )

        let activated = try await activate(script)
        let installedSnapshot = stateQueue.sync { () -> UserScriptSnapshot in
            scripts.insert(activated, at: 0)
            saveLocked()
            return snapshot(from: activated)
        }
        appendLog("已生成本地脚本扩展并请求安装。", level: .success, for: installedSnapshot.id)
        return installedSnapshot
    }

    @discardableResult
    func install(fromFile fileURL: URL) async throws -> UserScriptSnapshot {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { fileURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: fileURL)
        guard let source = String(data: data, encoding: .utf8) else { throw UserScriptStoreError.invalidEncoding }
        return try await install(source: source, sourceURL: fileURL, preferredName: fileURL.deletingPathExtension().lastPathComponent)
    }

    @discardableResult
    func install(fromRemoteURL url: URL) async throws -> UserScriptSnapshot {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw UserScriptStoreError.invalidRemoteURL
        }
        let source = try await downloadSource(from: url)
        return try await install(source: source, sourceURL: url, preferredName: url.deletingPathExtension().lastPathComponent)
    }

    /// Restores executable extensions for scripts created before runtime-backed installation,
    /// or after the browser runtime has removed an extension package.
    func synchronizeWithRuntime() async {
        let existingAddonIDs = Set(AddonRuntime.shared.installedAddons.map(\.id))
        let pending = stateQueue.sync { scripts.filter { $0.addonID == nil || !existingAddonIDs.contains($0.addonID ?? "") } }
        guard !pending.isEmpty else { return }

        for script in pending {
            do {
                let activated = try await activate(script)
                let changed = stateQueue.sync { () -> Bool in
                    guard let index = scripts.firstIndex(where: { $0.id == activated.id }) else { return false }
                    scripts[index] = activated
                    saveLocked()
                    return true
                }
                if changed {
                    appendLog("浏览器启动时已同步脚本扩展。", level: .success, for: script.id)
                }
            } catch {
                appendLog("脚本扩展同步失败：\(error.localizedDescription)", level: .error, for: script.id)
            }
        }
    }

    func logs(for id: UUID) -> [UserScriptLogEntry] {
        stateQueue.sync {
            (scripts.first(where: { $0.id == id })?.logs ?? []).sorted { $0.timestamp > $1.timestamp }
        }
    }

    func clearLogs(for id: UUID) {
        let changed = stateQueue.sync { () -> Bool in
            guard let index = scripts.firstIndex(where: { $0.id == id }) else { return false }
            scripts[index].logs = []
            saveLocked()
            return true
        }
        if changed { postDidChange() }
    }

    /// Records that a script is eligible to execute for a completed page load.
    func recordPageLoad(_ pageURL: URL) {
        let matchedIDs = stateQueue.sync {
            scripts.filter { $0.isEnabled && matches(pageURL, patterns: $0.matchPatterns) }.map(\.id)
        }
        for id in matchedIDs {
            appendLog("页面匹配：\(pageURL.host ?? pageURL.absoluteString)。已交由脚本扩展执行。", level: .info, for: id)
        }
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        let addonID = stateQueue.sync { () -> String? in
            guard let index = scripts.firstIndex(where: { $0.id == id }), scripts[index].isEnabled != enabled else { return nil }
            scripts[index].isEnabled = enabled
            scripts[index].updatedAt = Date()
            saveLocked()
            return scripts[index].addonID
        }
        guard let addonID else {
            appendLog("扩展标识缺失，等待浏览器启动时重新同步。", level: .warning, for: id)
            return
        }
        appendLog(enabled ? "已请求启用脚本扩展。" : "已请求停用脚本扩展。", level: .info, for: id)
        Task { [weak self] in
            guard let self else { return }
            guard let addon = try? await AddonRuntime.shared.addon(byID: addonID) else {
                self.appendLog("未找到脚本扩展，无法切换状态。", level: .error, for: id)
                return
            }
            do {
                if enabled {
                    _ = try await AddonRuntime.shared.enable(addon)
                } else {
                    _ = try await AddonRuntime.shared.disable(addon)
                }
                self.appendLog(enabled ? "脚本扩展已启用。" : "脚本扩展已停用。", level: .success, for: id)
            } catch {
                self.appendLog("切换扩展状态失败：\(error.localizedDescription)", level: .error, for: id)
            }
        }
    }

    func remove(id: UUID) {
        let addonID = stateQueue.sync { () -> String? in
            guard let index = scripts.firstIndex(where: { $0.id == id }) else { return nil }
            let addonID = scripts[index].addonID
            scripts.remove(at: index)
            saveLocked()
            return addonID
        }
        guard let addonID else { return }
        postDidChange()
        Task {
            guard let addon = try? await AddonRuntime.shared.addon(byID: addonID) else { return }
            try? await AddonRuntime.shared.uninstall(addon)
        }
    }

    private func activate(_ script: PersistedScript) async throws -> PersistedScript {
        let packageURL = try createPackage(for: script)
        let addon = try await AddonRuntime.shared.install(url: packageURL.absoluteString, installMethod: .manager)
        _ = try? await AddonRuntime.shared.setAllowedInPrivateBrowsing(addon, allowed: true)
        return PersistedScript(
            id: script.id,
            name: script.name,
            version: script.version,
            sourceURLString: script.sourceURLString,
            source: script.source,
            isEnabled: script.isEnabled,
            updatedAt: Date(),
            matchPatterns: script.matchPatterns,
            addonID: addon.id,
            logs: script.logs ?? []
        )
    }

    private func createPackage(for script: PersistedScript) throws -> URL {
        let extensionID = "userscript-\(script.id.uuidString.lowercased())@reynard.local"
        let manifest: [String: Any] = [
            "manifest_version": 2,
            "name": script.name,
            "version": normalizedVersion(script.version),
            "description": "Reynard 用户脚本：\(script.name)",
            "applications": ["gecko": ["id": extensionID]],
            "permissions": ["<all_urls>"],
            "content_scripts": [[
                "matches": ["<all_urls>"],
                "js": ["content.js"],
                "run_at": "document_end",
                "all_frames": false,
            ]],
        ]
        guard JSONSerialization.isValidJSONObject(manifest),
              let manifestData = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]),
              let contentData = wrappedContent(for: script).data(using: .utf8) else {
            throw UserScriptStoreError.invalidPackage
        }

        let packageURL = packagesDirectoryURL
            .appendingPathComponent("\(script.id.uuidString).xpi", isDirectory: false)
        let packageData = Self.makeStoredZIP(entries: [
            ("manifest.json", manifestData),
            ("content.js", contentData),
        ])
        try packageData.write(to: packageURL, options: .atomic)
        return packageURL
    }

    private func wrappedContent(for script: PersistedScript) -> String {
        let patterns = script.matchPatterns
        let patternData = (try? JSONSerialization.data(withJSONObject: patterns, options: [])) ?? Data("[]".utf8)
        let encodedPatterns = String(data: patternData, encoding: .utf8) ?? "[]"
        return """
        // Generated by Reynard. The original user script remains below unchanged.
        (() => {
          const reynardPatterns = \(encodedPatterns);
          const reynardMatches = reynardPatterns.some((pattern) => {
            const parts = pattern.split('*');
            let cursor = 0;
            for (let index = 0; index < parts.length; index += 1) {
              const part = parts[index];
              if (!part) continue;
              const foundAt = location.href.indexOf(part, cursor);
              if (foundAt < 0 || (index === 0 && !pattern.startsWith('*') && foundAt !== 0)) return false;
              cursor = foundAt + part.length;
            }
            return pattern.endsWith('*') || cursor === location.href.length;
          });
          if (!reynardMatches) return;
          \(script.source)
        })();
        """
    }

    private func normalizedVersion(_ version: String?) -> String {
        let candidate = version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "1.0.0"
        let components = candidate.split(separator: ".").map { Int($0) ?? 0 }
        guard !components.isEmpty else { return "1.0.0" }
        return (components + Array(repeating: 0, count: max(0, 3 - components.count))).prefix(3).map(String.init).joined(separator: ".")
    }

    private func downloadSource(from url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: url) { data, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let source = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: UserScriptStoreError.invalidEncoding)
                    return
                }
                continuation.resume(returning: source)
            }.resume()
        }
    }

    private func appendLog(_ message: String, level: UserScriptLogEntry.Level, for id: UUID) {
        let changed = stateQueue.sync { () -> Bool in
            guard let index = scripts.firstIndex(where: { $0.id == id }) else { return false }
            let entry = UserScriptLogEntry(id: UUID(), timestamp: Date(), level: level, message: message)
            scripts[index].logs = ([entry] + (scripts[index].logs ?? [])).prefix(120).map { $0 }
            scripts[index].updatedAt = Date()
            saveLocked()
            return true
        }
        if changed { postDidChange() }
    }

    private func loadLocked() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([PersistedScript].self, from: data) else {
            scripts = []
            return
        }
        scripts = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func saveLocked() {
        guard let data = try? JSONEncoder().encode(scripts.sorted { $0.updatedAt > $1.updatedAt }) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func snapshotsLocked() -> [UserScriptSnapshot] {
        scripts.sorted { $0.updatedAt > $1.updatedAt }.map(snapshot(from:))
    }

    private func snapshot(from script: PersistedScript) -> UserScriptSnapshot {
        UserScriptSnapshot(
            id: script.id,
            name: script.name,
            version: script.version,
            sourceURL: script.sourceURLString.flatMap(URL.init(string:)),
            isEnabled: script.isEnabled,
            updatedAt: script.updatedAt,
            matchPatterns: script.matchPatterns
        )
    }

    private func parseMetadata(from source: String) -> (name: String?, version: String?, matchPatterns: [String]) {
        var name: String?
        var version: String?
        var matchPatterns: [String] = []
        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("// @") else { continue }
            let content = String(line.dropFirst(4))
            let parts = content.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard let key = parts.first else { continue }
            let value = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            switch key.lowercased() {
            case "name" where !value.isEmpty:
                if name == nil { name = value }
            case "version" where !value.isEmpty:
                if version == nil { version = value }
            case "match", "include" where !value.isEmpty:
                matchPatterns.append(value)
            default:
                break
            }
        }
        return (name, version, matchPatterns.isEmpty ? ["*://*/*"] : matchPatterns)
    }

    private static func makeStoredZIP(entries: [(String, Data)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for (name, contents) in entries {
            let nameData = Data(name.utf8)
            let crc = crc32(contents)
            appendUInt32(0x04034b50, to: &archive)
            appendUInt16(20, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt32(crc, to: &archive)
            appendUInt32(UInt32(contents.count), to: &archive)
            appendUInt32(UInt32(contents.count), to: &archive)
            appendUInt16(UInt16(nameData.count), to: &archive)
            appendUInt16(0, to: &archive)
            archive.append(nameData)
            archive.append(contents)

            appendUInt32(0x02014b50, to: &centralDirectory)
            appendUInt16(20, to: &centralDirectory)
            appendUInt16(20, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt32(crc, to: &centralDirectory)
            appendUInt32(UInt32(contents.count), to: &centralDirectory)
            appendUInt32(UInt32(contents.count), to: &centralDirectory)
            appendUInt16(UInt16(nameData.count), to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt32(0, to: &centralDirectory)
            appendUInt32(offset, to: &centralDirectory)
            centralDirectory.append(nameData)

            offset = UInt32(archive.count)
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        appendUInt32(0x06054b50, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(UInt16(entries.count), to: &archive)
        appendUInt16(UInt16(entries.count), to: &archive)
        appendUInt32(UInt32(centralDirectory.count), to: &archive)
        appendUInt32(centralDirectoryOffset, to: &archive)
        appendUInt16(0, to: &archive)
        return archive
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        let littleEndianValue = value.littleEndian
        withUnsafeBytes(of: littleEndianValue) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        let littleEndianValue = value.littleEndian
        withUnsafeBytes(of: littleEndianValue) { data.append(contentsOf: $0) }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var value: UInt32 = 0xFFFFFFFF
        for byte in data {
            value ^= UInt32(byte)
            for _ in 0..<8 {
                value = value & 1 == 1 ? (value >> 1) ^ 0xEDB88320 : value >> 1
            }
        }
        return value ^ 0xFFFFFFFF
    }

    private func postDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .userScriptStoreDidChange, object: self)
        }
    }
}

extension Notification.Name {
    static let userScriptStoreDidChange = Notification.Name("com.minh-ton.Reynard.userScriptStoreDidChange")
}
