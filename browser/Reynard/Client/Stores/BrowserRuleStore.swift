//
//  BrowserRuleStore.swift
//  Reynard
//
//  Advertising and privacy rule management backed by a local WebExtension.
//

import Foundation
import GeckoView

struct BrowserRuleSnapshot: Equatable {
    let advertisingEnabled: Bool
    let privacyEnabled: Bool
    let cosmeticFilteringEnabled: Bool
    let blockedDomains: [String]
    let allowedDomains: [String]
}

enum BrowserRuleStoreError: LocalizedError {
    case invalidDomain

    var errorDescription: String? {
        switch self {
        case .invalidDomain: return "请输入有效的域名，例如 example.com。"
        }
    }
}

final class BrowserRuleStore {
    static let shared = BrowserRuleStore()

    private enum Key {
        static let advertisingEnabled = "com.minh-ton.Reynard.BrowserRules.AdvertisingEnabled"
        static let privacyEnabled = "com.minh-ton.Reynard.BrowserRules.PrivacyEnabled"
        static let cosmeticFilteringEnabled = "com.minh-ton.Reynard.BrowserRules.CosmeticFilteringEnabled"
        static let blockedDomains = "com.minh-ton.Reynard.BrowserRules.BlockedDomains"
        static let allowedDomains = "com.minh-ton.Reynard.BrowserRules.AllowedDomains"
        static let addonID = "com.minh-ton.Reynard.BrowserRules.AddonID"
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let packageURL: URL
    private var pendingRuntimeSync = false

    private init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("BrowserRulePackages", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        packageURL = directory.appendingPathComponent("ReynardRules.xpi", isDirectory: false)
        defaults.register(defaults: [
            Key.advertisingEnabled: true,
            Key.privacyEnabled: true,
            Key.cosmeticFilteringEnabled: true,
            Key.blockedDomains: [],
            Key.allowedDomains: [],
        ])
    }

    var snapshot: BrowserRuleSnapshot {
        BrowserRuleSnapshot(
            advertisingEnabled: defaults.bool(forKey: Key.advertisingEnabled),
            privacyEnabled: defaults.bool(forKey: Key.privacyEnabled),
            cosmeticFilteringEnabled: defaults.bool(forKey: Key.cosmeticFilteringEnabled),
            blockedDomains: normalizedDomains(defaults.stringArray(forKey: Key.blockedDomains) ?? []),
            allowedDomains: normalizedDomains(defaults.stringArray(forKey: Key.allowedDomains) ?? [])
        )
    }

