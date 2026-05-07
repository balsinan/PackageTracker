import StoreKit
import UIKit

/// Horizontal onboarding without `UIScrollView`: tap the continue control to slide between full-screen images (`onb_1` … `onb_4`).
final class OnboardingViewController: UIViewController {

    var onCompleted: (() -> Void)?

    private enum Metrics {
        static let horizontalInset: CGFloat = 22
        static let bottomInset: CGFloat = 24
        static let continueHeight: CGFloat = 70
        /// Figma corner radius for the continue control.
        static let continueCornerRadius: CGFloat = 31.7
        static let titleFontSize: CGFloat = 22
        static let indicatorSpacing: CGFloat = 8
        static let indicatorInactiveSize: CGFloat = 8
        static let indicatorActiveWidth: CGFloat = 28
        static let indicatorHeight: CGFloat = 8
        /// Page indicators sit this far above the continue control’s top edge.
        static let indicatorAboveContinue: CGFloat = 13
        /// Page indicators’ trailing inset from the continue button’s trailing edge (LTR).
        static let pageControlTrailingInsetFromButton: CGFloat = 8
        static let nextIconLeadingInset: CGFloat = 23
        static let nextIconWidth: CGFloat = 20
        static let nextIconHeight: CGFloat = 23
        /// Onboarding page 4 — review carousel (`onb_4`).
        static let reviewCardSize = CGSize(width: 287, height: 152)
        static let reviewCarouselSpacing: CGFloat = 12
        static let reviewCardToUsersTop: CGFloat = 45
        static let usersTopToContinueButton: CGFloat = 36
        static let usersTopSize = CGSize(width: 105, height: 40)
        static let reviewAutoScrollInterval: TimeInterval = 2.5
    }

    /// Inactive page dots — Figma `#102B4E`; active capsule uses `.white`.
    private static let inactiveDotColor = UIColor(red: 16 / 255, green: 43 / 255, blue: 78 / 255, alpha: 1)

    private struct OnboardingReview: Equatable {
        let name: String
        let body: String
    }

    private let onboardingReviews: [OnboardingReview] = [
        .init(
            name: "Sarah K.",
            body: "Good app—I track all my packages in one place now. When one order ships in two boxes, I don’t have to chase separate carrier links anymore."
        ),
        .init(
            name: "Daniel R.",
            body: "Fast and simple, and it actually stays accurate for me. I used to keep three carrier tabs open; here the status updates without me refreshing every hour."
        ),
        .init(
            name: "Emma L.",
            body: "I get updates on time, which is what I wanted from a tracker. The timeline made it obvious why a package sat “in transit” for a few extra days."
        ),
    ]

    private let pageNames = ["onb_1", "onb_2", "onb_3", "onb_4"]
    private var hasRequestedReviewOnLastOnboardingPage = false

    private var currentIndex = 0 {
        didSet {
            let lastIndex = pageNames.count - 1
            if currentIndex == lastIndex, oldValue != currentIndex, !hasRequestedReviewOnLastOnboardingPage {
                hasRequestedReviewOnLastOnboardingPage = true
                requestStoreReviewIfPossible()
            }
            refreshChrome(animated: true)
        }
    }

