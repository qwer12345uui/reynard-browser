//
//  BrowserViewController+Addons.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

import GeckoView
import UIKit

extension BrowserViewController: AddonCoordinatorDataSource, AddonCoordinatorDelegate {
    // MARK: - AddonCoordinatorDataSource
    
    var selectedAddonSession: GeckoSession? {
        return tabManager.selectedTab?.session
    }
    
    var isSelectedAddonTabPrivate: Bool {
        return tabManager.selectedTab?.isPrivate == true
    }
    
    var addonTabs: [Tab] {
        return tabManager.activeTabs
    }
    
    var selectedAddonTabMode: TabMode {
        return tabManager.selectedTabMode
    }
    
    var shouldPresentAddonPopupAsPopover: Bool {
        return browserLayout.chromeMode == .pad
    }
    
    func indexOfAddonTab(for session: GeckoSession) -> Int? {
        return tabManager.tabIndex(for: session)
    }
    
    // MARK: - AddonCoordinatorDelegate
    
    func refreshAddonChrome(_ coordinator: AddonCoordinator) {
        refreshAddressBar()
    }
    
    func performAfterAddonMenuDismissal(_ coordinator: AddonCoordinator, work: @escaping () -> Void) {
        browserChrome.performAfterAddressBarMenuDismissal(work)
    }
    
    func presentAddonViewController(_ coordinator: AddonCoordinator, _ viewController: UIViewController) {
        let presentViewController = { [weak self] in
            guard let self else {
                return
            }
            UIApplication.shared.topViewController(from: self).present(viewController, animated: true)
        }
        
        if let popupViewController = viewController as? AddonPopupViewController,
           let popover = popupViewController.popoverPresentationController {
            toolbarController.lock(for: .addonPopover)
            let sourceButton = browserChrome.addressBarButton
            popover.sourceView = sourceButton
            popover.sourceRect = sourceButton.bounds
            popover.permittedArrowDirections = .up
            popover.delegate = popupViewController
            browserChrome.performAfterAddressBarMenuDismissal(presentViewController)
            return
        }
        
        presentViewController()
    }
    
    func presentAddonAlert(_ coordinator: AddonCoordinator, title: String?, message: String) {
        AlertPresenter.show(title: title, message: message)
    }
    
    func dismissAddonModal(_ coordinator: AddonCoordinator, completion: (() -> Void)?) -> Bool {
        let presenter = UIApplication.shared.topViewController(from: self)
        guard presenter !== self else {
            return false
        }
        
        presenter.dismiss(animated: true, completion: completion)
        return true
    }
    
    func createAddonTab(
        _ coordinator: AddonCoordinator,
        selecting: Bool,
        url: String?,
        windowId: String?,
        at index: Int?,
        loadImmediately: Bool
    ) -> Tab? {
        // Extension-created tabs must stay in the same privacy container as
        // the active browsing context. Creating a regular tab here caused
        // private-context requests to fall back to the regular homepage.
        let mode = tabManager.selectedTabMode
        let tabIndex = tabManager.createTab(
            selecting: selecting,
            windowId: windowId,
            target: index.map(TabInsertionTarget.index) ?? .end,
            mode: mode
        )
        let tabs = mode == .private ? tabManager.privateTabs : tabManager.regularTabs
        guard let tab = tabs[safe: tabIndex] else {
            return nil
        }

        if let url = url?.trimmingCharacters(in: .whitespacesAndNewlines),
           !url.isEmpty {
            loadImmediately ? tabManager.browse(to: url, in: tab) : (tab.state.displayState = .pending(url))
        }
        return tab
    }
    
    func selectAddonTab(_ coordinator: AddonCoordinator, at index: Int, mode: TabMode?) {
        tabManager.selectTab(at: index, mode: mode)
    }
    
    func closeAddonTab(_ coordinator: AddonCoordinator, at index: Int, mode: TabMode?) {
        tabManager.removeTab(at: index, mode: mode)
    }
    
    func restoreAddonTabInteraction(_ coordinator: AddonCoordinator) {
        toolbarController.unlock(for: .addonPopover)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let session = tabManager.selectedTab?.session else {
                return
            }
            
            contentView.restoreInteraction(for: session)
            sessionManager.activate(session)
            requestContentKeyboardFocus(for: session)
        }
    }
}
