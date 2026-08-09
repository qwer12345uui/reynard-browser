//
//  ImagePreviewMenu.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import UIKit

struct ImagePreviewMenu {
    static func configuration(
        for context: ContextMenuContext,
        showsPreview: Bool,
        presentingController: UIViewController,
        sourceView: UIView,
        openLinkInNewTab: @escaping (URL) -> Void,
        openLinkInNewPrivateTab: @escaping (URL) -> Void,
        openLinkInBackground: @escaping (URL) -> Void,
        openImageInNewTab: @escaping () -> Void
    ) -> UIContextMenuConfiguration? {
        guard case let .image(url, linkURL) = context.target else {
            return nil
        }
        
        let previewProvider: UIContextMenuContentPreviewProvider? = showsPreview ? {
            ImagePreviewViewController(url: url)
        } : nil
        
        return UIContextMenuConfiguration(identifier: UUID().uuidString as NSString, previewProvider: previewProvider) { _ in
            var children: [UIMenuElement] = []
            if let linkURL {
                children.append(
                    UIMenu(title: "", options: .displayInline, children: [
                        UIAction(title: NSLocalizedString("Open Link in New Tab", comment: ""), image: UIImage(named: "reynard.plus.square")) { _ in
                            openLinkInNewTab(linkURL)
                        },
                        UIAction(title: NSLocalizedString("Open Link in New Private Tab", comment: ""), image: UIImage(named: "reynard.plus.square.fill")) { _ in
                            openLinkInNewPrivateTab(linkURL)
                        },
                        UIAction(title: NSLocalizedString("Open Link in Background", comment: ""), image: UIImage(named: "reynard.plus.square.dashed")) { _ in
                            openLinkInBackground(linkURL)
                        },
                    ])
                )
            }
            
            children.append(
                UIMenu(title: "", options: .displayInline, children: [
                    UIAction(title: NSLocalizedString("Open Image in New Tab", comment: ""), image: UIImage(named: "reynard.plus.square")) { _ in
                        openImageInNewTab()
                    },
                    UIAction(title: NSLocalizedString("Share Image", comment: ""), image: UIImage(named: "reynard.square.and.arrow.up")) { _ in
                        loadImage(from: url) { image in
                            presentShareSheet(
                                image: image,
                                from: presentingController,
                                sourceView: sourceView,
                                sourcePoint: context.point
                            )
                        }
                    },
                    UIAction(title: NSLocalizedString("Save to Photos", comment: ""), image: UIImage(named: "reynard.square.and.arrow.down")) { _ in
                        loadImage(from: url) { image in
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }
                    },
                    UIAction(title: NSLocalizedString("Copy Image", comment: ""), image: UIImage(named: "reynard.document.on.document")) { _ in
                        loadImage(from: url) { image in
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
    
    private static func loadImage(from url: URL, completion: @escaping @MainActor (UIImage) -> Void) {
        Task {
            guard let image = await ImagePreviewLoader.image(from: url) else {
                return
            }
            await MainActor.run {
                completion(image)
            }
        }
    }
    
    private static func presentShareSheet(
        image: UIImage,
        from controller: UIViewController,
        sourceView: UIView,
        sourcePoint: CGPoint
    ) {
        let sheet = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(origin: sourcePoint, size: .zero)
        }
        controller.present(sheet, animated: true)
    }
}
