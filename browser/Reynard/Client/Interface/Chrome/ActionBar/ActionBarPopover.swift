//
//  ActionBarPopover.swift
//  Reynard
//
//  Created by Minh Ton on 16/8/26.
//

import UIKit

final class ActionBarPopover: UIViewController, UIPopoverPresentationControllerDelegate {
    private enum UX {
        static let maximumWidth: CGFloat = 400
        static let height: CGFloat = ActionBar.height
    }
    
    private let actionBar: ActionBar
    private var actionBarConstraints: [NSLayoutConstraint] = []
    var onDismiss: (() -> Void)?
    
    init(actionBar: ActionBar) {
        self.actionBar = actionBar
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .popover
        isModalInPresentation = true
        preferredContentSize = CGSize(width: UX.maximumWidth, height: UX.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        actionBar.transform = .identity
        actionBar.setTopBorderVisible(false)
        view.addSubview(actionBar)
        actionBarConstraints = [
            actionBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionBar.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            actionBar.widthAnchor.constraint(equalTo: view.widthAnchor),
            actionBar.widthAnchor.constraint(lessThanOrEqualToConstant: UX.maximumWidth),
            actionBar.heightAnchor.constraint(equalToConstant: UX.height),
        ]
        NSLayoutConstraint.activate(actionBarConstraints)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeActionBar()
    }
    
    func removeActionBar() {
        NSLayoutConstraint.deactivate(actionBarConstraints)
        actionBarConstraints.removeAll()
        actionBar.removeFromSuperview()
        actionBar.setTopBorderVisible(true)
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    
    nonisolated func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        return .none
    }
    
    nonisolated func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        Task { @MainActor [weak self] in
            self?.onDismiss?()
        }
    }
}
