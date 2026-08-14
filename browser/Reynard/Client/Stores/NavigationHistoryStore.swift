//
//  NavigationHistoryStore.swift
//  Reynard
//
//  Created by Minh Ton on 17/5/26.
//

import Foundation
import UIKit

final class NavigationHistoryStore {
    static let shared = NavigationHistoryStore()
    
    struct HistoryItem {
        let title: String
        let url: String
    }
    
    struct Snapshot {
        let canGoBack: Bool
        let canGoForward: Bool
        let backHistory: [HistoryItem]
        let forwardHistory: [HistoryItem]
        let backPreviewImage: UIImage?
        let forwardPreviewImage: UIImage?
        let usesStoredHistory: Bool
    }
    
    private struct NavigationEntry: Codable {
        var url: String
        var title: String
        var thumbnailData: Data?
    }
    
    private struct StoredHistory: Codable {
        var currentURL: String?
        var currentTitle: String?
        var currentThumbnailData: Data?
        var backHistory: [NavigationEntry]
        var forwardHistory: [NavigationEntry]
        var usesStoredHistory: Bool?
        
        private enum CodingKeys: String, CodingKey {
            case currentURL
            case currentTitle
            case currentThumbnailData = "currentThumbnail"
            case backHistory = "backList"
            case forwardHistory = "forwardList"
            case usesStoredHistory = "ownsNav"
        }
        
        init(
            currentURL: String?,
            currentTitle: String?,
            currentThumbnailData: Data?,
            backHistory: [NavigationEntry],
            forwardHistory: [NavigationEntry],
            usesStoredHistory: Bool?
        ) {
            self.currentURL = currentURL
            self.currentTitle = currentTitle
            self.currentThumbnailData = currentThumbnailData
            self.backHistory = backHistory
            self.forwardHistory = forwardHistory
            self.usesStoredHistory = usesStoredHistory
        }
        
    }
    
    private let thumbnailJPEGQuality = 0.8
    private let fileManager: FileManager
    private let storageURL: URL
    private let queue = DispatchQueue(label: "com.minh-ton.Reynard.NavigationHistoryStore.Queue", qos: .userInitiated)
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        guard let applicationSupportDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        
        self.storageURL = applicationSupportDirectoryURL
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("TabSessions", isDirectory: true)
        
