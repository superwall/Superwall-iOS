//
//  SuperwallLogoViewController.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 24/11/2024.
//

#if !os(visionOS)
import UIKit

/// Displays the Superwall logo behind the notch/Dynamic Island using a separate
/// portrait-locked window. This approach ensures the logo never rotates with the app
/// and naturally stays aligned with the physical notch during device rotation.
final class SuperwallLogoViewController: UIViewController {
  // MARK: - Static Properties

  /// The shared instance managing the logo window.
  private static var shared: SuperwallLogoViewController?

  /// The dedicated window for the logo (not a subclass to avoid detection).
  private static var logoWindow: UIWindow?

  // MARK: - Static Methods

  /// Shows the logo if conditions are met.
  /// - Parameters:
  ///   - paywall: The paywall to check presentation conditions.
  ///   - presentationStyle: The paywall presentation style.
  ///   - windowScene: The window scene to attach to.
  @discardableResult
  static func showIfNeeded(
    for paywall: Paywall,
    presentationStyle: PaywallPresentationStyle,
    in windowScene: UIWindowScene?
  ) -> SuperwallLogoViewController? {
    #if os(visionOS)
    return nil
    #else
    // Don't show during UI tests
    if ProcessInfo.processInfo.arguments.contains("SUPERWALL_UI_TESTS") {
      return nil
    }

    // Only show for fullscreen paywalls
    switch presentationStyle {
    case .fullscreen,
      .fullscreenNoAnimation:
      break
    default:
      return nil
    }

    // Only show if device has a notch or Dynamic Island
    guard DynamicIslandInfo.current.hasDynamicIslandOrNotch else {
      return nil
    }

    // Only show when Superwall is presenting (not when dev uses getPaywall)
    guard paywall.presentationSourceType?.isSuperwallPresenting == true else {
      return nil
    }

    guard let windowScene = windowScene else {
      return nil
    }

    // Create the logo view controller
    let logoVC = SuperwallLogoViewController()
    shared = logoVC

    // Create the dedicated window
    let window = UIWindow(windowScene: windowScene)
    window.frame = windowScene.coordinateSpace.bounds
    window.backgroundColor = .clear
    // Just above normal window level, not excessively high
    window.windowLevel = .normal + 1
    window.rootViewController = logoVC
    window.isUserInteractionEnabled = false
    // Don't use makeKeyAndVisible() - just show it
    window.isHidden = false
    logoWindow = window

    return logoVC
    #endif
  }

  /// Hides and removes the logo window.
  static func hideAndRemove() {
    guard let logoVC = shared else { return }

    UIView.animate(
      withDuration: 0.2,
      animations: {
        logoVC.pillView.alpha = 0
      },
      completion: { _ in
        logoWindow?.isHidden = true
        logoWindow = nil
        shared = nil
      }
    )
  }

  // MARK: - Orientation Locking

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    .portrait
  }

  override var shouldAutorotate: Bool {
    false
  }

  // MARK: - Properties

  /// The pill-shaped container that holds the logo
  private let pillView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor(hexString: "#13151A")
    view.layer.cornerCurve = .continuous
    view.alpha = 0 // Start hidden
    return view
  }()

  private let logoImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(
      named: "SuperwallKit_superwall_logo",
      in: Bundle.module,
      compatibleWith: nil
    )
    return imageView
  }()

  private let dynamicIslandInfo = DynamicIslandInfo.current

  /// Padding around the logo inside the pill
  private let logoPadding: CGFloat = 12

  /// Work item for delayed show - can be cancelled if app backgrounds again
  private var showWorkItem: DispatchWorkItem?

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    setupPillView()
    setupObservers()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Delay initial show slightly to avoid flash during presentation
    showWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.showPill()
    }
    showWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Setup

  private func setupPillView() {
    view.addSubview(pillView)
    pillView.addSubview(logoImageView)

    if dynamicIslandInfo.hasDynamicIsland {
      setupDynamicIslandLayout()
    } else if dynamicIslandInfo.hasNotch {
      setupNotchLayout()
    }
  }

  private func setupDynamicIslandLayout() {
    let pillWidth = dynamicIslandInfo.width
    let pillHeight = dynamicIslandInfo.height
    let topPadding = dynamicIslandInfo.topPadding
    let screenWidth = UIScreen.main.bounds.width

    // Position pill centered at top
    pillView.frame = CGRect(
      x: (screenWidth - pillWidth) / 2,
      y: topPadding,
      width: pillWidth,
      height: pillHeight
    )

    // Corner radius = half height for capsule shape
    pillView.layer.cornerRadius = pillHeight / 2

    // Logo with padding
    logoImageView.frame = pillView.bounds.insetBy(dx: logoPadding, dy: logoPadding)
  }

  private func setupNotchLayout() {
    let pillWidth: CGFloat = 125
    let pillHeight: CGFloat = 30
    let screenWidth = UIScreen.main.bounds.width

    // Position pill centered at top
    pillView.frame = CGRect(
      x: (screenWidth - pillWidth) / 2,
      y: 0,
      width: pillWidth,
      height: pillHeight
    )

    // Only round the bottom corners to match notch shape
    pillView.layer.cornerRadius = 12
    pillView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

    // Logo with padding (less padding since it's smaller)
    let notchLogoPadding: CGFloat = 8
    logoImageView.frame = pillView.bounds.insetBy(dx: notchLogoPadding, dy: notchLogoPadding)
  }

  // MARK: - Observers

  private func setupObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func appWillResignActive() {
    // Cancel any pending show operation and hide immediately
    showWorkItem?.cancel()
    showWorkItem = nil
    pillView.alpha = 0
  }

  @objc private func appDidBecomeActive() {
    // Cancel any existing work item
    showWorkItem?.cancel()

    // Delay showing until app transition animation completes
    let workItem = DispatchWorkItem { [weak self] in
      self?.showPill()
    }
    showWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
  }

  private func showPill() {
    guard UIApplication.shared.applicationState == .active else { return }
    pillView.alpha = 1
  }
}
#endif
