import UIKit

final class HomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Viewglass Demo"
        view.backgroundColor = DemoTheme.background
        navigationItem.largeTitleDisplayMode = .always

        let scrollView = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 40, right: 20)

        let intro = makeSectionCard(
            title: "Agent Playground",
            subtitle: "A self-owned demo app for Viewglass. It covers navigation, alerts, sheets, gestures, forms and long scrolling surfaces with real UIKit views."
        )

        let tabSwitchRow = UIStackView()
        tabSwitchRow.axis = .horizontal
        tabSwitchRow.spacing = 12

        let switchForms = makeDemoButton(title: "Switch to Forms Tab", filled: false)
        switchForms.accessibilityIdentifier = DemoID.switchTabForms
        switchForms.addTarget(self, action: #selector(switchToFormsTab), for: .touchUpInside)

        let switchFeed = makeDemoButton(title: "Switch to Feed Tab", filled: false)
        switchFeed.accessibilityIdentifier = DemoID.switchTabFeed
        switchFeed.addTarget(self, action: #selector(switchToFeedTab), for: .touchUpInside)

        [switchForms, switchFeed].forEach(tabSwitchRow.addArrangedSubview(_:))
        intro.addArrangedSubview(tabSwitchRow)

        let actions = UIStackView()
        actions.axis = .vertical
        actions.spacing = 12
        actions.accessibilityIdentifier = DemoID.homeButtonsStack

        let buttons = makeDemoButton(title: "Open Buttons & Alerts")
        buttons.accessibilityIdentifier = DemoID.pushButtons
        buttons.addTarget(self, action: #selector(showButtons), for: .touchUpInside)

        let forms = makeDemoButton(title: "Open Forms Surface", filled: false)
        forms.accessibilityIdentifier = DemoID.pushForms
        forms.addTarget(self, action: #selector(showForms), for: .touchUpInside)

        let feed = makeDemoButton(title: "Open Long Feed")
        feed.accessibilityIdentifier = DemoID.pushFeed
        feed.addTarget(self, action: #selector(showFeed), for: .touchUpInside)

        let gestures = makeDemoButton(title: "Open Gesture Lab", filled: false)
        gestures.accessibilityIdentifier = DemoID.pushGestures
        gestures.addTarget(self, action: #selector(showGestures), for: .touchUpInside)

        let selectableSurfaces = makeDemoButton(title: "Open Selectable Surfaces")
        selectableSurfaces.accessibilityIdentifier = DemoID.pushSelectableSurfaces
        selectableSurfaces.addTarget(self, action: #selector(showSelectableSurfaces), for: .touchUpInside)

        let media = makeDemoButton(title: "Open Media & WebKit", filled: false)
        media.accessibilityIdentifier = DemoID.pushMedia
        media.addTarget(self, action: #selector(showMedia), for: .touchUpInside)

        let sheet = makeDemoButton(title: "Show Home Sheet", filled: false)
        sheet.accessibilityIdentifier = DemoID.showHomeSheet
        sheet.addTarget(self, action: #selector(showHomeSheet), for: .touchUpInside)

        [buttons, forms, feed, gestures, selectableSurfaces, media, sheet].forEach(actions.addArrangedSubview(_:))
        intro.addArrangedSubview(actions)

        stack.addArrangedSubview(intro)
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
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

    @objc private func showButtons() {
        navigationController?.pushViewController(ButtonsViewController(), animated: true)
    }

    @objc private func showForms() {
        navigationController?.pushViewController(FormsViewController(), animated: true)
    }

    @objc private func showFeed() {
        navigationController?.pushViewController(FeedViewController(), animated: true)
    }

    @objc private func showGestures() {
        navigationController?.pushViewController(GesturesViewController(), animated: true)
    }

    @objc private func showSelectableSurfaces() {
        navigationController?.pushViewController(SelectableSurfacesViewController(), animated: true)
    }

    @objc private func showMedia() {
        navigationController?.pushViewController(MediaViewController(), animated: true)
    }

    @objc private func showHomeSheet() {
        let modal = ModalCardViewController(titleText: "Home Sheet", bodyText: "Presented from the root screen to verify modal traversal.")
        modal.modalPresentationStyle = .pageSheet
        present(modal, animated: true)
    }

    @objc private func switchToFormsTab() {
        tabBarController?.selectedIndex = 1
    }

    @objc private func switchToFeedTab() {
        tabBarController?.selectedIndex = 2
    }
}
