//
//  PresentingWindowRootViewControllerTests.swift
//  SuperwallKitTests
//

import Testing
import UIKit
@testable import SuperwallKit

@MainActor
@Suite(.serialized)
struct PresentingWindowRootViewControllerTests {
  /// Stands in for an app view controller that locks its own orientation, the way Unity's does.
  private final class OrientationLockedViewController: UIViewController {
    let orientations: UIInterfaceOrientationMask
    let presented: OrientationLockedViewController?
    weak var presenter: UIViewController?
    private(set) var orientationUpdateCount = 0

    init(
      _ orientations: UIInterfaceOrientationMask,
      fillsWindow: Bool = true,
      presenting presented: OrientationLockedViewController? = nil
    ) {
      self.orientations = orientations
      self.presented = presented
      super.init(nibName: nil, bundle: nil)
      modalPresentationStyle = fillsWindow ? .fullScreen : .pageSheet
      presented?.presenter = self
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
      return orientations
    }

    override var presentedViewController: UIViewController? {
      return presented
    }

    override var presentingViewController: UIViewController? {
      return presenter
    }

    override func setNeedsUpdateOfSupportedInterfaceOrientations() {
      orientationUpdateCount += 1
    }
  }

  /// Stands in for an app view controller that decides for itself whether the status bar shows,
  /// the way Unity's does, or hands the decision to a child, the way a navigation controller does.
  private final class StatusBarViewController: UIViewController {
    let isStatusBarHidden: Bool
    let statusBarChild: UIViewController?
    private(set) var statusBarUpdateCount = 0

    init(
      isStatusBarHidden: Bool,
      child: UIViewController? = nil
    ) {
      self.isStatusBarHidden = isStatusBarHidden
      self.statusBarChild = child
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
      return isStatusBarHidden
    }

    override var childForStatusBarHidden: UIViewController? {
      return statusBarChild
    }

    override func setNeedsStatusBarAppearanceUpdate() {
      statusBarUpdateCount += 1
    }
  }

  /// Stands in for an app view controller that asks another one whether the status bar shows,
  /// the way one that goes by whatever is on top does.
  private final class StatusBarDeferringViewController: UIViewController {
    weak var asked: UIViewController?
    weak var statusBarChild: UIViewController?

    override var prefersStatusBarHidden: Bool {
      return asked?.prefersStatusBarHidden ?? true
    }

    override var childForStatusBarHidden: UIViewController? {
      return statusBarChild
    }
  }

  /// A paywall that's been presented from `presenter`.
  private final class PresentedPaywallViewController: PaywallViewController {
    var presenter: UIViewController?

    override var presentingViewController: UIViewController? {
      return presenter
    }
  }

  private func makePaywall(presentedFrom presenter: UIViewController) -> PresentedPaywallViewController {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let paywall = PresentedPaywallViewController(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: FakeWebView(
        isiOSAppOnMac: false,
        messageHandler: messageHandler,
        isOnDeviceCacheEnabled: true,
        factory: dependencyContainer
      ),
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: dependencyContainer.paywallManager.cache,
      paywallArchiveManager: nil,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    paywall.presenter = presenter
    return paywall
  }

  private func hostWindow(root: UIViewController) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.rootViewController = root
    return window
  }

  @Test
  func allowsTheOrientationsOfTheAppsWindow() {
    let window = hostWindow(root: OrientationLockedViewController(.landscape))
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)

