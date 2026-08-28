//
//  CustomerCenterViewController.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI
import UIKit

/// How a ``CustomerCenterViewController`` is put on screen.
@objc(SWKCustomerCenterPresentationStyle)
public enum CustomerCenterPresentationStyle: Int {
  /// Presented modally, with `present(_:animated:)`. Shows a close button that dismisses it.
  case modal

  /// Pushed onto a `UINavigationController` you own. Renders into your navigation bar and leaves
  /// it entirely alone — your title, your back button, your appearance. Its own drill-downs are
  /// pushed onto your stack as further view controllers.
  case pushed
}

extension CustomerCenterPresentationStyle {
  /// The `presentation` parameter reported on Customer Center events.
  var analyticsValue: String {
    switch self {
    case .modal: return "sheet"
    case .pushed: return "pushed"
    }
  }
}

/// A UIKit container for ``CustomerCenterView``.
///
/// Present it modally, or push it onto a navigation controller of your own with
/// ``CustomerCenterPresentationStyle/pushed``.
@available(iOS 15.0, *)
@objc(SWKCustomerCenterViewController)
public final class CustomerCenterViewController: UIHostingController<CustomerCenterView> {
  let viewModel: CustomerCenterViewModel
  let presentationStyle: CustomerCenterPresentationStyle
  var onDismiss: (() -> Void)?

  /// Retains the navigator that pushes this controller's own drill-downs, in `.pushed` style.
  private var pushNavigator: CustomerCenterPushNavigator?

  /// Whether this controller was on screen as part of a modal presentation, recorded while it
  /// still is. Compared against `presentingViewController` on the way out — see
  /// ``isLeavingHierarchy``.
  ///
  /// Internal rather than private only so tests can set it: a hostless test target never drives a
  /// modal transition to completion, so UIKit never populates `presentingViewController` there and
  /// this can't be reached through a real presentation.
  var wasPresentedModally = false

  /// Latches ``deliverDismissal()``; see its note on the overlapping call sites.
  private var hasDeliveredDismissal = false

  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``; `nil` uses the options value.
  ///   - presentationStyle: Whether you present this controller modally or push it onto a
  ///     navigation controller of your own. Defaults to ``CustomerCenterPresentationStyle/modal``.
  ///   - delegate: Receives Customer Center events. The view controller does not retain its
  ///     delegate. Keep a strong reference to it for the duration of the presentation — or present
  ///     via `Superwall.shared.presentCustomerCenter(delegate:)`, which retains the delegate while
  ///     the Customer Center is presented.
  public convenience init(
    configuration: CustomerCenterConfiguration? = nil,
    presentationStyle: CustomerCenterPresentationStyle = .modal,
    delegate: CustomerCenterDelegate? = nil
  ) {
    self.init(
      viewModel: CustomerCenterManager.makeViewModel(configuration: configuration),
      adapter: CustomerCenterDelegateAdapter(swiftDelegate: delegate, objcDelegate: nil),
      presentationStyle: presentationStyle
    )
  }

  /// Objective-C initializer.
  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``; `nil` uses the options value.
  ///   - presentationStyle: Whether you present this controller modally or push it onto a
  ///     navigation controller of your own.
  ///   - objcDelegate: Receives Customer Center events. The view controller does not retain its
  ///     delegate. Keep a strong reference to it for the duration of the presentation — or present
  ///     via `Superwall.shared.presentCustomerCenter(delegate:)`, which retains the delegate while
  ///     the Customer Center is presented.
  @available(swift, obsoleted: 1.0)
  @objc(initWithConfiguration:presentationStyle:delegate:)
  public convenience init(
    configuration: CustomerCenterConfiguration?,
    presentationStyle: CustomerCenterPresentationStyle,
    objcDelegate: CustomerCenterDelegateObjc?
  ) {
    self.init(
      viewModel: CustomerCenterManager.makeViewModel(configuration: configuration),
      adapter: CustomerCenterDelegateAdapter(swiftDelegate: nil, objcDelegate: objcDelegate),
      presentationStyle: presentationStyle
    )
  }

