import UIKit

final class SelectableSurfacesViewController: UIViewController {
    private let statusLabel = UILabel()
    private let tableItems = ["Inbox", "Profile", "Settings"]
    private let collectionItems = ["Coral", "Indigo", "Sunset", "Mint"]

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.accessibilityIdentifier = DemoID.selectableTable
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        tableView.isScrollEnabled = false
        tableView.backgroundColor = .clear
        tableView.register(SelectableTableCell.self, forCellReuseIdentifier: SelectableTableCell.reuseIdentifier)
        return tableView
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 140, height: 100)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.accessibilityIdentifier = DemoID.selectableCollection
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SelectableCollectionCell.self, forCellWithReuseIdentifier: SelectableCollectionCell.reuseIdentifier)
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Selectable Surfaces"
        view.backgroundColor = DemoTheme.background

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)

        let hero = makeSectionCard(
            title: "Semantic Cell Selection",
            subtitle: "These surfaces validate semantic taps on UITableViewCell and UICollectionViewCell, including taps on labels inside each cell."
        )

        statusLabel.text = "No selection triggered yet"
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = DemoID.selectionStatus
        hero.addArrangedSubview(statusLabel)

        let tableCard = makeSectionCard(
            title: "Table Rows",
            subtitle: "Tap a row title to trigger UITableViewDelegate selection."
        )
        tableCard.addArrangedSubview(tableView)
        tableView.heightAnchor.constraint(equalToConstant: 220).isActive = true

        let collectionCard = makeSectionCard(
            title: "Collection Tiles",
            subtitle: "Tap a tile title to trigger UICollectionViewDelegate selection."
        )
        collectionCard.addArrangedSubview(collectionView)
        collectionView.heightAnchor.constraint(equalToConstant: 240).isActive = true

        stack.addArrangedSubview(hero)
        stack.addArrangedSubview(tableCard)
        stack.addArrangedSubview(collectionCard)

        let scrollView = UIScrollView()
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
}

extension SelectableSurfacesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SelectableTableCell.reuseIdentifier, for: indexPath) as? SelectableTableCell else {
            return UITableViewCell()
        }
        cell.configure(text: tableItems[indexPath.row], index: indexPath.row)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        statusLabel.text = "Table selected: \(tableItems[indexPath.row])"
    }
}

extension SelectableSurfacesViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SelectableCollectionCell.reuseIdentifier, for: indexPath) as? SelectableCollectionCell else {
            return UICollectionViewCell()
        }
        cell.configure(text: collectionItems[indexPath.item], index: indexPath.item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        statusLabel.text = "Collection selected: \(collectionItems[indexPath.item])"
    }
}

private final class SelectableTableCell: UITableViewCell {
    static let reuseIdentifier = "SelectableTableCell"

    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        accessoryType = .disclosureIndicator
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = DemoTheme.ink
        contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String, index: Int) {
        accessibilityIdentifier = "table_row_\(index)"
        titleLabel.text = text
        titleLabel.accessibilityIdentifier = "\(DemoID.tableRowLabelPrefix)\(index)"
    }
}

private final class SelectableCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "SelectableCollectionCell"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = DemoTheme.accentSoft
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous

        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = DemoTheme.accent
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            contentView.layer.borderWidth = isSelected ? 2 : 0
            contentView.layer.borderColor = isSelected ? DemoTheme.accent.cgColor : nil
        }
    }

    func configure(text: String, index: Int) {
        accessibilityIdentifier = "collection_tile_\(index)"
        titleLabel.text = text
        titleLabel.accessibilityIdentifier = "\(DemoID.collectionTileLabelPrefix)\(index)"
    }
}
