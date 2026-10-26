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
    let presented: UIViewController?
    private(set) var orientationUpdateCount = 0

    init(_ orientations: UIInterfaceOrientationMask, presenting presented: UIViewController? = nil) {
      self.orientations = orientations
      self.presented = presented
      super.init(nibName: nil, bundle: nil)
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