    private let imageContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let fromImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let toImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let pageIndicatorStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Metrics.indicatorSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        stack.semanticContentAttribute = .forceLeftToRight
        return stack
    }()

    private var dotViews: [UIView] = []
    private var dotWidthConstraints: [NSLayoutConstraint] = []

    /// Groups page indicators + CTA so both share the same horizontal insets and trailing edge.
    private let onboardingFooter: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let continueShadowContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let continuePill: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = Metrics.continueCornerRadius
        view.clipsToBounds = true
        return view
    }()

    private let continueBackgroundImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "next_bg"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let nextIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = Typography.poppins(.semiBold, size: Metrics.titleFontSize)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        return label
    }()

    private let reviewCarouselLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = Metrics.reviewCardSize
        layout.minimumLineSpacing = Metrics.reviewCarouselSpacing
        return layout
    }()

    private lazy var reviewsCollectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: reviewCarouselLayout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.alwaysBounceHorizontal = true
        cv.dataSource = self
        cv.delegate = self
        cv.register(OnboardingReviewCell.self, forCellWithReuseIdentifier: OnboardingReviewCell.reuseIdentifier)
        return cv
    }()

    private let reviewCarouselToUsersTopSpacer: UIView = {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.backgroundColor = .clear
        return spacer
    }()

    private let usersTopImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "users_top"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private lazy var reviewsVerticalStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [reviewsCollectionView, reviewCarouselToUsersTopSpacer, usersTopImageView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let reviewsChromeContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()

    private var reviewsChromeHeightConstraint: NSLayoutConstraint!

    private var reviewAutoScrollTimer: Timer?
    private var currentReviewIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(imageContainer)
        imageContainer.addSubview(toImageView)
        imageContainer.addSubview(fromImageView)
        view.addSubview(reviewsChromeContainer)
        view.addSubview(onboardingFooter)
        onboardingFooter.addSubview(pageIndicatorStack)
        onboardingFooter.addSubview(continueShadowContainer)
        continueShadowContainer.addSubview(continuePill)

        buildPageIndicators()
        continuePill.addSubview(continueBackgroundImageView)
        continuePill.addSubview(nextIconImageView)
        continuePill.addSubview(titleLabel)
        configureNextIcon()
        configureReviewCarouselChrome()

        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: view.topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            fromImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            fromImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            fromImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            fromImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            toImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            toImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            toImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            toImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            continueShadowContainer.leadingAnchor.constraint(equalTo: onboardingFooter.leadingAnchor),
            continueShadowContainer.trailingAnchor.constraint(equalTo: onboardingFooter.trailingAnchor),
            continueShadowContainer.bottomAnchor.constraint(equalTo: onboardingFooter.bottomAnchor),
            continueShadowContainer.heightAnchor.constraint(equalToConstant: Metrics.continueHeight),

            continuePill.topAnchor.constraint(equalTo: continueShadowContainer.topAnchor),
            continuePill.leadingAnchor.constraint(equalTo: continueShadowContainer.leadingAnchor),
            continuePill.trailingAnchor.constraint(equalTo: continueShadowContainer.trailingAnchor),
            continuePill.bottomAnchor.constraint(equalTo: continueShadowContainer.bottomAnchor),

            continueBackgroundImageView.topAnchor.constraint(equalTo: continuePill.topAnchor),
            continueBackgroundImageView.leadingAnchor.constraint(equalTo: continuePill.leadingAnchor),
            continueBackgroundImageView.trailingAnchor.constraint(equalTo: continuePill.trailingAnchor),
            continueBackgroundImageView.bottomAnchor.constraint(equalTo: continuePill.bottomAnchor),

            onboardingFooter.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.horizontalInset),
            onboardingFooter.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.horizontalInset),
            onboardingFooter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Metrics.bottomInset),

            pageIndicatorStack.topAnchor.constraint(equalTo: onboardingFooter.topAnchor),
            pageIndicatorStack.trailingAnchor.constraint(
                equalTo: continuePill.trailingAnchor,
                constant: -Metrics.pageControlTrailingInsetFromButton
            ),
            pageIndicatorStack.bottomAnchor.constraint(
                equalTo: continueShadowContainer.topAnchor,
                constant: -Metrics.indicatorAboveContinue
            ),

            reviewsChromeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            reviewsChromeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            reviewsChromeContainer.bottomAnchor.constraint(
                equalTo: continueShadowContainer.topAnchor,
                constant: -Metrics.usersTopToContinueButton
            ),

            nextIconImageView.leadingAnchor.constraint(equalTo: continuePill.leadingAnchor, constant: Metrics.nextIconLeadingInset),
            nextIconImageView.centerYAnchor.constraint(equalTo: continuePill.centerYAnchor),
            nextIconImageView.widthAnchor.constraint(equalToConstant: Metrics.nextIconWidth),
            nextIconImageView.heightAnchor.constraint(equalToConstant: Metrics.nextIconHeight),

            titleLabel.centerXAnchor.constraint(equalTo: continuePill.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: continuePill.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nextIconImageView.trailingAnchor, constant: 12)
        ])

        reviewsChromeHeightConstraint = reviewsChromeContainer.heightAnchor.constraint(equalToConstant: 0)
        reviewsChromeHeightConstraint.isActive = true

        fromImageView.image = UIImage(named: pageNames[0])
        toImageView.image = nil
        toImageView.isHidden = true
        imageContainer.bringSubviewToFront(fromImageView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(primaryTapped))
        continuePill.addGestureRecognizer(tap)
        continuePill.isAccessibilityElement = true
        continuePill.accessibilityTraits = .button

        refreshChrome(animated: false)
    }

    deinit {
        stopReviewAutoScrollTimer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateReviewCarouselSectionInsetsIfNeeded()
    }

    private func configureReviewCarouselChrome() {
        reviewsChromeContainer.isUserInteractionEnabled = true
        reviewCarouselToUsersTopSpacer.isUserInteractionEnabled = false
        usersTopImageView.isUserInteractionEnabled = false
    }

    private func installReviewCarouselStackIfNeeded() {
        guard reviewsVerticalStack.superview != reviewsChromeContainer else { return }
        reviewsChromeContainer.addSubview(reviewsVerticalStack)
        reviewsVerticalStack.isUserInteractionEnabled = true
        reviewsCollectionView.isUserInteractionEnabled = true
        NSLayoutConstraint.activate([
            reviewsVerticalStack.topAnchor.constraint(equalTo: reviewsChromeContainer.topAnchor),
            reviewsVerticalStack.leadingAnchor.constraint(equalTo: reviewsChromeContainer.leadingAnchor),
            reviewsVerticalStack.trailingAnchor.constraint(equalTo: reviewsChromeContainer.trailingAnchor),
            reviewsVerticalStack.bottomAnchor.constraint(equalTo: reviewsChromeContainer.bottomAnchor),

            reviewsCollectionView.leadingAnchor.constraint(equalTo: reviewsVerticalStack.leadingAnchor),
            reviewsCollectionView.trailingAnchor.constraint(equalTo: reviewsVerticalStack.trailingAnchor),
            reviewsCollectionView.heightAnchor.constraint(equalToConstant: Metrics.reviewCardSize.height),

            reviewCarouselToUsersTopSpacer.heightAnchor.constraint(equalToConstant: Metrics.reviewCardToUsersTop),

            usersTopImageView.widthAnchor.constraint(equalToConstant: Metrics.usersTopSize.width),
            usersTopImageView.heightAnchor.constraint(equalToConstant: Metrics.usersTopSize.height),
        ])
    }

    private func uninstallReviewCarouselStackIfNeeded() {
        guard reviewsVerticalStack.superview != nil else { return }
        reviewsVerticalStack.removeFromSuperview()
    }

    private func updateReviewCarouselSectionInsetsIfNeeded() {
        guard currentIndex == pageNames.count - 1 else { return }
        let width = reviewsCollectionView.bounds.width
        guard width > 0 else { return }
        let card = Metrics.reviewCardSize.width
        let inset = max(Metrics.horizontalInset, (width - card) / 2)
        let next = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        guard reviewCarouselLayout.sectionInset != next else { return }
        reviewCarouselLayout.sectionInset = next
        reviewCarouselLayout.invalidateLayout()
    }

    private func syncReviewCarouselChrome(animated _: Bool) {
        let onLastPage = currentIndex == pageNames.count - 1
        /// Must match `onLastPage`: container defaults to `isHidden = true`; otherwise layout runs but nothing draws.
        reviewsChromeContainer.isHidden = !onLastPage

        if onLastPage {
            installReviewCarouselStackIfNeeded()
            reviewsChromeHeightConstraint.isActive = false
            updateReviewCarouselSectionInsetsIfNeeded()
            reviewsCollectionView.reloadData()
            currentReviewIndex = 0
            reviewsCollectionView.layoutIfNeeded()
            scrollReviewCarousel(to: 0, animated: false)
            startReviewAutoScrollTimer()
        } else {
            stopReviewAutoScrollTimer()
            uninstallReviewCarouselStackIfNeeded()
            reviewsChromeHeightConstraint.isActive = true
        }
    }

    private func startReviewAutoScrollTimer() {
        stopReviewAutoScrollTimer()
        let timer = Timer(timeInterval: Metrics.reviewAutoScrollInterval, repeats: true) { [weak self] _ in
            self?.advanceReviewCarouselAutomatically()
        }
        reviewAutoScrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopReviewAutoScrollTimer() {
        reviewAutoScrollTimer?.invalidate()
        reviewAutoScrollTimer = nil
    }

    private func restartReviewAutoScrollTimer() {
        guard currentIndex == pageNames.count - 1 else { return }
        startReviewAutoScrollTimer()
    }

    private func advanceReviewCarouselAutomatically() {
        guard currentIndex == pageNames.count - 1 else { return }
        let count = onboardingReviews.count
        guard count > 0 else { return }
        let next = (currentReviewIndex + 1) % count
        currentReviewIndex = next
        scrollReviewCarousel(to: next, animated: true)
    }

    private func scrollReviewCarousel(to index: Int, animated: Bool) {
        guard index >= 0, index < onboardingReviews.count else { return }
        let path = IndexPath(item: index, section: 0)
        reviewsCollectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: animated)
    }

    private func proposedContentOffsetForReviewSnap(scrollView: UIScrollView, proposedOffset: CGPoint) -> CGFloat {
        let midX = proposedOffset.x + scrollView.bounds.width / 2
        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for i in 0..<onboardingReviews.count {
            let path = IndexPath(item: i, section: 0)
            guard let attrs = reviewCarouselLayout.layoutAttributesForItem(at: path) else { continue }
            let distance = abs(attrs.frame.midX - midX)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = i
            }
        }
        let path = IndexPath(item: bestIndex, section: 0)
        guard let attrs = reviewCarouselLayout.layoutAttributesForItem(at: path) else { return proposedOffset.x }
        return attrs.frame.midX - scrollView.bounds.width / 2
    }

    private func updateCurrentReviewIndexFromScrollPosition() {
        let center = CGPoint(
            x: reviewsCollectionView.contentOffset.x + reviewsCollectionView.bounds.width / 2,
            y: reviewsCollectionView.bounds.height / 2
        )
        if let path = reviewsCollectionView.indexPathForItem(at: center) {
            currentReviewIndex = path.item
        }
    }

    private func requestStoreReviewIfPossible() {
        guard let scene = view.window?.windowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    private func configureNextIcon() {
        if let custom = UIImage(named: "next_icon") {
            nextIconImageView.image = custom
        } else {
            let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            let fallback = UIImage(systemName: "arrow.right", withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            nextIconImageView.image = fallback
        }
    }

    private func buildPageIndicators() {
        for index in 0..<pageNames.count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = Metrics.indicatorHeight / 2
            let isActive = index == 0
            let w = dot.widthAnchor.constraint(equalToConstant: isActive ? Metrics.indicatorActiveWidth : Metrics.indicatorInactiveSize)
            NSLayoutConstraint.activate([
                w,
                dot.heightAnchor.constraint(equalToConstant: Metrics.indicatorHeight)
            ])
            dot.backgroundColor = isActive ? .white : Self.inactiveDotColor
            pageIndicatorStack.addArrangedSubview(dot)
            dotViews.append(dot)
            dotWidthConstraints.append(w)
        }
    }

    private func refreshChrome(animated: Bool) {
        let title = currentIndex == 0 ? "Get Started" : "Continue"
        titleLabel.text = title
        continuePill.accessibilityLabel = title

        let updates = {
            for index in 0..<self.dotViews.count {
                let isActive = index == self.currentIndex
                self.dotWidthConstraints[index].constant = isActive ? Metrics.indicatorActiveWidth : Metrics.indicatorInactiveSize
                self.dotViews[index].backgroundColor = isActive ? .white : Self.inactiveDotColor
                self.dotViews[index].layer.cornerRadius = Metrics.indicatorHeight / 2
            }
            self.pageIndicatorStack.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.35, animations: updates)
        } else {
            updates()
        }

        syncReviewCarouselChrome(animated: animated)
    }

    @objc private func primaryTapped() {
        HapticFeedback.medium.play()
        if currentIndex < pageNames.count - 1 {
            let nextIndex = currentIndex + 1
            transitionToPage(nextIndex, forward: true)
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasCompletedOnboarding)
        onCompleted?()
    }

    private func transitionToPage(_ index: Int, forward: Bool, onFinished: (() -> Void)? = nil) {
        guard index != currentIndex, index >= 0, index < pageNames.count else { return }
        let width = view.bounds.width

        toImageView.image = UIImage(named: pageNames[index])
        toImageView.isHidden = false
        fromImageView.image = UIImage(named: pageNames[currentIndex])

        let duration = 0.38
        if forward {
            toImageView.transform = CGAffineTransform(translationX: width, y: 0)
            fromImageView.transform = .identity
        } else {
            toImageView.transform = CGAffineTransform(translationX: -width, y: 0)
            fromImageView.transform = .identity
        }
        imageContainer.sendSubviewToBack(toImageView)
        imageContainer.bringSubviewToFront(fromImageView)

        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
            if forward {
                self.fromImageView.transform = CGAffineTransform(translationX: -width, y: 0)
                self.toImageView.transform = .identity
            } else {
                self.fromImageView.transform = CGAffineTransform(translationX: width, y: 0)
                self.toImageView.transform = .identity
            }
        } completion: { _ in
            self.currentIndex = index
            self.fromImageView.transform = .identity
            self.toImageView.transform = .identity
            self.fromImageView.image = UIImage(named: self.pageNames[index])
            self.toImageView.isHidden = true
            self.imageContainer.bringSubviewToFront(self.fromImageView)
            onFinished?()
        }
    }

}

