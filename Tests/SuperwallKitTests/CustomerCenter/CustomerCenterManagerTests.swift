//
//  CustomerCenterManagerTests.swift
//
//
//  Created by Claude on 20/08/2026.
//

import Testing
import Foundation
import UIKit
@testable import SuperwallKit

@Suite("CustomerCenterManager")
@MainActor
struct CustomerCenterManagerTests {
  @available(iOS 15.0, *)
  @Test("resolveConfiguration: override > options > default")
  func resolution() {
    let container = DependencyContainer()
    let manager = CustomerCenterManager(container: container)
    #expect(manager.resolveConfiguration(nil) == container.configManager.options.customerCenter)
    let custom = CustomerCenterConfiguration.default
    custom.support.email = "x@y.z"
    #expect(manager.resolveConfiguration(custom) === custom)
  }

  @available(iOS 15.0, *)
  @Test("second present while presented is ignored")
  func singleInstance() {
    let container = DependencyContainer()
    let manager = CustomerCenterManager(container: container)
    let presenter = UIViewController()
    let window = makeTestWindow(rootViewController: presenter)
    window.makeKeyAndVisible()
    spinRunLoop(timeout: 1) { presenter.viewIfLoaded?.window != nil }

    manager.present(configuration: nil, from: presenter, delegate: nil, onDismiss: nil)
    #expect(manager.isPresented)
    manager.present(configuration: nil, from: presenter, delegate: nil, onDismiss: nil)
    #expect(manager.presentCount == 1)

    window.isHidden = true
  }

  @available(iOS 15.0, *)
  @Test("retains the delegate while presented, releases it after dismiss")
  func retainsDelegateForPresentationDuration() {
    final class ProbeDelegate: CustomerCenterDelegate {}

    let container = DependencyContainer()
    let manager = CustomerCenterManager(container: container)
    let presenter = UIViewController()
    let window = makeTestWindow(rootViewController: presenter)
    window.makeKeyAndVisible()
    spinRunLoop(timeout: 1) { presenter.viewIfLoaded?.window != nil }
    // Non-animated so that, in a host where UIKit does drive transitions to completion, this stays
    // fast and doesn't depend on animation timing.
    manager.presentsAnimated = false

    var strongDelegate: ProbeDelegate? = ProbeDelegate()
    weak var weakDelegate = strongDelegate

    manager.present(configuration: nil, from: presenter, delegate: strongDelegate, onDismiss: nil)
    strongDelegate = nil

    // Still presented: the manager should be the only thing keeping the delegate alive.
    #expect(weakDelegate != nil)
    #expect(manager.isPresented)

    // A hostless test target's run loop never drives a real view-controller-transition animation to
    // completion (there's no live display link committing frames): UIKit registers the presentation
    // synchronously but never finishes loading the presented view into a window, so it never calls
    // back into `viewDidDisappear` on its own. Trigger the exact same cleanup closure `present`
    // wires up as `onDismiss` — the real production code that clears `retainedDelegate` — the way
    // UIKit would if the transition had completed.
    manager.presentedControllerForTesting?.onDismiss?()
    spinRunLoop(timeout: 1) { weakDelegate == nil }

    #expect(weakDelegate == nil)
    #expect(!manager.isPresented)

    // With nothing presented, `dismiss(completion:)`'s early-exit path should complete synchronously.
    var dismissed = false
    manager.dismiss { dismissed = true }
    #expect(dismissed)

    window.isHidden = true
  }

  /// A window backed by a real connected `UIWindowScene` when one is available (as it is when a
  /// unit test target runs inside its generated host app), since modal presentation/dismissal
  /// transitions need one to actually animate and complete. Falls back to a legacy frame-based
  /// window when no scene is connected.
  private func makeTestWindow(rootViewController: UIViewController) -> UIWindow {
    let window: UIWindow
    if let scene = UIApplication.sharedApplication?.connectedScenes.first as? UIWindowScene {
      window = UIWindow(windowScene: scene)
      window.frame = scene.screen.bounds
    } else {
      window = UIWindow(frame: UIScreen.main.bounds)
    }
    window.rootViewController = rootViewController
    return window
  }

  /// Spins the main run loop in short increments until `condition` is true or `timeout` elapses,
  /// so tests can wait deterministically on UIKit's asynchronous presentation/dismissal animations.
  private func spinRunLoop(timeout: TimeInterval, until condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
  }
}
