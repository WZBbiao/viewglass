import UIKit

final class FormsViewController: UIViewController, UITextViewDelegate {
    private let primaryTextField = UITextField()
    private let secureTextField = UITextField()
    private let notesTextView = UITextView()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Forms"
        view.backgroundColor = DemoTheme.background

        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 32, right: 20)

        let intro = makeSectionCard(
            title: "Form Inputs",
            subtitle: "Covers text entry, secure input, toggles, segmented controls, sliders, steppers and date pickers."
        )

        let tabSwitchRow = UIStackView()
        tabSwitchRow.axis = .horizontal
        tabSwitchRow.spacing = 12

        let switchHome = makeDemoButton(title: "Switch to Home Tab", filled: false)
        switchHome.accessibilityIdentifier = DemoID.switchTabHome
        switchHome.addTarget(self, action: #selector(switchToHomeTab), for: .touchUpInside)

        let switchFeed = makeDemoButton(title: "Switch to Feed Tab", filled: false)
        switchFeed.accessibilityIdentifier = DemoID.switchTabFeed
        switchFeed.addTarget(self, action: #selector(switchToFeedTab), for: .touchUpInside)

        [switchHome, switchFeed].forEach(tabSwitchRow.addArrangedSubview(_:))
        intro.addArrangedSubview(tabSwitchRow)

        primaryTextField.borderStyle = .roundedRect
        primaryTextField.placeholder = "Email address"
        primaryTextField.accessibilityIdentifier = DemoID.primaryTextField
        primaryTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        secureTextField.borderStyle = .roundedRect
        secureTextField.isSecureTextEntry = true
        secureTextField.placeholder = "Password"
        secureTextField.accessibilityIdentifier = DemoID.secureTextField
        secureTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        notesTextView.font = UIFont.systemFont(ofSize: 16)
        notesTextView.text = "Multiline notes"
        notesTextView.backgroundColor = DemoTheme.accentSoft
        notesTextView.layer.cornerRadius = 16
        notesTextView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        notesTextView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        notesTextView.accessibilityIdentifier = DemoID.notesTextView
        notesTextView.delegate = self

        let notifications = UISwitch()
        notifications.isOn = true
        notifications.accessibilityIdentifier = DemoID.notificationsSwitch

        let priority = UISegmentedControl(items: ["Low", "Medium", "High"])
        priority.selectedSegmentIndex = 1
        priority.accessibilityIdentifier = DemoID.prioritySegment

        let slider = UISlider()
        slider.value = 0.65
        slider.accessibilityIdentifier = DemoID.volumeSlider

        let stepper = UIStepper()
        stepper.value = 2
        stepper.accessibilityIdentifier = DemoID.quantityStepper

        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.accessibilityIdentifier = DemoID.datePicker

        statusLabel.text = "Email: -, Password: 0 chars, Notes: 15 chars"
        statusLabel.numberOfLines = 0
        statusLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = DemoTheme.ink
        statusLabel.accessibilityIdentifier = DemoID.formsStatus

        let rows: [(String, UIView)] = [
            ("Email", primaryTextField),
            ("Password", secureTextField),
            ("Notes", notesTextView),
            ("Notifications", notifications),
            ("Priority", priority),
            ("Volume", slider),
            ("Quantity", stepper),
            ("When", datePicker)
        ]

        for (title, view) in rows {
            let row = UIStackView()
            row.axis = .vertical
            row.spacing = 8

            let label = UILabel()
            label.text = title
            label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            row.addArrangedSubview(label)
            row.addArrangedSubview(view)
            intro.addArrangedSubview(row)
        }
        intro.addArrangedSubview(statusLabel)
        refreshStatus()

        stack.addArrangedSubview(intro)
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

    func textViewDidChange(_ textView: UITextView) {
        refreshStatus()
    }

    @objc private func textFieldDidChange() {
        refreshStatus()
    }

    @objc private func switchToHomeTab() {
        tabBarController?.selectedIndex = 0
    }

    @objc private func switchToFeedTab() {
        tabBarController?.selectedIndex = 2
    }

    private func refreshStatus() {
        let email = primaryTextField.text?.isEmpty == false ? primaryTextField.text! : "-"
        statusLabel.text = "Email: \(email), Password: \(secureTextField.text?.count ?? 0) chars, Notes: \(notesTextView.text.count) chars"
    }
}
