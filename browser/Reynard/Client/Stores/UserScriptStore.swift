//
//  UserScriptStore.swift
//  Reynard
//
//  Local storage and validation for user scripts imported from files, text and links.
//

import Foundation

struct UserScriptSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    let version: String?
    let sourceURL: URL?
    let isEnabled: Bool
    let updatedAt: Date
    let matchPatterns: [String]
}

enum UserScriptStoreError: LocalizedError {
    case emptySource
    case sourceTooLarge
    case invalidEncoding
    case invalidRemoteURL

    var errorDescription: String? {
        switch self {
        case .emptySource: return "脚本内容不能为空。"
        case .sourceTooLarge: return "脚本文件超过 3 MB 限制。"
        case .invalidEncoding: return "无法读取脚本文本，请使用 UTF-8 编码。"
        case .invalidRemoteURL: return "请输入有效的 HTTP 或 HTTPS 脚本链接。"
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
    }

    private let fileManager: FileManager
    private let stateQueue = DispatchQueue(label: "com.minh-ton.Reynard.UserScriptStore.Queue", qos: .userInitiated)
    private let storageURL: URL
    private var scripts: [PersistedScript] = []

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        let appDataURL = applicationSupportURL.appendingPathComponent("AppData", isDirectory: true)
        storageURL = appDataURL.appendingPathComponent("UserScripts.json", isDirectory: false)
        stateQueue.sync {
            try? fileManager.createDirectory(at: appDataURL, withIntermediateDirectories: true)
            loadLocked()
        }
    }

    func currentScripts() -> [UserScriptSnapshot] {
        stateQueue.sync { snapshotsLocked() }
    }

    func source(for id: UUID) -> String? {
        stateQueue.sync { scripts.first(where: { $0.id == id })?.source }
    }

    /// Provides enabled scripts matching a page URL for the browser content bridge.
    func scripts(matching pageURL: URL) -> [String] {
        stateQueue.sync {
            scripts
                .filter { $0.isEnabled && matches(pageURL, patterns: $0.matchPatterns) }
                .map(\.source)
        }
    }

    @discardableResult
    func install(source: String, sourceURL: URL? = nil, preferredName: String? = nil) throws -> UserScriptSnapshot {
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
            matchPatterns: metadata.matchPatterns
        )

        let snapshot = stateQueue.sync { () -> UserScriptSnapshot in
            scripts.insert(script, at: 0)
            saveLocked()
            return snapshot(from: script)
        }
        postDidChange()
        return snapshot
    }

    func install(fromFile fileURL: URL) throws -> UserScriptSnapshot {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { fileURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: fileURL)
        guard let source = String(data: data, encoding: .utf8) else { throw UserScriptStoreError.invalidEncoding }
        return try install(source: source, sourceURL: fileURL, preferredName: fileURL.deletingPathExtension().lastPathComponent)
    }

    func install(fromRemoteURL url: URL, completion: @escaping (Result<UserScriptSnapshot, Error>) -> Void) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            completion(.failure(UserScriptStoreError.invalidRemoteURL))
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data, let source = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion(.failure(UserScriptStoreError.invalidEncoding)) }
                return
            }
            do {
                let result = try self?.install(source: source, sourceURL: url, preferredName: url.deletingPathExtension().lastPathComponent)
                if let result {
                    DispatchQueue.main.async { completion(.success(result)) }
                } else {
                    DispatchQueue.main.async { completion(.failure(UserScriptStoreError.emptySource)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        let didChange = stateQueue.sync { () -> Bool in
            guard let index = scripts.firstIndex(where: { $0.id == id }), scripts[index].isEnabled != enabled else { return false }
            scripts[index].isEnabled = enabled
            scripts[index].updatedAt = Date()
            saveLocked()
            return true
        }
        if didChange { postDidChange() }
    }

    func remove(id: UUID) {
        let didChange = stateQueue.sync { () -> Bool in
            let originalCount = scripts.count
            scripts.removeAll { $0.id == id }
            guard scripts.count != originalCount else { return false }
            saveLocked()
            return true
        }
        if didChange { postDidChange() }
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

    private func matches(_ url: URL, patterns: [String]) -> Bool {
        let target = url.absoluteString
        return patterns.contains { pattern in
            let escaped = NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*", with: ".*")
            return target.range(of: "^\(escaped)$", options: .regularExpression) != nil
        }
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
