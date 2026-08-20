//
//  CustomerCenterViewController.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI
import UIKit

/// A UIKit container for ``CustomerCenterView``.
@available(iOS 15.0, *)
@objc(SWKCustomerCenterViewController)
public final class CustomerCenterViewController: UIViewController {
  let viewModel: CustomerCenterViewModel
  private var hosting: UIHostingController<CustomerCenterView>?
  var onDismiss: (() -> Void)?

  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``; `nil` uses the options value.
  ///   - delegate: Receives Customer Center events. The view controller does not retain its
  ///     delegate. Keep a strong reference to it for the duration of the presentation — or present
  ///     via `Superwall.shared.presentCustomerCenter(delegate:)`, which retains the delegate while
  ///     the Customer Center is presented.
  public convenience init(
    configuration: CustomerCenterConfiguration? = nil,
    delegate: CustomerCenterDelegate? = nil
  ) {
    self.init(
      viewModel: CustomerCenterManager.makeViewModel(configuration: configuration),
      adapter: CustomerCenterDelegateAdapter(swiftDelegate: delegate, objcDelegate: nil)
    )
  }

  /// Objective-C initializer.
  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``; `nil` uses the options value.
  ///   - objcDelegate: Receives Customer Center events. The view controller does not retain its
  ///     delegate. Keep a strong reference to it for the duration of the presentation — or present
  ///     via `Superwall.shared.presentCustomerCenter(delegate:)`, which retains the delegate while
  ///     the Customer Center is presented.
  @objc public convenience init(configuration: CustomerCenterConfiguration?, objcDelegate: CustomerCenterDelegateObjc?) {
    self.init(
      viewModel: CustomerCenterManager.makeViewModel(configuration: configuration),
      adapter: CustomerCenterDelegateAdapter(swiftDelegate: nil, objcDelegate: objcDelegate)
    )
  }

  init(viewModel: CustomerCenterViewModel, adapter: CustomerCenterDelegateAdapter) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
    viewModel.callbacks = adapter.makeCallbacks()
    modalPresentationStyle = .pageSheet
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override public func viewDidLoad() {
    super.viewDidLoad()
    let options = CustomerCenterNavigationOptions(
      usesExistingNavigation: false,
      showsCloseButton: true
    ) { [weak self] in
      self?.dismiss(animated: true)
    }
    let host = UIHostingController(rootView: CustomerCenterView(viewModel: viewModel, navigationOptions: options))
    addChild(host)
    view.addSubview(host.view)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    host.didMove(toParent: self)
    hosting = host
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isBeingDismissed || presentingViewController == nil {
      onDismiss?()
    }
  }
}
