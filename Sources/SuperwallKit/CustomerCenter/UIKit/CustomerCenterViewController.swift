//
//  CustomerCenterViewController.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// How the Customer Center is put on screen, for ``CustomerCenterViewController`` and
/// ``CustomerCenterView`` alike. Also reported on ``SuperwallEvent/customerCenterOpen(screen:presentation:)``.
@objc(SWKCustomerCenterPresentationStyle)
public enum CustomerCenterPresentationStyle: Int, Sendable {
  /// Presented as a sheet. The Customer Center brings its own navigation and a close button.
  case sheet

  /// Inside navigation you own: a ``CustomerCenterViewController`` pushed onto your
  /// `UINavigationController`, or a ``CustomerCenterView`` placed in your SwiftUI navigation.
  /// Renders into your navigation bar and leaves it entirely alone — your title, your back button,
  /// your appearance — and pushes its own screens onto your stack.
  case embedded

  var analyticsName: String {
    switch self {
    case .sheet: return "sheet"
    case .embedded: return "embedded"
    }
  }
}

#if os(macOS)
/// An AppKit container for ``CustomerCenterView``.
///
/// Present it as a sheet, or place it in a window or a view of your own with
/// ``CustomerCenterPresentationStyle/embedded``. AppKit has no navigation controller for the
/// Customer Center's own screens to be pushed onto, so it brings its own navigation in either
/// style. Embedded, it leaves out the close button.
@objc(SWKCustomerCenterViewController)
public final class CustomerCenterViewController: NSHostingController<CustomerCenterView> {
  let viewModel: CustomerCenterViewModel
  let presentationStyle: CustomerCenterPresentationStyle
  var onDismiss: (() -> Void)?

  /// Whether this controller was on screen as a presented sheet, recorded while it still is.
  var wasPresentedModally = false

  /// Latches ``deliverDismissal()``: a removal from a container is also a disappearance.
  private var hasDeliveredDismissal = false

  /// The size it opens at as a sheet, which takes its size from its content.
  static let sheetSize = CGSize(width: 520, height: 680)

  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``; `nil` uses the options value.
  ///   - presentationStyle: Whether you present this controller as a sheet or place it yourself.
  ///     Defaults to ``CustomerCenterPresentationStyle/sheet``.
  ///   - delegate: Receives Customer Center events. The view controller does not retain its
  ///     delegate. Keep a strong reference to it for the duration of the presentation — or present
  ///     via `Superwall.shared.presentCustomerCenter(delegate:)`, which retains the delegate while
  ///     the Customer Center is presented.
  public convenience init(
    configuration: CustomerCenterConfiguration? = nil,
    presentationStyle: CustomerCenterPresentationStyle = .sheet,
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
  ///   - presentationStyle: Whether you present this controller as a sheet or place it yourself.
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
    viewModel.presentationMode = presentationStyle

    var options = CustomerCenterNavigationOptions(
      style: .sheet,
      showsCloseButton: presentationStyle == .sheet
    )
    super.init(rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: options))

    // The close action needs `self`, which isn't available until `super.init` has run.
    options.onClose = { [weak self] in self?.close() }
    rootView = CustomerCenterView(viewModel: viewModel, navigationOptions: options)

    if presentationStyle == .sheet {
      preferredContentSize = Self.sheetSize
    }
  }

  @available(*, unavailable)
  required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override public func viewDidAppear() {
    super.viewDidAppear()
    wasPresentedModally = presentingViewController != nil
  }

  override public func viewDidDisappear() {
    super.viewDidDisappear()
    // AppKit is still in the middle of a dismissal here: it lets go of `presentingViewController`
    // only once this returns. So settle whether the Customer Center left or was only hidden on the
    // next turn of the run loop. That's still ahead of the view model's dismissal debounce, which
    // the disappearance has just armed.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      if self.isLeavingHierarchy {
        self.deliverDismissal()
      } else {
        self.viewModel.suppressDismissalUntilNextAppearance()
      }
    }
  }

  override public func removeFromParent() {
    super.removeFromParent()
    deliverDismissal()
  }

  private func close() {
    if let presenting = presentingViewController {
      presenting.dismiss(self)
    } else {
      view.window?.performClose(nil)
    }
  }

  /// See the iOS controller: fires the view model's dismissal straight away rather than after its
  /// visibility debounce, and runs `onDismiss` at most once.
  private func deliverDismissal() {
    guard !hasDeliveredDismissal else { return }
    hasDeliveredDismissal = true
    viewModel.dismiss()
    onDismiss?()
  }

  /// Whether the Customer Center has gone, rather than being hidden along with its window or
  /// covered within it.
  private var isLeavingHierarchy: Bool {
    if wasPresentedModally {
      return presentingViewController == nil
    }
    if let window = view.window {
      return window.isClosedRatherThanHidden
    }
    // Out of its window: removed, unless a container still holds it, as a tab view holds a tab
    // that isn't showing.
    return parent == nil
  }
}

