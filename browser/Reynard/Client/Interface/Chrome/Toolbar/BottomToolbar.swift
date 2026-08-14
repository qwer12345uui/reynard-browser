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
        static let bottomToolbarCompactContentHeight: CGFloat = 44
        static let bottomToolbarButtonStackHeight: CGFloat = 30
        static let bottomToolbarButtonStackBottomInset: CGFloat = 5
        static let addressBarHorizontalInset: CGFloat = 12
        static let addressBarTopInset: CGFloat = 8
        static let bottomToolbarButtonStackHorizontalInset: CGFloat = 24
        static let bottomToolbarButtonStackTopSpacing: CGFloat = 7
        static let bottomToolbarButtonSpacing: CGFloat = 8
        static let backgroundViewHorizontalExtension: CGFloat = 16
        static let navigationGlassHorizontalInset: CGFloat = 12
        static let navigationGlassHeight: CGFloat = 42
        static let navigationGlassCornerRadius: CGFloat = 21
    }
    
    enum LayoutState {
        case hidden
        case collapsed // visually hidden but still takes up space
        case standard
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

    private let navigationGlassShadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.12)
        view.layer.cornerRadius = UX.navigationGlassCornerRadius
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.22).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 12
        view.layer.shadowOffset = CGSize(width: 0, height: 5)
        return view
    }()

    private let navigationGlassView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = UX.navigationGlassCornerRadius
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.68).cgColor
        view.clipsToBounds = true
        view.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.10)
        return view
    }()
    
    private let keyboardDockedBlurView: UIView = {
        let view = VariableBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.direction = .up
        view.isHidden = true
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
    private let buttonMenus = ToolbarButtonMenus()
    
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
    private var standardButtonsBottomConstraint: NSLayoutConstraint!
    private var compactButtonsTopConstraint: NSLayoutConstraint!
    private var addressBarConstraints: [NSLayoutConstraint] = []
    private var addressBarTopConstraint: NSLayoutConstraint?
    private weak var addressBar: AddressBar?
    
    private var addressBarDockOffset: CGFloat = 0
    
    private func addressBarTopConstant(for dockOffset: CGFloat) -> CGFloat {
        let dockedAdjustment = dockOffset == 0 ? 0 : UX.addressBarDockedVerticalAdjustment
        return UX.addressBarTopInset + dockOffset + dockedAdjustment
    }
    
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
        self.addressBar = addressBar
        if addressBar.superview !== contentView {
            addressBar.removeFromSuperview()
            contentView.addSubview(addressBar)
        }
        if addressBarConstraints.isEmpty {
            let topConstraint = addressBar.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: addressBarTopConstant(for: addressBarDockOffset)
            )
            addressBarTopConstraint = topConstraint
            addressBarConstraints = [
                addressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UX.addressBarHorizontalInset),
                addressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UX.addressBarHorizontalInset),
                topConstraint,
            ]
        }
        addressBarTopConstraint?.constant = addressBarTopConstant(for: addressBarDockOffset)
        NSLayoutConstraint.activate(addressBarConstraints)
    }
    
    func detachAddressBar() {
        NSLayoutConstraint.deactivate(addressBarConstraints)
        addressBar = nil
    }
    
    func hitTestAddressBar(at point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden,
              isUserInteractionEnabled,
              alpha > 0.01,
              !contentView.isHidden,
              contentView.isUserInteractionEnabled,
              contentView.alpha > 0.01,
              let addressBar else {
            return nil
        }
        return addressBar.hitTest(addressBar.convert(point, from: self), with: event)
    }
    
    func apply(state: LayoutState, hidesButtons: Bool) {
        let contentHeight: CGFloat
        switch state {
        case .hidden, .standard:
            contentHeight = UX.bottomToolbarStandardContentHeight
        case .collapsed, .compact:
            contentHeight = UX.bottomToolbarCompactContentHeight
        }
        
        UIView.performWithoutAnimation {
            topConstraint.constant = -contentHeight
            contentHeightConstraint.constant = contentHeight
            isHidden = state == .hidden || state == .collapsed
            backgroundView.isHidden = state == .focused
            let hidesNavigationGlass = state == .focused || hidesButtons
            navigationGlassView.isHidden = hidesNavigationGlass
            navigationGlassShadowView.isHidden = hidesNavigationGlass
            
            let isCompact = state == .compact || state == .collapsed
            standardButtonsBottomConstraint?.isActive = !isCompact
            compactButtonsTopConstraint.isActive = isCompact
            buttons.alpha = hidesButtons ? 0 : 1
            buttons.isUserInteractionEnabled = !hidesButtons
            layoutIfNeeded()
        }
    }
    
    // MARK: - Updates
    
    func updateNavigation(canGoBack: Bool, canGoForward: Bool, canShare: Bool) {
        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward
        shareButton.isEnabled = canShare
    }
    
    func configureNavigationMenus(
        itemsProvider: @escaping (ToolbarButtonMenus.NavigationDirection) -> [NavigationHistoryStore.HistoryItem],
        onSelect: @escaping (ToolbarButtonMenus.NavigationDirection, Int) -> Void
    ) {
        buttonMenus.installNavigationMenus(
            on: backButton,
            forwardButton: forwardButton,
            itemsProvider: itemsProvider,
            onSelect: onSelect
        )
    }
    
    func configureLibraryMenus(onSelect: @escaping (LibrarySection) -> Void) {
        buttonMenus.installLibraryMenus(on: [libraryButton], onSelect: onSelect)
    }
    
    func configureTabOverviewMenus(
        tabCountProvider: @escaping () -> Int,
        onCloseAllTabs: @escaping () -> Void,
        onCloseTab: @escaping () -> Void,
        onNewPrivateTab: @escaping () -> Void,
        onNewTab: @escaping () -> Void
    ) {
        buttonMenus.installTabOverviewMenus(
            on: [tabOverviewButton],
            tabCountProvider: tabCountProvider,
            onCloseAllTabs: onCloseAllTabs,
            onCloseTab: onCloseTab,
            onNewPrivateTab: onNewPrivateTab,
            onNewTab: onNewTab
        )
    }
    
    func setAddressBarDockOffset(_ offset: CGFloat) {
        addressBarDockOffset = offset
        addressBarTopConstraint?.constant = addressBarTopConstant(for: offset)
        keyboardDockedBlurView.transform = CGAffineTransform(translationX: 0, y: offset)
        keyboardDockedBlurView.isHidden = offset == 0
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
        addSubview(keyboardDockedBlurView)
        addSubview(backgroundView)
        addSubview(contentView)
        contentView.addSubview(navigationGlassShadowView)
        contentView.addSubview(navigationGlassView)
        contentView.addSubview(buttons)
    }
    
    private func configureConstraints() {
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: UX.bottomToolbarStandardContentHeight)
        standardButtonsBottomConstraint = buttons.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -UX.bottomToolbarButtonStackBottomInset
        )
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
            
            navigationGlassView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UX.navigationGlassHorizontalInset),
            navigationGlassView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UX.navigationGlassHorizontalInset),
            navigationGlassView.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            navigationGlassView.heightAnchor.constraint(equalToConstant: UX.navigationGlassHeight),

            navigationGlassShadowView.leadingAnchor.constraint(equalTo: navigationGlassView.leadingAnchor),
            navigationGlassShadowView.trailingAnchor.constraint(equalTo: navigationGlassView.trailingAnchor),
            navigationGlassShadowView.topAnchor.constraint(equalTo: navigationGlassView.topAnchor),
            navigationGlassShadowView.bottomAnchor.constraint(equalTo: navigationGlassView.bottomAnchor),

            buttons.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UX.bottomToolbarButtonStackHorizontalInset),
            buttons.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UX.bottomToolbarButtonStackHorizontalInset),
            buttons.heightAnchor.constraint(equalToConstant: UX.bottomToolbarButtonStackHeight),
        ])
        
        NSLayoutConstraint.activate([
            keyboardDockedBlurView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -UX.backgroundViewHorizontalExtension),
            keyboardDockedBlurView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: UX.backgroundViewHorizontalExtension),
            keyboardDockedBlurView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: UX.addressBarDockedVerticalAdjustment - UX.keyboardDockedBlurTopExtension
            ),
            keyboardDockedBlurView.bottomAnchor.constraint(equalTo: bottomAnchor),
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
