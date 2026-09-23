//
//  CustomerCenterSheetOwnershipTests.swift
//
//
//  Created by Jordan Morgan on 28/08/2026.
//

import Testing
import Combine
import Foundation
import SwiftUI
import UIKit
@testable import SuperwallKit

/// Every Customer Center screen still in the stack applies the sheet modifiers, whether the host's
/// `UINavigationController` pushed it or a `NavigationLink` did. Only the screen the user is
/// actually looking at may present, or two screens race for the same sheet.
///
/// These drive `CustomerCenterPushNavigator`, the real drill-down rows and the screens they push
/// rather than restating their arithmetic — an earlier version of this file re-implemented the
/// rules locally and passed while the real gate presented nothing at all.
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

  /// Waits by suspending rather than spinning the run loop. SwiftUI delivers some updates through
  /// the main queue, which a run loop spun inside a main-actor test never drains: a view taken down
  /// by a state change, or a `.task`, only happens once the test gives the main actor back.
  private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  // MARK: - Which screen is on top

  @Test("a pushed screen is on top until it's released")
  func claimsTrackTheScreenOnTop() {
    var surfaces = PushedSurfaces()
    let detail = UUID()
    let nested = UUID()
    #expect(surfaces.depth == 0)

    surfaces.claim(detail, depth: 1)
    surfaces.claim(nested, depth: 2)
    #expect(surfaces.depth == 2)

    surfaces.release(nested)
    #expect(surfaces.depth == 1)
    surfaces.release(detail)
    #expect(surfaces.depth == 0)
  }

  /// A screen comes back into view when the one above it is popped, and the popped screen's
  /// release can arrive after that.
  @Test("a screen coming back into view is on top again, whenever the popped one reports")
  func reappearingScreenIsOnTop() {
    var surfaces = PushedSurfaces()
    let detail = UUID()
    let nested = UUID()
    surfaces.claim(detail, depth: 1)
    surfaces.claim(nested, depth: 2)

    surfaces.claim(detail, depth: 1)
    #expect(surfaces.depth == 1)
    surfaces.release(nested)
    #expect(surfaces.depth == 1, "a late release can't take the depth below the screen on top")

    surfaces.claim(detail, depth: 1)
    #expect(surfaces.claims.count == 1, "claiming again changes nothing")
  }

  /// A split view's detail column replaces one screen with another at the same depth, and SwiftUI
  /// doesn't promise the new one appears after the old one goes.
  @Test("a screen replaced at its depth can't take the replacement's depth with it", arguments: [true, false])
  func replacementKeepsTheDepth(releaseArrivesLate: Bool) {
    var surfaces = PushedSurfaces()
    let first = UUID()
    let second = UUID()
    surfaces.claim(first, depth: 1)

    if releaseArrivesLate {
      surfaces.claim(second, depth: 1)
      surfaces.release(first)
    } else {
      surfaces.release(first)
      surfaces.claim(second, depth: 1)
    }

    #expect(surfaces.depth == 1)
    #expect(surfaces.claims.map(\.id) == [second])
  }

  @Test("screens popped together can report in either order", arguments: [true, false])
  func poppedTogetherInEitherOrder(deepestFirst: Bool) {
    var surfaces = PushedSurfaces()
    let detail = UUID()
    let nested = UUID()
    surfaces.claim(detail, depth: 1)
    surfaces.claim(nested, depth: 2)

    for id in deepestFirst ? [nested, detail] : [detail, nested] {
      surfaces.release(id)
    }

    #expect(surfaces.depth == 0)
  }

  // MARK: - Which screen presents a sheet

  @available(iOS 15.0, *)
  @Test("a sheet is presented by the screen on top when it's requested")
  func sheetGoesToTheScreenOnTop() {
    let viewModel = makeViewModel()
    viewModel.sheet = .survey(pathId: "cancel")
    #expect(viewModel.sheetOwnerDepth == 0)

    viewModel.sheet = nil
    #expect(viewModel.sheetOwnerDepth == nil)

    viewModel.claimPushedSurface(UUID(), depth: 1)
    viewModel.sheet = .survey(pathId: "cancel")
    #expect(viewModel.sheetOwnerDepth == 1)
  }

  /// The race: a refund is requested on the detail and the user goes back while the request awaits
  /// its transaction. The request lands mid-pop, so the outgoing detail presents it. When the pop
  /// finished, a sheet that followed the depth was presented again by the root: a second refund
  /// request for one tap.
  @available(iOS 15.0, *)
  @Test("a sheet whose screen is popped isn't presented again by the root")
  func poppedScreensSheetStaysWithIt() {
    let viewModel = makeViewModel()
    let root = CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: 0)
    let detail = CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: 1)
    let detailClaim = UUID()
    viewModel.claimPushedSurface(detailClaim, depth: 1)

    viewModel.sheet = .refund(transactionId: 7, productId: "monthly_pro")
    viewModel.renderedStoreKitSheetParameters = StoreKitSheetParameters(refundTransactionId: 7)
    #expect(detail.refundBinding.wrappedValue)
    #expect(!root.refundBinding.wrappedValue)

    viewModel.releasePushedSurface(detailClaim)
    #expect(viewModel.pushDepth == 0)
    #expect(!root.refundBinding.wrappedValue, "the root presented a refund the detail had already asked for")

    // Nor does the next screen pushed at the same depth pick it up.
    viewModel.claimPushedSurface(UUID(), depth: 1)
    #expect(!detail.refundBinding.wrappedValue)

    // A fresh request goes to whichever screen is on top by then.
    viewModel.sheet = .refund(transactionId: 7, productId: "monthly_pro")
    #expect(detail.refundBinding.wrappedValue)
  }

  @available(iOS 15.0, *)
  @Test("a sheet stays with its screen until that screen leaves")
  func sheetOutlivesUnrelatedDepartures() {
    let viewModel = makeViewModel()
    let detail = UUID()
    let nested = UUID()
    viewModel.claimPushedSurface(detail, depth: 1)
    viewModel.sheet = .survey(pathId: "cancel")

    // Something deeper comes and goes: the detail's sheet is untouched.
    viewModel.claimPushedSurface(nested, depth: 2)
    viewModel.releasePushedSurface(nested)
    #expect(viewModel.sheetOwnerDepth == 1)

    viewModel.releasePushedSurface(detail)
    #expect(viewModel.sheetOwnerDepth == nil)
  }

  /// The asymmetry that made this rule necessary: SwiftUI writes `false` to a boolean sheet
  /// binding whenever its getter goes false, which happens to every surface the moment something
  /// is pushed over it — not only when that surface's own sheet is dismissed. An unconditional
  /// clear therefore let a covered screen tear down the sheet the visible one had just opened,
  /// and run `sheetDidDismiss()` against it.
  @Test("only the sheet that is actually up may clear itself", arguments: [
    (CustomerCenterSheet.manageSubscriptions(groupId: nil), true, false),
    (CustomerCenterSheet.refund(transactionId: 1, productId: "monthly_pro"), false, true),
    (CustomerCenterSheet.survey(pathId: "cancel"), false, false),
    (CustomerCenterSheet.webManageUnavailable, false, false)
  ])
  func dismissalOnlyClearsItsOwnSheet(
    current: CustomerCenterSheet,
    clearsManage: Bool,
    clearsRefund: Bool
  ) {
    #expect(CustomerCenterSheetOwnership.dismissalClears(current, .manageSubscriptions) == clearsManage)
    #expect(CustomerCenterSheetOwnership.dismissalClears(current, .refund) == clearsRefund)
  }

  @Test("a dismissal with no sheet up clears nothing")
  func dismissalWithNothingPresentedClearsNothing() {
    #expect(!CustomerCenterSheetOwnership.dismissalClears(nil, .manageSubscriptions))
    #expect(!CustomerCenterSheetOwnership.dismissalClears(nil, .refund))
  }

  /// The two above prove the rule; this proves the binding applies it. Testing only the rule
  /// would pass just as happily against the unguarded setter that made it necessary.
  @available(iOS 15.0, *)
  @Test("a stale dismissal write does not tear down another surface's sheet")
  func staleDismissalLeavesTheOpenSheetAlone() async {
    let viewModel = makeViewModel()
    let modifier = CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: 0)

    // A drill-down opens the refund sheet. The root's manage binding is still alive underneath.
    viewModel.sheet = .refund(transactionId: 1, productId: "monthly_pro")
    #expect(!modifier.isManagePresented.wrappedValue, "the manage sheet is not the one showing")

    // SwiftUI writes `false` into it, as it does to every binding whose getter goes false.
    modifier.isManagePresented.wrappedValue = false

    #expect(
      viewModel.sheet == .refund(transactionId: 1, productId: "monthly_pro"),
      "the refund sheet must survive a dismissal meant for a sheet that was never up"
    )

    // And the binding that does own the sheet still clears it.
    modifier.refundBinding.wrappedValue = false
    #expect(viewModel.sheet == nil)

    // The screen that opened a sheet keeps that right after it stops owning it: popped with the
    // sheet still up, say. That's why the setters are gated on identity rather than ownership —
    // an earlier depth-gated setter is exactly what stranded a sheet here.
    let detail = CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: 1)
    let detailClaim = UUID()
    viewModel.claimPushedSurface(detailClaim, depth: 1)
    viewModel.sheet = .manageSubscriptions(groupId: nil)
    viewModel.releasePushedSurface(detailClaim)
    detail.isManagePresented.wrappedValue = false
    #expect(viewModel.sheet == nil, "the screen that opened a sheet must always be able to clear it")
  }

  /// StoreKit writes `false` into its sheets' `isPresented` bindings from the background thread
  /// their presentation finishes on. The view model is main-actor state SwiftUI observes, so the
  /// write has to reach it on the main thread — and still clear the sheet when it gets there.
  @available(iOS 15.0, *)
  @Test("a dismissal StoreKit writes off the main thread updates the view model on it", arguments: [
    CustomerCenterSheetOwnership.SheetKind.manageSubscriptions,
    .refund
  ])
  func backgroundDismissalWriteLandsOnMainThread(kind: CustomerCenterSheetOwnership.SheetKind) async {
    let viewModel = makeViewModel()
    let modifier = CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: 0)
    let binding: Binding<Bool>
    switch kind {
    case .manageSubscriptions:
      viewModel.sheet = .manageSubscriptions(groupId: "group_pro")
      binding = modifier.isManagePresented
    case .refund:
      viewModel.sheet = .refund(transactionId: 1, productId: "monthly_pro")
      binding = modifier.refundBinding
    }

    await confirmation("the view model published from a background thread", expectedCount: 0) { offMainPublish in
      let observation = viewModel.objectWillChange.sink { _ in
        if !Thread.isMainThread { offMainPublish() }
      }
      defer { observation.cancel() }

      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.global(qos: .userInitiated).async {
          binding.wrappedValue = false
          continuation.resume()
        }
      }
      spinRunLoop(timeout: 1) { viewModel.sheet == nil }
    }

    #expect(viewModel.sheet == nil, "the closed sheet must still be cleared")
  }

  /// StoreKit's sheets read their parameter from the render before the one that presents them.
  /// Both parameters come from `sheet`, so presenting in the render they change in hands StoreKit
  /// the previous value: transaction 0, a refund request that can only fail, or no subscription
  /// group, a manage sheet with no subscriptions on it.
  @available(iOS 15.0, *)
  @Test("a StoreKit sheet waits until its parameter has been rendered", arguments: [
    CustomerCenterSheetOwnership.SheetKind.refund,
    .manageSubscriptions
  ])
  func storeKitSheetWaitsForItsParameter(kind: CustomerCenterSheetOwnership.SheetKind) {
    let viewModel = makeViewModel()
    let modifier = CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: 0)
    let binding: Binding<Bool>
    var rendered = StoreKitSheetParameters()
    switch kind {
    case .refund:
      viewModel.sheet = .refund(transactionId: 7, productId: "monthly_pro")
      binding = modifier.refundBinding
      rendered.refundTransactionId = 7
    case .manageSubscriptions:
      viewModel.sheet = .manageSubscriptions(groupId: "21601298")
      binding = modifier.isManagePresented
      rendered.manageGroupId = "21601298"
    }
    #expect(!binding.wrappedValue, "presenting now would hand StoreKit the previous parameter")

    viewModel.renderedStoreKitSheetParameters = rendered
    #expect(binding.wrappedValue)
  }

  /// With no group to hand over there's nothing to wait for: StoreKit already has the empty group.
  @available(iOS 15.0, *)
  @Test("a manage sheet without a subscription group presents at once")
  func manageSheetWithoutAGroupPresentsAtOnce() {
    let viewModel = makeViewModel()
    let modifier = CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: 0)

    viewModel.sheet = .manageSubscriptions(groupId: nil)

    #expect(modifier.isManagePresented.wrappedValue)
  }

  /// The tests above prove the gate; this proves the real modifier opens it, by recording what it
  /// has rendered into StoreKit's sheets.
  @available(iOS 15.0, *)
  @Test("the sheet modifier records what it has rendered into StoreKit's sheets")
  func sheetModifierRecordsTheRenderedParameters() {
    let viewModel = makeViewModel()
    // Another surface is on top, so this one never presents: the record is under test here, not
    // StoreKit's sheets.
    viewModel.claimPushedSurface(UUID(), depth: 1)
    let host = UIHostingController(rootView: Color.clear.customerCenterSheets(viewModel: viewModel))
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    spinRunLoop(timeout: 1) { host.viewIfLoaded?.window != nil }

    viewModel.sheet = .refund(transactionId: 7, productId: "monthly_pro")
    spinRunLoop(timeout: 2) { viewModel.renderedStoreKitSheetParameters.refundTransactionId == 7 }
    #expect(viewModel.renderedStoreKitSheetParameters == StoreKitSheetParameters(refundTransactionId: 7))

    viewModel.sheet = .manageSubscriptions(groupId: "21601298")
    spinRunLoop(timeout: 2) { viewModel.renderedStoreKitSheetParameters.manageGroupId == "21601298" }
    #expect(viewModel.renderedStoreKitSheetParameters == StoreKitSheetParameters(manageGroupId: "21601298"))
  }

  // MARK: - Covered or removed

  @available(iOS 15.0, *)
  private func makeProbe(log: ProbeLog) -> CustomerCenterLifecycleProbeController {
    let probe = CustomerCenterLifecycleProbeController()
    probe.onCovered = { log.events.append("covered") }
    probe.onRemoved = { log.events.append("removed") }
    probe.onDismantled = { log.events.append("dismantled") }
    return probe
  }

  /// A screen with the probe inside it, the way SwiftUI places one.
  private func makeScreen(containing probe: UIViewController) -> UIViewController {
    let screen = UIViewController()
    screen.addChild(probe)
    screen.view.addSubview(probe.view)
    probe.didMove(toParent: screen)
    return screen
  }

  @available(iOS 15.0, *)
  @Test("a screen the host pushes over is covered")
  func pushOverIsACover() {
    let log = ProbeLog()
    let screen = makeScreen(containing: makeProbe(log: log))
    let navigation = UINavigationController(rootViewController: screen)
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    spinRunLoop(timeout: 1) { screen.viewIfLoaded?.window != nil }

    navigation.pushViewController(UIViewController(), animated: false)
    spinRunLoop(timeout: 1) { !log.events.isEmpty }

    #expect(log.events == ["covered"])
  }

  /// A full-screen presentation takes the screen out of the window before it's told it
  /// disappeared, so the window can't be read off the screen at that point.
  @available(iOS 15.0, *)
  @Test("the window's root is covered when something is presented over it")
  func coveredWindowRootIsACover() {
    let log = ProbeLog()
    let probe = makeProbe(log: log)
    let screen = makeScreen(containing: probe)
    let window = makeWindow(rootViewController: screen)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    spinRunLoop(timeout: 1) { probe.viewIfLoaded?.window != nil }

    screen.view.removeFromSuperview()
    probe.viewDidDisappear(false)

    #expect(log.events == ["covered"])
  }

  @available(iOS 15.0, *)
  @Test("a screen popped off a navigation controller is removed")
  func popIsARemoval() {
    let log = ProbeLog()
    let screen = makeScreen(containing: makeProbe(log: log))
    let navigation = UINavigationController(rootViewController: UIViewController())
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    navigation.pushViewController(screen, animated: false)
    spinRunLoop(timeout: 1) { screen.viewIfLoaded?.window != nil }

    navigation.popViewController(animated: false)
    spinRunLoop(timeout: 1) { !log.events.isEmpty }

    #expect(log.events == ["removed"])
  }

  /// SwiftUI's `NavigationStack` detaches a popped screen from its navigation controller before the
  /// screen is told it disappeared, and marks nothing on the way.
  @available(iOS 15.0, *)
  @Test("a screen detached before it's told it disappeared is removed")
  func detachedScreenIsARemoval() {
    let log = ProbeLog()
    let probe = makeProbe(log: log)
    let screen = makeScreen(containing: probe)
    let container = UIViewController()
    container.addChild(screen)
    container.view.addSubview(screen.view)
    screen.didMove(toParent: container)
    let window = makeWindow(rootViewController: container)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    spinRunLoop(timeout: 1) { probe.viewIfLoaded?.window != nil }

    // Detached while its view is still up, the order `NavigationStack` does it in. Removing the
    // view as well would have UIKit report the disappearance itself, from wherever the screen
    // happened to be attached at that moment.
    screen.willMove(toParent: nil)
    screen.removeFromParent()
    probe.viewDidDisappear(false)

    #expect(log.events == ["removed"])
  }

  @available(iOS 15.0, *)
  @Test("a screen inside a container being dismissed is removed")
  func dismissedContainerIsARemoval() {
    let log = ProbeLog()
    let probe = makeProbe(log: log)
    let navigation = DismissingNavigationController(rootViewController: makeScreen(containing: probe))
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    spinRunLoop(timeout: 1) { probe.viewIfLoaded?.window != nil }

    probe.viewDidDisappear(false)

    #expect(log.events == ["removed"])
  }

  @available(iOS 15.0, *)
  @Test("SwiftUI taking a screen down is reported")
  func dismantleIsReported() async {
    let log = ProbeLog()
    let visibility = ProbeVisibility()
    let host = UIHostingController(rootView: ProbeHost(visibility: visibility, log: log))
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    await waitUntil {
      host.view.layoutIfNeeded()
      return !host.children.isEmpty
    }
    #expect(log.events.isEmpty)

    visibility.isShown = false
    await waitUntil {
      host.view.layoutIfNeeded()
      return log.events.contains("dismantled")
    }

    #expect(log.events.contains("dismantled"))
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
    viewModel.sheet = .survey(pathId: "cancel")
    #expect(viewModel.sheetOwnerDepth == 1, "a sheet requested now belongs to the pushed screen")
    viewModel.sheet = nil

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
    viewModel.sheet = .survey(pathId: "cancel")
    #expect(viewModel.sheetOwnerDepth == 0, "the root must be able to present again")

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

  /// UIKit marks the controller it is directly removing, not the screens inside it. When a host
  /// presents a navigation controller holding a pushed Customer Center and dismisses it while the
  /// user is on a drill-down, nothing on the drill-down itself is set — so a check of `self` alone
  /// reads a real teardown as a cover, vetoes the debounce, and delivers no dismissal at all. The
  /// root underneath is covered, so it never gets a `viewDidDisappear` of its own to correct it.
  @available(iOS 15.0, *)
  @Test("dismissing a container the Customer Center sits inside is a teardown, not a cover")
  func dismissingTheContainingNavigationControllerDismisses() async {
    let debounce: TimeInterval = 0.2
    let delegate = ProbeDelegate()
    let viewModel = makeViewModel(delegate: delegate, dismissDebounceInterval: debounce)
    let host = UIViewController()
    let navigation = DismissingNavigationController(rootViewController: host)
    let window = makeWindow(rootViewController: navigation)
    window.makeKeyAndVisible()
    spinRunLoop(timeout: 1) { host.viewIfLoaded?.window != nil }

    let navigator = CustomerCenterPushNavigator(viewModel: viewModel)
    navigator.presenter = host
    navigator.push(Text("purchase history"))
    spinRunLoop(timeout: 2) { navigation.viewControllers.last?.viewIfLoaded?.window != nil }

    // The drill-down disappears because the container around it is being dismissed. SwiftUI has
    // armed the debounce; nothing must cancel it.
    viewModel.surfaceDidDisappear()
    navigation.viewControllers.last?.viewDidDisappear(false)

    try? await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(delegate.didDismissCount == 1, "a dismissed container is a dismissed Customer Center")

    window.isHidden = true
  }

  // MARK: - Driving the real NavigationLink

  // Sheets requested from a subscription's own screen, when SwiftUI's `NavigationLink` pushed it.
  // These host the real `CustomerCenterView` and open the detail screen through the real row,
  // because the bug they guard against lived in which screen carried the sheet modifiers, which no
  // test of the view model alone can see.
  //
  // This test host has no window scene, and without one UIKit leaves a covered screen in the
  // window. The root could therefore present here even though it can't on a device, which is why
  // these assert which screen owns the sheets as well as that the sheet appeared.
  //
  // iOS 16 and later only: before that, SwiftUI's `List` is a `UITableView`, which
  // `openFirstSubscription` doesn't drive, and there's no runtime that old to check a path that
  // did.

  private static let now = Date()

  @available(iOS 15.0, *)
  private func makeLoadedViewModel(dismissDebounceInterval: TimeInterval = 0.6) async -> CustomerCenterViewModel {
    let subscription = SubscriptionTransaction(
      transactionId: "t1",
      productId: "monthly_pro",
      purchaseDate: Self.now.addingTimeInterval(-30 * 86_400),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Self.now.addingTimeInterval(12 * 86_400),
      offerType: nil,
      subscriptionGroupId: "group_pro",
      store: .appStore
    )
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [subscription], nonSubscriptions: [], entitlements: [])
    )
    let viewModel = CustomerCenterViewModel(
      configuration: .default,
      dependencies: deps,
      strings: .english,
      dismissDebounceInterval: dismissDebounceInterval
    )
    await viewModel.load()
    return viewModel
  }

  private func firstSubview<T: UIView>(of type: T.Type, in view: UIView) -> T? {
    if let match = view as? T { return match }
    for subview in view.subviews {
      if let match = firstSubview(of: type, in: subview) { return match }
    }
    return nil
  }

  private func firstChild<T: UIViewController>(of type: T.Type, in controller: UIViewController) -> T? {
    if let match = controller as? T { return match }
    for child in controller.children {
      if let match = firstChild(of: type, in: child) { return match }
    }
    return nil
  }

  /// Opens the first subscription's screen the way a tap on its row does: through the list's own
  /// selection, which is what drives the row's `NavigationLink`.
  private func openFirstSubscription(in host: UIViewController) throws -> UINavigationController {
    var list: UICollectionView?
    spinRunLoop(timeout: 2) {
      list = firstSubview(of: UICollectionView.self, in: host.view)
      return (list?.numberOfSections ?? 0) > 0
    }
    let collectionView = try #require(list, "the management screen's list never loaded")
    let row = IndexPath(item: 0, section: 0)
    collectionView.selectItem(at: row, animated: false, scrollPosition: [])
    collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: row)

    var navigation: UINavigationController?
    spinRunLoop(timeout: 3) {
      navigation = firstChild(of: UINavigationController.self, in: host)
      guard let navigation, navigation.viewControllers.count == 2 else { return false }
      return navigation.topViewController?.viewIfLoaded?.window != nil
        && navigation.transitionCoordinator == nil
    }
    let pushed = try #require(navigation, "no navigation controller hosts the Customer Center")
    try #require(pushed.viewControllers.count == 2, "the subscription's screen never opened")
    return pushed
  }

  /// Asks for the cancellation survey from the subscription's screen and reports whether anything
  /// was presented over it.
  @available(iOS 15.0, *)
  private func requestSurvey(from viewModel: CustomerCenterViewModel, window: UIWindow) async throws -> Bool {
    let purchase = try #require(viewModel.purchases.first)
    let cancel = try #require(
      viewModel.paths(for: purchase, isScreenLevel: false).first { $0.path.id == "manage_subscription" }
    )
    await viewModel.select(cancel, purchase: purchase)
    #expect(viewModel.sheet == .survey(pathId: cancel.path.id))

    spinRunLoop(timeout: 2) { window.rootViewController?.presentedViewController != nil }
    return window.rootViewController?.presentedViewController != nil
  }

  @available(iOS 16.0, *)
  @Test("the survey presents over a subscription's screen when the Customer Center brings its own navigation")
  func surveyPresentsFromDetailInOwnNavigation() async throws {
    let viewModel = await makeLoadedViewModel()
    let host = UIHostingController(
      rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: .default)
    )
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    _ = try openFirstSubscription(in: host)
    #expect(viewModel.pushDepth == 1, "the subscription's screen must own the sheets while it's on top")
    let presented = try await requestSurvey(from: viewModel, window: window)

    #expect(presented, "the survey waited for the covered root screen instead of presenting over the detail")
    host.dismiss(animated: false, completion: nil)
  }

  @available(iOS 16.0, *)
  @Test("the survey presents over a subscription's screen pushed onto the host's navigation")
  func surveyPresentsFromDetailInHostNavigation() async throws {
    let viewModel = await makeLoadedViewModel()
    let host = UIHostingController(
      rootView: NavigationStack {
        CustomerCenterView(viewModel: viewModel, navigationOptions: .init(style: .embedded))
      }
    )
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    _ = try openFirstSubscription(in: host)
    #expect(viewModel.pushDepth == 1, "the subscription's screen must own the sheets while it's on top")
    let presented = try await requestSurvey(from: viewModel, window: window)

    #expect(presented, "the survey waited for the covered root screen instead of presenting over the detail")
    host.dismiss(animated: false, completion: nil)
  }

  @available(iOS 16.0, *)
  @Test("going back from a subscription's screen hands sheets back to the root")
  func poppingTheDetailRestoresRootOwnership() async throws {
    let viewModel = await makeLoadedViewModel()
    let host = UIHostingController(
      rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: .default)
    )
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    let navigation = try openFirstSubscription(in: host)
    #expect(viewModel.pushDepth == 1)

    navigation.popViewController(animated: false)
    await waitUntil { viewModel.pushDepth == 0 }
    #expect(viewModel.pushDepth == 0, "the root must be able to present again once the detail is gone")
  }

  /// Something the host did covers the subscription's screen: here, a push of its own over the
  /// whole Customer Center. The screen is still in its stack. Handing its claim back on
  /// `onDisappear` gave the sheets to the root, out of the window, and dismissed any sheet the
  /// screen had open.
  @available(iOS 16.0, *)
  @Test("covering a subscription's screen leaves it owning the sheets")
  func coveredDetailKeepsItsClaim() async throws {
    let debounce: TimeInterval = 0.2
    let viewModel = await makeLoadedViewModel(dismissDebounceInterval: debounce)
    var dismissals = 0
    viewModel.callbacks.didDismiss = { dismissals += 1 }
    let host = UIHostingController(
      rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: .default)
    )
    let hostNavigation = UINavigationController(rootViewController: host)
    let window = makeWindow(rootViewController: hostNavigation)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    _ = try openFirstSubscription(in: host)
    #expect(viewModel.pushDepth == 1)

    hostNavigation.pushViewController(UIViewController(), animated: false)
    try await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(viewModel.pushDepth == 1, "a covered screen is still on top of its stack")
    #expect(dismissals == 0, "a covered Customer Center hasn't been closed")

    hostNavigation.popViewController(animated: false)
    try await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(viewModel.pushDepth == 1)
    #expect(dismissals == 0)
  }

  /// `NavigationStack { CustomerCenterView(.embedded) }`, with a screen of the host's own pushed
  /// on top — the same as switching tabs away from it. Nothing told the visibility count this was
  /// a cover, so it delivered `customerCenterDidDismiss()` for a Customer Center still in the
  /// stack, and `dismiss()` latches, so the real close later went unreported.
  @available(iOS 16.0, *)
  @Test("an embedded Customer Center the host covers isn't dismissed")
  func coveredEmbeddedCustomerCenterIsNotDismissed() async throws {
    let debounce: TimeInterval = 0.2
    let viewModel = await makeLoadedViewModel(dismissDebounceInterval: debounce)
    var dismissals = 0
    viewModel.callbacks.didDismiss = { dismissals += 1 }
    let path = HostPath()
    let host = UIHostingController(rootView: EmbeddingHost(path: path, viewModel: viewModel))
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    path.screens = [.customerCenter]
    await waitUntil { viewModel.visibleSurfaceCount == 1 }
    try #require(viewModel.visibleSurfaceCount == 1, "the Customer Center never appeared")

    path.screens = [.customerCenter, .hostScreen]
    try await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(dismissals == 0, "a covered Customer Center hasn't been closed")

    path.screens = [.customerCenter]
    await waitUntil { viewModel.visibleSurfaceCount == 1 }
    try await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(dismissals == 0)
  }

  /// The cost of vetoing a cover: the Customer Center can then be removed from under it without
  /// appearing again, and nothing but its removal is left to report the close.
  @available(iOS 16.0, *)
  @Test("an embedded Customer Center removed from under a cover still reports its close")
  func removalFromUnderACoverIsADismissal() async throws {
    let debounce: TimeInterval = 0.2
    let viewModel = await makeLoadedViewModel(dismissDebounceInterval: debounce)
    var dismissals = 0
    viewModel.callbacks.didDismiss = { dismissals += 1 }
    let path = HostPath()
    let host = UIHostingController(rootView: EmbeddingHost(path: path, viewModel: viewModel))
    let window = makeWindow(rootViewController: host)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    path.screens = [.customerCenter]
    await waitUntil { viewModel.visibleSurfaceCount == 1 }
    try #require(viewModel.visibleSurfaceCount == 1, "the Customer Center never appeared")

    path.screens = [.customerCenter, .hostScreen]
    try await Task.sleep(nanoseconds: UInt64(debounce * 4 * 1_000_000_000))
    #expect(dismissals == 0, "covered by the host's own screen isn't closed")

    path.screens = []
    await waitUntil { dismissals > 0 }
    #expect(dismissals == 1)
  }
}