    func setAdvertisingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.advertisingEnabled)
        scheduleRuntimeSync()
    }

    func setPrivacyEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.privacyEnabled)
        scheduleRuntimeSync()
    }

    func setCosmeticFilteringEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.cosmeticFilteringEnabled)
        scheduleRuntimeSync()
    }

    func addBlockedDomain(_ value: String) throws {
        let domain = try validatedDomain(value)
        var domains = snapshot.blockedDomains
        guard !domains.contains(domain) else { return }
        domains.append(domain)
        defaults.set(domains, forKey: Key.blockedDomains)
        scheduleRuntimeSync()
    }

    func removeBlockedDomain(_ domain: String) {
        defaults.set(snapshot.blockedDomains.filter { $0 != domain }, forKey: Key.blockedDomains)
        scheduleRuntimeSync()
    }

    func addAllowedDomain(_ value: String) throws {
        let domain = try validatedDomain(value)
        var domains = snapshot.allowedDomains
        guard !domains.contains(domain) else { return }
        domains.append(domain)
        defaults.set(domains, forKey: Key.allowedDomains)
        scheduleRuntimeSync()
    }

    func removeAllowedDomain(_ domain: String) {
        defaults.set(snapshot.allowedDomains.filter { $0 != domain }, forKey: Key.allowedDomains)
        scheduleRuntimeSync()
    }

    func synchronizeWithRuntime() async {
        let addonID = defaults.string(forKey: Key.addonID)
        let existing = addonID.flatMap { id in AddonRuntime.shared.installedAddons.first(where: { $0.id == id }) }
        if let existing {
            try? await AddonRuntime.shared.uninstall(existing)
        }

        guard snapshot.advertisingEnabled || snapshot.privacyEnabled || snapshot.cosmeticFilteringEnabled else {
            defaults.removeObject(forKey: Key.addonID)
            notifyChange()
            return
        }

        do {
            try createPackage()
            let addon = try await AddonRuntime.shared.install(url: packageURL.absoluteString, installMethod: .manager)
            _ = try? await AddonRuntime.shared.setAllowedInPrivateBrowsing(addon, allowed: true)
            defaults.set(addon.id, forKey: Key.addonID)
        } catch {
            defaults.removeObject(forKey: Key.addonID)
        }
        notifyChange()
    }

    private func scheduleRuntimeSync() {
        guard !pendingRuntimeSync else { return }
        pendingRuntimeSync = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.pendingRuntimeSync = false }
            await self.synchronizeWithRuntime()
        }
        notifyChange()
    }

    private func createPackage() throws {
        let configuration: [String: Any] = [
            "advertisingEnabled": snapshot.advertisingEnabled,
            "privacyEnabled": snapshot.privacyEnabled,
            "cosmeticFilteringEnabled": snapshot.cosmeticFilteringEnabled,
            "blockedDomains": snapshot.blockedDomains,
            "allowedDomains": snapshot.allowedDomains,
        ]
        let manifest: [String: Any] = [
            "manifest_version": 2,
            "name": "Reynard 广告与隐私保护规则",
            "version": "1.0.0",
            "description": "由 Reynard 管理的广告拦截与隐私保护规则。",
            "applications": ["gecko": ["id": "browser-rules@reynard.local"]],
            "permissions": ["<all_urls>", "webRequest", "webRequestBlocking"],
            "background": ["scripts": ["background.js"]],
            "content_scripts": [[
                "matches": ["<all_urls>"],
                "js": ["content.js"],
                "run_at": "document_start",
                "all_frames": true,
            ]],
        ]
        guard let manifestData = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]),
              let configurationData = try? JSONSerialization.data(withJSONObject: configuration, options: []),
              let backgroundData = backgroundScript(configuration: configurationData).data(using: .utf8),
              let contentData = cosmeticScript(configuration: configurationData).data(using: .utf8) else {
            throw BrowserRuleStoreError.invalidDomain
        }
        let archive = Self.makeStoredZIP(entries: [
            ("manifest.json", manifestData),
            ("background.js", backgroundData),
            ("content.js", contentData),
        ])
        try archive.write(to: packageURL, options: .atomic)
    }

    private func backgroundScript(configuration: Data) -> String {
        let json = String(data: configuration, encoding: .utf8) ?? "{}"
        return """
        const config = \(json);
        const builtInAdvertisingDomains = [
          'doubleclick.net', 'googlesyndication.com', 'googleadservices.com', 'adservice.google.com',
          'adnxs.com', 'taboola.com', 'outbrain.com', 'criteo.com', 'scorecardresearch.com'
        ];
        const builtInPrivacyDomains = [
          'google-analytics.com', 'googletagmanager.com', 'facebook.net', 'connect.facebook.net',
          'hotjar.com', 'mixpanel.com', 'segment.io', 'sentry.io'
        ];
        const queryParameters = ['fbclid', 'gclid', 'dclid', 'msclkid', 'mc_cid', 'mc_eid', '_ga', '_gl'];
        const hostMatches = (host, domain) => host === domain || host.endsWith(`.${domain}`);
        const allowed = (host) => config.allowedDomains.some((domain) => hostMatches(host, domain));
        const blocked = (host) => {
          if (allowed(host)) return false;
          const custom = config.blockedDomains.some((domain) => hostMatches(host, domain));
          const advertising = config.advertisingEnabled && builtInAdvertisingDomains.some((domain) => hostMatches(host, domain));
          const privacy = config.privacyEnabled && builtInPrivacyDomains.some((domain) => hostMatches(host, domain));
          return custom || advertising || privacy;
        };
        browser.webRequest.onBeforeRequest.addListener((details) => {
          try {
            const url = new URL(details.url);
            if (blocked(url.hostname)) return { cancel: true };
            if (config.privacyEnabled && (details.type === 'main_frame' || details.type === 'sub_frame')) {
              const clean = new URL(url.toString());
              let changed = false;
              for (const parameter of queryParameters) {
                if (clean.searchParams.has(parameter)) { clean.searchParams.delete(parameter); changed = true; }
              }
              if (changed) return { redirectUrl: clean.toString() };
            }
          } catch (_) { }
          return {};
        }, { urls: ['<all_urls>'] }, ['blocking']);
        """
    }

    private func cosmeticScript(configuration: Data) -> String {
        let json = String(data: configuration, encoding: .utf8) ?? "{}"
        return """
        (() => {
          const config = \(json);
          if (!config.cosmeticFilteringEnabled || config.allowedDomains.some((domain) => location.hostname === domain || location.hostname.endsWith(`.${domain}`))) return;
          const style = document.createElement('style');
          style.id = 'reynard-privacy-filter';
          style.textContent = [
            '[id*="ad-" i]', '[id^="ad_" i]', '[class*=" ad-" i]', '[class^="ad-" i]',
            '[data-ad]', '[data-ad-slot]', '[data-ad-client]', 'iframe[src*="doubleclick.net"]',
            'iframe[src*="googlesyndication.com"]', 'ins.adsbygoogle', '.advertisement', '.advertising'
          ].join(',') + '{display:none!important;visibility:hidden!important;}';
          (document.documentElement || document).appendChild(style);
        })();
        """
    }

    private func validatedDomain(_ value: String) throws -> String {
        let candidate = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/").first.map(String.init) ?? ""
        guard candidate.contains("."),
              candidate.range(of: "^[a-z0-9.-]+$", options: .regularExpression) != nil else {
            throw BrowserRuleStoreError.invalidDomain
        }
        return candidate
    }

    private func normalizedDomains(_ domains: [String]) -> [String] {
        Array(Set(domains.compactMap { try? validatedDomain($0) })).sorted()
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .browserRuleStoreDidChange, object: self)
        }
    }

    private static func makeStoredZIP(entries: [(String, Data)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0
        for (name, contents) in entries {
            let nameData = Data(name.utf8)
            let crc = crc32(contents)
            appendUInt32(0x04034b50, to: &archive); appendUInt16(20, to: &archive); appendUInt16(0, to: &archive); appendUInt16(0, to: &archive); appendUInt16(0, to: &archive); appendUInt16(0, to: &archive)
            appendUInt32(crc, to: &archive); appendUInt32(UInt32(contents.count), to: &archive); appendUInt32(UInt32(contents.count), to: &archive); appendUInt16(UInt16(nameData.count), to: &archive); appendUInt16(0, to: &archive)
            archive.append(nameData); archive.append(contents)
            appendUInt32(0x02014b50, to: &centralDirectory); appendUInt16(20, to: &centralDirectory); appendUInt16(20, to: &centralDirectory); appendUInt16(0, to: &centralDirectory); appendUInt16(0, to: &centralDirectory); appendUInt16(0, to: &centralDirectory); appendUInt16(0, to: &centralDirectory)
            appendUInt32(crc, to: &centralDirectory); appendUInt32(UInt32(contents.count), to: &centralDirectory); appendUInt32(UInt32(contents.count), to: &centralDirectory); appendUInt16(UInt16(nameData.count), to: &centralDirectory); appendUInt16(0, to: &centralDirectory); appendUInt16(0, to: &centralDirectory); appendUInt16(0, to: &centralDirectory); appendUInt16(0, to: &centralDirectory); appendUInt32(0, to: &centralDirectory); appendUInt32(offset, to: &centralDirectory)
            centralDirectory.append(nameData)
            offset = UInt32(archive.count)
        }
        let centralOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        appendUInt32(0x06054b50, to: &archive); appendUInt16(0, to: &archive); appendUInt16(0, to: &archive); appendUInt16(UInt16(entries.count), to: &archive); appendUInt16(UInt16(entries.count), to: &archive); appendUInt32(UInt32(centralDirectory.count), to: &archive); appendUInt32(centralOffset, to: &archive); appendUInt16(0, to: &archive)
        return archive
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var value: UInt32 = 0xFFFFFFFF
        for byte in data {
            value ^= UInt32(byte)
            for _ in 0..<8 { value = value & 1 == 1 ? (value >> 1) ^ 0xEDB88320 : value >> 1 }
        }
        return value ^ 0xFFFFFFFF
    }
}

extension Notification.Name {
    static let browserRuleStoreDidChange = Notification.Name("com.minh-ton.Reynard.browserRuleStoreDidChange")
}
