import UIKit

final class GesturesViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gesture Lab"
        view.backgroundColor = DemoTheme.background

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)

        let card = makeSectionCard(
            title: "Semantic Gestures",
            subtitle: "Use these surfaces to verify UILabel tap and long-press gesture triggering without relying on physical input."
        )

        let label = UILabel()
        label.text = "Tap this status label"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = DemoTheme.accent
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.accessibilityIdentifier = DemoID.tappableLabel
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        card.addArrangedSubview(label)

        let longPressCard = UIView()
        longPressCard.backgroundColor = DemoTheme.accentSoft
        longPressCard.layer.cornerRadius = 20
        longPressCard.layer.cornerCurve = .continuous
        longPressCard.heightAnchor.constraint(equalToConstant: 140).isActive = true
        longPressCard.accessibilityIdentifier = DemoID.longPressCard
        longPressCard.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:))))

        let longPressLabel = UILabel()
        longPressLabel.text = "Long press this card"
        longPressLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        longPressLabel.textAlignment = .center
        longPressLabel.translatesAutoresizingMaskIntoConstraints = false
        longPressCard.addSubview(longPressLabel)
        NSLayoutConstraint.activate([
            longPressLabel.centerXAnchor.constraint(equalTo: longPressCard.centerXAnchor),
            longPressLabel.centerYAnchor.constraint(equalTo: longPressCard.centerYAnchor)
        ])
        card.addArrangedSubview(longPressCard)

        statusLabel.text = "No gesture triggered yet"
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = DemoID.gestureStatus
        card.addArrangedSubview(statusLabel)

        stack.addArrangedSubview(card)
        view.addSubview(stack)
        pinToEdges(stack, in: view.safeAreaLayoutGuide.owningView ?? view, inset: 0)
    }

    @objc private func handleTap() {
        statusLabel.text = "Tap gesture fired"
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        statusLabel.text = "Long press fired"
    }
}
