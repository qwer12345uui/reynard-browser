//
//  ContextMenuCoordinator.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import GeckoView
import UIKit

protocol ContextMenuCoordinatorHost: AnyObject {
    var contextMenuSourceView: ContentView { get }
    var contextMenuTabActions: ContextMenuTabActions { get }
    var contextMenuSelectedTabIsPrivate: Bool { get }
    var contextMenuSelectedSession: GeckoSession? { get }
    
    func captureSourceTabThumbnail(completion: @escaping () -> Void)
    func contextMenuOpenLink(_ url: URL, disposition: TabOpenDisposition)
    func contextMenuPresentShareSheet(items: [Any], sourceView: UIView, sourceRect: CGRect)
    func contextMenuRestoreInteraction(for session: GeckoSession)
}

final class ContextMenuCoordinator: NSObject {
    private enum UX {
        static let targetedPreviewSideLength: CGFloat = 1
    }
    
    private weak var host: ContextMenuCoordinatorHost?
    private let sessionManager: SessionManager
    private var pendingContext: ContextMenuContext?
    private var interaction: UIContextMenuInteraction?
    private var linkPreview: LinkPreviewViewController?
    private var isCommitting = false
    private var isPresenting = false
    
    init(host: ContextMenuCoordinatorHost, sessionManager: SessionManager) {
        self.host = host
        self.sessionManager = sessionManager
        super.init()
    }
    
    func configure() {
        guard interaction == nil,
              let host else {
            return
        }
        
        let interaction = UIContextMenuInteraction(delegate: self)
        host.contextMenuSourceView.addWebViewInteraction(interaction)
        self.interaction = interaction
    }
    
    func present(at point: CGPoint, target: ContextMenuContext.Target, allowsPreview: Bool) {
        guard let interaction else {
            return
        }
        
        let context = ContextMenuContext(target: target, point: point, allowsPreview: allowsPreview)
        closePreview()
        pendingContext = context
        isCommitting = false
        isPresenting = true
        
        let selector = NSSelectorFromString("_presentMenuAtLocation:")
        guard interaction.responds(to: selector) else {
            isPresenting = false
            pendingContext = nil
            return
        }
        
        Haptics.rigid()
        _ = interaction.perform(selector, with: NSValue(cgPoint: context.point))
    }
    
    private func openLinkPreview(disposition: TabOpenDisposition) {
        guard let host else {
            return
        }
        
        if pendingContext?.allowsPreview != true || !Prefs.BrowsingSettings.showLinkPreviews {
            guard case .link(let url) = pendingContext?.target else {
                return
            }
            
            isCommitting = true
            host.contextMenuOpenLink(url, disposition: disposition)
            return
        }
        
        guard linkPreview != nil else {
            return
        }
        
        isCommitting = true
        host.captureSourceTabThumbnail { [weak self] in
            guard let self,
                  let host = self.host,
                  let preview = self.linkPreview,
                  let session = preview.releaseSession() else {
                self?.isCommitting = false
                return
            }
            
            host.contextMenuTabActions.openPreviewSession(
                session,
                url: preview.pageURL,
                title: preview.pageTitle,
                disposition: disposition
            )
            self.linkPreview = nil
        }
    }
    
    private func makeTargetedPreview() -> UITargetedPreview? {
        guard let host else {
            return nil
        }
        
        let sourcePoint = pendingContext?.point ?? CGPoint(
            x: host.contextMenuSourceView.bounds.midX,
            y: host.contextMenuSourceView.bounds.midY
        )
        let target = UIPreviewTarget(container: host.contextMenuSourceView, center: sourcePoint)
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        let previewFrame = CGRect(
            x: 0,
            y: 0,
            width: UX.targetedPreviewSideLength,
            height: UX.targetedPreviewSideLength
        )
        parameters.visiblePath = UIBezierPath(rect: previewFrame)
        
        let view = UIView(frame: previewFrame)
        view.backgroundColor = .clear
        return UITargetedPreview(view: view, parameters: parameters, target: target)
    }
    
