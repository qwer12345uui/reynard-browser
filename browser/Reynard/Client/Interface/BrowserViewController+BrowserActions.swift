//
//  BrowserViewController+BrowserActions.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import UIKit

extension BrowserViewController {
    func presentContentModal(_ rootViewController: UIViewController) {
        let navigationController = ContentModalNavigationController(
            rootViewController: rootViewController
        ) { [weak self] in
            self?.requestContentKeyboardFocus()
        }
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }
    
    func presentLibrary(initialSection: LibrarySection = .bookmarks) {
        if initialSection == .downloads {
            DownloadStore.shared.markCompletedAsViewed()
            if browserLayout.interfaceIdiom == .pad,
               browserLayout.chromeMode == .pad {
                sidebarCoordinator.showSection(.downloads)
                return
            }
        }
        
        let libraryController = LibraryViewController(
            initialSection: initialSection,
            isPrivateMode: tabManager.selectedTab?.isPrivate == true
        ) { [weak self] in
            self?.dismiss(animated: true)
        }
        presentContentModal(libraryController)
    }
    
    func presentShareSheet(url urlString: String? = nil) {
        let urlToShare: URL?
        if let urlString {
            urlToShare = URL(string: urlString)
        } else if let tab = tabManager.selectedTab {
            urlToShare = tabManager.shareableURL(for: tab)
        } else {
            urlToShare = nil
        }
        
        guard let url = urlToShare else {
            return
        }
        
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            let sourceView = browserChrome.sharePopoverSourceView()
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(activityController, animated: true)
    }
    
    func handleClipboardURLIfNeeded() {
        guard Prefs.ClipboardSettings.automaticallyParseURLs,
              tabManager.selectedTab?.isPrivate != true else {
            return
        }

        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != Prefs.ClipboardSettings.lastHandledChangeCount else {
            return
        }
        guard let text = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            Prefs.ClipboardSettings.lastHandledChangeCount = changeCount
            return
        }
        guard viewIfLoaded?.window != nil,
              presentedViewController == nil else {
            return
        }

        Prefs.ClipboardSettings.lastHandledChangeCount = changeCount
        let alert = UIAlertController(
            title: "检测到剪切板网址",
            message: url.absoluteString,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: "打开", style: .default) { [weak self] _ in
            self?.openExternalURL(url)
        })
        present(alert, animated: true)
    }

    func createNewTab() {
        toolbarController.reset()
        dismissAddressBarEditingAndOverlays()
        
        if tabOverview.isPresented {
            tabOverview.prepareNextTabChangesWithoutAnimation()
            createTabFromOverview(mode: tabOverview.mode.tabMode)
        } else {
            homepageOverlayCoordinator.prepareHomepageForNewTab(mode: tabManager.selectedTabMode)
            let createdIndex = tabManager.createTab(selecting: true)
            applyNewTabDisplayOption(toTabAt: createdIndex)
            tabBar.setPendingExpansion(at: createdIndex)
            setTabOverviewVisible(false, animated: true)
        }
    }
}
