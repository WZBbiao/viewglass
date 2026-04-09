import UIKit

final class FormsViewController: UIViewController, UITextViewDelegate {
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

        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "Email address"
        textField.accessibilityIdentifier = DemoID.primaryTextField

        let secureField = UITextField()
        secureField.borderStyle = .roundedRect
        secureField.isSecureTextEntry = true
        secureField.placeholder = "Password"
        secureField.accessibilityIdentifier = DemoID.secureTextField

        let notes = UITextView()
        notes.font = UIFont.systemFont(ofSize: 16)
        notes.text = "Multiline notes"
        notes.backgroundColor = DemoTheme.accentSoft
        notes.layer.cornerRadius = 16
        notes.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        notes.heightAnchor.constraint(equalToConstant: 120).isActive = true
        notes.accessibilityIdentifier = DemoID.notesTextView
        notes.delegate = self

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

        statusLabel.text = "2 guests, notifications on"
        statusLabel.numberOfLines = 0
        statusLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = DemoTheme.ink

        let rows: [(String, UIView)] = [
            ("Email", textField),
            ("Password", secureField),
            ("Notes", notes),
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
        statusLabel.text = "Notes characters: \(textView.text.count)"
    }
}
