//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/10/2022.
//

import UIKit

extension Superwall {
  // MARK: - Unavailable methods
  // TODO: Fix deprecation here
  /*@available(*, unavailable, renamed: "configure(apiKey:purchaseController:options:completion:)")
  @discardableResult
  @objc static func configure(
    apiKey: String,
    userId: String?,
    delegate: SuperwallDelegate? = nil,
    options: SuperwallOptions? = nil
  ) -> Superwall {
    return shared
  }*/

  @available(*, unavailable, renamed: "preloadPaywalls(forEvents:)")
  @objc public func preloadPaywalls(forTriggers triggers: Set<String>) {}

  @available(*, unavailable, renamed: "track(event:params:paywallOverrides:paywallHandler:)")
  @objc public func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onSkip: ((NSError?) -> Void)? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil
  ) {}

  @available(*, unavailable, renamed: "track(event:params:)")
  @objc public func track(
    _ name: String,
    _ params: [String: Any] = [:]
  ) {}

  @available(*, unavailable, message: "Set the SuperwallOption \"localeIdentifier\" instead.")
  @objc public func localizationOverride(localeIdentifier: String? = nil) {}

  @available(*, unavailable, renamed: "SuperwallEvent")
  public enum EventName: String {
    case fakeCase = "fake"
  }
}
