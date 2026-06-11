import UIKit

final class ComplexScenariosViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate {
    private let nestedStatusLabel = UILabel()
    private let waterfallStatusLabel = UILabel()
    private let pageFeedStatusLabel = UILabel()
    private var waterfallItems = Array(1...18)
    private var didLoadWaterfallPageTwo = false
    private lazy var waterfallCollection = UICollectionView(frame: .zero, collectionViewLayout: WaterfallLayout())
    private let pageFeedScroll = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Complex Scenarios"
        view.backgroundColor = DemoTheme.background

        let outerScroll = UIScrollView()
        outerScroll.accessibilityIdentifier = DemoID.complexOuterScroll

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 40, right: 20)

        stack.addArrangedSubview(makeSectionCard(
            title: "Agent Stress Cases",
            subtitle: "Nested scroll views, lazy collection loading and full-page vertical paging exercise the cases where agents often pick the wrong target or keep retrying."
        ))
        stack.addArrangedSubview(makeNestedScrollSection())
        stack.addArrangedSubview(makeWaterfallSection())
        stack.addArrangedSubview(makePageFeedSection())

        outerScroll.addSubview(stack)
        view.addSubview(outerScroll)

        outerScroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            outerScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            outerScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outerScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            outerScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: outerScroll.frameLayoutGuide.widthAnchor)
        ])
    }

    private func makeNestedScrollSection() -> UIStackView {
        let card = makeSectionCard(
            title: "Nested Scroll Views",
            subtitle: "Horizontal chips sit above an inner vertical picker, both embedded inside the page scroll view."
        )

        nestedStatusLabel.text = "Nested target: none"
        nestedStatusLabel.accessibilityIdentifier = DemoID.nestedStatus
        nestedStatusLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nestedStatusLabel.textColor = DemoTheme.ink
        card.addArrangedSubview(nestedStatusLabel)

        let horizontal = UIScrollView()
        horizontal.accessibilityIdentifier = DemoID.nestedHorizontalScroll
        horizontal.showsHorizontalScrollIndicator = true
        horizontal.alwaysBounceHorizontal = true
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 10
        for index in 1...12 {
            let label = paddedLabel("Chip \(index)", color: index % 2 == 0 ? DemoTheme.accentSoft : UIColor.systemGray6)
            horizontalStack.addArrangedSubview(label)
        }
        horizontal.addSubview(horizontalStack)
        horizontal.heightAnchor.constraint(equalToConstant: 52).isActive = true
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            horizontalStack.topAnchor.constraint(equalTo: horizontal.contentLayoutGuide.topAnchor),
            horizontalStack.leadingAnchor.constraint(equalTo: horizontal.contentLayoutGuide.leadingAnchor),
            horizontalStack.trailingAnchor.constraint(equalTo: horizontal.contentLayoutGuide.trailingAnchor),
            horizontalStack.bottomAnchor.constraint(equalTo: horizontal.contentLayoutGuide.bottomAnchor),
            horizontalStack.heightAnchor.constraint(equalTo: horizontal.frameLayoutGuide.heightAnchor)
        ])
        card.addArrangedSubview(horizontal)

        let inner = UIScrollView()
        inner.accessibilityIdentifier = DemoID.nestedInnerScroll
        inner.backgroundColor = UIColor.systemGray6
        inner.layer.cornerRadius = 18
        inner.layer.cornerCurve = .continuous
        inner.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let innerStack = UIStackView()
        innerStack.axis = .vertical
        innerStack.spacing = 10
        innerStack.isLayoutMarginsRelativeArrangement = true
        innerStack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        for index in 1...14 {
            let button = makeDemoButton(title: "Nested inner option \(index)", filled: index == 10)
            button.accessibilityIdentifier = "\(DemoID.nestedInnerButtonPrefix)\(index)"
            button.tag = index
            button.addTarget(self, action: #selector(selectNestedOption(_:)), for: .touchUpInside)
            innerStack.addArrangedSubview(button)
        }
        inner.addSubview(innerStack)
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: inner.contentLayoutGuide.topAnchor),
            innerStack.leadingAnchor.constraint(equalTo: inner.contentLayoutGuide.leadingAnchor),
            innerStack.trailingAnchor.constraint(equalTo: inner.contentLayoutGuide.trailingAnchor),
            innerStack.bottomAnchor.constraint(equalTo: inner.contentLayoutGuide.bottomAnchor),
            innerStack.widthAnchor.constraint(equalTo: inner.frameLayoutGuide.widthAnchor)
        ])
        card.addArrangedSubview(inner)

        return card
    }

    private func makeWaterfallSection() -> UIStackView {
        let card = makeSectionCard(
            title: "Waterfall Loading",
            subtitle: "A two-column variable-height collection view appends the next page when scrolled near the bottom."
        )

        waterfallStatusLabel.text = "Waterfall page: 1, items: 18"
        waterfallStatusLabel.accessibilityIdentifier = DemoID.waterfallStatus
        waterfallStatusLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        waterfallStatusLabel.textColor = DemoTheme.ink
        card.addArrangedSubview(waterfallStatusLabel)

        waterfallCollection.accessibilityIdentifier = DemoID.waterfallCollection
        waterfallCollection.backgroundColor = UIColor.systemGray6
        waterfallCollection.layer.cornerRadius = 18
        waterfallCollection.layer.cornerCurve = .continuous
        waterfallCollection.dataSource = self
        waterfallCollection.delegate = self
        waterfallCollection.register(WaterfallCell.self, forCellWithReuseIdentifier: WaterfallCell.reuseIdentifier)
        waterfallCollection.heightAnchor.constraint(equalToConstant: 520).isActive = true
        card.addArrangedSubview(waterfallCollection)

        return card
    }

    private func makePageFeedSection() -> UIStackView {
        let card = makeSectionCard(
            title: "Vertical Page Feed",
            subtitle: "A paging scroll view similar to short-video feeds. Agents need one decisive swipe instead of repeated tiny scroll attempts."
        )

        pageFeedStatusLabel.text = "Page feed: card 1"
        pageFeedStatusLabel.accessibilityIdentifier = DemoID.pageFeedStatus
        pageFeedStatusLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        pageFeedStatusLabel.textColor = DemoTheme.ink
        card.addArrangedSubview(pageFeedStatusLabel)

        pageFeedScroll.accessibilityIdentifier = DemoID.pageFeedScroll
        pageFeedScroll.isPagingEnabled = true
        pageFeedScroll.delegate = self
        pageFeedScroll.showsVerticalScrollIndicator = false
        pageFeedScroll.backgroundColor = UIColor.black
        pageFeedScroll.layer.cornerRadius = 22
        pageFeedScroll.layer.cornerCurve = .continuous
        pageFeedScroll.clipsToBounds = true
        pageFeedScroll.heightAnchor.constraint(equalToConstant: 560).isActive = true

        var previousCard: UIView?
        for index in 1...5 {
            let cardView = makePageCard(index: index)
            pageFeedScroll.addSubview(cardView)
            cardView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cardView.leadingAnchor.constraint(equalTo: pageFeedScroll.contentLayoutGuide.leadingAnchor),
                cardView.trailingAnchor.constraint(equalTo: pageFeedScroll.contentLayoutGuide.trailingAnchor),
                cardView.widthAnchor.constraint(equalTo: pageFeedScroll.frameLayoutGuide.widthAnchor),
                cardView.heightAnchor.constraint(equalTo: pageFeedScroll.frameLayoutGuide.heightAnchor)
            ])
            if let previousCard {
                cardView.topAnchor.constraint(equalTo: previousCard.bottomAnchor).isActive = true
            } else {
                cardView.topAnchor.constraint(equalTo: pageFeedScroll.contentLayoutGuide.topAnchor).isActive = true
            }
            previousCard = cardView
        }
        previousCard?.bottomAnchor.constraint(equalTo: pageFeedScroll.contentLayoutGuide.bottomAnchor).isActive = true
        card.addArrangedSubview(pageFeedScroll)

        return card
    }

    @objc private func selectNestedOption(_ sender: UIButton) {
        nestedStatusLabel.text = "Nested target: option \(sender.tag)"
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        waterfallItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WaterfallCell.reuseIdentifier, for: indexPath) as! WaterfallCell
        let item = waterfallItems[indexPath.item]
        cell.configure(index: item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        waterfallStatusLabel.text = "Waterfall tapped: item \(waterfallItems[indexPath.item])"
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === waterfallCollection {
            maybeLoadMoreWaterfallItems()
        } else if scrollView === pageFeedScroll {
            updatePageFeedStatus()
        }
    }

    private func maybeLoadMoreWaterfallItems() {
        guard !didLoadWaterfallPageTwo else { return }
        let threshold = max(0, waterfallCollection.contentSize.height - waterfallCollection.bounds.height - 40)
        guard waterfallCollection.contentOffset.y >= threshold else { return }
        didLoadWaterfallPageTwo = true
        waterfallItems.append(contentsOf: 19...30)
        waterfallStatusLabel.text = "Waterfall page: 2, items: 30"
        waterfallCollection.reloadData()
    }

    private func updatePageFeedStatus() {
        guard pageFeedScroll.bounds.height > 0 else { return }
        let page = min(5, max(1, Int(round(pageFeedScroll.contentOffset.y / pageFeedScroll.bounds.height)) + 1))
        pageFeedStatusLabel.text = "Page feed: card \(page)"
    }

    private func makePageCard(index: Int) -> UIView {
        let container = UIView()
        container.accessibilityIdentifier = "\(DemoID.pageFeedCardPrefix)\(index)"
        container.backgroundColor = [
            UIColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1),
            UIColor(red: 0.13, green: 0.08, blue: 0.18, alpha: 1),
            UIColor(red: 0.06, green: 0.15, blue: 0.12, alpha: 1),
            UIColor(red: 0.18, green: 0.09, blue: 0.06, alpha: 1),
            UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        ][index - 1]

        let title = UILabel()
        title.text = "Page Card \(index)"
        title.font = UIFont.systemFont(ofSize: 34, weight: .heavy)
        title.textColor = .white

        let subtitle = UILabel()
        subtitle.text = "Swipe up to continue. This page intentionally fills one viewport."
        subtitle.numberOfLines = 0
        subtitle.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.78)

        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = 12
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -38)
        ])
        return container
    }

    private func paddedLabel(_ text: String, color: UIColor) -> UILabel {
        let label = PaddedLabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        label.textColor = DemoTheme.ink
        label.backgroundColor = color
        label.layer.cornerRadius = 16
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        return label
    }
}

