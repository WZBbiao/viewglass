import UIKit

final class RootTabBarController: UITabBarController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        assignTabAccessibilityIdentifiers()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.tintColor = DemoTheme.accent
        tabBar.backgroundColor = DemoTheme.surface

        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "square.grid.2x2"), tag: 0)

        let forms = UINavigationController(rootViewController: FormsViewController())
        forms.tabBarItem = UITabBarItem(title: "Forms", image: UIImage(systemName: "slider.horizontal.3"), tag: 1)

        let feed = UINavigationController(rootViewController: FeedViewController())
        feed.tabBarItem = UITabBarItem(title: "Feed", image: UIImage(systemName: "rectangle.stack"), tag: 2)

        viewControllers = [home, forms, feed]
    }

    private func assignTabAccessibilityIdentifiers() {
        let identifiers = [DemoID.tabHome, DemoID.tabForms, DemoID.tabFeed]
        let tabButtons = tabBar.subviews
            .filter { $0 is UIControl }
            .sorted { $0.frame.minX < $1.frame.minX }

        for (index, button) in tabButtons.enumerated() where index < identifiers.count {
            button.accessibilityIdentifier = identifiers[index]
        }
    }
}
