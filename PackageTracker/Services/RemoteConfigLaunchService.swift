import Foundation
import FirebaseRemoteConfig

/// Remote values read during splash; refreshed from the network each cold start (no local RC throttle).
enum LaunchRemoteState {
    static var isInReview: Bool = false
}

final class RemoteConfigLaunchService {
    static let shared = RemoteConfigLaunchService()

    private let rc = RemoteConfig.remoteConfig()

    /// Fetches and activates Remote Config for this session (`minimumFetchInterval = 0`, `expirationDuration = 0`).
    func fetchFreshSessionInReview(completion: @escaping (Bool) -> Void) {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        rc.configSettings = settings
        rc.setDefaults(["inReview": false as NSObject])

        attemptFetch(remainingAttempts: 3, completion: completion)
    }

    private func attemptFetch(remainingAttempts: Int, completion: @escaping (Bool) -> Void) {
        rc.fetch(withExpirationDuration: 0) { [weak self] status, _ in
            guard let self else { return }

            let finish: (Bool) -> Void = { value in
                DispatchQueue.main.async {
                    LaunchRemoteState.isInReview = value
                    completion(value)
                }
            }

            guard status == .success else {
                if remainingAttempts > 1 {
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.75) {
                        self.attemptFetch(remainingAttempts: remainingAttempts - 1, completion: completion)
                    }
                } else {
                    finish(false)
                }
                return
            }

            self.rc.activate { _, error in
                if error != nil {
                    if remainingAttempts > 1 {
                        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.75) {
                            self.attemptFetch(remainingAttempts: remainingAttempts - 1, completion: completion)
                        }
                    } else {
                        finish(false)
                    }
                    return
                }
                let inReview = self.rc.configValue(forKey: "inReview").boolValue
                finish(inReview)
            }
        }
    }
}
