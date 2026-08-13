//
//  BottomToolbar.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import UIKit

final class BottomToolbar: UIView {
    private enum UX {
        static let bottomToolbarStandardContentHeight: CGFloat = 94
        static let bottomToolbarFocusedContentHeight: CGFloat = 58
        static let bottomToolbarCompactContentHeight: CGFloat = 44
        static let bottomToolbarButtonStackHeight: CGFloat = 30
        static let addressBarHorizontalInset: CGFloat = 12
        static let addressBarTopInset: CGFloat = 8
        static let bottomToolbarButtonStackHorizontalInset: CGFloat = 24
        static let bottomToolbarButtonStackTopSpacing: CGFloat = 7
        static let bottomToolbarButtonSpacing: CGFloat = 8
        static let backgroundViewHorizontalExtension: CGFloat = 16
    }
    
    enum LayoutState {
        case hidden
        case collapsed // visually hidden but still takes up space
        case standard
        case focused
        case compact
    }

    enum QuickAction {
        case reload
        case desktopSite
        case copyURL
        case bookmark
        case toggleDownloads
        case newTab
    }
    
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var onShare: (() -> Void)?
    var onBasket: (() -> Void)?
    var onDownloads: (() -> Void)?
    var onTabOverview: (() -> Void)?
    var onQuickAction: ((QuickAction) -> Void)?
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private let backgroundView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect.nonAdaptive(style: .regular)
        } else {
            effect = UIBlurEffect(style: .systemChromeMaterial)
        }
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var backButton = ToolbarButton(buttonType: .back, target: self, action: #selector(backTapped))
    private lazy var forwardButton = ToolbarButton(buttonType: .forward, target: self, action: #selector(forwardTapped))
    private lazy var shareButton = ToolbarButton(buttonType: .share, target: self, action: #selector(shareTapped))
    private lazy var basketButton: ToolbarButton = {
        let button = ToolbarButton(buttonType: .library, target: self, action: #selector(basketTapped))
        button.setImage(UIImage(systemName: "tray.full"), for: .normal)
        button.accessibilityLabel = NSLocalizedString("Quick actions", comment: "")
        return button
    }()
    private lazy var downloadButton = ToolbarButton(buttonType: .download, target: self, action: #selector(downloadsTapped))
    private lazy var tabOverviewButton = ToolbarButton(buttonType: .tabOverview, target: self, action: #selector(tabOverviewTapped))
    
    private lazy var buttons: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = UX.bottomToolbarButtonSpacing
        return stack
    }()

    private var preferencesObserver: NSObjectProtocol?
    private var quickActionMenuDelegates: [BottomToolbarQuickActionMenuDelegate] = []
    
    private var topConstraint: NSLayoutConstraint!
    private var contentHeightConstraint: NSLayoutConstraint!
    private var buttonsHeightConstraint: NSLayoutConstraint!
    private var standardButtonsTopConstraint: NSLayoutConstraint!
    private var compactButtonsTopConstraint: NSLayoutConstraint!
    private var addressBarConstraints: [NSLayoutConstraint] = []
    
    private var verticalOffset: CGFloat = 0
    
    // MARK: - Lifecycle
    
    init() {
        super.init(frame: .zero)
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        configureInitialState()
        configureBottomToolbarPreferences()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
    }
    
    // MARK: - Layout
    
    func configureTopAnchor(to safeAreaBottomAnchor: NSLayoutYAxisAnchor) {
        topConstraint = topAnchor.constraint(equalTo: safeAreaBottomAnchor, constant: -UX.bottomToolbarStandardContentHeight)
        topConstraint.isActive = true
    }
    
    func attachAddressBar(_ addressBar: AddressBar) {
        if addressBar.superview !== contentView {
            addressBar.removeFromSuperview()
            contentView.addSubview(addressBar)
        }
        if addressBarConstraints.isEmpty {
            addressBarConstraints = [
                addressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UX.addressBarHorizontalInset),
                addressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UX.addressBarHorizontalInset),
                addressBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.addressBarTopInset),
            ]
        }
        standardButtonsTopConstraint?.isActive = false
        standardButtonsTopConstraint = buttons.topAnchor.constraint(
            equalTo: addressBar.bottomAnchor,
            constant: UX.bottomToolbarButtonStackTopSpacing
        )
        NSLayoutConstraint.activate(addressBarConstraints)
    }
    
    func detachAddressBar() {
        NSLayoutConstraint.deactivate(addressBarConstraints)
        standardButtonsTopConstraint?.isActive = false
    }
    
    func apply(state: LayoutState, hidesButtons: Bool) {
        let contentHeight: CGFloat
        switch state {
        case .hidden:
            contentHeight = UX.bottomToolbarStandardContentHeight
        case .collapsed:
            contentHeight = UX.bottomToolbarCompactContentHeight
        case .standard:
            contentHeight = UX.bottomToolbarStandardContentHeight
        case .focused:
            contentHeight = UX.bottomToolbarFocusedContentHeight
        case .compact:
            contentHeight = UX.bottomToolbarCompactContentHeight
        }
        
        UIView.performWithoutAnimation {
            topConstraint.constant = verticalOffset - contentHeight
            contentHeightConstraint.constant = contentHeight
            isHidden = state == .hidden || state == .collapsed
            backgroundView.isHidden = state == .focused
            
            let isCompact = state == .compact || state == .collapsed
            standardButtonsTopConstraint?.isActive = !isCompact
            compactButtonsTopConstraint.isActive = isCompact
            buttonsHeightConstraint.constant = state == .focused ? 0 : UX.bottomToolbarButtonStackHeight
            buttons.alpha = state == .focused || hidesButtons ? 0 : 1
            buttons.isUserInteractionEnabled = state != .focused && !hidesButtons
            layoutIfNeeded()
        }
    }
    
    // MARK: - Updates
    
    func updateNavigation(canGoBack: Bool, canGoForward: Bool, canShare: Bool) {
        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward
        shareButton.isEnabled = canShare
    }
    
    func setVerticalOffset(_ offset: CGFloat) {
        verticalOffset = offset
        topConstraint.constant = offset - contentHeightConstraint.constant
    }
    
    func setContentAlpha(_ alpha: CGFloat) {
        contentView.alpha = alpha
    }
    
    func updateDownload(_ summary: DownloadStoreSummary) {
        downloadButton.applyDownloadSummary(summary)
        downloadButton.isHidden = !downloadButton.isShowingDownloads
    }
    
    func setMenuButtonIndicatesUpdate(_ hasUpdate: Bool) {
        basketButton.setImage(UIImage(systemName: hasUpdate ? "tray.full.fill" : "tray.full"), for: .normal)
    }
    
    // MARK: - Action Wiring
    
    @objc private func backTapped() { onBack?() }
    @objc private func forwardTapped() { onForward?() }
    @objc private func shareTapped() { onShare?() }
    @objc private func basketTapped() { onBasket?() }
    @objc private func downloadsTapped() { onDownloads?() }
    @objc private func tabOverviewTapped() { onTabOverview?() }

    fileprivate func performQuickAction(_ action: QuickAction) {
        onQuickAction?(action)
    }
    
    // MARK: - Preference Customization

    private func configureBottomToolbarPreferences() {
        applyButtonOrder()
        configureQuickActionMenus()
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .bottomToolbarPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyButtonOrder()
            self?.configureQuickActionMenus()
        }
    }

    private func applyButtonOrder() {
        for view in buttons.arrangedSubviews {
            buttons.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let buttonByIdentifier: [String: ToolbarButton] = [
            "back": backButton,
            "forward": forwardButton,
            "share": shareButton,
            "basket": basketButton,
            "downloads": downloadButton,
            "tabs": tabOverviewButton,
        ]
        for identifier in Prefs.ToolbarSettings.bottomButtonOrder {
            guard let button = buttonByIdentifier[identifier] else {
                continue
            }
            buttons.addArrangedSubview(button)
        }
    }

    private func configureQuickActionMenus() {
        let toolbarButtons = [backButton, forwardButton, shareButton, basketButton, downloadButton, tabOverviewButton]
        for button in toolbarButtons {
            for interaction in button.interactions where interaction is UIContextMenuInteraction {
                button.removeInteraction(interaction)
            }
        }
        quickActionMenuDelegates.removeAll()
        guard Prefs.ToolbarSettings.longPressQuickActions else {
            return
        }

        let identifiers = ["back", "forward", "share", "basket", "downloads", "tabs"]
        for (identifier, button) in zip(identifiers, toolbarButtons) {
            let delegate = BottomToolbarQuickActionMenuDelegate(toolbar: self, identifier: identifier)
            button.addInteraction(UIContextMenuInteraction(delegate: delegate))
            quickActionMenuDelegates.append(delegate)
        }
    }

    // MARK: - View Setup
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }
    
    private func configureHierarchy() {
        addSubview(backgroundView)
        addSubview(contentView)
        contentView.addSubview(buttons)
    }
    
    private func configureConstraints() {
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: UX.bottomToolbarStandardContentHeight)
        buttonsHeightConstraint = buttons.heightAnchor.constraint(equalToConstant: UX.bottomToolbarButtonStackHeight)
        compactButtonsTopConstraint = buttons.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.bottomToolbarButtonStackTopSpacing)
        
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -UX.backgroundViewHorizontalExtension),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: UX.backgroundViewHorizontalExtension),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentHeightConstraint,
            
            buttons.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UX.bottomToolbarButtonStackHorizontalInset),
            buttons.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UX.bottomToolbarButtonStackHorizontalInset),
            buttonsHeightConstraint,
        ])
    }
    
    private func configureInitialState() {
        shareButton.isEnabled = false
        downloadButton.isHidden = true
    }
}