    private func closePreview() {
        linkPreview?.closeSession()
        linkPreview = nil
    }
    
    private func restoreSelectedTabInteraction() {
        DispatchQueue.main.async { [weak self] in
            guard let host = self?.host,
                  let session = host.contextMenuSelectedSession else {
                return
            }
            
            host.contextMenuRestoreInteraction(for: session)
        }
    }
    
    private func endPresentation() {
        if !isCommitting {
            closePreview()
            restoreSelectedTabInteraction()
        } else {
            isCommitting = false
        }
        pendingContext = nil
    }
}

extension ContextMenuCoordinator: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard interaction === self.interaction,
              isPresenting,
              let context = pendingContext,
              let host else {
            return nil
        }
        isPresenting = false
        
        if case let .image(url, _) = context.target,
           let imageConfiguration = ImagePreviewMenu.configuration(
            for: context,
            showsPreview: context.allowsPreview && Prefs.BrowsingSettings.showImagePreviews,
            sourceView: host.contextMenuSourceView,
            shareImage: { [weak host] image, sourceView, sourceRect in
                host?.contextMenuPresentShareSheet(
                    items: [image],
                    sourceView: sourceView,
                    sourceRect: sourceRect
                )
            },
            openLinkInNewTab: { [weak host] url in
                host?.contextMenuOpenLink(url, disposition: .newTab)
            },
            openLinkInNewPrivateTab: { [weak host] url in
                host?.contextMenuOpenLink(url, disposition: .newPrivateTab)
            },
            openLinkInBackground: { [weak host] url in
                host?.contextMenuOpenLink(url, disposition: .backgroundTab)
            },
            openImageInNewTab: { [weak host] in
                host?.contextMenuOpenLink(url, disposition: .newTab)
            }
           ) {
            return imageConfiguration
        }
        
        return LinkPreviewMenu.configuration(
            for: context,
            showsPreview: context.allowsPreview && Prefs.BrowsingSettings.showLinkPreviews,
            isPrivate: host.contextMenuSelectedTabIsPrivate,
            sessionManager: sessionManager,
            sourceView: host.contextMenuSourceView,
            onPreviewCreated: { [weak self] preview in
                self?.linkPreview = preview
            },
            openInNewTab: { [weak self] in
                self?.openLinkPreview(disposition: .newTab)
            },
            openInNewPrivateTab: { [weak self] in
                self?.openLinkPreview(disposition: .newPrivateTab)
            },
            openInBackground: { [weak self] in
                self?.openLinkPreview(disposition: .backgroundTab)
            },
            shareLink: { [weak host] url, sourceView, sourceRect in
                host?.contextMenuPresentShareSheet(
                    items: [url],
                    sourceView: sourceView,
                    sourceRect: sourceRect
                )
            }
        )
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionCommitAnimating
    ) {
        animator.preferredCommitStyle = .pop
        guard interaction === self.interaction,
              let host,
              let preview = animator.previewViewController as? LinkPreviewViewController,
              let session = preview.releaseSession() else {
            return
        }
        
        isCommitting = true
        host.contextMenuTabActions.openPreviewSession(
            session,
            url: preview.pageURL,
            title: preview.pageTitle,
            disposition: .currentTab
        )
        linkPreview = nil
        
        animator.addCompletion { [weak self] in
            self?.isCommitting = false
            self?.pendingContext = nil
        }
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard interaction === self.interaction else {
            return nil
        }
        
        return makeTargetedPreview()
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard interaction === self.interaction else {
            return nil
        }
        
        return makeTargetedPreview()
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        guard interaction === self.interaction else {
            return
        }
        
        guard let animator else {
            endPresentation()
            return
        }
        
        animator.addCompletion { [weak self] in
            self?.endPresentation()
        }
    }
}