extension NSWindow {
  /// Whether a window that's no longer visible was closed, rather than minimised or hidden with
  /// the app.
  var isClosedRatherThanHidden: Bool {
    return !isVisible
      && !isMiniaturized
      && NSApplication.sharedApplication?.isHidden != true
  }
}
#else
/// A UIKit container for ``CustomerCenterView``.
///
/// Present it modally, or push it onto a navigation controller of your own with
/// ``CustomerCenterPresentationStyle/embedded``.
@objc(SWKCustomerCenterViewController)
public final class CustomerCenterViewController: UIHostingController<CustomerCenterView> {
  let viewModel: CustomerCenterViewModel
  let presentationStyle: CustomerCenterPresentationStyle
  var onDismiss: (() -> Void)?

  /// Retains the navigator that pushes this controller's own drill-downs, in `.embedded` style.
  private var pushNavigator: CustomerCenterPushNavigator?

  /// Whether this controller was on screen as part of a modal presentation, recorded while it
  /// still is. Compared against `presentingViewController` on the way out — see
  /// ``isLeavingHierarchy``.
  ///
  /// Internal rather than private only so tests can set it: a hostless test target never drives a
  /// modal transition to completion, so `viewDidAppear` never runs there and this can't be set
  /// through a real presentation. UIKit does still set `presentingViewController` as soon as the
  /// presentation starts.
  var wasPresentedModally = false

  /// Latches ``deliverDismissal()``; see its note on the overlapping call sites.
  private var hasDeliveredDismissal = false

  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``; `nil` uses the options value.
  ///   - presentationStyle: Whether you present this controller modally or push it onto a
  ///     navigation controller of your own. Defaults to ``CustomerCenterPresentationStyle/sheet``.
  ///   - delegate: Receives Customer Center events. The view controller does not retain its
  ///     delegate. Keep a strong reference to it for the duration of the presentation — or present
  ///     via `Superwall.shared.presentCustomerCenter(delegate:)`, which retains the delegate while
  ///     the Customer Center is presented.
  public convenience init(
    configuration: CustomerCenterConfiguration? = nil,
    presentationStyle: CustomerCenterPresentationStyle = .sheet,
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
    viewModel.presentationMode = presentationStyle

    // Presented modally we supply the navigation; pushed, the host already has it and we add
    // nothing — no wrapping `NavigationView`, no close button, and nothing done to their bar.
    // The drill-downs that `NavigationLink` can't serve in that case are pushed through
    // `CustomerCenterNavigating` instead.
    var options = CustomerCenterNavigationOptions(style: presentationStyle)
    super.init(rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: options))

    // The button actions need `self`, which isn't available until `super.init` has run. Assigning
    // `rootView` again here is free: `CustomerCenterView` is a struct, and SwiftUI hasn't rendered
    // it or installed its `@StateObject` yet.
    options.onClose = { [weak self] in self?.dismiss(animated: true) }

    // Pushed, the host owns the navigation, so `NavigationLink` has no SwiftUI ancestor to work
    // with and the drill-downs go through the navigator instead.
    var navigator: CustomerCenterPushNavigator?
    if presentationStyle == .embedded {
      navigator = CustomerCenterPushNavigator(viewModel: viewModel)
      navigator?.presenter = self
      pushNavigator = navigator
    }
    rootView = CustomerCenterView(
      viewModel: viewModel,
      navigationOptions: options,
      navigator: navigator
    )

    if presentationStyle == .sheet {
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
      viewModel.suppressDismissalUntilNextAppearance()
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
    if isLeavingHierarchyOrAContainerIs {
      return true
    }
    return wasPresentedModally && presentingViewController == nil
  }
}

extension UIViewController {
  /// Whether this controller, or any container it sits inside, is on its way out.
  ///
  /// UIKit sets `isBeingDismissed`/`isMovingFromParent` only on the controller it is directly
  /// removing, so a screen inside a container the host tears down — a navigation controller that
  /// was presented and is later dismissed, say — reads as merely covered unless the chain is
  /// walked. Both the root Customer Center and its pushed drill-downs have to make that
  /// distinction, and getting it wrong in either place turns a real teardown into a veto.
  var isLeavingHierarchyOrAContainerIs: Bool {
    var controller: UIViewController? = self
    while let current = controller {
      if current.isBeingDismissed || current.isMovingFromParent {
        return true
      }
      controller = current.parent
    }
    return false
  }
}
#endif