private final class BottomToolbarQuickActionMenuDelegate: NSObject, UIContextMenuInteractionDelegate {
    private weak var toolbar: BottomToolbar?
    private let identifier: String

    init(toolbar: BottomToolbar, identifier: String) {
        self.toolbar = toolbar
        self.identifier = identifier
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else {
                return nil
            }
            return UIMenu(children: self.actions)
        }
    }

    private var actions: [UIAction] {
        switch identifier {
        case "back":
            return [
                action(title: "刷新", image: "arrow.clockwise", value: .reload),
                action(title: "请求桌面网站", image: "desktopcomputer", value: .desktopSite),
            ]
        case "forward":
            return [
                action(title: "刷新", image: "arrow.clockwise", value: .reload),
                action(title: "复制 URL", image: "doc.on.doc", value: .copyURL),
            ]
        case "share":
            return [
                action(title: "复制 URL", image: "doc.on.doc", value: .copyURL),
                action(title: "添加到收藏", image: "star", value: .bookmark),
            ]
        case "basket":
            return [
                action(title: "添加到收藏", image: "star", value: .bookmark),
                action(title: "刷新", image: "arrow.clockwise", value: .reload),
            ]
        case "downloads":
            return [
                action(title: "暂停或继续下载", image: "arrow.down.circle", value: .toggleDownloads),
            ]
        case "tabs":
            return [
                action(title: "新建标签页", image: "plus", value: .newTab),
            ]
        default:
            return []
        }
    }

    private func action(title: String, image: String, value: BottomToolbar.QuickAction) -> UIAction {
        return UIAction(title: title, image: UIImage(systemName: image)) { [weak self] _ in
            self?.toolbar?.performQuickAction(value)
        }
    }
}
