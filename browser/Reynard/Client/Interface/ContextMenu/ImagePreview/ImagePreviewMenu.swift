//
//  ImagePreviewMenu.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import GeckoView
import UIKit

struct ImagePreviewMenu {
    static func configuration(
        for context: ContextMenuContext,
        session: GeckoSession,
        showsPreview: Bool,
        isPrivate: Bool,
        sourceView: UIView,
        shareImage: @escaping (UIImage, UIView, CGRect) -> Void,
        openLinkInNewTab: @escaping (URL) -> Void,
        openLinkInNewPrivateTab: @escaping (URL) -> Void,
        openImageInNewTab: @escaping () -> Void
    ) -> UIContextMenuConfiguration? {
        guard case let .image(url, linkURL) = context.target else {
            return nil
        }
        
        let previewProvider: UIContextMenuContentPreviewProvider? = showsPreview ? {
            ImagePreviewViewController(url: url, session: session)
        } : nil
        
        return UIContextMenuConfiguration(identifier: UUID().uuidString as NSString, previewProvider: previewProvider) { _ in
            var children: [UIMenuElement] = []
            if let linkURL {
                var linkActions: [UIMenuElement] = [
                    UIAction(title: NSLocalizedString("Open Link in New Tab", comment: ""), image: UIImage(named: "reynard.plus.square.on.square")) { _ in
                        openLinkInNewTab(linkURL)
                    },
                ]
                if !isPrivate {
                    linkActions.append(
                        UIAction(title: NSLocalizedString("Open Link in New Private Tab", comment: ""), image: UIImage(named: "reynard.plus.square.fill.on.square.fill")) { _ in
                            openLinkInNewPrivateTab(linkURL)
                        }
                    )
                }
                children.append(
                    UIMenu(title: "", options: .displayInline, children: linkActions)
                )
            }
            
            children.append(
                UIMenu(title: "", options: .displayInline, children: [
                    UIAction(title: NSLocalizedString("Open Image in New Tab", comment: ""), image: UIImage(named: "reynard.plus.square.on.square")) { _ in
                        openImageInNewTab()
                    },
                    UIAction(title: NSLocalizedString("Share Image", comment: ""), image: UIImage(named: "reynard.square.and.arrow.up")) { _ in
                        loadImage(from: url, in: session) { image in
                            shareImage(
                                image,
                                sourceView,
                                CGRect(origin: context.point, size: .zero)
                            )
                        }
                    },
                    UIAction(title: NSLocalizedString("Save to Photos", comment: ""), image: UIImage(named: "reynard.square.and.arrow.down")) { _ in
                        loadImage(from: url, in: session) { image in
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }
                    },
                    UIAction(title: NSLocalizedString("Copy Image", comment: ""), image: UIImage(named: "reynard.document.on.document")) { _ in
                        loadImage(from: url, in: session) { image in
                            UIPasteboard.general.image = image
                        }
                    },
                    UIAction(title: NSLocalizedString("Copy Image Address", comment: ""), image: UIImage(named: "reynard.document.on.document")) { _ in
                        UIPasteboard.general.string = url.absoluteString
                    },
                ])
            )
            
            return UIMenu(title: "", children: children)
        }
    }
    
    private static func loadImage(from url: URL, in session: GeckoSession, completion: @escaping @MainActor (UIImage) -> Void) {
        Task {
            guard let image = await ImagePreviewLoader.image(from: url, in: session),
                  let cgImage = image.cgImage else {
                return
            }
            let exportImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            await MainActor.run {
                completion(exportImage)
            }
        }
    }
    
}
