import UIKit

final class GesturesViewController: UIViewController {
    private let statusLabel = UILabel()
    private var accumulatedPanTranslation = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gesture Lab"
        view.backgroundColor = DemoTheme.background

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = DemoID.gestureScroll

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

        let coordinateWrapper = UIView()
        coordinateWrapper.backgroundColor = UIColor(red: 0.91, green: 0.96, blue: 0.89, alpha: 1)
        coordinateWrapper.layer.cornerRadius = 20
        coordinateWrapper.layer.cornerCurve = .continuous
        coordinateWrapper.heightAnchor.constraint(equalToConstant: 120).isActive = true
        coordinateWrapper.accessibilityIdentifier = DemoID.coordinateFallbackWrapper

        let coordinateButton = makeDemoButton(title: "Coordinate fallback target", filled: false)
        coordinateButton.translatesAutoresizingMaskIntoConstraints = false
        coordinateButton.addTarget(self, action: #selector(handleCoordinateFallback), for: .touchUpInside)
        coordinateWrapper.addSubview(coordinateButton)
        NSLayoutConstraint.activate([
            coordinateButton.centerXAnchor.constraint(equalTo: coordinateWrapper.centerXAnchor),
            coordinateButton.centerYAnchor.constraint(equalTo: coordinateWrapper.centerYAnchor),
            coordinateButton.leadingAnchor.constraint(greaterThanOrEqualTo: coordinateWrapper.leadingAnchor, constant: 20),
            coordinateButton.trailingAnchor.constraint(lessThanOrEqualTo: coordinateWrapper.trailingAnchor, constant: -20)
        ])
        card.addArrangedSubview(coordinateWrapper)

        let panCard = UIView()
        panCard.backgroundColor = UIColor(red: 0.93, green: 0.91, blue: 0.99, alpha: 1)
        panCard.layer.cornerRadius = 20
        panCard.layer.cornerCurve = .continuous
        panCard.heightAnchor.constraint(equalToConstant: 120).isActive = true
        panCard.accessibilityIdentifier = DemoID.panCard
        panCard.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))

        let panLabel = UILabel()
        panLabel.text = "Swipe this pan card"
        panLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        panLabel.textAlignment = .center
        panLabel.translatesAutoresizingMaskIntoConstraints = false
        panCard.addSubview(panLabel)
        NSLayoutConstraint.activate([
            panLabel.centerXAnchor.constraint(equalTo: panCard.centerXAnchor),
            panLabel.centerYAnchor.constraint(equalTo: panCard.centerYAnchor)
        ])
        card.addArrangedSubview(panCard)

        let selfRemovingTapCard = makeGestureCard(
            text: "Tap to remove this card",
            color: UIColor(red: 1.0, green: 0.92, blue: 0.90, alpha: 1),
            accessibilityIdentifier: DemoID.selfRemovingTapCard
        )
        selfRemovingTapCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleSelfRemovingTap(_:))))
        card.addArrangedSubview(selfRemovingTapCard)

        let selfRemovingPanCard = makeGestureCard(
            text: "Swipe to remove this card",
            color: UIColor(red: 0.89, green: 0.96, blue: 1.0, alpha: 1),
            accessibilityIdentifier: DemoID.selfRemovingPanCard
        )
        selfRemovingPanCard.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleSelfRemovingPan(_:))))
        card.addArrangedSubview(selfRemovingPanCard)

        statusLabel.text = "No gesture triggered yet"
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = DemoID.gestureStatus
        card.addArrangedSubview(statusLabel)

        stack.addArrangedSubview(card)
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    @objc private func handleTap() {
        statusLabel.text = "Tap gesture fired"
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        statusLabel.text = "Long press fired"
    }

    @objc private func handleCoordinateFallback() {
        statusLabel.text = "Coordinate fallback fired"
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began {
            accumulatedPanTranslation = .zero
            return
        }
        guard recognizer.state == .changed || recognizer.state == .ended else { return }
        let delta = recognizer.translation(in: recognizer.view)
        accumulatedPanTranslation.x += delta.x
        accumulatedPanTranslation.y += delta.y
        recognizer.setTranslation(.zero, in: recognizer.view)
        guard recognizer.state == .ended else { return }
        let direction: String
        if abs(accumulatedPanTranslation.x) > abs(accumulatedPanTranslation.y) {
            direction = accumulatedPanTranslation.x >= 0 ? "right" : "left"
        } else {
            direction = accumulatedPanTranslation.y >= 0 ? "down" : "up"
        }
        let distance = Int(round(max(abs(accumulatedPanTranslation.x), abs(accumulatedPanTranslation.y))))
        statusLabel.text = "Pan \(direction) \(distance) fired"
    }

    @objc private func handleSelfRemovingTap(_ recognizer: UITapGestureRecognizer) {
        statusLabel.text = "Self-removing tap fired"
        recognizer.view?.removeFromSuperview()
    }

    @objc private func handleSelfRemovingPan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        statusLabel.text = "Self-removing pan fired"
        recognizer.view?.removeFromSuperview()
    }

    private func makeGestureCard(text: String, color: UIColor, accessibilityIdentifier: String) -> UIView {
        let card = UIView()
        card.backgroundColor = color
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.heightAnchor.constraint(equalToConstant: 96).isActive = true
        card.accessibilityIdentifier = accessibilityIdentifier

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }
}
