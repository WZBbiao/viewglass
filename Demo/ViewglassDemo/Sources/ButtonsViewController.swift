import UIKit

final class ButtonsViewController: UIViewController {
    private static var emptyOverlayWindow: UIWindow?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Buttons & Alerts"
        view.backgroundColor = DemoTheme.background

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)

        let hero = makeSectionCard(
            title: "Modal States",
            subtitle: "Use this screen to validate alerts, action sheets, page sheets and full-screen presentation flows."
        )

        let alertButton = makeDemoButton(title: "Open Alert")
        alertButton.accessibilityIdentifier = DemoID.openAlert
        alertButton.addTarget(self, action: #selector(showAlert), for: .touchUpInside)

        let actionSheetButton = makeDemoButton(title: "Open Action Sheet", filled: false)
        actionSheetButton.accessibilityIdentifier = DemoID.openActionSheet
        actionSheetButton.addTarget(self, action: #selector(showActionSheet), for: .touchUpInside)

        let pageSheetButton = makeDemoButton(title: "Open Page Sheet")
        pageSheetButton.accessibilityIdentifier = DemoID.openPageSheet
        pageSheetButton.addTarget(self, action: #selector(showPageSheet), for: .touchUpInside)

        let fullScreenButton = makeDemoButton(title: "Open Full Screen", filled: false)
        fullScreenButton.accessibilityIdentifier = DemoID.openFullScreen
        fullScreenButton.addTarget(self, action: #selector(showFullScreen), for: .touchUpInside)

        let emptyOverlayButton = makeDemoButton(title: "Show Empty Overlay Window", filled: false)
        emptyOverlayButton.accessibilityIdentifier = DemoID.showEmptyOverlayWindow
        emptyOverlayButton.addTarget(self, action: #selector(showEmptyOverlayWindow), for: .touchUpInside)

        [alertButton, actionSheetButton, pageSheetButton, fullScreenButton, emptyOverlayButton].forEach(hero.addArrangedSubview(_:))

        let info = makeSectionCard(
            title: "Visual Regression Hint",
            subtitle: "The hero card, stacked buttons and mixed filled/tinted styles intentionally create spacing, radius and typography details for screenshot comparison."
        )

        stack.addArrangedSubview(hero)
        stack.addArrangedSubview(info)

        let scroll = UIScrollView()
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

    @objc private func showAlert() {
        let alert = UIAlertController(title: "Ship checklist", message: "Primary CTA, body copy and spacing should match the design spec.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        alert.addAction(UIAlertAction(title: "Ship", style: .default))
        present(alert, animated: true)
    }

    @objc private func showActionSheet(_ sender: UIButton) {
        let sheet = UIAlertController(title: "Quick actions", message: "An action sheet gives you system container coverage.", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Archive", style: .default))
        sheet.addAction(UIAlertAction(title: "Delete", style: .destructive))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func showPageSheet() {
        let modal = ModalCardViewController(titleText: "Page Sheet", bodyText: "Use semantic dismiss and screenshot capture here.")
        modal.modalPresentationStyle = .pageSheet
        present(modal, animated: true)
    }

    @objc private func showFullScreen() {
        let modal = ModalCardViewController(titleText: "Full Screen", bodyText: "This presentation covers a second controller stack.")
        modal.modalPresentationStyle = .fullScreen
        present(modal, animated: true)
    }

    @objc private func showEmptyOverlayWindow() {
        let frame = view.window?.windowScene?.coordinateSpace.bounds ?? UIScreen.main.bounds
        let overlay = UIWindow(frame: frame)
        overlay.windowScene = view.window?.windowScene
        overlay.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue + 1)
        overlay.backgroundColor = .black
        overlay.isUserInteractionEnabled = false
        overlay.isHidden = false
        Self.emptyOverlayWindow = overlay

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak overlay] in
            overlay?.isHidden = true
            if Self.emptyOverlayWindow === overlay {
                Self.emptyOverlayWindow = nil
            }
        }
    }
}