  init(
    viewModel: CustomerCenterViewModel,
    adapter: CustomerCenterDelegateAdapter,
    presentationStyle: CustomerCenterPresentationStyle
  ) {
    self.viewModel = viewModel
    self.presentationStyle = presentationStyle
    viewModel.callbacks = adapter.makeCallbacks()
    viewModel.presentationMode = presentationStyle.analyticsValue

    // Presented modally we supply the navigation; pushed, the host already has it and we add
    // nothing — no wrapping `NavigationView`, no close button, and nothing done to their bar.
    // The drill-downs that `NavigationLink` can't serve in that case are pushed through
    // `CustomerCenterNavigating` instead.
    var options = CustomerCenterNavigationOptions(
      usesExistingNavigation: presentationStyle == .pushed,
      showsCloseButton: presentationStyle == .modal
    )
    super.init(rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: options))

    // The button actions need `self`, which isn't available until `super.init` has run. Assigning
    // `rootView` again here is free: `CustomerCenterView` is a struct, and SwiftUI hasn't rendered
    // it or installed its `@StateObject` yet.
    options.onClose = { [weak self] in self?.dismiss(animated: true) }

    // Pushed, the host owns the navigation, so `NavigationLink` has no SwiftUI ancestor to work
    // with and the drill-downs go through the navigator instead.
    var navigator: CustomerCenterPushNavigator?
    if presentationStyle == .pushed {
      navigator = CustomerCenterPushNavigator(viewModel: viewModel)
      navigator?.presenter = self
      pushNavigator = navigator
    }
    rootView = CustomerCenterView(
      viewModel: viewModel,
      navigationOptions: options,
      navigator: navigator
    )

    if presentationStyle == .modal {
      modalPresentationStyle = .pageSheet
    }
  }

  @available(*, unavailable)
  required dynamic init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    wasPresentedModally = presentingViewController != nil
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isLeavingHierarchy else {
      // Merely covered — a host push on top, a tab switch. `super` has just forwarded the
      // disappearance into SwiftUI, whose `onDisappear` dropped the visible-surface count to zero
      // and armed the dismissal debounce. That debounce is a heuristic for the embedded SwiftUI
      // case, which has no way to tell a cover from a teardown; here we know, so veto it. Left to
      // fire it would deliver `customerCenterDidDismiss()` and track `customerCenterClose` while
      // the screen sits on the back stack, and latch, silencing the genuine teardown later.
      viewModel.cancelPendingDismissal()
      return
    }
    deliverDismissal()
  }

  override public func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    // Being removed from a container. This is not redundant with `viewDidDisappear`: a controller
    // that was already covered — the host pushed its own screen on top — has disappeared once
    // already, so popping it off the stack produces no second disappearance and the teardown would
    // otherwise never be delivered at all.
    if parent == nil {
      deliverDismissal()
    }
  }

  /// A view controller on its way out knows definitively that the Customer Center is gone, so fire
  /// the view model's dismissal now rather than waiting out its visibility debounce — `onDismiss`
  /// releases the manager's retained delegate, and a debounced dismissal would land after that
  /// release and reach a nil delegate.
  ///
  /// Latched because the two call sites overlap: an ordinary pop is both a disappearance and a
  /// removal from the container. `viewModel.dismiss()` is idempotent on its own, but `onDismiss`
  /// is the manager's cleanup and must not run twice.
  private func deliverDismissal() {
    guard !hasDeliveredDismissal else { return }
    hasDeliveredDismissal = true
    viewModel.dismiss()
    onDismiss?()
  }

  /// Whether this disappearance is the Customer Center actually going away, rather than it being
  /// covered by something the host put on top.
  ///
  /// UIKit sets `isBeingDismissed`/`isMovingFromParent` only on the controller it is directly
  /// removing, so a Customer Center inside a container the host tears down — a navigation
  /// controller that gets presented and later dismissed, say — has to look up the chain too.
  ///
  /// Testing `presentingViewController == nil` on its own would be wrong: it is `nil` for the
  /// entire lifetime of a controller pushed onto a stack that isn't itself presented, so every
  /// cover event would read as a teardown, fire `customerCenterDidDismiss()` while the screen sat
  /// on the back stack, and — because `dismiss()` latches — leave the real teardown silent.
  /// Paired with ``wasPresentedModally`` it becomes a sound signal again, and it backstops the
  /// modal path in case a dismissal ever completes with `isBeingDismissed` already cleared.
  private var isLeavingHierarchy: Bool {
    var controller: UIViewController? = self
    while let current = controller {
      if current.isBeingDismissed || current.isMovingFromParent {
        return true
      }
      controller = current.parent
    }
    return wasPresentedModally && presentingViewController == nil
  }
}
