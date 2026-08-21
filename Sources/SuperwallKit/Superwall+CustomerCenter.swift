//
//  Superwall+CustomerCenter.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import UIKit

extension Superwall {
  /// Presents the Customer Center, a self-service screen where users can view and manage their
  /// subscriptions, request refunds, restore purchases, and contact support.
  ///
  /// Only one Customer Center can be presented at a time; calling this while one is already
  /// presented is a no-op.
  ///
  /// - Parameters:
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter`` for this presentation. `nil`
  ///     uses the value configured via `SuperwallOptions`.
  ///   - presenter: The view controller to present from. `nil` presents from the top-most
  ///     currently-presented view controller.
  ///   - delegate: Receives Customer Center events. Strongly retained for the duration of the
  ///     presentation.
  ///   - onDismiss: Called after the Customer Center is dismissed.
  @available(iOS 15.0, *)
  @MainActor
  public func presentCustomerCenter(
    configuration: CustomerCenterConfiguration? = nil,
    from presenter: UIViewController? = nil,
    delegate: CustomerCenterDelegate? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    guard Superwall.isInitialized else {
      Logger.debug(
        logLevel: .error,
        scope: .customerCenter,
        message: "Superwall has not been configured. Please call Superwall.configure() first."
      )
      return
    }
    dependencyContainer.customerCenterManager.present(
      configuration: configuration,
      from: presenter,
      delegate: delegate,
      onDismiss: onDismiss
    )
  }

  /// Dismisses a Customer Center presented via
  /// ``presentCustomerCenter(configuration:from:delegate:onDismiss:)``. A no-op if none is presented.
  ///
  /// Available to Objective-C as `dismissCustomerCenterWithCompletion:`.
  @available(iOS 15.0, *)
  @MainActor
  @objc(dismissCustomerCenterWithCompletion:)
  public func dismissCustomerCenter(completion: (() -> Void)? = nil) {
    guard Superwall.isInitialized else {
      Logger.debug(
        logLevel: .error,
        scope: .customerCenter,
        message: "Superwall has not been configured. Please call Superwall.configure() first."
      )
      return
    }
    dependencyContainer.customerCenterManager.dismiss(completion: completion)
  }

  /// Objective-C: presents the Customer Center. See
  /// ``presentCustomerCenter(configuration:from:delegate:onDismiss:)``.
  @available(iOS 15.0, *)
  @available(swift, obsoleted: 1.0)
  @MainActor
  @objc(presentCustomerCenterWithConfiguration:from:delegate:onDismiss:)
  public func presentCustomerCenterObjc(
    configuration: CustomerCenterConfiguration?,
    from presenter: UIViewController?,
    delegate: CustomerCenterDelegateObjc?,
    onDismiss: (() -> Void)?
  ) {
    guard Superwall.isInitialized else {
      Logger.debug(
        logLevel: .error,
        scope: .customerCenter,
        message: "Superwall has not been configured. Please call Superwall.configure() first."
      )
      return
    }
    dependencyContainer.customerCenterManager.presentObjc(
      configuration: configuration,
      from: presenter,
      objcDelegate: delegate,
      onDismiss: onDismiss
    )
  }
}
