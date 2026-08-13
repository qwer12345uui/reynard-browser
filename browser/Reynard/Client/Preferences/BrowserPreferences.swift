//
//  BrowserPreferences.swift
//  Reynard
//
//  Created by Minh Ton on 10/3/26.
//

import Foundation
import GeckoView
import UIKit

typealias Prefs = BrowserPreferences

enum VideoDecoderPreference: String, CaseIterable {
    case automatic
}

enum PlaybackSpeedPreference: Double, CaseIterable {
    case one = 1.0
    case oneAndHalf = 1.5
    case two = 2.0
}

enum PlaybackSeekGesturePreference: String, CaseIterable {
    case adaptive
    case tenSeconds
    case fifteenSeconds
    case thirtySeconds
}

enum PlaybackTriggerCorner: String, CaseIterable {
    case bottomRight
    case bottomLeft
}

enum DownloadListSortOrder: String, CaseIterable {
    case newestFirst
    case oldestFirst
    case fileName
}

enum ImageSaveLocation: String, CaseIterable {
    case downloads
    case photoLibrary
}

final class BrowserPreferences {
    static var shared = BrowserPreferences()
    
    let profile: String
    
    init(profile: String = "default") {
        self.profile = profile
        registerDefaults()
    }
    
    // Possible future work
    static func useProfile(_ name: String) {
        shared = BrowserPreferences(profile: name)
    }
    
    func key(_ setting: String, _ name: String) -> String {
        "\(profile).\(setting).\(name)"
    }
    
