import UIKit

final class FeedViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Long Feed"
        view.backgroundColor = DemoTheme.background

        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = DemoID.longFeedScroll

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 40, right: 20)

        let hero = makeSectionCard(
            title: "Infinite-ish Feed",
            subtitle: "A long mixed-height feed for semantic scroll and screenshot stitching checks."
        )
        stack.addArrangedSubview(hero)

        for index in 1...24 {
            let card = makeSectionCard(
                title: "Feed card \(index)",
                subtitle: "Card \(index) uses varying subtitle lengths to create natural layout drift across a long scrollable page."
            )
            card.accessibilityIdentifier = "\(DemoID.feedCardPrefix)\(index)"
            if index % 3 == 0 {
                let badge = UILabel()
                badge.text = "Pinned item"
                badge.textAlignment = .center
                badge.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                badge.textColor = .white
                badge.backgroundColor = DemoTheme.warning
                badge.layer.cornerRadius = 12
                badge.layer.masksToBounds = true
                badge.heightAnchor.constraint(equalToConstant: 28).isActive = true
                card.addArrangedSubview(badge)
            }
            stack.addArrangedSubview(card)
        }

        scroll.addSubview(stack)
        view.addSubview(scroll)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }
}