private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
}

private final class WaterfallCell: UICollectionViewCell {
    static let reuseIdentifier = "WaterfallCell"

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = DemoTheme.surface
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous

        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = DemoTheme.ink

        bodyLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(index: Int) {
        accessibilityIdentifier = "\(DemoID.waterfallItemPrefix)\(index)"
        accessibilityLabel = "Waterfall item \(index)"
        titleLabel.text = "Item \(index)"
        bodyLabel.text = String(repeating: "Variable height content. ", count: (index % 4) + 1)
    }
}

private final class WaterfallLayout: UICollectionViewLayout {
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0
    private let columns = 2
    private let spacing: CGFloat = 12
    private let insets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }

    override func prepare() {
        guard let collectionView else { return }
        cache.removeAll()
        contentHeight = 0

        let availableWidth = collectionView.bounds.width - insets.left - insets.right - spacing * CGFloat(columns - 1)
        let itemWidth = floor(availableWidth / CGFloat(columns))
        var columnHeights = Array(repeating: insets.top, count: columns)

        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let x = insets.left + CGFloat(column) * (itemWidth + spacing)
            let y = columnHeights[column]
            let height = WaterfallLayout.height(for: item + 1)

            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: 0))
            attributes.frame = CGRect(x: x, y: y, width: itemWidth, height: height)
            cache.append(attributes)

            columnHeights[column] = y + height + spacing
        }

        contentHeight = (columnHeights.max() ?? 0) + insets.bottom
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cache.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != collectionView?.bounds.width
    }

    private static func height(for item: Int) -> CGFloat {
        [128, 172, 148, 210, 160, 196][(item - 1) % 6]
    }
}