    func registerDefaults() {
        let donationRecommendationShowTimeKey = key("HomepageSettings", "donationRecommendationShowTime")
        if UserDefaults.standard.object(forKey: donationRecommendationShowTimeKey) == nil {
            let delay = TimeInterval.random(in: (3 * 86_400)...(5 * 86_400))
            UserDefaults.standard.set(Date().addingTimeInterval(delay).timeIntervalSince1970, forKey: donationRecommendationShowTimeKey)
        }
        
        UserDefaults.standard.register(defaults: [
            // Search
            key("SearchSettings", "searchEngine"): SearchEngine.google.rawValue,
            key("SearchSettings", "customSearchTemplate"): "",
            key("SearchSettings", "searchSuggestionProvider"): SearchCompletion.Provider.google.rawValue,
            key("SearchSettings", "showSearchSuggestions"): true,
            key("SearchSettings", "showSearchSuggestionsInPrivateBrowsing"): true,
            key("SearchSettings", "searchBrowsingHistory"): true,
            key("SearchSettings", "searchBookmarks"): true,
            key("SearchSettings", "searchOpenedTabs"): true,
            
            // JIT
            key("JITSettings", "isJITEnabled"): false,
            
            // Experimental
            key("ExperimentalSettings", "isVideoPictureInPictureEnabled"): false,
            
            // Downloads
            key("DownloadSettings", "confirmManualDownloads"): true,
            key("DownloadSettings", "continuesInBackground"): true,
            key("DownloadSettings", "backgroundTimeLimit"): 300,
            key("DownloadSettings", "listSortOrder"): DownloadListSortOrder.newestFirst.rawValue,
            key("DownloadSettings", "imageSaveLocation"): ImageSaveLocation.downloads.rawValue,
            key("DownloadSettings", "maxConcurrentDownloads"): 3,
            key("DownloadSettings", "automaticallyMergeM3U8ToMP4"): true,
            key("DownloadSettings", "allowsCellularDownloads"): true,
            key("DownloadSettings", "automaticRetryCount"): 30,
            key("DownloadSettings", "retryIndefinitely"): false,
            key("DownloadSettings", "autoBookmarkDownloadedVideos"): false,
            key("DownloadSettings", "playsCompletionSound"): true,

            // Privacy
            key("PrivateBrowsingSettings", "allowsCookies"): true,
            key("PrivateBrowsingSettings", "remembersLoginState"): true,

            // Security
            key("SecuritySettings", "gesturePasswordEnabled"): false,

            // Bottom toolbar
            key("ToolbarSettings", "longPressQuickActions"): true,

            // Clipboard
            key("ClipboardSettings", "automaticallyParseURLs"): false,
            key("ClipboardSettings", "lastHandledChangeCount"): 0,

            // Playback
            key("PlaybackSettings", "openVideosInNewTab"): true,
            key("PlaybackSettings", "videoDecoder"): VideoDecoderPreference.automatic.rawValue,
            key("PlaybackSettings", "longPressPlaybackSpeed"): PlaybackSpeedPreference.two.rawValue,
            key("PlaybackSettings", "allowsMultiplePlayers"): true,
            key("PlaybackSettings", "allowsWebMediaAutoplay"): true,
            key("PlaybackSettings", "seekGesture"): PlaybackSeekGesturePreference.adaptive.rawValue,
            key("PlaybackSettings", "allowsPictureInPicture"): false,
            key("PlaybackSettings", "entersPictureInPictureInBackground"): false,
            key("PlaybackSettings", "allowsBackgroundPlayback"): false,
            key("PlaybackSettings", "mutesByDefault"): false,
            key("PlaybackSettings", "remembersPlaybackPosition"): true,
            key("PlaybackSettings", "swipeDownEntersMiniPlayer"): false,
            key("PlaybackSettings", "triggerCorner"): PlaybackTriggerCorner.bottomRight.rawValue,
            key("PlaybackSettings", "showsControls"): true,

            // Compatibility
            key("CompatibilitySettings", "androidUserAgentDomains"): [],
            key("CompatibilitySettings", "useAndroidUserAgent"): true,
            
            // Browsing
            key("BrowsingSettings", "requestDesktopWebsite"): UIDevice.current.userInterfaceIdiom == .pad,
            key("BrowsingSettings", "showLinkPreviews"): true,
            key("BrowsingSettings", "showImagePreviews"): true,
            key("BrowsingSettings", "openLinksInExternalApps"): true,
            key("BrowsingSettings", "defaultPageZoomLevel"): PageZoomLevels.defaultLevel,
            
            // New Tab
            key("NewTabSettings", "newTabDisplayOption"): NewTabDisplayOption.homepage.rawValue,
            key("NewTabSettings", "customNewTabURL"): "",
            
            // Homepage
            key("HomepageSettings", "openingScreen"): HomepageOpeningScreen.homepage.rawValue,
            key("HomepageSettings", "showsFavorites"): true,
            key("HomepageSettings", "showsFavoritesInPrivateBrowsing"): false,
            key("HomepageSettings", "favoriteRowCount"): 2,
            key("HomepageSettings", "showsFrequentlyVisited"): true,
            key("HomepageSettings", "showsFrequentlyVisitedInPrivateBrowsing"): false,
            key("HomepageSettings", "frequentlyVisitedSiteCount"): 8,
            key("HomepageSettings", "showsRecentlyClosedTabs"): true,
            key("HomepageSettings", "recentlyClosedTabLimit"): 10,
            key("HomepageSettings", "showsRecommendations"): true,
            key("HomepageSettings", "showsNewUpdates"): true,
            key("HomepageSettings", "showsWallpaper"): false,
            key("HomepageSettings", "donationRecommendationMultiplier"): 1,
            
            // Appearance
            key("AppearanceSettings", "appAppearance"): AppAppearance.system.rawValue,
            key("AppearanceSettings", "addressBarPosition"): BrowserChromePosition.bottom.rawValue,
            key("AppearanceSettings", "showsFullWebsiteAddress"): false,
            key("AppearanceSettings", "showsLandscapeTabBar"): true,
            
            // Languages
            key("LanguageSettings", "websiteLanguages"): (try? JSONEncoder().encode(WebsiteLanguageCatalog.defaultLanguageCodes())) ?? Data(),
            
            // Bookmarks
            key("BookmarkSettings", "placeFoldersOnTop"): true,
            key("BookmarkSettings", "sortOrders"): BookmarkSortOrder.none.rawValue,
            
            // Add-ons
            key("AddonSettings", "lastGlobalCheckAt"): "",
            key("AddonSettings", "pendingApprovalAddonIDs"): Data(),
            
            // Site Permissions
            key("SitePermissionSettings", "defaultAutoplayPermission"): SitePermissionAction.askToAllow.rawValue,
            key("SitePermissionSettings", "defaultCameraPermission"): SitePermissionAction.askToAllow.rawValue,
            key("SitePermissionSettings", "defaultMicrophonePermission"): SitePermissionAction.askToAllow.rawValue,
            key("SitePermissionSettings", "defaultLocationPermission"): SitePermissionAction.askToAllow.rawValue,
            key("SitePermissionSettings", "defaultPersistentStoragePermission"): SitePermissionAction.askToAllow.rawValue,
            key("SitePermissionSettings", "defaultCrossOriginStorageAccessPermission"): SitePermissionAction.askToAllow.rawValue,
            key("SitePermissionSettings", "defaultLocalDeviceAccessPermission"): SitePermissionAction.askToAllow.rawValue,
            key("SitePermissionSettings", "defaultLocalNetworkAccessPermission"): SitePermissionAction.askToAllow.rawValue,
            
            // Clear Browsing Data
            key("ClearBrowsingData", "clearsBrowsingHistory"): true,
            key("ClearBrowsingData", "clearsCookiesAndSiteData"): true,
            key("ClearBrowsingData", "clearsCachedImagesAndFiles"): true,
            key("ClearBrowsingData", "clearsDownloadedFiles"): false,
            key("ClearBrowsingData", "clearsSitePermissions"): true,
            key("ClearBrowsingData", "clearsOpenedTabs"): true,
            
            // HTTPS-Only Mode
            key("HTTPSOnlyMode", "enabled"): false,
            key("HTTPSOnlyMode", "scope"): HTTPSOnlyModeScope.allTabs.rawValue,
            
            // Tracking Protection
            key("TrackingProtection", "enhancedTrackingProtectionLevel"): TrackingProtectionLevel.standard.rawValue,
            key("TrackingProtection", "strictBaselineAllowListEnabled"): true,
            key("TrackingProtection", "strictConvenienceAllowListEnabled"): false,
            key("TrackingProtection", "customBaselineAllowListEnabled"): true,
            key("TrackingProtection", "customConvenienceAllowListEnabled"): false,
            key("TrackingProtection", "customCookiePolicy"): CustomCookiePolicy.isolateCrossSite.rawValue,
            key("TrackingProtection", "customTrackingContentScope"): CustomBlockingScope.all.rawValue,
            key("TrackingProtection", "customBlocksCryptominers"): true,
            key("TrackingProtection", "customBlocksKnownFingerprinters"): true,
            key("TrackingProtection", "customBlocksRedirectTrackers"): true,
            key("TrackingProtection", "customSuspectedFingerprinterScope"): CustomBlockingScope.privateOnly.rawValue,
            key("TrackingProtection", "globalPrivacyControlEnabled"): false,
        ])
    }
    
