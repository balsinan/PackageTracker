import UIKit

final class SplashViewController: UIViewController {

    /// Called on the main queue after Remote Config (`inReview`) and RevenueCat customer info have been loaded this session.
    var onFinishedBootstrapping: (() -> Void)?

    private var didStartBootstrap = false

    private let imageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "splash"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        beginSessionBootstrapIfNeeded()
    }

    private func beginSessionBootstrapIfNeeded() {
        guard !didStartBootstrap else { return }
        didStartBootstrap = true

        RemoteConfigLaunchService.shared.fetchFreshSessionInReview { _ in
            IapService.sharedInstance.checkIapValidation { _, _ in
                DispatchQueue.main.async { [weak self] in
                    self?.onFinishedBootstrapping?()
                }
            }
        }
    }
}
