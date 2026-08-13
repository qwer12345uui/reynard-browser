//
//  ToolboxPopupViewController.swift
//  Reynard
//
//  Compact address-bar toolbox presented inside ChromeOverlayContentView.
//

import UIKit

enum ToolboxMode {
    case top
    case bottom
    case bottomToolbox
    case developer
}

enum ToolboxAction {
    case bookmark
    case bookmarks
    case favorite
    case share
    case copyURL
    case openInSafari
    case library
    case history
    case downloads
    case settings
    case toolbox
    case tabOverview
    case reload
    case imageMode
    case mp4
    case videoCapture
    case zoom
    case sniff
    case detectQRCode
    case noImages
    case saveOffline
    case longScreenshot
    case generateQRCode
    case generatePDF
    case adBlock
    case addToBlocklist
    case markMode
    case translate
    case compatibility
    case findInPage
    case siteSearch
    case readerMode
    case bigbang
    case desktopSite
    case customUA
    case pageSource
    case uaAndCookie
    case eruda
    case vConsole
    case scriptStatus
    case clearPageCache
}

private struct ToolboxItem {
    let title: String
    let icon: String
    let action: ToolboxAction
}

private struct ToolboxSection {
    let title: String?
    let items: [ToolboxItem]
}

final class ToolboxPopupViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {
    private enum UX {
        static let horizontalInset: CGFloat = 14
        static let verticalInset: CGFloat = 14
        static let sectionSpacing: CGFloat = 12
        static let itemSpacing: CGFloat = 6
        static let titleHeight: CGFloat = 30
        static let itemHeight: CGFloat = 82
        static let iconSize: CGFloat = 24
        static let itemCornerRadius: CGFloat = 12
    }

    var onAction: ((ToolboxAction) -> Void)?
    var onDismissRequest: (() -> Void)?