        queue.sync {
            createStorageDirectory()
        }
    }
    
    func currentSnapshot(for tabID: UUID) -> Snapshot {
        queue.sync {
            let history = loadHistory(for: tabID)
            return snapshot(from: history)
        }
    }
    
    func recordNavigation(to url: String, title: String, for tabID: UUID) -> Snapshot {
        queue.sync {
            var history = loadHistory(for: tabID)
            guard history.currentURL != url else {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty,
                   history.currentTitle != trimmedTitle {
                    history.currentTitle = trimmedTitle
                    saveHistory(history, for: tabID)
                }
                return snapshot(from: history)
            }
            let normalizedTitle = normalizedTitle(title, fallback: url)
            
            if let currentURL = history.currentURL,
               !currentURL.isEmpty {
                history.backHistory.append(NavigationEntry(
                    url: currentURL,
                    title: history.currentTitle ?? currentURL,
                    thumbnailData: history.currentThumbnailData
                ))
            }
            
            history.currentURL = url
            history.currentTitle = normalizedTitle
            history.currentThumbnailData = nil
            history.forwardHistory.removeAll(keepingCapacity: false)
            saveHistory(history, for: tabID)
            return snapshot(from: history)
        }
    }
    
    func setUsesPersistedHistory(_ usesPersistedHistory: Bool, for tabID: UUID) -> Snapshot {
        queue.sync {
            var history = loadHistory(for: tabID)
            history.usesStoredHistory = usesPersistedHistory
            saveHistory(history, for: tabID)
            return snapshot(from: history)
        }
    }
    
    func goBack(to index: Int, for tabID: UUID) -> String? {
        queue.sync {
            var history = loadHistory(for: tabID)
            guard index >= 0,
                  index < history.backHistory.count else {
                return nil
            }
            
            let targetIndex = history.backHistory.count - index - 1
            let target = history.backHistory[targetIndex]
            let firstForwardIndex = targetIndex + 1
            var movedEntries = firstForwardIndex < history.backHistory.count
            ? Array(history.backHistory[firstForwardIndex...])
            : []
            if let currentURL = history.currentURL,
               !currentURL.isEmpty {
                movedEntries.append(NavigationEntry(
                    url: currentURL,
                    title: history.currentTitle ?? currentURL,
                    thumbnailData: history.currentThumbnailData
                ))
            }
            
            history.backHistory.removeLast(index + 1)
            history.forwardHistory = movedEntries + history.forwardHistory
            history.currentURL = target.url
            history.currentTitle = target.title
            history.currentThumbnailData = target.thumbnailData
            saveHistory(history, for: tabID)
            return target.url
        }
    }
    
    func goForward(to index: Int, for tabID: UUID) -> String? {
        queue.sync {
            var history = loadHistory(for: tabID)
            guard index >= 0,
                  index < history.forwardHistory.count else {
                return nil
            }
            
            let target = history.forwardHistory[index]
            let movedEntries = Array(history.forwardHistory.prefix(index))
            if let currentURL = history.currentURL,
               !currentURL.isEmpty {
                history.backHistory.append(NavigationEntry(
                    url: currentURL,
                    title: history.currentTitle ?? currentURL,
                    thumbnailData: history.currentThumbnailData
                ))
            }
            history.backHistory.append(contentsOf: movedEntries)
            history.forwardHistory.removeFirst(index + 1)
            history.currentURL = target.url
            history.currentTitle = target.title
            history.currentThumbnailData = target.thumbnailData
            saveHistory(history, for: tabID)
            return target.url
        }
    }
    
    func updateCurrentHistoryTitle(_ title: String, for tabID: UUID, matching url: String) {
        queue.sync {
            var history = self.loadHistory(for: tabID)
            guard history.currentURL == url else {
                return
            }
            
            let normalizedTitle = self.normalizedTitle(title, fallback: url)
            guard history.currentTitle != normalizedTitle else {
                return
            }
            
            history.currentTitle = normalizedTitle
            self.saveHistory(history, for: tabID)
        }
    }
    
    func updateCurrentHistoryThumbnail(_ image: UIImage?, for tabID: UUID, matching url: String) {
        queue.async {
            var history = self.loadHistory(for: tabID)
            guard history.currentURL == url else {
                return
            }
            
            history.currentThumbnailData = image?.jpegData(compressionQuality: self.thumbnailJPEGQuality)
            self.saveHistory(history, for: tabID)
        }
    }
    
    func invalidateThumbnails() {
        queue.sync {
            guard let fileURLs = try? self.fileManager.contentsOfDirectory(
                at: self.storageURL,
                includingPropertiesForKeys: nil
            ) else {
                return
            }
            
            fileURLs.forEach { fileURL in
                guard let tabID = UUID(uuidString: fileURL.lastPathComponent) else {
                    return
                }
                
                var history = self.loadHistory(for: tabID)
                history.currentThumbnailData = nil
                history.backHistory = history.backHistory.map {
                    NavigationEntry(url: $0.url, title: $0.title, thumbnailData: nil)
                }
                history.forwardHistory = history.forwardHistory.map {
                    NavigationEntry(url: $0.url, title: $0.title, thumbnailData: nil)
                }
                self.saveHistory(history, for: tabID)
            }
        }
    }
    
    func removeNavigationHistory(for tabID: UUID) {
        queue.async {
            let fileURL = self.historyURL(for: tabID)
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                return
            }
            
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    private func createStorageDirectory() {
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
    
    private func loadHistory(for tabID: UUID) -> StoredHistory {
        guard let data = try? Data(contentsOf: historyURL(for: tabID)),
              let decoded = try? JSONDecoder().decode(StoredHistory.self, from: data) else {
            return StoredHistory(
                currentURL: nil,
                currentTitle: nil,
                currentThumbnailData: nil,
                backHistory: [],
                forwardHistory: [],
                usesStoredHistory: nil
            )
        }
        
        return decoded
    }
    
    private func saveHistory(_ history: StoredHistory, for tabID: UUID) {
        guard let data = try? JSONEncoder().encode(history) else {
            return
        }
        
        try? data.write(to: historyURL(for: tabID), options: .atomic)
    }
    
    private func snapshot(from history: StoredHistory) -> Snapshot {
        Snapshot(
            canGoBack: !history.backHistory.isEmpty,
            canGoForward: !history.forwardHistory.isEmpty,
            backHistory: history.backHistory.reversed().map(historyItem(from:)),
            forwardHistory: history.forwardHistory.map(historyItem(from:)),
            backPreviewImage: history.backHistory.last?.thumbnailData.flatMap(UIImage.init(data:)),
            forwardPreviewImage: history.forwardHistory.first?.thumbnailData.flatMap(UIImage.init(data:)),
            usesStoredHistory: history.usesStoredHistory ?? false
        )
    }
    
    private func historyItem(from entry: NavigationEntry) -> HistoryItem {
        HistoryItem(title: entry.title, url: entry.url)
    }
    
    private func normalizedTitle(_ title: String, fallback: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? fallback : trimmedTitle
    }
    
    private func historyURL(for tabID: UUID) -> URL {
        storageURL.appendingPathComponent(tabID.uuidString, isDirectory: false)
    }
}
