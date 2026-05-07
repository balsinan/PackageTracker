//
//  SceneDelegate.swift
//  PackageTracker
//
//  Created by Merve Çelik on 17.04.2026.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        configureRevenueCat()
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .light

        let splash = SplashViewController()
        splash.onFinishedBootstrapping = { [weak self] in
            guard let self, let window = self.window else { return }
            self.applyPostSplashRouting(window: window)
        }
        window.rootViewController = splash
        window.makeKeyAndVisible()
        self.window = window
    }

    private func applyPostSplashRouting(window: UIWindow) {
        if LaunchRemoteState.isInReview {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.rootViewController = MainTabBarController()
            }
            return
        }

        if isPremium() {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.rootViewController = MainTabBarController()
            }
            return
        }

        if UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedOnboarding) {
            let paywall = PaywallViewController()
            paywall.presentationStyle = .sessionGate
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.rootViewController = paywall
            }
            return
        }

        let onboarding = OnboardingViewController()
        onboarding.onCompleted = { [weak window] in
            guard let window else { return }
            let paywall = PaywallViewController()
            paywall.presentationStyle = .sessionGate
            UIView.transition(with: window, duration: 0.28, options: .transitionCrossDissolve) {
                window.rootViewController = paywall
            }
        }
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = onboarding
        }
    }
}