// MARK: - Review carousel

extension OnboardingViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        onboardingReviews.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OnboardingReviewCell.reuseIdentifier, for: indexPath) as! OnboardingReviewCell
        let review = onboardingReviews[indexPath.item]
        cell.configure(name: review.name, body: review.body)
        return cell
    }
}

extension OnboardingViewController: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === reviewsCollectionView else { return }
        stopReviewAutoScrollTimer()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity _: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard scrollView === reviewsCollectionView else { return }
        let x = proposedContentOffsetForReviewSnap(scrollView: scrollView, proposedOffset: targetContentOffset.pointee)
        targetContentOffset.pointee.x = x
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === reviewsCollectionView else { return }
        if !decelerate {
            updateCurrentReviewIndexFromScrollPosition()
            restartReviewAutoScrollTimer()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === reviewsCollectionView else { return }
        updateCurrentReviewIndexFromScrollPosition()
        restartReviewAutoScrollTimer()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === reviewsCollectionView else { return }
        updateCurrentReviewIndexFromScrollPosition()
        restartReviewAutoScrollTimer()
    }
}

private final class OnboardingReviewCell: UICollectionViewCell {
    static let reuseIdentifier = "OnboardingReviewCell"

    /// Matches review card copy (`#102B4E`).
    private static let textColor = UIColor(red: 16 / 255, green: 43 / 255, blue: 78 / 255, alpha: 1)
    private static let namePointSize: CGFloat = 11
    private static let reviewPointSize: CGFloat = 11

    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = 28
        view.clipsToBounds = true
        return view
    }()

    private let cardBackgroundImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "review_bg"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let starsImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "stars"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = OnboardingReviewCell.textColor
        label.font = Typography.poppins(.bold, size: OnboardingReviewCell.namePointSize)
        label.textAlignment = .right
        label.numberOfLines = 1
        return label
    }()

    private let reviewLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = OnboardingReviewCell.textColor
        label.font = Typography.poppins(.medium, size: OnboardingReviewCell.reviewPointSize)
        label.textAlignment = .natural
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)
        cardView.addSubview(cardBackgroundImageView)
        cardView.addSubview(starsImageView)
        cardView.addSubview(nameLabel)
        cardView.addSubview(reviewLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            cardBackgroundImageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            cardBackgroundImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            cardBackgroundImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            cardBackgroundImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            starsImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            starsImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            starsImageView.heightAnchor.constraint(equalToConstant: 18),

            nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            nameLabel.centerYAnchor.constraint(equalTo: starsImageView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: starsImageView.trailingAnchor, constant: 8),

            reviewLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            reviewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            reviewLabel.topAnchor.constraint(equalTo: starsImageView.bottomAnchor, constant: 10),
            reviewLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(name: String, body: String) {
        nameLabel.text = name
        reviewLabel.text = body
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        reviewLabel.text = nil
    }
}
