//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/10/2022.
//

import GameController
import UIKit
/*
@available(*, unavailable, renamed: "Superwall")
public final class Paywall: NSObject {
  @objc static var delegate: SuperwallDelegate?

  enum EventName: String {
    case fakeCase = "fake"
  }

  static var userAttributes: [String: Any] {
    return [:]
  }

  static var presentedViewController: UIViewController? {
    return nil
  }

  static func handleDeepLink(_ url: URL) {}

  static var options: SuperwallOptions {
    return .init()
  }

  static var latestPaywallInfo: PaywallInfo? {
    return nil
  }

  @objc static func configure(
    apiKey: String,
    userId: String?,
    delegate: SuperwallDelegate? = nil,
    options: SuperwallOptions? = nil
  ) -> Paywall {
    return .init()
  }

  @discardableResult
  @objc static func identify(userId: String) -> Paywall {
    return .init()
  }

  @objc static func preloadPaywalls(forTriggers triggers: Set<String>) {}

  @objc static func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onSkip: ((NSError?) -> Void)? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil
  ) {}

  @objc static func track(
    event: String,
    params: [String: Any]? = nil,
    products: PaywallProducts? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onSkip: ((Error?) -> Void)? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil
  ) {}

  @objc static func track(
    _ name: String,
    _ params: [String: Any] = [:]
  ) {}

  static func setUserAttributes(_ attributes: [String: Any?]) {}

  @objc static func setUserAttributesDictionary(_ attributes: NSDictionary) {}

  static func gamepadValueChanged(
    gamepad: GCExtendedGamepad,
    element: GCControllerElement
  ) {}

  static func dismiss(_ completion: (() -> Void)? = nil) {}
}
*/
