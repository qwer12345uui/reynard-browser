//
//  ContentView.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import GeckoView
import UIKit

final class ContentView: UIView, UIGestureRecognizerDelegate {
    struct ThumbnailGeometry {
        let fullFrame: CGRect
        let cropRect: CGRect
    }
    
    struct ThumbnailCaptureGeometry {
        let size: CGSize
        let visibleRect: CGRect
    }
    
    private enum UX {
        static let phoneSearchFocusedBottomInset: CGFloat = 94
        static let focusedInputBottomClearance: CGFloat = 12
        static let focusedInputOffsetThreshold: CGFloat = 0.5
        static let historyPreviewParallaxRatio: CGFloat = 0.33
        static let historyTransitionOverlayMaximumAlpha: CGFloat = 0.12
        static let historyTransitionProjectionDuration: CGFloat = 0.2
        static let historyTransitionDuration: TimeInterval = 0.35
    }
    
    private enum HistorySwipeDirection: Equatable {
        case back
        case forward
    }
    
    private enum HistorySwipeState {
        case idle // No history swipe is active.
        case swiping(HistorySwipeDirection) // Gesture is tracking the user's drag.
        case settling // Swipe completed; finish animation is running.
        case settled // Location changed before finish animation ended.
        case loaded // Page load completed before finish animation ended.
        case loading // Finish animation ended; waiting for page load.
        case resetting // Location changed without a load; reset on next run loop.
    }
    
    struct State: Equatable {
        let webVisibility: WebContentView.VisibilityState
        let overlayPresentation: OverlayContentView.PresentationState
        
        static let browsing = State(
            webVisibility: .visible,
            overlayPresentation: .hidden
        )
    }
    
    struct LayoutState: Equatable {
        enum Mode: Equatable {
            case standard
            case searchFocused
            case fullscreen
        }
        
        let mode: Mode
    }
    
    private(set) var state: State = .browsing
    private var layoutState = LayoutState(mode: .standard)
    private var session: GeckoSession?
    private var dynamicToolbarMaxHeight: CGFloat = 0
    private var contentBottomOffset: CGFloat = 0
    private var toolbarTopOffset: CGFloat = 0
    private var maxTopToolbarOffset: CGFloat = 0
    private var focusedInputTask: Task<Void, Never>?
    private var inputBottomRatio: CGFloat?
    private var isSystemTextInputActive = false
    private var focusedInputOffset: CGFloat = 0
    private var historyEdgePanGestures: [UIScreenEdgePanGestureRecognizer] = []
    private var fullScreenHistoryPanGesture: UIPanGestureRecognizer?
    
    private var canGoBack = false
    private var canGoForward = false
    private var backPreviewImage: UIImage?
    private var forwardPreviewImage: UIImage?
    private var isHistorySwipeEnabled = false
    private var historySwipeState = HistorySwipeState.idle
    private var activeHistorySwipeDirection: HistorySwipeDirection?
    private var webContentSize: CGSize?
    
