//
//  CustomerCenterSheetOwnershipTests.swift
//
//
//  Created by Jordan Morgan on 28/08/2026.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import SuperwallKit

/// When the host owns the navigation, the Customer Center's screens are separate hosting
/// controllers and every one of them applies the sheet modifiers. Only the screen the user is
/// actually looking at may present, or two controllers race for the same sheet.
///
/// These drive `CustomerCenterPushNavigator` and the controllers it pushes rather than restating
/// their arithmetic — an earlier version of this file re-implemented the rules locally and passed
/// while the real gate presented nothing at all.
@Suite("Customer Center sheet ownership", .serialized)
@MainActor
struct CustomerCenterSheetOwnershipTests {
  private final class ProbeDelegate: CustomerCenterDelegate {
    var didDismissCount = 0
    func customerCenterDidDismiss() { didDismissCount += 1 }
  }

  @available(iOS 15.0, *)
  private func makeViewModel(
    delegate: CustomerCenterDelegate? = nil,
    dismissDebounceInterval: TimeInterval = 0.6
  ) -> CustomerCenterViewModel {
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    )
    let viewModel = CustomerCenterViewModel(
      configuration: .default,
      dependencies: deps,
      strings: .english,
      dismissDebounceInterval: dismissDebounceInterval
    )
    if let delegate {
      viewModel.callbacks = CustomerCenterDelegateAdapter(
        swiftDelegate: delegate,
        objcDelegate: nil
      ).makeCallbacks()
    }
    return viewModel
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

  /// The rule the sheet modifier applies, exercised directly.
  @Test("the root owns sheets until something is pushed over it")
  func ownershipFollowsDepth() {
    #expect(CustomerCenterSheetOwnership.isTopmost(surfaceDepth: 0, pushDepth: 0))
    #expect(!CustomerCenterSheetOwnership.isTopmost(surfaceDepth: 0, pushDepth: 1))
    #expect(CustomerCenterSheetOwnership.isTopmost(surfaceDepth: 1, pushDepth: 1))
    // A surface deeper than the current depth is stale and must not present either.
    #expect(!CustomerCenterSheetOwnership.isTopmost(surfaceDepth: 2, pushDepth: 1))
  }

  // MARK: - Driving the real navigator

  @available(iOS 15.0, *)
  @Test("pushing a drill-down takes ownership, popping it hands ownership back")
  func pushAndPopMoveOwnership() {
    let viewModel = makeViewModel()
    let host = UIViewController()
    let navigation = UINavigationController(rootViewController: host)
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    spinRunLoop(timeout: 1) { host.viewIfLoaded?.window != nil }

    let navigator = CustomerCenterPushNavigator(viewModel: viewModel)
    navigator.presenter = host

    navigator.push(Text("purchase history"))
    // Wait for the pushed screen to actually be on screen: UIKit only reports a removal for a
    // controller that appeared, so asserting on `viewControllers.count` alone would test a
    // controller that never lived.
    spinRunLoop(timeout: 2) { navigation.viewControllers.last?.viewIfLoaded?.window != nil }
    #expect(viewModel.pushDepth == 1)
    #expect(!CustomerCenterSheetOwnership.isTopmost(surfaceDepth: 0, pushDepth: viewModel.pushDepth))

    navigation.popViewController(animated: false)
    spinRunLoop(timeout: 1) { viewModel.pushDepth == 0 }
    #expect(viewModel.pushDepth == 0, "the root must be able to present again")

    window.isHidden = true
  }

  /// Two screens popped at once are both removed and UIKit doesn't promise which reports first.
  /// Driven through the real controllers rather than by restating the navigator's arithmetic.
  @available(iOS 15.0, *)
  @Test("popping two drill-downs at once does not strand ownership")
  func poppingTwoAtOnceDoesNotStrand() {
    let viewModel = makeViewModel()
    let host = UIViewController()
    let navigation = UINavigationController(rootViewController: host)
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    spinRunLoop(timeout: 1) { host.viewIfLoaded?.window != nil }

    let navigator = CustomerCenterPushNavigator(viewModel: viewModel)
    navigator.presenter = host

    navigator.push(Text("purchase history"))
    spinRunLoop(timeout: 2) { navigation.viewControllers.last?.viewIfLoaded?.window != nil }
    // The second push comes from the screen that was just pushed.
    navigator.presenter = navigation.viewControllers.last
    navigator.push(Text("purchase detail"))
    spinRunLoop(timeout: 2) { navigation.viewControllers.count == 3 }
    spinRunLoop(timeout: 2) { navigation.viewControllers.last?.viewIfLoaded?.window != nil }
    #expect(viewModel.pushDepth == 2)

    navigation.popToRootViewController(animated: false)
    spinRunLoop(timeout: 1) { viewModel.pushDepth == 0 }

    #expect(viewModel.pushDepth == 0)
    #expect(CustomerCenterSheetOwnership.isTopmost(surfaceDepth: 0, pushDepth: viewModel.pushDepth))

    window.isHidden = true
  }

  /// A pushed screen being covered is not a teardown, and the debounce must be vetoed there just
  /// as it is on the root controller — otherwise `didDismiss` latches and the real teardown is
  /// silent.
  @available(iOS 15.0, *)
  @Test("covering a drill-down does not deliver a dismissal")
  func coveringADrillDownDoesNotDismiss() async {
    let debounce: TimeInterval = 0.2
    let delegate = ProbeDelegate()
    let viewModel = makeViewModel(delegate: delegate, dismissDebounceInterval: debounce)
    let host = UIViewController()
    let navigation = UINavigationController(rootViewController: host)
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    spinRunLoop(timeout: 1) { host.viewIfLoaded?.window != nil }

    let navigator = CustomerCenterPushNavigator(viewModel: viewModel)
    navigator.presenter = host
    navigator.push(Text("purchase history"))
    spinRunLoop(timeout: 2) { navigation.viewControllers.last?.viewIfLoaded?.window != nil }

    // The drill-down reports the disappearance SwiftUI uses to arm the debounce…
    viewModel.surfaceDidDisappear()
    // …and the host covers it with its own screen rather than popping it.
    navigation.pushViewController(UIViewController(), animated: false)
    spinRunLoop(timeout: 1) { navigation.viewControllers.count == 3 }

    try? await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(delegate.didDismissCount == 0, "being covered is not being torn down")

    window.isHidden = true
  }
}
