//
//  BrowserViewController+VideoPlayback.swift
//  Reynard
//
//  Entry point for video playback requests created from the downloads library.
//

import Foundation

extension BrowserViewController {
    func startVideoPlayback(at url: URL) {
        if Prefs.PlaybackSettings.openVideosInNewTab && Prefs.PlaybackSettings.allowsMultiplePlayers {
            createNewTab()
        }
        tabManager.browse(to: url.absoluteString)
    }
}
