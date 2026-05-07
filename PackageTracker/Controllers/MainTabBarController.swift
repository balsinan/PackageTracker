import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        configureAppearance()
        setViewControllers([makePackagesNav(), makeSettingsNav()], animated: false)
    }

    private func configureAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppTheme.secondaryBackground
        appearance.stackedLayoutAppearance.selected.iconColor = AppTheme.accent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: AppTheme.accent]
        appearance.stackedLayoutAppearance.normal.iconColor = AppTheme.textSecondary
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: AppTheme.textSecondary]
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = AppTheme.accent
    }

    private func makePackagesNav() -> UINavigationController {
        let controller = PackageListViewController()
        controller.title = "My Packages"
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.tabBarItem = UITabBarItem(title: "Packages", image: UIImage(systemName: "shippingbox"), selectedImage: UIImage(systemName: "shippingbox.fill"))
        return navigationController
    }

    private func makeSettingsNav() -> UINavigationController {
        let controller = SettingsViewController()
        controller.title = "Settings"
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), selectedImage: UIImage(systemName: "gearshape.fill"))
        return navigationController
    }
}

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewController !== tabBarController.selectedViewController {
            HapticFeedback.selection.play()
        }
        return true
    }
}
