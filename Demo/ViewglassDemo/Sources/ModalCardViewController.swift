import UIKit

final class ModalCardViewController: UIViewController {
    private let titleText: String
    private let bodyText: String

    init(titleText: String, bodyText: String) {
        self.titleText = titleText
        self.bodyText = bodyText
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DemoTheme.background

        let card = makeSectionCard(title: titleText, subtitle: bodyText)
        let dismiss = makeDemoButton(title: "Dismiss")
        dismiss.accessibilityIdentifier = DemoID.dismissModal
        dismiss.addTarget(self, action: #selector(close), for: .touchUpInside)
        card.addArrangedSubview(dismiss)

        view.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            view.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: 20)
        ])
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
