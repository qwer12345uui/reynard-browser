//
//  UserAgentPolicy.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import Foundation
import GeckoView

// MARK: - User Agent Configuration

struct UserAgentConfiguration {
    let override: String?
    let platformOverride: String?
    let appVersionOverride: String?
    let oscpuOverride: String?
    let forcesMobileMode: Bool
}

struct UserAgentPolicy {
    // MARK: - Policy Resolution
    
    func configuration(for url: String, prefersDesktopMode: Bool) -> UserAgentConfiguration {
        let host = DomainMatcher.host(from: url)
        let geckoMajorVersion = GeckoRuntime.version.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? "0"
        let chromeMajorVersion = (Int(geckoMajorVersion) ?? 0) + 4
        
        // It's sad to have the Android UA, because Gecko + iOS
        // is a super weird combination that websites don't expect!
        let androidMobileUserAgent = "Mozilla/5.0 (Android 15; Mobile; rv:\(geckoMajorVersion).0) Gecko/\(geckoMajorVersion).0 Firefox/\(geckoMajorVersion).0"
        let androidDesktopUserAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:\(geckoMajorVersion).0) Gecko/20100101 Firefox/\(geckoMajorVersion).0"
        let googleMobileUserAgent = "Mozilla/5.0 (Linux; Android 15; Nexus 5 Build/MRA58N) FxQuantum/\(geckoMajorVersion).0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromeMajorVersion).0.0.0 Mobile Safari/537.36"
        let androidMobilePlatform = "Linux armv81"
        let androidDesktopPlatform = "Linux x86_64"
        let androidMobileAppVersion = "5.0 (Android 15)"
        let androidDesktopAppVersion = "5.0 (X11)"
        
        // Always use the Android mobile user agent for AMO to
        // allow addons installation.
        if host == "addons.mozilla.org" {
            return UserAgentConfiguration(
                override: androidMobileUserAgent,
                platformOverride: androidMobilePlatform,
                appVersionOverride: androidMobileAppVersion,
                oscpuOverride: androidMobilePlatform,
                forcesMobileMode: true
            )
        }
        
        // Addon setting pages also require the Android user agent to work properly.
        if url.starts(with: "moz-extension://") {
            return UserAgentConfiguration(
                override: androidMobileUserAgent,
                platformOverride: androidMobilePlatform,
                appVersionOverride: androidMobileAppVersion,
                oscpuOverride: androidMobilePlatform,
                forcesMobileMode: true
            )
        }
        
        // I have so many people reporting broken UI issues, login
        // issues, etc on Google services, so this is a compatibility
        // hack stolen from the Google Search Fixer extension.
        if Prefs.CompatibilitySettings.useAndroidUserAgent && !prefersDesktopMode,
           host?.split(separator: ".").contains("google") == true {
            return UserAgentConfiguration(
                override: googleMobileUserAgent,
                platformOverride: androidMobilePlatform,
                appVersionOverride: androidMobileAppVersion,
                oscpuOverride: androidMobilePlatform,
                forcesMobileMode: false
            )
        }
        
        let usesAndroidUserAgent = Prefs.CompatibilitySettings.useAndroidUserAgent || (host.map { host in
            Prefs.CompatibilitySettings.androidUserAgentDomains.contains { DomainMatcher.matches(host: host, domain: $0) }
        } ?? false)
        
        guard usesAndroidUserAgent else {
            return UserAgentConfiguration(
                override: nil,
                platformOverride: nil,
                appVersionOverride: nil,
                oscpuOverride: nil,
                forcesMobileMode: false
            )
        }
        return UserAgentConfiguration(
            override: prefersDesktopMode ? androidDesktopUserAgent : androidMobileUserAgent,
            platformOverride: prefersDesktopMode ? androidDesktopPlatform : androidMobilePlatform,
            appVersionOverride: prefersDesktopMode ? androidDesktopAppVersion : androidMobileAppVersion,
            oscpuOverride: prefersDesktopMode ? androidDesktopPlatform : androidMobilePlatform,
            forcesMobileMode: false
        )
    }
}
