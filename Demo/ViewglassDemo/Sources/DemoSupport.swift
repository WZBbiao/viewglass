import UIKit

enum DemoID {
    static let tabHome = "tab_home"
    static let tabForms = "tab_forms"
    static let tabFeed = "tab_feed"
    static let switchTabHome = "switch_tab_home"
    static let switchTabForms = "switch_tab_forms"
    static let switchTabFeed = "switch_tab_feed"
    static let homeButtonsStack = "home_buttons_stack"
    static let pushButtons = "push_buttons_screen"
    static let pushForms = "push_forms_screen"
    static let pushFeed = "push_feed_screen"
    static let pushGestures = "push_gestures_screen"
    static let pushSelectableSurfaces = "push_selectable_surfaces_screen"
    static let showHomeSheet = "show_home_sheet"
    static let openAlert = "open_alert"
    static let openActionSheet = "open_action_sheet"
    static let openPageSheet = "open_page_sheet"
    static let openFullScreen = "open_full_screen"
    static let dismissModal = "dismiss_modal"
    static let primaryTextField = "primary_text_field"
    static let secureTextField = "secure_text_field"
    static let notesTextView = "notes_text_view"
    static let formsStatus = "forms_status"
    static let notificationsSwitch = "notifications_switch"
    static let prioritySegment = "priority_segment"
    static let volumeSlider = "volume_slider"
    static let quantityStepper = "quantity_stepper"
    static let datePicker = "date_picker"
    static let longFeedScroll = "long_feed_scroll"
    static let feedCardPrefix = "feed_card_"
    static let tappableLabel = "tappable_label"
    static let longPressCard = "long_press_card"
    static let gestureStatus = "gesture_status"
    static let selectionStatus = "selection_status"
    static let tableSelectionTimeline = "table_selection_timeline"
    static let collectionSelectionTimeline = "collection_selection_timeline"
    static let selectableTable = "selectable_table"
    static let selectableCollection = "selectable_collection"
    static let tableRowLabelPrefix = "table_row_label_"
    static let collectionTileLabelPrefix = "collection_tile_label_"
}

enum DemoTheme {
    static let background = UIColor(red: 0.95, green: 0.96, blue: 0.99, alpha: 1)
    static let surface = UIColor.white
    static let ink = UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1)
    static let accent = UIColor(red: 0.10, green: 0.45, blue: 0.95, alpha: 1)
    static let accentSoft = UIColor(red: 0.88, green: 0.93, blue: 1.0, alpha: 1)
    static let warning = UIColor(red: 0.98, green: 0.54, blue: 0.20, alpha: 1)
}

func makeDemoButton(title: String, filled: Bool = true) -> UIButton {
    let button = UIButton(type: .system)
    if #available(iOS 15.0, *) {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        config.title = title
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        config.baseForegroundColor = filled ? .white : DemoTheme.accent
        config.baseBackgroundColor = filled ? DemoTheme.accent : DemoTheme.accentSoft
        button.configuration = config
    } else {
        button.setTitle(title, for: .normal)
        button.setTitleColor(filled ? .white : DemoTheme.accent, for: .normal)
        button.backgroundColor = filled ? DemoTheme.accent : DemoTheme.accentSoft
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        button.layer.cornerRadius = 16
    }
    button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
    return button
}

func makeSectionCard(title: String, subtitle: String? = nil) -> UIStackView {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 8
    stack.isLayoutMarginsRelativeArrangement = true
    stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    stack.backgroundColor = DemoTheme.surface
    stack.layer.cornerRadius = 24
    stack.layer.cornerCurve = .continuous

    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
    titleLabel.textColor = DemoTheme.ink
    stack.addArrangedSubview(titleLabel)

    if let subtitle {
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.numberOfLines = 0
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(subtitleLabel)
    }

    return stack
}

func pinToEdges(_ child: UIView, in parent: UIView, inset: CGFloat = 0) {
    child.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
        child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
        parent.trailingAnchor.constraint(equalTo: child.trailingAnchor, constant: inset),
        parent.bottomAnchor.constraint(equalTo: child.bottomAnchor, constant: inset)
    ])
}

extension UIView {
    func embedInRoundedSurface() -> UIView {
        let container = UIView()
        container.backgroundColor = DemoTheme.surface
        container.layer.cornerRadius = 24
        container.layer.cornerCurve = .continuous
        container.addSubview(self)
        pinToEdges(self, in: container, inset: 20)
        return container
    }
}