    private let mode: ToolboxMode
    private let sections: [ToolboxSection]
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = UX.itemSpacing
        layout.minimumLineSpacing = UX.sectionSpacing
        layout.sectionInset = UIEdgeInsets(
            top: UX.verticalInset,
            left: UX.horizontalInset,
            bottom: UX.verticalInset,
            right: UX.horizontalInset
        )
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.dataSource = self
        view.delegate = self
        view.showsVerticalScrollIndicator = true
        view.register(ToolboxItemCell.self, forCellWithReuseIdentifier: ToolboxItemCell.reuseIdentifier)
        view.register(ToolboxSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ToolboxSectionHeader.reuseIdentifier)
        return view
    }()

    init(mode: ToolboxMode) {
        self.mode = mode
        sections = Self.sections(for: mode)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(collectionView)
        if mode == .bottom || mode == .bottomToolbox {
            let dismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
            dismissPan.delegate = self
            dismissPan.cancelsTouchesInView = false
            collectionView.addGestureRecognizer(dismissPan)
        }
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        // A deliberate downward pull from the top of the upward panel closes it.
        guard translation.y >= 72,
              velocity.y > 320,
              collectionView.contentOffset.y <= 1 else {
            return
        }
        onDismissRequest?()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return otherGestureRecognizer === collectionView.panGestureRecognizer
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ToolboxItemCell.reuseIdentifier, for: indexPath) as? ToolboxItemCell else {
            return UICollectionViewCell()
        }
        let item = sections[indexPath.section].items[indexPath.item]
        cell.configure(title: item.title, iconName: item.icon)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onAction?(sections[indexPath.section].items[indexPath.item].action)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = collectionView.bounds.width - (UX.horizontalInset * 2) - (UX.itemSpacing * 3)
        return CGSize(width: floor(availableWidth / 4), height: UX.itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return sections[section].title == nil ? .zero : CGSize(width: collectionView.bounds.width, height: UX.titleHeight)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ToolboxSectionHeader.reuseIdentifier,
                for: indexPath
              ) as? ToolboxSectionHeader else {
            return UICollectionReusableView()
        }
        header.configure(title: sections[indexPath.section].title)
        return header
    }

    private static func sections(for mode: ToolboxMode) -> [ToolboxSection] {
        switch mode {
        case .top:
            return topSections
        case .bottom:
            return bottomSections
        case .bottomToolbox:
            return topSections
        case .developer:
            return developerSections
        }
    }

    private static let topSections: [ToolboxSection] = [
        ToolboxSection(title: "常用功能", items: [
            ToolboxItem(title: "添加到\n收藏", icon: "star.badge.plus", action: .bookmark),
            ToolboxItem(title: "添加到\n首页", icon: "house.badge.plus", action: .favorite),
            ToolboxItem(title: "分享", icon: "square.and.arrow.up", action: .share),
            ToolboxItem(title: "复制 URL", icon: "link", action: .copyURL),
            ToolboxItem(title: "Safari", icon: "safari", action: .openInSafari),
        ]),
        ToolboxSection(title: "网页资源", items: [
            ToolboxItem(title: "看图模式", icon: "photo", action: .imageMode),
            ToolboxItem(title: "MP4", icon: "film", action: .mp4),
            ToolboxItem(title: "视频采集", icon: "play.rectangle", action: .videoCapture),
            ToolboxItem(title: "缩放", icon: "arrow.up.left.and.arrow.down.right", action: .zoom),
            ToolboxItem(title: "超级嗅探", icon: "dot.radiowaves.left.and.right", action: .sniff),
            ToolboxItem(title: "检测\n二维码", icon: "qrcode.viewfinder", action: .detectQRCode),
            ToolboxItem(title: "无图模式", icon: "photo.slash", action: .noImages),
        ]),
        ToolboxSection(title: "网页另存为", items: [
            ToolboxItem(title: "保存离线\n网页", icon: "doc.text", action: .saveOffline),
            ToolboxItem(title: "截长图", icon: "camera.viewfinder", action: .longScreenshot),
            ToolboxItem(title: "生成\n二维码", icon: "qrcode", action: .generateQRCode),
            ToolboxItem(title: "生成 PDF", icon: "doc.richtext", action: .generatePDF),
        ]),
        ToolboxSection(title: "广告拦截", items: [
            ToolboxItem(title: "加入\n黑名单", icon: "nosign", action: .addToBlocklist),
            ToolboxItem(title: "标记模式", icon: "a.circle", action: .markMode),
            ToolboxItem(title: "AD", icon: "shield.lefthalf.filled", action: .adBlock),
        ]),
        ToolboxSection(title: "通用工具", items: [
            ToolboxItem(title: "网页翻译", icon: "character.book.closed", action: .translate),
            ToolboxItem(title: "兼容模式", icon: "rectangle.on.rectangle", action: .compatibility),
            ToolboxItem(title: "页内查找", icon: "text.magnifyingglass", action: .findInPage),
            ToolboxItem(title: "站内搜索词", icon: "magnifyingglass", action: .siteSearch),
            ToolboxItem(title: "阅读模式", icon: "doc.plaintext", action: .readerMode),
            ToolboxItem(title: "Bigbang", icon: "text.badge.plus", action: .bigbang),
            ToolboxItem(title: "请求桌面\n网站", icon: "desktopcomputer", action: .desktopSite),
        ]),
        ToolboxSection(title: "开发者工具", items: [
            ToolboxItem(title: "自定义 UA", icon: "slider.horizontal.3", action: .customUA),
            ToolboxItem(title: "网页源码", icon: "chevron.left.forwardslash.chevron.right", action: .pageSource),
            ToolboxItem(title: "UA&Cookie", icon: "person.crop.circle", action: .uaAndCookie),
            ToolboxItem(title: "eruda", icon: "ladybug", action: .eruda),
            ToolboxItem(title: "vConsole", icon: "terminal", action: .vConsole),
            ToolboxItem(title: "脚本状态", icon: "chevron.left.slash.chevron.right", action: .scriptStatus),
            ToolboxItem(title: "清理网页\n缓存", icon: "broom", action: .clearPageCache),
        ]),
    ]

    private static let bottomSections: [ToolboxSection] = [
        ToolboxSection(title: nil, items: [
            ToolboxItem(title: "收藏", icon: "star.fill", action: .bookmarks),
            ToolboxItem(title: "历史", icon: "clock.arrow.circlepath", action: .history),
            ToolboxItem(title: "收藏网址", icon: "star.badge.plus", action: .bookmark),
            ToolboxItem(title: "下载管理", icon: "folder", action: .downloads),
            ToolboxItem(title: "设置", icon: "gearshape", action: .settings),
            ToolboxItem(title: "工具箱", icon: "briefcase", action: .toolbox),
            ToolboxItem(title: "复制 URL", icon: "link", action: .copyURL),
            ToolboxItem(title: "多窗口", icon: "square.on.square", action: .tabOverview),
            ToolboxItem(title: "刷新", icon: "arrow.clockwise", action: .reload),
        ]),
    ]

    private static let developerSections: [ToolboxSection] = [
        ToolboxSection(title: "开发者工具", items: [
            ToolboxItem(title: "自定义 UA", icon: "slider.horizontal.3", action: .customUA),
            ToolboxItem(title: "网页源码", icon: "chevron.left.forwardslash.chevron.right", action: .pageSource),
            ToolboxItem(title: "UA&Cookie", icon: "person.crop.circle", action: .uaAndCookie),
            ToolboxItem(title: "eruda", icon: "ladybug", action: .eruda),
            ToolboxItem(title: "vConsole", icon: "terminal", action: .vConsole),
            ToolboxItem(title: "脚本状态", icon: "chevron.left.slash.chevron.right", action: .scriptStatus),
            ToolboxItem(title: "清理网页\n缓存", icon: "broom", action: .clearPageCache),
        ]),
    ]
}

private final class ToolboxItemCell: UICollectionViewCell {
    static let reuseIdentifier = "ToolboxItemCell"

    private let iconView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = .label
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .label
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.45)
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 3),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.alpha = isHighlighted ? 0.55 : 1
        }
    }

    func configure(title: String, iconName: String) {
        titleLabel.text = title
        iconView.image = UIImage(systemName: iconName)
        accessibilityLabel = title.replacingOccurrences(of: "\n", with: " ")
    }
}

private final class ToolboxSectionHeader: UICollectionReusableView {
    static let reuseIdentifier = "ToolboxSectionHeader"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String?) {
        titleLabel.text = title
    }
}
