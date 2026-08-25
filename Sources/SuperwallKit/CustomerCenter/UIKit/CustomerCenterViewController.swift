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

  /// Pushed onto a `UINavigationController` you own. Shows a back button that pops it off your
  /// stack, and hides your navigation bar for as long as it is on screen so that only one
  /// navigation bar is ever visible.
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

  /// The host navigation bar's visibility before ``CustomerCenterPresentationStyle/pushed`` hid
  /// it, so it can be handed back exactly as it was found.
  private var hostNavigationBarWasHidden: Bool?
  private var replacedInteractivePopDelegate: UIGestureRecognizerDelegate?
  private lazy var interactivePopDelegate = InteractivePopGestureDelegate()

  /// Whether this controller was on screen as part of a modal presentation, recorded while it
  /// still is. Compared against `presentingViewController` on the way out — see
  /// ``isLeavingHierarchy``.
  ///
  /// Internal rather than private only so tests can set it: a hostless test target never drives a
  /// modal transition to completion, so UIKit never populates `presentingViewController` there and
  /// this can't be reached through a real presentation.
  var wasPresentedModally = false

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

    // Both styles keep the Customer Center's own navigation stack, hence
    // `usesExistingNavigation: false` even when pushed. Its drill-downs — purchase history and
    // per-purchase detail — are SwiftUI `NavigationLink`s, and a `NavigationLink` does nothing
    // without a SwiftUI navigation ancestor; a surrounding `UINavigationController` is not one.
    // `.pushed` hides the host's bar instead (see `viewWillAppear`), so the user still only ever
    // sees a single navigation bar.
    var options = CustomerCenterNavigationOptions(
      usesExistingNavigation: false,
      showsCloseButton: presentationStyle == .modal,
      showsBackButton: presentationStyle == .pushed
    )
    super.init(rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: options))

    // The button actions need `self`, which isn't available until `super.init` has run. Assigning
    // `rootView` again here is free: `CustomerCenterView` is a struct, and SwiftUI hasn't rendered
    // it or installed its `@StateObject` yet.
    options.onClose = { [weak self] in self?.dismiss(animated: true) }
    options.onBack = { [weak self] in self?.navigationController?.popViewController(animated: true) }
    rootView = CustomerCenterView(viewModel: viewModel, navigationOptions: options)

    if presentationStyle == .modal {
      modalPresentationStyle = .pageSheet
    }
  }

  @available(*, unavailable)
  required dynamic init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard presentationStyle == .pushed, let navigationController else { return }
    if hostNavigationBarWasHidden == nil {
      hostNavigationBarWasHidden = navigationController.isNavigationBarHidden
    }
    navigationController.setNavigationBarHidden(true, animated: animated)

    // Hiding the bar also takes UIKit's swipe-to-go-back with it, so drive the recognizer for as
    // long as we're on screen and hand it back untouched on the way out.
    replacedInteractivePopDelegate = navigationController.interactivePopGestureRecognizer?.delegate
    interactivePopDelegate.navigationController = navigationController
    navigationController.interactivePopGestureRecognizer?.delegate = interactivePopDelegate
    navigationController.interactivePopGestureRecognizer?.isEnabled = true
  }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    wasPresentedModally = presentingViewController != nil
  }

  override public func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    guard presentationStyle == .pushed, let navigationController else { return }
    // Also runs when the host merely covers us — pushing its own screen on top, or presenting
    // something. Restoring the bar is right in that case too: the screen taking over wants its
    // own chrome, and `viewWillAppear` hides it again if we come back.
    if let hostNavigationBarWasHidden {
      navigationController.setNavigationBarHidden(hostNavigationBarWasHidden, animated: animated)
    }
    hostNavigationBarWasHidden = nil
    navigationController.interactivePopGestureRecognizer?.delegate = replacedInteractivePopDelegate
    replacedInteractivePopDelegate = nil
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isLeavingHierarchy else { return }
    // A view controller on its way out knows definitively that the Customer Center is gone, so
    // fire the view model's dismissal now rather than waiting out its visibility debounce —
    // `onDismiss` releases the manager's retained delegate, and a debounced dismissal would
    // land after that release and reach a nil delegate. `dismiss()` is idempotent, so the
    // debounce firing later (or having fired) is harmless.
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

/// Keeps swipe-to-go-back working while ``CustomerCenterPresentationStyle/pushed`` has the host's
/// navigation bar hidden. Deliberately not a conformance on `CustomerCenterViewController` itself,
/// which would put `gestureRecognizerShouldBegin(_:)` on the SDK's public surface.
@available(iOS 15.0, *)
private final class InteractivePopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
  weak var navigationController: UINavigationController?

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    // Swiping on the stack's root would leave UIKit mid-transition with nothing to pop.
    guard let navigationController else { return false }
    return navigationController.viewControllers.count > 1
  }
}
