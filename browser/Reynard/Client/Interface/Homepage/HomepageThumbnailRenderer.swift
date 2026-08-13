//
//  HomepageThumbnailRenderer.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

final class HomepageThumbnailRenderer {
    private weak var homepageViewController: HomepageViewController?
    
    init(homepageViewController: HomepageViewController) {
        self.homepageViewController = homepageViewController
    }
    
    func prepareForCapture(contentMode: HomepageContentMode, isPrivateBrowsing: Bool) {
        guard let homepageViewController else {
            return
        }
        
        homepageViewController.loadViewIfNeeded()
        homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
        homepageViewController.setContentMode(contentMode)
        homepageViewController.setShowsBackground(true)
        homepageViewController.view.setNeedsLayout()
        homepageViewController.view.layoutIfNeeded()
    }
    
    func capture(
        size: CGSize,
        visibleRect: CGRect,
        contentMode: HomepageContentMode,
        isPrivateBrowsing: Bool,
        capturesWindow: Bool,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard size.width > 1,
              size.height > 1,
              visibleRect.width > 1,
              visibleRect.height > 1 else {
            completion(nil)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            completion(self?.snapshot(
                size: size,
                visibleRect: visibleRect,
                contentMode: contentMode,
                isPrivateBrowsing: isPrivateBrowsing,
                capturesWindow: capturesWindow
            ))
        }
    }
    
    func snapshot(
        size: CGSize,
        visibleRect: CGRect,
        contentMode: HomepageContentMode,
        isPrivateBrowsing: Bool,
        capturesWindow: Bool
    ) -> UIImage? {
        guard size.width > 1,
              size.height > 1,
              visibleRect.width > 1,
              visibleRect.height > 1,
              let homepageViewController else {
            return nil
        }
        
        homepageViewController.loadViewIfNeeded()
        homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
        homepageViewController.setContentMode(contentMode)
        homepageViewController.setShowsBackground(true)
        homepageViewController.setVisibleContentInsets(visibleContentInsets(size: size, visibleRect: visibleRect))
        
        let view = homepageViewController.view!
        let originalFrame = view.frame
        let originalBounds = view.bounds
        let temporarilyAttachedView = view.superview == nil
        var captureContainer: UIView?
        if temporarilyAttachedView {
            captureContainer = UIView(frame: CGRect(origin: .zero, size: size))
            captureContainer?.addSubview(view)
            view.frame = captureContainer?.bounds ?? .zero
        }
        
        captureContainer?.layoutIfNeeded()
        view.layoutIfNeeded()
        
        let captureRoot = capturesWindow ? (view.window ?? view) : view
        captureRoot.layoutIfNeeded()
        let captureFrame = view.convert(view.bounds, to: captureRoot)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.saveGState()
            guard captureFrame.width > 1, captureFrame.height > 1 else {
                context.cgContext.restoreGState()
                return
            }
            let scaleX = size.width / captureFrame.width
            let scaleY = size.height / captureFrame.height
            context.cgContext.concatenate(CGAffineTransform(
                a: scaleX,
                b: 0,
                c: 0,
                d: scaleY,
                tx: -captureFrame.minX * scaleX,
                ty: -captureFrame.minY * scaleY
            ))
            captureRoot.drawHierarchy(in: captureRoot.bounds, afterScreenUpdates: false)
            context.cgContext.restoreGState()
        }
        
        if temporarilyAttachedView {
            view.removeFromSuperview()
        }
        view.frame = originalFrame
        view.bounds = originalBounds
        return image
    }
    
    private func visibleContentInsets(size: CGSize, visibleRect: CGRect) -> UIEdgeInsets {
        return UIEdgeInsets(
            top: max(0, visibleRect.minY),
            left: 0,
            bottom: max(0, size.height - visibleRect.maxY),
            right: 0
        )
    }
}
