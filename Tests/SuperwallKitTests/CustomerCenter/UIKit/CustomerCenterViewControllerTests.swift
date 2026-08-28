//
//  CustomerCenterViewControllerTests.swift
//
//
//  Created by Jordan Morgan on 25/08/2026.
//

import Testing
import Foundation
import UIKit
@testable import SuperwallKit

@Suite("CustomerCenterViewController presentation styles", .serialized)
@MainActor
struct CustomerCenterViewControllerTests {
  // MARK: - Fixtures

  private final class ProbeDelegate: CustomerCenterDelegate {
    var didDismissCount = 0
    func customerCenterDidDismiss() { didDismissCount += 1 }
  }

  @available(iOS 15.0, *)
  private func makeController(
    style: CustomerCenterPresentationStyle,
    delegate: CustomerCenterDelegate?,
    dismissDebounceInterval: TimeInterval = 0.6
  ) -> CustomerCenterViewController {
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    )
    let viewModel = CustomerCenterViewModel(
      configuration: .default,
      dependencies: deps,
      strings: .english,
      dismissDebounceInterval: dismissDebounceInterval
    )
    return CustomerCenterViewController(
      viewModel: viewModel,
      adapter: CustomerCenterDelegateAdapter(swiftDelegate: delegate, objcDelegate: nil),
      presentationStyle: style
    )
  }

  private func makeWindow(rootViewController: UIViewController) -> UIWindow {
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

  private func spinRunLoop(timeout: TimeInterval, until condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
  }

  // MARK: - Being covered is not being dismissed

  /// The regression this whole style split exists for. A pushed controller has
  /// `presentingViewController == nil` for its entire lifetime, so the previous teardown check
  /// treated every cover event — a push on top, a tab switch — as the Customer Center closing.
  /// `dismiss()` latches, so that also permanently silenced the real teardown.
  @available(iOS 15.0, *)
  @Test("pushed: being covered on the host's stack does not fire the dismissal")
  func pushedCoveredDoesNotDismiss() {
    let delegate = ProbeDelegate()
    let controller = makeController(style: .pushed, delegate: delegate)
    var onDismissCount = 0
    controller.onDismiss = { onDismissCount += 1 }

    let navigation = UINavigationController(rootViewController: UIViewController())
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    navigation.pushViewController(controller, animated: false)
    spinRunLoop(timeout: 1) { controller.viewIfLoaded?.window != nil }

    // The host pushes its own screen on top. UIKit leaves `isBeingDismissed` and
    // `isMovingFromParent` false here — we are covered, not removed.
    navigation.pushViewController(UIViewController(), animated: false)
    spinRunLoop(timeout: 1) { controller.viewIfLoaded?.window == nil }
    controller.viewDidDisappear(false)

    #expect(delegate.didDismissCount == 0)
    #expect(onDismissCount == 0)

    window.isHidden = true
  }

  /// The synchronous cover test above only proves nothing fires *immediately*. The view model also
  /// arms a debounced dismissal from SwiftUI's `onDisappear`, which a `UIHostingController`
  /// forwards on a cover just as it does on a teardown — so without a veto the dismissal simply
  /// arrives late, and the latch then silences the genuine pop. This waits past the debounce.
  @available(iOS 15.0, *)
  @Test("pushed: a cover does not fire a late dismissal, and the real pop still does")
  func pushedCoverDoesNotFireLateDismissal() async {
    let debounce: TimeInterval = 0.2
    let delegate = ProbeDelegate()
    let controller = makeController(style: .pushed, delegate: delegate, dismissDebounceInterval: debounce)

    let navigation = UINavigationController(rootViewController: UIViewController())
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    navigation.pushViewController(controller, animated: false)
    spinRunLoop(timeout: 1) { controller.viewIfLoaded?.window != nil }

    // Covered by the host's own screen.
    navigation.pushViewController(UIViewController(), animated: false)
    spinRunLoop(timeout: 1) { controller.viewIfLoaded?.window == nil }

    // Arm the debounce explicitly rather than trusting SwiftUI's `onDisappear` to have fired in
    // this harness. The claim under test is that the veto cancels an *armed* dismissal, and with
    // nothing armed the test would pass whether or not the veto works at all. In production the
    // ordering is guaranteed the other way round: `viewDidDisappear` calls `super` first, which
    // is what forwards the disappearance into SwiftUI and arms this.
    controller.viewModel.surfaceDidDisappear()
    controller.viewDidDisappear(false)

    try? await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(delegate.didDismissCount == 0, "a cover must not deliver a dismissal, even late")

    // And the genuine teardown afterwards must still be delivered — the premature fire would have
    // latched `didDismiss` and made this silent.
    navigation.popToRootViewController(animated: false)
    spinRunLoop(timeout: 1) { delegate.didDismissCount > 0 }
    #expect(delegate.didDismissCount == 1)

    window.isHidden = true
  }

  @available(iOS 15.0, *)
  @Test("pushed: being popped off the host's stack fires the dismissal exactly once")
  func pushedPopFiresDismissal() {
    let delegate = ProbeDelegate()
    let controller = makeController(style: .pushed, delegate: delegate)
    var onDismissCount = 0
    controller.onDismiss = { onDismissCount += 1 }

    let navigation = UINavigationController(rootViewController: UIViewController())
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    navigation.pushViewController(controller, animated: false)
    spinRunLoop(timeout: 1) { controller.viewIfLoaded?.window != nil }

    navigation.popViewController(animated: false)
    spinRunLoop(timeout: 1) { delegate.didDismissCount > 0 }

    #expect(delegate.didDismissCount == 1)
    #expect(onDismissCount == 1)

    window.isHidden = true
  }

  @available(iOS 15.0, *)
  @Test("modal: dismissing fires the dismissal exactly once")
  func modalDismissFiresDismissal() {
    let delegate = ProbeDelegate()
    let controller = makeController(style: .modal, delegate: delegate)
    var onDismissCount = 0
    controller.onDismiss = { onDismissCount += 1 }

    // A hostless test target never drives a modal transition to completion, so UIKit never
    // populates `presentingViewController` and a real `present(_:animated:)` here would leave the
    // controller unable to tell it had ever been presented. Set the one fact UIKit would have
    // recorded during `viewDidAppear`, then let the real teardown check run against it.
    controller.wasPresentedModally = true
    #expect(controller.presentingViewController == nil, "a dismissed modal has no presenter left")

    controller.viewDidDisappear(false)

    #expect(delegate.didDismissCount == 1)
    #expect(onDismissCount == 1)
  }

  /// A controller that was never presented and is not being removed is not a teardown. This is the
  /// case the old `presentingViewController == nil` check got wrong, since it is indistinguishable
  /// from a pushed controller sitting on a back stack.
  @available(iOS 15.0, *)
  @Test("a controller that was never presented does not report a dismissal")
  func neverPresentedDoesNotDismiss() {
    let delegate = ProbeDelegate()
    let controller = makeController(style: .modal, delegate: delegate)
    var onDismissCount = 0
    controller.onDismiss = { onDismissCount += 1 }

    controller.viewDidDisappear(false)

    #expect(delegate.didDismissCount == 0)
    #expect(onDismissCount == 0)
  }

  // MARK: - Chrome

  /// The Customer Center used to hide a host's navigation bar in `.pushed` and hand it back on
  /// the way out. It no longer touches the bar in any style — the host's chrome is theirs.
  @available(iOS 15.0, *)
  @Test("neither style modifies the host's navigation bar", arguments: [
    CustomerCenterPresentationStyle.pushed, .modal
  ])
  func neitherStyleTouchesTheHostBar(style: CustomerCenterPresentationStyle) {
    let controller = makeController(style: style, delegate: nil)
    let navigation = UINavigationController(rootViewController: UIViewController())
    navigation.setNavigationBarHidden(false, animated: false)
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    let recognizer = navigation.interactivePopGestureRecognizer
    let hostDelegate = recognizer?.delegate
    let hostEnabled = recognizer?.isEnabled

    navigation.pushViewController(controller, animated: false)
    spinRunLoop(timeout: 1) { controller.viewIfLoaded?.window != nil }

    #expect(!navigation.isNavigationBarHidden, "the host's bar stays visible")
    #expect(recognizer?.delegate === hostDelegate, "the pop gesture is left alone")
    #expect(recognizer?.isEnabled == hostEnabled)

    window.isHidden = true
  }



  // MARK: - Analytics

  @available(iOS 15.0, *)
  @Test("presentation style is reported on Customer Center events")
  func reportsPresentationMode() {
    #expect(makeController(style: .modal, delegate: nil).viewModel.presentationMode == "sheet")
    #expect(makeController(style: .pushed, delegate: nil).viewModel.presentationMode == "pushed")
  }
}
