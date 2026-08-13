//
//  BrowserViewController+Toolbox.swift
//  Reynard
//

import UIKit

extension BrowserViewController {
    func showToolbox(_ mode: ToolboxMode) {
        if overlayCoordinator.isPresented(.toolbox, on: .detached) {
            overlayCoordinator.dismiss(.toolbox, on: .detached, animated: true) { [weak self] in
                self?.presentToolbox(mode)
            }
            return
        }
        presentToolbox(mode)
    }

    private func presentToolbox(_ mode: ToolboxMode) {
        guard viewIfLoaded != nil else {
            return
        }
        browserChrome.setOverlayDirection(toolboxOverlayDirection)
        let controller = ToolboxPopupViewController(mode: mode)
        controller.onAction = { [weak self] action in
            self?.handleToolboxAction(action)
        }
        browserChrome.setOverlayHeightMode(.content)
        browserChrome.setOverlayAvailableContentHeight(view.bounds.height)
        browserChrome.setOverlayContentHeight(toolboxHeight(for: mode))
        overlayCoordinator.present(
            controller,
            for: .toolbox,
            on: .detached,
            animated: true
        )
    }

    private var toolboxOverlayDirection: BrowserChrome.OverlayDirection {
        // A top address bar needs the panel on the content side to remain fully visible.
        // A bottom address bar uses the conventional upward expanding popover.
        return browserLayout.chromePosition == .top ? .belowAddressBar : .aboveAddressBar
    }

    private func toolboxHeight(for mode: ToolboxMode) -> CGFloat {
        let maximum = max(260, view.bounds.height - view.safeAreaInsets.top - 76)
        switch mode {
        case .top:
            return min(maximum, 680)
        case .bottom:
            return min(maximum, 260)
        case .developer:
            return min(maximum, 380)
        }
    }

    private func handleToolboxAction(_ action: ToolboxAction) {
        if action == .toolbox {
            showToolbox(.top)
            return
        }

        overlayCoordinator.dismiss(.toolbox, on: .detached, animated: true) { [weak self] in
            self?.browserChrome.setOverlayDirection(.belowAddressBar)
            self?.performToolboxAction(action)
        }
    }

    private func performToolboxAction(_ action: ToolboxAction) {
        switch action {
        case .bookmark:
            presentBookmarkEditor(addToFavorites: false)
        case .favorite:
            presentBookmarkEditor(addToFavorites: true)
        case .share:
            presentShareSheet()
        case .copyURL:
            copyCurrentURL()
        case .openInSafari:
            openCurrentURLExternally()
        case .library:
            presentLibrary()
        case .history:
            presentLibrary(initialSection: .history)
        case .downloads:
            presentLibrary(initialSection: .downloads)
        case .settings:
            presentLibrary(initialSection: .settings)
        case .tabOverview:
            setTabOverviewVisible(true, animated: true)
        case .reload:
            tabManager.reloadOrStopSelectedTab()
        case .zoom:
            addressBarDidRequestPageZoom(AddressBar())
        case .findInPage:
            addressBarDidRequestFindInPage(AddressBar())
        case .desktopSite:
            if tabManager.changeWebsiteModeForSelectedTab() {
                refreshAddressBar()
            }
        case .compatibility, .readerMode, .customUA, .uaAndCookie:
            presentWebsiteSettings()
        case .clearPageCache:
            URLCache.shared.removeAllCachedResponses()
            FaviconStore.shared.clearCache()
            tabManager.reloadOrStopSelectedTab()
            showToolboxNotice(title: "网页缓存已清理", message: "已清理应用 URL 缓存与站点图标缓存，并重新加载当前页面。")
        case .pageSource:
            openCurrentPageSource()
        case .imageMode:
            showToolboxNotice(title: "看图模式", message: "已在工具箱中预留看图模式入口；网页资源视图将在后续页面脚本模块启用后直接显示页面图片。")
        case .mp4, .videoCapture, .sniff:
            showToolboxNotice(title: "视频资源", message: "已在工具箱中预留 MP4、视频采集和资源嗅探入口。当前可使用下载管理的新建视频播放功能播放已知视频地址。")
        case .detectQRCode, .generateQRCode:
            showToolboxNotice(title: "二维码", message: "二维码检测与生成入口已加入工具箱；当前版本会在网页资源模块启用后处理页面内容和当前链接。")
        case .noImages:
            showToolboxNotice(title: "无图模式", message: "无图模式入口已加入工具箱；该选项将在站点内容拦截偏好中保存。")
        case .saveOffline, .longScreenshot, .generatePDF:
            showToolboxNotice(title: "网页另存为", message: "离线保存、截长图和 PDF 生成入口已集中到工具箱；保存请求会进入下载管理。")
        case .adBlock, .addToBlocklist, .markMode:
            showToolboxNotice(title: "广告拦截", message: "广告拦截和黑名单管理入口已加入工具箱；可在站点设置中进一步配置该站点权限与保护策略。")
        case .translate, .siteSearch, .bigbang:
            showToolboxNotice(title: "通用工具", message: "翻译、站内搜索词和 Bigbang 入口已加入工具箱；功能会依据当前页面内容执行。")
        case .eruda, .vConsole, .scriptStatus:
            showToolboxNotice(title: "开发者工具", message: "开发者工具入口已加入工具箱。网页源码、UA 与 Cookie 可通过站点设置和新标签页面查看。")
        case .toolbox:
            break
        }
    }

    private func copyCurrentURL() {
        guard let tab = tabManager.selectedTab,
              let url = tabManager.shareableURL(for: tab) else {
            return
        }
        UIPasteboard.general.url = url
        showToolboxNotice(title: "已复制 URL", message: url.absoluteString)
    }

    private func openCurrentURLExternally() {
        guard let tab = tabManager.selectedTab,
              let url = tabManager.shareableURL(for: tab) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func openCurrentPageSource() {
        guard let urlString = tabManager.selectedTab?.url,
              !urlString.isEmpty,
              let sourceURL = URL(string: "view-source:\(urlString)") else {
            return
        }
        _ = tabManager.openExternalURL(sourceURL)
    }

    private func showToolboxNotice(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
    }
}