    private let webContentView = WebContentView()
    private let overlayContentView = OverlayContentView()
    private let historyPreviewImageView = UIImageView()
    private let historyTransitionOverlayView = UIView()
    
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var onHistorySwipeBegan: (() -> Void)?
    var onHistorySwipeEnded: (() -> Void)?
    var onVerticalScroll: ((CGFloat) -> Void)?
    
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var webContentBottomConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        configureHistoryNavigation()
        applyState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        focusedInputTask?.cancel()
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .systemBackground
    }
    
    private func configureHierarchy() {
        webContentView.translatesAutoresizingMaskIntoConstraints = false
        historyPreviewImageView.translatesAutoresizingMaskIntoConstraints = false
        historyTransitionOverlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayContentView.translatesAutoresizingMaskIntoConstraints = false
        historyPreviewImageView.isHidden = true
        historyPreviewImageView.backgroundColor = .systemBackground
        historyPreviewImageView.contentMode = .scaleAspectFill
        historyPreviewImageView.clipsToBounds = true
        historyTransitionOverlayView.isHidden = true
        historyTransitionOverlayView.backgroundColor = .black
        historyTransitionOverlayView.alpha = 0
        addSubview(webContentView)
        addSubview(historyPreviewImageView)
        addSubview(historyTransitionOverlayView)
        addSubview(overlayContentView)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            webContentView.topAnchor.constraint(equalTo: topAnchor),
            webContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        [historyPreviewImageView, historyTransitionOverlayView].forEach { contentView in
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
    }
    
    private func configureHistoryNavigation() {
        let backGesture = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleBackHistoryPan(_:))
        )
        backGesture.edges = .left
        backGesture.delegate = self
        addGestureRecognizer(backGesture)
        
        let forwardGesture = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleForwardHistoryPan(_:))
        )
        forwardGesture.edges = .right
        forwardGesture.delegate = self
        addGestureRecognizer(forwardGesture)
        historyEdgePanGestures = [backGesture, forwardGesture]

        let fullScreenPanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handleFullScreenHistoryPan(_:))
        )
        fullScreenPanGesture.delegate = self
        fullScreenPanGesture.cancelsTouchesInView = false
        fullScreenPanGesture.delaysTouchesBegan = false
        fullScreenPanGesture.delaysTouchesEnded = false
        addGestureRecognizer(fullScreenPanGesture)
        fullScreenHistoryPanGesture = fullScreenPanGesture
        
        webContentView.historySwipeDirectionsProvider = { [weak self] in
            return self?.allowedTrackpadHistorySwipeDirections() ?? []
        }
        webContentView.onHistorySwipeDidStart = { [weak self] direction in
            self?.beginTrackpadHistoryNavigation(direction)
        }
        webContentView.onHistorySwipeDidUpdate = { [weak self] progress in
            self?.updateTrackpadHistoryNavigation(progress)
        }
        webContentView.onHistorySwipeDidComplete = { [weak self] direction in
            self?.completeTrackpadHistoryNavigation(direction)
        }
        webContentView.onHistorySwipeDidEnd = { [weak self] in
            self?.endTrackpadHistoryNavigation()
        }
        webContentView.onVerticalScroll = { [weak self] delta in
            self?.onVerticalScroll?(delta)
        }
    }
    
    // MARK: - Layout
    
    func applyLayout(
        _ layoutState: LayoutState,
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor
    ) {
        self.layoutState = layoutState
        applyLayoutState(topAnchor: topAnchor, bottomAnchor: bottomAnchor)
    }
    
    func setSystemTextInputActive(_ active: Bool) {
        guard isSystemTextInputActive != active else {
            return
        }
        isSystemTextInputActive = active
        historyEdgePanGestures.forEach { $0.isEnabled = !active }
        fullScreenHistoryPanGesture?.isEnabled = !active
        webContentView.setSystemTextInputActive(active)
    }

    func reloadBrowsingPreferences() {
        if Prefs.BrowsingSettings.historyGestureMode == .disabled {
            resetHistoryNavigation()
        }
        updatePullToRefreshAvailability()
    }

    func updateWebContentSize() -> Bool {
        let size = webContentView.bounds.size
        guard size.width > 1, size.height > 1 else {
            return false
        }
        defer { webContentSize = size }
        
        guard let previousSize = webContentSize else {
            return false
        }
        
        return previousSize != size
    }
    
    func setToolbarLimits(maxHeight: CGFloat, topOffset: CGFloat) {
        if maxHeight != dynamicToolbarMaxHeight {
            dynamicToolbarMaxHeight = maxHeight
            session?.setDynamicToolbarMaxHeight(maxHeight)
        }
        
        guard abs(topOffset - maxTopToolbarOffset) > 0.5 else {
            return
        }
        maxTopToolbarOffset = topOffset
        updateContentBottomInset()
    }
    
    func applyToolbarOffsets(top: CGFloat, bottom: CGFloat) {
        toolbarTopOffset = top
        webContentView.transform = toolbarAlignedTransform(
            translationX: webContentView.transform.tx
        )
        historyPreviewImageView.transform = toolbarAlignedTransform(
            translationX: historyPreviewImageView.transform.tx
        )
        historyTransitionOverlayView.transform = toolbarAlignedTransform(
            translationX: historyTransitionOverlayView.transform.tx
        )
        let contentBottomOffset = -bottom
        guard contentBottomOffset != self.contentBottomOffset else {
            return
        }
        self.contentBottomOffset = contentBottomOffset
        session?.setContentBottomOffset(contentBottomOffset)
    }
    
    private func toolbarAlignedTransform(translationX: CGFloat) -> CGAffineTransform {
        return CGAffineTransform(translationX: translationX, y: -toolbarTopOffset)
    }
    
    func configureLayout(
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor
    ) {
        let bottomConstraint = webContentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomConstraint.isActive = true
        webContentBottomConstraint = bottomConstraint
        webContentView.extendPageBackground(to: topAnchor)
        [historyPreviewImageView, historyTransitionOverlayView].forEach { contentView in
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: topAnchor),
                contentView.bottomAnchor.constraint(equalTo: webContentView.bottomAnchor),
            ])
        }
        overlayContentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        overlayContentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        overlayContentView.configureContentLayout(
            topAnchor: self.topAnchor,
            bottomAnchor: self.bottomAnchor
        )
    }
    
    private func applyLayoutState(
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor
    ) {
        let nextTopConstraint = self.topAnchor.constraint(equalTo: topAnchor)
        let nextBottomConstraint = self.bottomAnchor.constraint(equalTo: bottomAnchor)
        guard canActivateConstraints([nextTopConstraint, nextBottomConstraint]) else {
            return
        }
        
        topConstraint?.isActive = false
        bottomConstraint?.isActive = false
        
        NSLayoutConstraint.activate([nextTopConstraint, nextBottomConstraint])
        topConstraint = nextTopConstraint
        bottomConstraint = nextBottomConstraint
        updateLayoutOffsets()
        updatePullToRefreshAvailability()
    }
    
    private func canActivateConstraints(_ constraints: [NSLayoutConstraint]) -> Bool {
        constraints.allSatisfy { constraint in
            guard let firstView = owningView(for: constraint.firstItem),
                  let secondView = owningView(for: constraint.secondItem) else {
                return true
            }
            
            return firstView.hasCommonAncestor(with: secondView)
        }
    }
    
    private func owningView(for item: Any?) -> UIView? {
        if let view = item as? UIView {
            return view
        }
        
        if let layoutGuide = item as? UILayoutGuide {
            return layoutGuide.owningView
        }
        
        return nil
    }
    
    private func updateLayoutOffsets() {
        topConstraint?.constant = layoutState.mode == .fullscreen ? 0 : -focusedInputOffset
        switch layoutState.mode {
        case .standard:
            bottomConstraint?.constant = -focusedInputOffset
        case .searchFocused:
            bottomConstraint?.constant = -UX.phoneSearchFocusedBottomInset
        case .fullscreen:
            bottomConstraint?.constant = 0
        }
        updateContentBottomInset()
    }
    
    private func updateContentBottomInset() {
        webContentBottomConstraint?.constant = maxTopToolbarOffset - focusedInputOffset
    }
    
    // MARK: - Focused Input Relocation
    
    func relocateFocusedInput(
        above keyboardFrame: CGRect,
        animationDuration: TimeInterval,
        animationOptions: UIView.AnimationOptions
    ) {
        focusedInputTask?.cancel()
        guard let session else {
            resetFocusedInputRelocation(
                animationDuration: animationDuration,
                animationOptions: animationOptions
            )
            return
        }
        
        focusedInputTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let bottomRatio = await session.focusedInputBottomRatio()
            guard !Task.isCancelled else { return }
            
            inputBottomRatio = bottomRatio
            superview?.layoutIfNeeded()
            let newOffset = calculateFocusedInputOffset(keyboardFrame: keyboardFrame)
            guard abs(newOffset - focusedInputOffset) > UX.focusedInputOffsetThreshold else {
                return
            }
            
            focusedInputOffset = newOffset
            updateLayoutOffsets()
            animateLayout(duration: animationDuration, options: animationOptions)
        }
    }
    
    private func calculateFocusedInputOffset(keyboardFrame: CGRect) -> CGFloat {
        guard let inputBottomRatio else { return 0 }
        
        let unshiftedFrame = frame.offsetBy(dx: 0, dy: focusedInputOffset)
        guard unshiftedFrame.height > 1 else { return 0 }
        
        let keyboardOverlap = max(0, unshiftedFrame.maxY - keyboardFrame.minY)
        guard keyboardOverlap > 0 else { return 0 }
        
        let focusBottom = unshiftedFrame.height * inputBottomRatio
        let visibleBottom = max(
            0,
            unshiftedFrame.height - keyboardOverlap - UX.focusedInputBottomClearance
        )
        return min(keyboardOverlap, max(0, focusBottom - visibleBottom))
    }
    
    func resetFocusedInputRelocation(
        animationDuration: TimeInterval = 0,
        animationOptions: UIView.AnimationOptions = []
    ) {
        focusedInputTask?.cancel()
        focusedInputTask = nil
        inputBottomRatio = nil
        guard focusedInputOffset != 0 else { return }
        
        focusedInputOffset = 0
        updateLayoutOffsets()
        animateLayout(duration: animationDuration, options: animationOptions)
    }
    
    private func animateLayout(duration: TimeInterval, options: UIView.AnimationOptions) {
        guard duration > 0 else {
            superview?.layoutIfNeeded()
            return
        }
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.superview?.layoutIfNeeded()
        }
    }
    
    // MARK: - State
    
    func setState(_ state: State) {
        guard self.state != state else {
            return
        }
        
        self.state = state
        applyState()
    }
    
    func setWebVisibility(_ visibility: WebContentView.VisibilityState) {
        setState(State(
            webVisibility: visibility,
            overlayPresentation: state.overlayPresentation
        ))
    }
    
    func setOverlayPresentation(
        _ presentation: OverlayContentView.PresentationState,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        self.state = State(
            webVisibility: state.webVisibility,
            overlayPresentation: presentation
        )
        webContentView.setVisibility(state.webVisibility)
        overlayContentView.setPresentation(presentation, animated: animated, completion: completion)
        updatePullToRefreshAvailability()
    }
    
    private func applyState() {
        webContentView.setVisibility(state.webVisibility)
        overlayContentView.setPresentation(state.overlayPresentation, animated: false)
        updatePullToRefreshAvailability()
    }
    
    // MARK: - Session
    
    func setTab(_ tab: Tab?, pageBackgroundColor: UIColor? = nil) {
        resetHistoryNavigation()
        self.session = tab?.session
        resetFocusedInputRelocation()
        webContentView.setTab(tab, pageBackgroundColor: pageBackgroundColor)
        tab?.session.setDynamicToolbarMaxHeight(dynamicToolbarMaxHeight)
        tab?.session.setContentBottomOffset(contentBottomOffset)
        updatePullToRefreshAvailability()
    }
    
    func setPageBackgroundColor(_ color: UIColor) {
        webContentView.setPageBackgroundColor(color)
    }
    
    func resetScrollTracking() {
        webContentView.resetScrollTracking()
    }
    
    func showPageError(for url: String?) {
        webContentView.showPageError(for: url)
    }
    
    func didFinishLoading(session: GeckoSession) {
        webContentView.didFinishLoading(session: session)
    }
    
    func isDisplaying(session: GeckoSession) -> Bool {
        webContentView.isDisplaying(session: session)
    }
    
    func restoreInteraction(for session: GeckoSession) {
        webContentView.restoreInteraction(for: session)
    }
    
    // MARK: - Interaction
    
    func addWebViewInteraction(_ interaction: UIInteraction) {
        webContentView.addWebViewInteraction(interaction)
    }
    
    // MARK: - History Navigation
    
    func setHistoryNavigation(
        canGoBack: Bool,
        canGoForward: Bool,
        backPreviewImage: UIImage?,
        forwardPreviewImage: UIImage?,
        isSwipeEnabled: Bool
    ) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.backPreviewImage = backPreviewImage
        self.forwardPreviewImage = forwardPreviewImage
        isHistorySwipeEnabled = isSwipeEnabled
    }
    
    @objc private func handleBackHistoryPan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        handleHistoryPan(gesture, direction: .back)
    }
    
    @objc private func handleForwardHistoryPan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        handleHistoryPan(gesture, direction: .forward)
    }

    @objc private func handleFullScreenHistoryPan(_ gesture: UIPanGestureRecognizer) {
        let direction: HistorySwipeDirection?
        switch gesture.state {
        case .began:
            let velocityX = gesture.velocity(in: self).x
            direction = velocityX >= 0 ? .back : .forward
        default:
            direction = activeHistorySwipeDirection
        }
        guard let direction else { return }
        handleHistoryPan(gesture, direction: direction)
    }
    
    private func handleHistoryPan(
        _ gesture: UIPanGestureRecognizer,
        direction: HistorySwipeDirection
    ) {
        switch gesture.state {
        case .began:
            beginHistoryNavigation(direction)
        case .changed:
            updateHistoryNavigation(gesture, direction: direction)
        case .ended:
            finishHistoryNavigation(gesture, direction: direction, cancelled: false)
        case .cancelled, .failed:
            finishHistoryNavigation(gesture, direction: direction, cancelled: true)
        default:
            break
        }
    }
    
    private func beginHistoryNavigation(_ direction: HistorySwipeDirection) {
        guard case .idle = historySwipeState else {
            return
        }
        
        onHistorySwipeBegan?()
        historySwipeState = .swiping(direction)
        activeHistorySwipeDirection = direction
        updatePullToRefreshAvailability()
        historyPreviewImageView.image = direction == .back ? backPreviewImage : forwardPreviewImage
        historyPreviewImageView.isHidden = false
        historyTransitionOverlayView.isHidden = false
        
        let width = bounds.width
        switch direction {
        case .back:
            insertSubview(historyPreviewImageView, belowSubview: webContentView)
            insertSubview(historyTransitionOverlayView, belowSubview: webContentView)
            historyPreviewImageView.transform = toolbarAlignedTransform(
                translationX: -width * UX.historyPreviewParallaxRatio
            )
            updateHistoryTransitionOverlay(direction: direction, progress: 0)
        case .forward:
            insertSubview(historyTransitionOverlayView, aboveSubview: webContentView)
            insertSubview(historyPreviewImageView, aboveSubview: historyTransitionOverlayView)
            historyPreviewImageView.transform = toolbarAlignedTransform(translationX: width)
            updateHistoryTransitionOverlay(direction: direction, progress: 0)
        }
        historyTransitionOverlayView.transform = toolbarAlignedTransform(translationX: 0)
    }
    
    private func updateHistoryNavigation(
        _ gesture: UIPanGestureRecognizer,
        direction: HistorySwipeDirection
    ) {
        let progress = historyNavigationProgress(for: gesture, direction: direction)
        updateHistoryNavigation(progress: progress, direction: direction)
    }
    
    private func updateHistoryNavigation(
        progress: CGFloat,
        direction: HistorySwipeDirection
    ) {
        guard case .swiping(let activeDirection) = historySwipeState,
              activeDirection == direction else {
            return
        }
        
        let width = bounds.width
        switch direction {
        case .back:
            webContentView.transform = toolbarAlignedTransform(translationX: width * progress)
            historyPreviewImageView.transform = toolbarAlignedTransform(
                translationX: -width * UX.historyPreviewParallaxRatio * (1 - progress)
            )
        case .forward:
            historyPreviewImageView.transform = toolbarAlignedTransform(
                translationX: width * (1 - progress)
            )
        }
        updateHistoryTransitionOverlay(direction: direction, progress: progress)
    }
    
    private func finishHistoryNavigation(
        _ gesture: UIPanGestureRecognizer,
        direction: HistorySwipeDirection,
        cancelled: Bool
    ) {
        guard case .swiping(let activeDirection) = historySwipeState,
              activeDirection == direction else {
            resetHistoryNavigation()
            return
        }
        
        let progress = historyNavigationProgress(for: gesture, direction: direction)
        let velocityX = gesture.velocity(in: self).x
        let directionalVelocity: CGFloat
        switch direction {
        case .back:
            directionalVelocity = max(velocityX, 0)
        case .forward:
            directionalVelocity = max(-velocityX, 0)
        }
        
        let width = bounds.width
        let projectedDistance = width * progress
        + directionalVelocity * UX.historyTransitionProjectionDuration
        let shouldComplete = !cancelled && projectedDistance >= width
        
        settleHistoryNavigation(
            direction: direction,
            shouldComplete: shouldComplete,
            velocityX: velocityX
        )
    }
    
    private func settleHistoryNavigation(
        direction: HistorySwipeDirection,
        shouldComplete: Bool,
        velocityX: CGFloat
    ) {
        let width = bounds.width
        UIView.animate(
            withDuration: UX.historyTransitionDuration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: abs(velocityX) / max(width, 1),
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            if shouldComplete {
                self.historySwipeState = .settling
                switch direction {
                case .back:
                    self.webContentView.transform = self.toolbarAlignedTransform(translationX: width)
                    self.historyPreviewImageView.transform = self.toolbarAlignedTransform(translationX: 0)
                    self.updateHistoryTransitionOverlay(direction: direction, progress: 1)
                    self.onBack?()
                case .forward:
                    self.historyPreviewImageView.transform = self.toolbarAlignedTransform(translationX: 0)
                    self.updateHistoryTransitionOverlay(direction: direction, progress: 1)
                    self.onForward?()
                }
            } else {
                self.webContentView.transform = self.toolbarAlignedTransform(translationX: 0)
                switch direction {
                case .back:
                    self.historyPreviewImageView.transform = self.toolbarAlignedTransform(
                        translationX: -width * UX.historyPreviewParallaxRatio
                    )
                    self.updateHistoryTransitionOverlay(direction: direction, progress: 0)
                case .forward:
                    self.historyPreviewImageView.transform = self.toolbarAlignedTransform(translationX: width)
                    self.updateHistoryTransitionOverlay(direction: direction, progress: 0)
                }
            }
        } completion: { _ in
            guard shouldComplete else {
                self.resetHistoryNavigation()
                return
            }
            
            if case .loaded = self.historySwipeState {
                self.resetHistoryNavigation()
                return
            }
            
            switch self.historySwipeState {
            case .settling:
                self.historySwipeState = .loading
            case .settled:
                self.scheduleHistoryLocationReset()
            default:
                break
            }
        }
    }
    
    private func historyNavigationProgress(
        for gesture: UIPanGestureRecognizer,
        direction: HistorySwipeDirection
    ) -> CGFloat {
        let translationX = gesture.translation(in: self).x
        let distance: CGFloat
        switch direction {
        case .back:
            distance = translationX
        case .forward:
            distance = -translationX
        }
        return min(max(distance / max(bounds.width, 1), 0), 1)
    }
    
    private func allowedTrackpadHistorySwipeDirections() -> GeckoEdgeSwipeDirections {
        guard canBeginHistoryNavigation else {
            return []
        }
        
        var directions: GeckoEdgeSwipeDirections = []
        if canGoBack {
            directions.insert(.left)
        }
        if canGoForward {
            directions.insert(.right)
        }
        return directions
    }
    
    private func beginTrackpadHistoryNavigation(_ direction: GeckoEdgeSwipeDirections) {
        guard let direction = historySwipeDirection(from: direction) else {
            return
        }
        beginHistoryNavigation(direction)
    }
    
    private func updateTrackpadHistoryNavigation(_ progress: CGFloat) {
        guard let direction = activeHistorySwipeDirection else {
            return
        }
        updateHistoryNavigation(
            progress: min(max(progress, 0), 1),
            direction: direction
        )
    }
    
    private func completeTrackpadHistoryNavigation(_ direction: GeckoEdgeSwipeDirections) {
        guard let direction = historySwipeDirection(from: direction),
              direction == activeHistorySwipeDirection,
              case .swiping(let activeDirection) = historySwipeState,
              activeDirection == direction else {
            return
        }
        
        settleHistoryNavigation(
            direction: direction,
            shouldComplete: true,
            velocityX: 0
        )
    }
    
    private func endTrackpadHistoryNavigation() {
        guard case .swiping = historySwipeState else {
            return
        }
        resetHistoryNavigation()
    }
    
    private func historySwipeDirection(
        from direction: GeckoEdgeSwipeDirections
    ) -> HistorySwipeDirection? {
        if direction.contains(.left) {
            return .back
        }
        if direction.contains(.right) {
            return .forward
        }
        return nil
    }
    
    private func updateHistoryTransitionOverlay(
        direction: HistorySwipeDirection,
        progress: CGFloat
    ) {
        let leadingEdgeProgress: CGFloat
        switch direction {
        case .back:
            leadingEdgeProgress = 1 - progress
        case .forward:
            leadingEdgeProgress = progress
        }
        
        historyTransitionOverlayView.alpha = UX.historyTransitionOverlayMaximumAlpha * leadingEdgeProgress
    }
    
    private func resetHistoryNavigation() {
        webContentView.transform = toolbarAlignedTransform(translationX: 0)
        historyPreviewImageView.transform = .identity
        historyTransitionOverlayView.transform = .identity
        historyPreviewImageView.image = nil
        historyPreviewImageView.isHidden = true
        historyTransitionOverlayView.alpha = 0
        historyTransitionOverlayView.isHidden = true
        historySwipeState = .idle
        activeHistorySwipeDirection = nil
        updatePullToRefreshAvailability()
        onHistorySwipeEnded?()
    }
    
    private func updatePullToRefreshAvailability() {
        let isHistoryNavigationIdle: Bool
        if case .idle = historySwipeState {
            isHistoryNavigationIdle = true
        } else {
            isHistoryNavigationIdle = false
        }
        let isEnabled = Prefs.BrowsingSettings.pullToRefreshEnabled &&
        session != nil &&
        state == .browsing &&
        webContentView.visibility == .visible &&
        layoutState.mode != .fullscreen &&
        isHistoryNavigationIdle
        webContentView.setPullToRefreshEnabled(isEnabled)
    }
    
    func finishHistoryLoad() {
        switch historySwipeState {
        case .settling, .settled:
            historySwipeState = .loaded
        case .loading, .resetting:
            resetHistoryNavigation()
        case .idle, .swiping, .loaded:
            break
        }
    }
    
    func noteHistoryLocationChange() {
        switch historySwipeState {
        case .settling:
            historySwipeState = .settled
        case .loading:
            scheduleHistoryLocationReset()
        case .idle, .swiping, .settled, .loaded, .resetting:
            break
        }
    }
    
    private func scheduleHistoryLocationReset() {
        historySwipeState = .resetting
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  case .resetting = self.historySwipeState else {
                return
            }
            
            self.resetHistoryNavigation()
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard canBeginHistoryNavigation else {
            return false
        }

        switch Prefs.BrowsingSettings.historyGestureMode {
        case .disabled:
            return false
        case .edge:
            guard let edgeGesture = gestureRecognizer as? UIScreenEdgePanGestureRecognizer else {
                return false
            }
            return edgeGesture.edges == .left ? canGoBack : canGoForward
        case .fullscreen:
            guard gestureRecognizer === fullScreenHistoryPanGesture,
                  let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }
            let velocity = panGesture.velocity(in: self)
            guard abs(velocity.x) > abs(velocity.y), abs(velocity.x) > 0 else {
                return false
            }
            return velocity.x > 0 ? canGoBack : canGoForward
        }
    }
    
    private var canBeginHistoryNavigation: Bool {
        guard !isSystemTextInputActive,
              case .idle = historySwipeState else {
            return false
        }
        
        return isHistorySwipeEnabled &&
        state == .browsing &&
        webContentView.visibility == .visible
    }
    
    // MARK: - Presentation
    
    func setTransitionTransform(_ transform: CGAffineTransform) {
        self.transform = transform
    }
    
    func setTransitionHidden(_ hidden: Bool) {
        isHidden = hidden
    }
    
    func frame(in view: UIView) -> CGRect {
        convert(bounds, to: view)
    }
    
    // MARK: - Thumbnail
    
    func thumbnailGeometry(in view: UIView) -> ThumbnailGeometry? {
        let fullFrame = webContentView.thumbnailFrame(in: view)
        let visibleFrame = fullFrame.intersection(frame(in: view))
        guard fullFrame.width > 1,
              fullFrame.height > 1,
              visibleFrame.width > 1,
              visibleFrame.height > 1 else {
            return nil
        }
        
        return ThumbnailGeometry(
            fullFrame: fullFrame,
            cropRect: CGRect(
                x: (visibleFrame.minX - fullFrame.minX) / fullFrame.width,
                y: (visibleFrame.minY - fullFrame.minY) / fullFrame.height,
                width: visibleFrame.width / fullFrame.width,
                height: visibleFrame.height / fullFrame.height
            )
        )
    }
    
    var thumbnailCaptureGeometry: ThumbnailCaptureGeometry? {
        guard let geometry = thumbnailGeometry(in: self) else {
            return nil
        }
        
        let size = geometry.fullFrame.size
        return ThumbnailCaptureGeometry(
            size: size,
            visibleRect: CGRect(
                x: geometry.cropRect.minX * size.width,
                y: geometry.cropRect.minY * size.height,
                width: geometry.cropRect.width * size.width,
                height: geometry.cropRect.height * size.height
            )
        )
    }
    
    func makeWebThumbnail() -> UIImage? {
        return webContentView.makeThumbnail()
    }
    
    // MARK: - Overlay Hosting
    
    func setOverlayController(
        _ viewController: UIViewController,
        for page: OverlayContentView.Page,
        in parentViewController: UIViewController
    ) {
        overlayContentView.setController(viewController, for: page, in: parentViewController)
    }
    
    func layoutOverlayIfNeeded() {
        overlayContentView.layoutIfNeeded()
    }
    
    func removeOverlayController(for page: OverlayContentView.Page) {
        overlayContentView.removeController(for: page)
    }
    
}
