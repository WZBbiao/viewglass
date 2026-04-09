import UIKit

final class RootTabBarController: UITabBarController {
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
}
