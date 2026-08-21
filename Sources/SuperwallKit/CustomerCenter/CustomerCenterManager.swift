//
//  CustomerCenterManager.swift
//
//
//  Created by Claude on 20/08/2026.
//

import UIKit

/// Builds the dependencies backing ``CustomerCenterView`` and owns the single Customer Center
/// presentation for ``Superwall/presentCustomerCenter(configuration:from:delegate:onDismiss:)``.
@available(iOS 15.0, *)
@MainActor
final class CustomerCenterManager {
  private unowned let container: DependencyContainer
  private weak var presentedController: CustomerCenterViewController?

  /// Strongly retains the delegate passed to `present`/`presentObjc` for the duration of the
  /// presentation. `CustomerCenterDelegateAdapter` only holds a `weak` reference to the delegate
  /// (so the view controller itself never retains it), so this is the retention the public API
  /// docs promise: "present via `Superwall.shared.presentCustomerCenter(delegate:)`, which retains
  /// the delegate while the Customer Center is presented."
  private var retainedDelegate: AnyObject?

  /// Test hook: the number of times `present` has actually started a presentation.
  private(set) var presentCount = 0

  /// Test hook: whether `present`/`dismiss` animate. Always `true` in production. A hostless test
  /// target's run loop never drives a real transition-coordinator animation to completion (there's
  /// no live display link committing frames), so tests set this to `false` to get UIKit's
  /// completion handlers to fire deterministically.
  var presentsAnimated = true

  /// Test hook: the currently presented controller, if any. Lets tests trigger the exact same
  /// dismissal cleanup UIKit's `viewDidDisappear` would (via its `onDismiss`), without depending on
  /// a live view-controller-transition animation actually completing — unavailable in a hostless
  /// test target, where UIKit registers a presentation's bookkeeping synchronously but never
  /// actually finishes loading the presented view into a window.
  var presentedControllerForTesting: CustomerCenterViewController? { presentedController }

  init(container: DependencyContainer) {
    self.container = container
  }

  /// Whether a Customer Center is currently presented.
  var isPresented: Bool { presentedController != nil }

  /// Resolves the configuration to use: `override` if provided, otherwise the value configured via
  /// ``SuperwallOptions/customerCenter``.
  func resolveConfiguration(_ override: CustomerCenterConfiguration?) -> CustomerCenterConfiguration {
    override ?? container.configManager.options.customerCenter
  }

  /// Builds the view model backing ``CustomerCenterView``, using `Superwall.shared`'s dependency
  /// container. Used by `CustomerCenterViewController`'s public initializers.
  static func makeViewModel(configuration: CustomerCenterConfiguration?) -> CustomerCenterViewModel {
    let container = Superwall.shared.dependencyContainer
    let resolved = configuration ?? container.configManager.options.customerCenter
    return CustomerCenterViewModel(
      configuration: resolved,
      dependencies: .live(container: container, configuration: resolved),
      strings: .bundled()
    )
  }

  /// Presents the Customer Center for a Swift ``CustomerCenterDelegate``.
  func present(
    configuration: CustomerCenterConfiguration?,
    from presenter: UIViewController?,
    delegate: CustomerCenterDelegate?,
    onDismiss: (() -> Void)?
  ) {
    present(
      configuration: configuration,
      from: presenter,
      adapter: CustomerCenterDelegateAdapter(swiftDelegate: delegate, objcDelegate: nil),
      retaining: delegate,
      onDismiss: onDismiss
    )
  }

  /// Presents the Customer Center for an Objective-C ``CustomerCenterDelegateObjc``.
  func presentObjc(
    configuration: CustomerCenterConfiguration?,
    from presenter: UIViewController?,
    objcDelegate: CustomerCenterDelegateObjc?,
    onDismiss: (() -> Void)?
  ) {
    present(
      configuration: configuration,
      from: presenter,
      adapter: CustomerCenterDelegateAdapter(swiftDelegate: nil, objcDelegate: objcDelegate),
      retaining: objcDelegate,
      onDismiss: onDismiss
    )
  }

  private func present(
    configuration: CustomerCenterConfiguration?,
    from presenter: UIViewController?,
    adapter: CustomerCenterDelegateAdapter,
    retaining delegate: AnyObject?,
    onDismiss: (() -> Void)?
  ) {
    guard !isPresented else {
      Logger.debug(logLevel: .warn, scope: .customerCenter, message: "Customer Center is already presented.")
      return
    }
    var presenting = presenter ?? UIViewController.topMostViewController
    while let presented = presenting?.presentedViewController, !presented.isBeingDismissed {
      presenting = presented
    }
    guard let presenting else {
      Logger.debug(
        logLevel: .error,
        scope: .customerCenter,
        message: "No view controller available to present the Customer Center."
      )
      return
    }
    let resolved = resolveConfiguration(configuration)
    let viewModel = CustomerCenterViewModel(
      configuration: resolved,
      dependencies: .live(container: container, configuration: resolved),
      strings: .bundled()
    )
    let controller = CustomerCenterViewController(viewModel: viewModel, adapter: adapter)
    controller.onDismiss = { [weak self] in
      self?.presentedController = nil
      self?.retainedDelegate = nil
      onDismiss?()
    }
    retainedDelegate = delegate
    presentedController = controller
    presentCount += 1
    presenting.present(controller, animated: presentsAnimated)
  }

  /// Dismisses the presented Customer Center, if any.
  func dismiss(completion: (() -> Void)?) {
    guard let controller = presentedController else {
      completion?()
      return
    }
    controller.dismiss(animated: presentsAnimated) { [weak self] in
      self?.presentedController = nil
      self?.retainedDelegate = nil
      completion?()
    }
  }
}