    func bool(forSetting setting: String, key name: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(setting, name))
    }
    
    func string(forSetting setting: String, key name: String) -> String? {
        UserDefaults.standard.string(forKey: key(setting, name))
    }
    
    func data(forSetting setting: String, key name: String) -> Data? {
        UserDefaults.standard.data(forKey: key(setting, name))
    }
    
    func double(forSetting setting: String, key name: String) -> Double {
        UserDefaults.standard.double(forKey: key(setting, name))
    }
    
    func integer(forSetting setting: String, key name: String) -> Int {
        UserDefaults.standard.integer(forKey: key(setting, name))
    }
    
    func set(_ value: Bool, forSetting setting: String, key name: String) {
        UserDefaults.standard.set(value, forKey: key(setting, name))
    }
    
    func set(_ value: String?, forSetting setting: String, key name: String) {
        UserDefaults.standard.set(value, forKey: key(setting, name))
    }
    
    func set(_ value: Data?, forSetting setting: String, key name: String) {
        UserDefaults.standard.set(value, forKey: key(setting, name))
    }
    
    func set(_ value: Double, forSetting setting: String, key name: String) {
        UserDefaults.standard.set(value, forKey: key(setting, name))
    }
    
    func set(_ value: Int, forSetting setting: String, key name: String) {
        UserDefaults.standard.set(value, forKey: key(setting, name))
    }
    
    // MARK: - Search
    struct SearchSettings {
        static var searchEngine: SearchEngine {
            get {
                let rawValue = prefs.string(forSetting: "SearchSettings", key: "searchEngine") ?? SearchEngine.google.rawValue
                return SearchEngine(rawValue: rawValue) ?? .google
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SearchSettings", key: "searchEngine")
            }
        }
        
        static var customSearchTemplate: String {
            get {
                return prefs.string(forSetting: "SearchSettings", key: "customSearchTemplate") ?? ""
            }
            set {
                prefs.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forSetting: "SearchSettings", key: "customSearchTemplate")
            }
        }
        
        static var searchSuggestionProvider: SearchCompletion.Provider {
            get {
                let rawValue = prefs.string(forSetting: "SearchSettings", key: "searchSuggestionProvider") ?? SearchCompletion.Provider.google.rawValue
                return SearchCompletion.Provider(rawValue: rawValue) ?? .google
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SearchSettings", key: "searchSuggestionProvider")
            }
        }
        
        static var showSearchSuggestions: Bool {
            get {
                return prefs.bool(forSetting: "SearchSettings", key: "showSearchSuggestions")
            }
            set {
                prefs.set(newValue, forSetting: "SearchSettings", key: "showSearchSuggestions")
            }
        }
        
        static var showSearchSuggestionsInPrivateBrowsing: Bool {
            get {
                return prefs.bool(forSetting: "SearchSettings", key: "showSearchSuggestionsInPrivateBrowsing")
            }
            set {
                prefs.set(newValue, forSetting: "SearchSettings", key: "showSearchSuggestionsInPrivateBrowsing")
            }
        }
        
        static var searchBrowsingHistory: Bool {
            get {
                return prefs.bool(forSetting: "SearchSettings", key: "searchBrowsingHistory")
            }
            set {
                prefs.set(newValue, forSetting: "SearchSettings", key: "searchBrowsingHistory")
            }
        }
        
        static var searchBookmarks: Bool {
            get {
                return prefs.bool(forSetting: "SearchSettings", key: "searchBookmarks")
            }
            set {
                prefs.set(newValue, forSetting: "SearchSettings", key: "searchBookmarks")
            }
        }
        
        static var searchOpenedTabs: Bool {
            get {
                return prefs.bool(forSetting: "SearchSettings", key: "searchOpenedTabs")
            }
            set {
                prefs.set(newValue, forSetting: "SearchSettings", key: "searchOpenedTabs")
            }
        }
    }
    
    // MARK: - Downloads
    struct DownloadSettings {
        static var confirmManualDownloads: Bool {
            get {
                prefs.bool(forSetting: "DownloadSettings", key: "confirmManualDownloads")
            }
            set {
                prefs.set(newValue, forSetting: "DownloadSettings", key: "confirmManualDownloads")
            }
        }

        static var continuesInBackground: Bool {
            get {
                prefs.bool(forSetting: "DownloadSettings", key: "continuesInBackground")
            }
            set {
                prefs.set(newValue, forSetting: "DownloadSettings", key: "continuesInBackground")
            }
        }

        /// The maximum grace period granted to active downloads after the app enters the background.
        /// Zero means to pause immediately; the operating system may end any non-zero period early.
        static var backgroundTimeLimit: TimeInterval {
            get {
                let storedValue = prefs.integer(forSetting: "DownloadSettings", key: "backgroundTimeLimit")
                return TimeInterval(max(0, min(storedValue, 1_800)))
            }
            set {
                let boundedValue = max(0, min(Int(newValue.rounded()), 1_800))
                prefs.set(boundedValue, forSetting: "DownloadSettings", key: "backgroundTimeLimit")
            }
        }

        static var listSortOrder: DownloadListSortOrder {
            get {
                let value = prefs.string(forSetting: "DownloadSettings", key: "listSortOrder") ?? DownloadListSortOrder.newestFirst.rawValue
                return DownloadListSortOrder(rawValue: value) ?? .newestFirst
            }
            set { prefs.set(newValue.rawValue, forSetting: "DownloadSettings", key: "listSortOrder") }
        }

        static var imageSaveLocation: ImageSaveLocation {
            get {
                let value = prefs.string(forSetting: "DownloadSettings", key: "imageSaveLocation") ?? ImageSaveLocation.downloads.rawValue
                return ImageSaveLocation(rawValue: value) ?? .downloads
            }
            set { prefs.set(newValue.rawValue, forSetting: "DownloadSettings", key: "imageSaveLocation") }
        }

        static var maxConcurrentDownloads: Int {
            get { max(1, min(prefs.integer(forSetting: "DownloadSettings", key: "maxConcurrentDownloads"), 8)) }
            set { prefs.set(max(1, min(newValue, 8)), forSetting: "DownloadSettings", key: "maxConcurrentDownloads") }
        }

        static var automaticallyMergeM3U8ToMP4: Bool {
            get { prefs.bool(forSetting: "DownloadSettings", key: "automaticallyMergeM3U8ToMP4") }
            set { prefs.set(newValue, forSetting: "DownloadSettings", key: "automaticallyMergeM3U8ToMP4") }
        }

        static var allowsCellularDownloads: Bool {
            get { prefs.bool(forSetting: "DownloadSettings", key: "allowsCellularDownloads") }
            set { prefs.set(newValue, forSetting: "DownloadSettings", key: "allowsCellularDownloads") }
        }

        static var automaticRetryCount: Int {
            get { max(0, min(prefs.integer(forSetting: "DownloadSettings", key: "automaticRetryCount"), 100)) }
            set { prefs.set(max(0, min(newValue, 100)), forSetting: "DownloadSettings", key: "automaticRetryCount") }
        }

        static var retryIndefinitely: Bool {
            get { prefs.bool(forSetting: "DownloadSettings", key: "retryIndefinitely") }
            set { prefs.set(newValue, forSetting: "DownloadSettings", key: "retryIndefinitely") }
        }

        static var autoBookmarkDownloadedVideos: Bool {
            get { prefs.bool(forSetting: "DownloadSettings", key: "autoBookmarkDownloadedVideos") }
            set { prefs.set(newValue, forSetting: "DownloadSettings", key: "autoBookmarkDownloadedVideos") }
        }

        static var playsCompletionSound: Bool {
            get { prefs.bool(forSetting: "DownloadSettings", key: "playsCompletionSound") }
            set { prefs.set(newValue, forSetting: "DownloadSettings", key: "playsCompletionSound") }
        }
    }

    // MARK: - Private Browsing
    struct PrivateBrowsingSettings {
        static var allowsCookies: Bool {
            get { prefs.bool(forSetting: "PrivateBrowsingSettings", key: "allowsCookies") }
            set { prefs.set(newValue, forSetting: "PrivateBrowsingSettings", key: "allowsCookies") }
        }

        static var remembersLoginState: Bool {
            get { prefs.bool(forSetting: "PrivateBrowsingSettings", key: "remembersLoginState") }
            set { prefs.set(newValue, forSetting: "PrivateBrowsingSettings", key: "remembersLoginState") }
        }

        /// Gecko applies these preferences only to private contexts. Existing regular tabs are never changed.
        static func applyRuntimePolicy() {
            GeckoRuntime.setDefaultPrefs([
                "network.cookie.cookieBehavior.pbmode": allowsCookies ? 0 : 2,
                "signon.privateBrowsingCaptureEnabled": remembersLoginState,
                "signon.rememberSignons": remembersLoginState,
            ])
        }
    }

    // MARK: - Security
    struct SecuritySettings {
        static var gesturePasswordEnabled: Bool {
            get {
                prefs.bool(forSetting: "SecuritySettings", key: "gesturePasswordEnabled") && GesturePasswordStore.hasPassword
            }
            set {
                prefs.set(newValue && GesturePasswordStore.hasPassword, forSetting: "SecuritySettings", key: "gesturePasswordEnabled")
            }
        }
    }

    // MARK: - Bottom Toolbar
    struct ToolbarSettings {
        static let defaultBottomButtonOrder = ["back", "forward", "share", "basket", "downloads", "tabs"]

        static var bottomButtonOrder: [String] {
            get {
                guard let data = prefs.data(forSetting: "ToolbarSettings", key: "bottomButtonOrder"),
                      let order = try? JSONDecoder().decode([String].self, from: data) else {
                    return defaultBottomButtonOrder
                }
                let uniqueOrder = order.filter { defaultBottomButtonOrder.contains($0) }
                guard Set(uniqueOrder) == Set(defaultBottomButtonOrder), uniqueOrder.count == defaultBottomButtonOrder.count else {
                    return defaultBottomButtonOrder
                }
                return uniqueOrder
            }
            set {
                let uniqueOrder = newValue.filter { defaultBottomButtonOrder.contains($0) }
                guard Set(uniqueOrder) == Set(defaultBottomButtonOrder), uniqueOrder.count == defaultBottomButtonOrder.count else {
                    return
                }
                prefs.set(try? JSONEncoder().encode(uniqueOrder), forSetting: "ToolbarSettings", key: "bottomButtonOrder")
                NotificationCenter.default.post(name: .bottomToolbarPreferencesDidChange, object: nil)
            }
        }

        static var longPressQuickActions: Bool {
            get {
                prefs.bool(forSetting: "ToolbarSettings", key: "longPressQuickActions")
            }
            set {
                prefs.set(newValue, forSetting: "ToolbarSettings", key: "longPressQuickActions")
                NotificationCenter.default.post(name: .bottomToolbarPreferencesDidChange, object: nil)
            }
        }
    }

    // MARK: - Clipboard
    struct ClipboardSettings {
        static var automaticallyParseURLs: Bool {
            get {
                prefs.bool(forSetting: "ClipboardSettings", key: "automaticallyParseURLs")
            }
            set {
                prefs.set(newValue, forSetting: "ClipboardSettings", key: "automaticallyParseURLs")
            }
        }

        static var lastHandledChangeCount: Int {
            get {
                prefs.integer(forSetting: "ClipboardSettings", key: "lastHandledChangeCount")
            }
            set {
                prefs.set(newValue, forSetting: "ClipboardSettings", key: "lastHandledChangeCount")
            }
        }
    }

    // MARK: - Playback
    struct PlaybackSettings {
        static var openVideosInNewTab: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "openVideosInNewTab") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "openVideosInNewTab") }
        }

        static var videoDecoder: VideoDecoderPreference {
            get {
                let value = prefs.string(forSetting: "PlaybackSettings", key: "videoDecoder") ?? VideoDecoderPreference.automatic.rawValue
                return VideoDecoderPreference(rawValue: value) ?? .automatic
            }
            set { prefs.set(newValue.rawValue, forSetting: "PlaybackSettings", key: "videoDecoder") }
        }

        static var longPressPlaybackSpeed: PlaybackSpeedPreference {
            get {
                let value = prefs.double(forSetting: "PlaybackSettings", key: "longPressPlaybackSpeed")
                return PlaybackSpeedPreference(rawValue: value) ?? .two
            }
            set { prefs.set(newValue.rawValue, forSetting: "PlaybackSettings", key: "longPressPlaybackSpeed") }
        }

        static var allowsMultiplePlayers: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "allowsMultiplePlayers") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "allowsMultiplePlayers") }
        }

        static var allowsWebMediaAutoplay: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "allowsWebMediaAutoplay") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "allowsWebMediaAutoplay") }
        }

        static var seekGesture: PlaybackSeekGesturePreference {
            get {
                let value = prefs.string(forSetting: "PlaybackSettings", key: "seekGesture") ?? PlaybackSeekGesturePreference.adaptive.rawValue
                return PlaybackSeekGesturePreference(rawValue: value) ?? .adaptive
            }
            set { prefs.set(newValue.rawValue, forSetting: "PlaybackSettings", key: "seekGesture") }
        }

        static var allowsPictureInPicture: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "allowsPictureInPicture") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "allowsPictureInPicture") }
        }

        static var entersPictureInPictureInBackground: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "entersPictureInPictureInBackground") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "entersPictureInPictureInBackground") }
        }

        static var allowsBackgroundPlayback: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "allowsBackgroundPlayback") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "allowsBackgroundPlayback") }
        }

        static var mutesByDefault: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "mutesByDefault") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "mutesByDefault") }
        }

        static var remembersPlaybackPosition: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "remembersPlaybackPosition") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "remembersPlaybackPosition") }
        }

        static var swipeDownEntersMiniPlayer: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "swipeDownEntersMiniPlayer") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "swipeDownEntersMiniPlayer") }
        }

        static var triggerCorner: PlaybackTriggerCorner {
            get {
                let value = prefs.string(forSetting: "PlaybackSettings", key: "triggerCorner") ?? PlaybackTriggerCorner.bottomRight.rawValue
                return PlaybackTriggerCorner(rawValue: value) ?? .bottomRight
            }
            set { prefs.set(newValue.rawValue, forSetting: "PlaybackSettings", key: "triggerCorner") }
        }

        static var showsControls: Bool {
            get { prefs.bool(forSetting: "PlaybackSettings", key: "showsControls") }
            set { prefs.set(newValue, forSetting: "PlaybackSettings", key: "showsControls") }
        }
    }

    // MARK: - Browsing
    struct BrowsingSettings {
        static var requestDesktopWebsite: Bool {
            get {
                return prefs.bool(forSetting: "BrowsingSettings", key: "requestDesktopWebsite")
            }
            set {
                prefs.set(newValue, forSetting: "BrowsingSettings", key: "requestDesktopWebsite")
            }
        }
        
        static var showLinkPreviews: Bool {
            get {
                return prefs.bool(forSetting: "BrowsingSettings", key: "showLinkPreviews")
            }
            set {
                prefs.set(newValue, forSetting: "BrowsingSettings", key: "showLinkPreviews")
            }
        }
        
        static var showImagePreviews: Bool {
            get {
                return prefs.bool(forSetting: "BrowsingSettings", key: "showImagePreviews")
            }
            set {
                prefs.set(newValue, forSetting: "BrowsingSettings", key: "showImagePreviews")
            }
        }
        
        static var openLinksInExternalApps: Bool {
            get {
                return prefs.bool(forSetting: "BrowsingSettings", key: "openLinksInExternalApps")
            }
            set {
                prefs.set(newValue, forSetting: "BrowsingSettings", key: "openLinksInExternalApps")
            }
        }
        
        static var defaultPageZoomLevel: Int {
            get {
                let level = prefs.integer(forSetting: "BrowsingSettings", key: "defaultPageZoomLevel")
                return PageZoomLevels.all.contains(level) ? level : PageZoomLevels.defaultLevel
            }
            set {
                guard PageZoomLevels.all.contains(newValue) else {
                    return
                }
                prefs.set(newValue, forSetting: "BrowsingSettings", key: "defaultPageZoomLevel")
            }
        }
    }
    
    // MARK: - Clear Browsing Data
    struct ClearBrowsingData {
        static var clearsBrowsingHistory: Bool {
            get {
                return prefs.bool(forSetting: "ClearBrowsingData", key: "clearsBrowsingHistory")
            }
            set {
                prefs.set(newValue, forSetting: "ClearBrowsingData", key: "clearsBrowsingHistory")
            }
        }
        
        static var clearsCookiesAndSiteData: Bool {
            get {
                return prefs.bool(forSetting: "ClearBrowsingData", key: "clearsCookiesAndSiteData")
            }
            set {
                prefs.set(newValue, forSetting: "ClearBrowsingData", key: "clearsCookiesAndSiteData")
            }
        }
        
        static var clearsCachedImagesAndFiles: Bool {
            get {
                return prefs.bool(forSetting: "ClearBrowsingData", key: "clearsCachedImagesAndFiles")
            }
            set {
                prefs.set(newValue, forSetting: "ClearBrowsingData", key: "clearsCachedImagesAndFiles")
            }
        }
        
        static var clearsDownloadedFiles: Bool {
            get {
                return prefs.bool(forSetting: "ClearBrowsingData", key: "clearsDownloadedFiles")
            }
            set {
                prefs.set(newValue, forSetting: "ClearBrowsingData", key: "clearsDownloadedFiles")
            }
        }
        
        static var clearsSitePermissions: Bool {
            get {
                return prefs.bool(forSetting: "ClearBrowsingData", key: "clearsSitePermissions")
            }
            set {
                prefs.set(newValue, forSetting: "ClearBrowsingData", key: "clearsSitePermissions")
            }
        }
        
        static var clearsOpenedTabs: Bool {
            get {
                return prefs.bool(forSetting: "ClearBrowsingData", key: "clearsOpenedTabs")
            }
            set {
                prefs.set(newValue, forSetting: "ClearBrowsingData", key: "clearsOpenedTabs")
            }
        }
    }
    
    // MARK: - HTTPS-Only Mode
    struct HTTPSOnlyModePreferences {
        static var enabled: Bool {
            get {
                return prefs.bool(forSetting: "HTTPSOnlyMode", key: "enabled")
            }
            set {
                prefs.set(newValue, forSetting: "HTTPSOnlyMode", key: "enabled")
            }
        }
        
        static var scope: HTTPSOnlyModeScope {
            get {
                let rawValue = prefs.string(forSetting: "HTTPSOnlyMode", key: "scope") ?? HTTPSOnlyModeScope.allTabs.rawValue
                return HTTPSOnlyModeScope(rawValue: rawValue) ?? .allTabs
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "HTTPSOnlyMode", key: "scope")
            }
        }
    }
    
    // MARK: - Tracking Protection
    struct TrackingProtectionPreferences {
        static var level: TrackingProtectionLevel {
            get {
                let rawValue = prefs.string(forSetting: "TrackingProtection", key: "enhancedTrackingProtectionLevel") ?? TrackingProtectionLevel.standard.rawValue
                return TrackingProtectionLevel(rawValue: rawValue) ?? .standard
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "TrackingProtection", key: "enhancedTrackingProtectionLevel")
            }
        }
        
        static var strictBaselineAllowListEnabled: Bool {
            get {
                return prefs.bool(forSetting: "TrackingProtection", key: "strictBaselineAllowListEnabled")
            }
            set {
                prefs.set(newValue, forSetting: "TrackingProtection", key: "strictBaselineAllowListEnabled")
            }
        }
        
        static var strictConvenienceAllowListEnabled: Bool {
            get {
                return prefs.bool(forSetting: "TrackingProtection", key: "strictConvenienceAllowListEnabled")
            }
            set {
                prefs.set(newValue, forSetting: "TrackingProtection", key: "strictConvenienceAllowListEnabled")
            }
        }
        
        static var customBaselineAllowListEnabled: Bool {
            get { return prefs.bool(forSetting: "TrackingProtection", key: "customBaselineAllowListEnabled") }
            set { prefs.set(newValue, forSetting: "TrackingProtection", key: "customBaselineAllowListEnabled") }
        }
        
        static var customConvenienceAllowListEnabled: Bool {
            get { return prefs.bool(forSetting: "TrackingProtection", key: "customConvenienceAllowListEnabled") }
            set { prefs.set(newValue, forSetting: "TrackingProtection", key: "customConvenienceAllowListEnabled") }
        }
        
        static var customCookiePolicy: CustomCookiePolicy {
            get {
                return CustomCookiePolicy(rawValue: prefs.integer(forSetting: "TrackingProtection", key: "customCookiePolicy")) ?? .isolateCrossSite
            }
            set { prefs.set(newValue.rawValue, forSetting: "TrackingProtection", key: "customCookiePolicy") }
        }
        
        static var customTrackingContentScope: CustomBlockingScope {
            get {
                let rawValue = prefs.string(forSetting: "TrackingProtection", key: "customTrackingContentScope") ?? CustomBlockingScope.all.rawValue
                return CustomBlockingScope(rawValue: rawValue) ?? .all
            }
            set { prefs.set(newValue.rawValue, forSetting: "TrackingProtection", key: "customTrackingContentScope") }
        }
        
        static var customBlocksCryptominers: Bool {
            get { return prefs.bool(forSetting: "TrackingProtection", key: "customBlocksCryptominers") }
            set { prefs.set(newValue, forSetting: "TrackingProtection", key: "customBlocksCryptominers") }
        }
        
        static var customBlocksKnownFingerprinters: Bool {
            get { return prefs.bool(forSetting: "TrackingProtection", key: "customBlocksKnownFingerprinters") }
            set { prefs.set(newValue, forSetting: "TrackingProtection", key: "customBlocksKnownFingerprinters") }
        }
        
        static var customBlocksRedirectTrackers: Bool {
            get { return prefs.bool(forSetting: "TrackingProtection", key: "customBlocksRedirectTrackers") }
            set { prefs.set(newValue, forSetting: "TrackingProtection", key: "customBlocksRedirectTrackers") }
        }
        
        static var customSuspectedFingerprinterScope: CustomBlockingScope {
            get {
                let rawValue = prefs.string(forSetting: "TrackingProtection", key: "customSuspectedFingerprinterScope") ?? CustomBlockingScope.privateOnly.rawValue
                return CustomBlockingScope(rawValue: rawValue) ?? .privateOnly
            }
            set { prefs.set(newValue.rawValue, forSetting: "TrackingProtection", key: "customSuspectedFingerprinterScope") }
        }
        
        static var globalPrivacyControlEnabled: Bool {
            get { return prefs.bool(forSetting: "TrackingProtection", key: "globalPrivacyControlEnabled") }
            set { prefs.set(newValue, forSetting: "TrackingProtection", key: "globalPrivacyControlEnabled") }
        }
    }
    
    // MARK: - New Tab
    struct NewTabSettings {
        static var newTabDisplayOption: NewTabDisplayOption {
            get {
                let rawValue = prefs.string(forSetting: "NewTabSettings", key: "newTabDisplayOption") ?? NewTabDisplayOption.homepage.rawValue
                return NewTabDisplayOption(rawValue: rawValue) ?? .homepage
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "NewTabSettings", key: "newTabDisplayOption")
                NotificationCenter.default.post(name: .newTabDisplayOptionDidChange, object: nil)
            }
        }
        
        static var customNewTabURL: String {
            get {
                return prefs.string(forSetting: "NewTabSettings", key: "customNewTabURL") ?? ""
            }
            set {
                prefs.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forSetting: "NewTabSettings", key: "customNewTabURL")
            }
        }
    }
    
    // MARK: - Homepage
    struct HomepageSettings {
        static var openingScreen: HomepageOpeningScreen {
            get {
                let rawValue = prefs.string(forSetting: "HomepageSettings", key: "openingScreen") ?? HomepageOpeningScreen.homepage.rawValue
                return HomepageOpeningScreen(rawValue: rawValue) ?? .homepage
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "HomepageSettings", key: "openingScreen")
            }
        }
        
        static var showsFavorites: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsFavorites")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsFavorites")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var favoriteRowCount: Int {
            get {
                return prefs.integer(forSetting: "HomepageSettings", key: "favoriteRowCount")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "favoriteRowCount")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var showsFavoritesInPrivateBrowsing: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsFavoritesInPrivateBrowsing")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsFavoritesInPrivateBrowsing")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var showsFrequentlyVisited: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsFrequentlyVisited")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsFrequentlyVisited")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var showsFrequentlyVisitedInPrivateBrowsing: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsFrequentlyVisitedInPrivateBrowsing")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsFrequentlyVisitedInPrivateBrowsing")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var frequentlyVisitedSiteCount: Int {
            get {
                return prefs.integer(forSetting: "HomepageSettings", key: "frequentlyVisitedSiteCount")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "frequentlyVisitedSiteCount")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var showsRecentlyClosedTabs: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsRecentlyClosedTabs")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsRecentlyClosedTabs")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var recentlyClosedTabLimit: Int {
            get {
                return prefs.integer(forSetting: "HomepageSettings", key: "recentlyClosedTabLimit")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "recentlyClosedTabLimit")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var showsRecommendations: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsRecommendations")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsRecommendations")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var showsNewUpdates: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsNewUpdates")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsNewUpdates")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var showsWallpaper: Bool {
            get {
                return prefs.bool(forSetting: "HomepageSettings", key: "showsWallpaper")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "showsWallpaper")
                NotificationCenter.default.post(name: .homepageSettingsDidChange, object: nil)
            }
        }
        
        static var donationRecommendationShowTime: Date {
            get {
                return Date(timeIntervalSince1970: prefs.double(forSetting: "HomepageSettings", key: "donationRecommendationShowTime"))
            }
            set {
                prefs.set(newValue.timeIntervalSince1970, forSetting: "HomepageSettings", key: "donationRecommendationShowTime")
            }
        }
        
        static var donationRecommendationMultiplier: Int {
            get {
                return prefs.integer(forSetting: "HomepageSettings", key: "donationRecommendationMultiplier")
            }
            set {
                prefs.set(newValue, forSetting: "HomepageSettings", key: "donationRecommendationMultiplier")
            }
        }
    }
    
    // MARK: - Site Permissions
    struct SitePermissionSettings {
        static var defaultAutoplayPermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultAutoplayPermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultAutoplayPermission")
            }
        }
        
        static var defaultCameraPermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultCameraPermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultCameraPermission")
            }
        }
        
        static var defaultMicrophonePermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultMicrophonePermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultMicrophonePermission")
            }
        }
        
        static var defaultLocationPermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultLocationPermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultLocationPermission")
            }
        }
        
        static var defaultPersistentStoragePermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultPersistentStoragePermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultPersistentStoragePermission")
            }
        }
        
        static var defaultCrossOriginStorageAccessPermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultCrossOriginStorageAccessPermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultCrossOriginStorageAccessPermission")
            }
        }
        
        static var defaultLocalDeviceAccessPermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultLocalDeviceAccessPermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultLocalDeviceAccessPermission")
            }
        }
        
        static var defaultLocalNetworkAccessPermission: SitePermissionAction {
            get {
                let rawValue = prefs.string(forSetting: "SitePermissionSettings", key: "defaultLocalNetworkAccessPermission")
                guard let rawValue,
                      let action = SitePermissionAction(rawValue: rawValue) else {
                    return .askToAllow
                }
                return action
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "SitePermissionSettings", key: "defaultLocalNetworkAccessPermission")
            }
        }
    }
    
    // MARK: - Compatibility
    struct CompatibilitySettings {
        static var androidUserAgentDomains: [String] {
            get {
                guard let data = prefs.data(forSetting: "CompatibilitySettings", key: "androidUserAgentDomains"),
                      let list = try? JSONDecoder().decode([String].self, from: data) else {
                    return []
                }
                return list
            }
            set {
                let data = try? JSONEncoder().encode(newValue)
                prefs.set(data, forSetting: "CompatibilitySettings", key: "androidUserAgentDomains")
            }
        }
        
        static var useAndroidUserAgent: Bool {
            get {
                prefs.bool(forSetting: "CompatibilitySettings", key: "useAndroidUserAgent")
            }
            set {
                prefs.set(newValue, forSetting: "CompatibilitySettings", key: "useAndroidUserAgent")
            }
        }
    }
    
    // MARK: - Appearance
    struct AppearanceSettings {
        static var appAppearance: AppAppearance {
            get {
                let rawValue = prefs.string(forSetting: "AppearanceSettings", key: "appAppearance") ?? AppAppearance.system.rawValue
                return AppAppearance(rawValue: rawValue) ?? .system
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "AppearanceSettings", key: "appAppearance")
            }
        }
        
        static var addressBarPosition: BrowserChromePosition {
            get {
                let rawValue = prefs.string(forSetting: "AppearanceSettings", key: "addressBarPosition") ?? BrowserChromePosition.bottom.rawValue
                return BrowserChromePosition(rawValue: rawValue) ?? .bottom
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "AppearanceSettings", key: "addressBarPosition")
                NotificationCenter.default.post(name: .addressBarPositionDidChange, object: nil)
            }
        }
        
        static var showsLandscapeTabBar: Bool {
            get {
                prefs.bool(forSetting: "AppearanceSettings", key: "showsLandscapeTabBar")
            }
            set {
                prefs.set(newValue, forSetting: "AppearanceSettings", key: "showsLandscapeTabBar")
                NotificationCenter.default.post(name: .landscapeTabBarDidChange, object: nil)
            }
        }
        
        static var showsFullWebsiteAddress: Bool {
            get {
                prefs.bool(forSetting: "AppearanceSettings", key: "showsFullWebsiteAddress")
            }
            set {
                prefs.set(newValue, forSetting: "AppearanceSettings", key: "showsFullWebsiteAddress")
                NotificationCenter.default.post(name: .showFullWebsiteAddressDidChange, object: nil)
            }
        }
        
    }
    
    // MARK: - JIT
    struct JITSettings {
        static var hasPairingFile: Bool {
            FileManager.default.fileExists(atPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("pairingFile.plist", isDirectory: false).path)
        }
        
        static var isJITEnabled: Bool {
            get {
                guard hasPairingFile else {
                    return false
                }
                return prefs.bool(forSetting: "JITSettings", key: "isJITEnabled")
            }
            set {
                prefs.set(hasPairingFile && newValue, forSetting: "JITSettings", key: "isJITEnabled")
            }
        }
    }
    
    // MARK: - Experimental
    struct ExperimentalSettings {
        static var isVideoPictureInPictureEnabled: Bool {
            get {
                return prefs.bool(forSetting: "ExperimentalSettings", key: "isVideoPictureInPictureEnabled")
            }
            set {
                prefs.set(newValue, forSetting: "ExperimentalSettings", key: "isVideoPictureInPictureEnabled")
            }
        }
    }
    
    // MARK: - Bookmarks
    struct BookmarkSettings {
        static var placeFoldersOnTop: Bool {
            get {
                prefs.bool(forSetting: "BookmarkSettings", key: "placeFoldersOnTop")
            }
            set {
                prefs.set(newValue, forSetting: "BookmarkSettings", key: "placeFoldersOnTop")
            }
        }
        
        static var sortOrders: BookmarkSortOrder {
            get {
                let rawValue = prefs.string(forSetting: "BookmarkSettings", key: "sortOrders") ?? BookmarkSortOrder.none.rawValue
                return BookmarkSortOrder(rawValue: rawValue) ?? .none
            }
            set {
                prefs.set(newValue.rawValue, forSetting: "BookmarkSettings", key: "sortOrders")
            }
        }
    }
    
    // MARK: - Languages
    struct LanguageSettings {
        static var websiteLanguages: [String] {
            get {
                guard let data = prefs.data(forSetting: "LanguageSettings", key: "websiteLanguages"),
                      let values = try? JSONDecoder().decode([String].self, from: data) else {
                    return WebsiteLanguageCatalog.defaultLanguageCodes()
                }
                return WebsiteLanguageCatalog.sanitizedLanguageCodes(values)
            }
            set {
                let values = WebsiteLanguageCatalog.sanitizedLanguageCodes(newValue)
                let data = try? JSONEncoder().encode(values)
                prefs.set(data, forSetting: "LanguageSettings", key: "websiteLanguages")
            }
        }
    }
    
    // MARK: - Add-ons
    struct AddonSettings {
        static var lastGlobalCheckAt: Date? {
            get {
                guard let value = prefs.string(forSetting: "AddonSettings", key: "lastGlobalCheckAt"),
                      !value.isEmpty else {
                    return nil
                }
                return ISO8601DateFormatter().date(from: value)
            }
            set {
                prefs.set(newValue.map { ISO8601DateFormatter().string(from: $0) }, forSetting: "AddonSettings", key: "lastGlobalCheckAt")
            }
        }
        
        static var pendingApprovalAddonIDs: [String] {
            get {
                guard let data = prefs.data(forSetting: "AddonSettings", key: "pendingApprovalAddonIDs"),
                      !data.isEmpty,
                      let values = try? JSONDecoder().decode([String].self, from: data) else {
                    return []
                }
                return values
            }
            set {
                let data = try? JSONEncoder().encode(newValue)
                prefs.set(data, forSetting: "AddonSettings", key: "pendingApprovalAddonIDs")
            }
        }
    }
}

private var prefs: BrowserPreferences { BrowserPreferences.shared }