    #expect(rootViewController.supportedInterfaceOrientations == .landscape)
  }

  @Test
  func allowsTheOrientationsOfTheTopmostPresentedViewController() {
    let window = hostWindow(
      root: OrientationLockedViewController(
        .landscape,
        presenting: OrientationLockedViewController(.portrait)
      )
    )
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)

    #expect(rootViewController.supportedInterfaceOrientations == .portrait)
  }

  @Test
  func ignoresASheetOnTheAppsWindow() {
    let window = hostWindow(
      root: OrientationLockedViewController(
        .landscape,
        presenting: OrientationLockedViewController(.allButUpsideDown, fillsWindow: false)
      )
    )
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)

    #expect(rootViewController.supportedInterfaceOrientations == .landscape)
  }

  @Test
  func allowsTheOrientationsOfAFullScreenViewControllerUnderASheet() {
    let window = hostWindow(
      root: OrientationLockedViewController(
        .landscape,
        presenting: OrientationLockedViewController(
          .portrait,
          presenting: OrientationLockedViewController(.allButUpsideDown, fillsWindow: false)
        )
      )
    )
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)

    #expect(rootViewController.supportedInterfaceOrientations == .portrait)
  }

  @Test
  func aSheetLooksThroughToTheScreenUnderIt() {
    let sheet = OrientationLockedViewController(.allButUpsideDown, fillsWindow: false)
    let root = OrientationLockedViewController(.landscape, presenting: sheet)

    #expect(sheet.orientationDecidingAncestor === root)
    #expect(root.orientationDecidingAncestor === root)
  }

  @Test
  func aFullScreenViewControllerDecidesForItself() {
    let fullScreen = OrientationLockedViewController(.portrait)
    let root = OrientationLockedViewController(.landscape, presenting: fullScreen)

    #expect(fullScreen.presentingViewController === root)
    #expect(fullScreen.orientationDecidingAncestor === fullScreen)
  }

  @Test
  func allowsTheDefaultOrientationsWithoutAnAppWindow() {
    let rootViewController = PresentingWindowRootViewController(hostWindow: nil)

    #expect(rootViewController.supportedInterfaceOrientations == UIViewController().supportedInterfaceOrientations)
  }

  @Test
  func doesNotAskItselfWhenItIsTheAppsWindowRoot() throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)
    window.rootViewController = rootViewController
    window.isHidden = false
    try #require(rootViewController.view.window === window)

    #expect(rootViewController.supportedInterfaceOrientations == UIViewController().supportedInterfaceOrientations)
  }

  @Test
  func destroyingThePresentingWindowAsksTheAppToCheckItsOrientations() {
    let appViewController = OrientationLockedViewController(.landscape)
    let window = hostWindow(root: appViewController)
    let presentingWindow = UIWindow()
    presentingWindow.rootViewController = PresentingWindowRootViewController(hostWindow: window)
    Superwall.shared.presentationItems.window = presentingWindow

    Superwall.shared.destroyPresentingWindow()

    #expect(Superwall.shared.presentationItems.window == nil)
    #expect(appViewController.orientationUpdateCount == 1)
  }

  @Test
  func hidesTheStatusBarWhenTheAppsWindowDoes() {
    let window = hostWindow(root: StatusBarViewController(isStatusBarHidden: true))
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)

    #expect(rootViewController.prefersStatusBarHidden)
  }

  @Test
  func showsTheStatusBarWhenTheAppsWindowDoes() {
    let window = hostWindow(root: StatusBarViewController(isStatusBarHidden: false))
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)

    #expect(!rootViewController.prefersStatusBarHidden)
  }

  @Test
  func asksTheChildTheAppHandsTheStatusBarTo() {
    let window = hostWindow(
      root: StatusBarViewController(
        isStatusBarHidden: false,
        child: StatusBarViewController(
          isStatusBarHidden: false,
          child: StatusBarViewController(isStatusBarHidden: true)
        )
      )
    )
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)

    #expect(rootViewController.prefersStatusBarHidden)
  }

  @Test
  func showsTheStatusBarWithoutAnAppWindow() {
    let rootViewController = PresentingWindowRootViewController(hostWindow: nil)

    #expect(rootViewController.prefersStatusBarHidden == UIViewController().prefersStatusBarHidden)
  }

  @Test
  func destroyingThePresentingWindowAsksTheAppToCheckItsStatusBar() {
    let appViewController = StatusBarViewController(isStatusBarHidden: true)
    let window = hostWindow(root: appViewController)
    let presentingWindow = UIWindow()
    presentingWindow.rootViewController = PresentingWindowRootViewController(hostWindow: window)
    Superwall.shared.presentationItems.window = presentingWindow

    Superwall.shared.destroyPresentingWindow()

    #expect(Superwall.shared.presentationItems.window == nil)
    #expect(appViewController.statusBarUpdateCount == 1)
  }

  @Test
  func aPaywallHidesTheStatusBarWhenTheScreenItCoversDoes() {
    let paywall = makePaywall(presentedFrom: StatusBarViewController(isStatusBarHidden: true))

    #expect(paywall.prefersStatusBarHidden)
  }

  @Test
  func aPaywallShowsTheStatusBarWhenTheScreenItCoversDoes() {
    let paywall = makePaywall(presentedFrom: StatusBarViewController(isStatusBarHidden: false))

    #expect(!paywall.prefersStatusBarHidden)
  }

  @Test
  func aPaywallAnswersForItselfWhenTheScreenItCoversAsksIt() {
    let presenter = StatusBarDeferringViewController()
    let paywall = makePaywall(presentedFrom: presenter)
    presenter.asked = paywall

    #expect(!paywall.prefersStatusBarHidden)
  }

  @Test
  func aPaywallAnswersForItselfWhenTheScreenItCoversHandsItTheStatusBar() {
    let presenter = StatusBarDeferringViewController()
    let paywall = makePaywall(presentedFrom: presenter)
    presenter.statusBarChild = paywall

    #expect(!paywall.prefersStatusBarHidden)
  }

  @Test
  func answersForItselfWhenTheAppsWindowAsksIt() {
    let appViewController = StatusBarDeferringViewController()
    let window = hostWindow(root: appViewController)
    let rootViewController = PresentingWindowRootViewController(hostWindow: window)
    appViewController.asked = rootViewController

    #expect(!rootViewController.prefersStatusBarHidden)
  }

  @Test
  func stopsAtAViewControllerThatHandsTheStatusBarToItself() {
    let viewController = StatusBarDeferringViewController()
    viewController.statusBarChild = viewController

    #expect(viewController.hidesStatusBar)
  }

  @Test
  func stopsWhenViewControllersHandTheStatusBarToEachOther() {
    let first = StatusBarDeferringViewController()
    let second = StatusBarDeferringViewController()
    first.statusBarChild = second
    second.statusBarChild = first

    #expect(first.hidesStatusBar)
  }
}