/// Stands in for a navigation controller the host has presented and is now dismissing.
/// `isBeingDismissed` is read-only, and a hostless test target never drives a modal transition to
/// completion, so the one fact UIKit would report is supplied directly.
private final class DismissingNavigationController: UINavigationController {
  override var isBeingDismissed: Bool { true }
}

private enum HostScreen: Hashable {
  case customerCenter
  case hostScreen
}

private final class HostPath: ObservableObject {
  @Published var screens: [HostScreen] = []
}

/// A host that places an embedded `CustomerCenterView` in its own `NavigationStack`, and can push
/// a screen of its own over it.
@available(iOS 16.0, *)
private struct EmbeddingHost: View {
  @ObservedObject var path: HostPath
  let viewModel: CustomerCenterViewModel

  var body: some View {
    NavigationStack(path: $path.screens) {
      Color.clear.navigationDestination(for: HostScreen.self) { screen in
        switch screen {
        case .customerCenter:
          CustomerCenterView(viewModel: viewModel, navigationOptions: .init(style: .embedded))
        case .hostScreen:
          Text("host screen")
        }
      }
    }
  }
}

/// What a lifecycle probe reported, in order.
private final class ProbeLog {
  var events: [String] = []
}

private final class ProbeVisibility: ObservableObject {
  @Published var isShown = true
}

/// A lifecycle probe SwiftUI can take down, by flipping `visibility`.
@available(iOS 15.0, *)
private struct ProbeHost: View {
  @ObservedObject var visibility: ProbeVisibility
  let log: ProbeLog

  var body: some View {
    if visibility.isShown {
      Color.clear.background(
        CustomerCenterLifecycleProbe(
          onCovered: { [log] in log.events.append("covered") },
          onRemoved: { [log] in log.events.append("removed") },
          onDismantled: { [log] in log.events.append("dismantled") }
        )
      )
    }
  }
}
