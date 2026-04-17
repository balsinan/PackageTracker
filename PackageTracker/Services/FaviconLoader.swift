import UIKit

final class FaviconLoader {
    static let shared = FaviconLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session = URLSession.shared

    private init() {
        cache.countLimit = 500
    }

    func loadFavicon(for websiteURL: String?, into imageView: UIImageView, placeholder: UIImage?) {
        imageView.image = placeholder

        guard let websiteURL,
              let host = URL(string: websiteURL)?.host else { return }

        let cacheKey = host as NSString
        if let cached = cache.object(forKey: cacheKey) {
            imageView.image = cached
            return
        }

        let faviconURLString = "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
        guard let faviconURL = URL(string: faviconURLString) else { return }

        let task = session.dataTask(with: faviconURL) { [weak self, weak imageView] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            self?.cache.setObject(image, forKey: cacheKey)
            DispatchQueue.main.async {
                imageView?.image = image
            }
        }
        task.resume()
    }
}
