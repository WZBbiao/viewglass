import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var debugFloatingWindow: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootTabBarController()
        window.makeKeyAndVisible()
        self.window = window

        if ProcessInfo.processInfo.environment["VIEWGLASS_DEMO_FLOATING_KEY_WINDOW"] == "1" {
            showDebugFloatingKeyWindow(in: windowScene)
        }
    }

    private func showDebugFloatingKeyWindow(in windowScene: UIWindowScene) {
        let floatingWindow = UIWindow(windowScene: windowScene)
        floatingWindow.frame = CGRect(x: 0, y: 150, width: 44, height: 44)
        floatingWindow.windowLevel = .alert + 10
        floatingWindow.rootViewController = DebugFloatingViewController()
        floatingWindow.makeKeyAndVisible()
        debugFloatingWindow = floatingWindow
    }
}

private final class DebugFloatingViewController: UIViewController {
    override func loadView() {
        let label = UILabel()
        label.accessibilityIdentifier = "debug_floating_avatar"
        label.backgroundColor = UIColor.systemBlue
        label.layer.cornerRadius = 22
        label.layer.masksToBounds = true
        label.text = "测"
        label.textAlignment = .center
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 18)
        view = label
    }
}
