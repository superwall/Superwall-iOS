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
  /// Reports whether its view controller fills the window, as UIKit's sheet and full-screen
  /// presentation controllers do.
  private final class FakePresentationController: UIPresentationController {
    let fillsWindow: Bool

    init(presentedViewController: UIViewController, fillsWindow: Bool) {
      self.fillsWindow = fillsWindow
      super.init(presentedViewController: presentedViewController, presenting: nil)
    }

    override var shouldPresentInFullscreen: Bool {
      return fillsWindow
    }
  }

  /// Stands in for an app view controller that locks its own orientation, the way Unity's does.
  private final class OrientationLockedViewController: UIViewController {
    let orientations: UIInterfaceOrientationMask
    let presented: OrientationLockedViewController?
    let fillsWindow: Bool
    weak var presenter: UIViewController?
    private(set) var orientationUpdateCount = 0
    private lazy var fakePresentationController = FakePresentationController(
      presentedViewController: self,
      fillsWindow: fillsWindow
    )

    init(
      _ orientations: UIInterfaceOrientationMask,
      fillsWindow: Bool = true,
      presenting presented: OrientationLockedViewController? = nil
    ) {
      self.orientations = orientations
      self.fillsWindow = fillsWindow
      self.presented = presented
      super.init(nibName: nil, bundle: nil)
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

    override var presentationController: UIPresentationController? {
      return presenter == nil ? nil : fakePresentationController
    }

    override func setNeedsUpdateOfSupportedInterfaceOrientations() {
      orientationUpdateCount += 1
    }
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
}
