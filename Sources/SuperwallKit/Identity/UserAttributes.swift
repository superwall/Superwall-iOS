//
//  UserAttributes.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

extension Superwall {
  /// Sets user attributes for use in paywalls and on the Superwall dashboard.
  ///
  /// If an attribute already exists, its value will be overwritten while other attributes remain unchanged.
  /// This is useful for analytics and campaign audience filters you may define in the Superwall Dashboard.
  /// **Note:** These attributes should not be used as a source of truth for sensitive information.
  ///
  /// Here's how you might set user attributes after retrieving your user's data:
  ///  ```swift
  ///  var attributes: [String: Any] = [
  ///   "name": user.name,
  ///   "apnsToken": user.apnsTokenString,
  ///   "email": user.email,
  ///   "username": user.username,
  ///   "profilePic": user.profilePicUrl
  ///  ]
  ///  await Superwall.shared.setUserAttributes(attributes)
  ///  ```
  /// See [Setting User Attributes](https://docs.superwall.com/docs/setting-user-properties) for more.
  ///
  /// - Parameter attributes: A `[String: Any?]` dictionary used to describe any custom
  /// attributes you'd like to store for the user. Values can be any JSON encodable value, `URL`s or `Date`s.
  /// Note: Keys beginning with `$` are reserved for Superwall and will be dropped. Arrays and dictionaries
  /// as values are not supported at this time, and will be dropped.
  ///
  /// Note: `idfv`, `idfa` and `attStatus` are owned by the SDK, which keeps them
  /// in step with the device. A value you set on one of those keys is replaced
  /// the next time the app becomes active or you set an integration attribute.
  public func setUserAttributes(_ attributes: [String: Any?]) {
    dependencyContainer.attributionFetcher?.forgetSyncedDeviceIdentifiers(
      ifChangedBy: attributes
    )
    mergeAttributes(attributes)
  }

  /// The Objective-C method for setting user attributes for use in your paywalls and the dashboard.
  ///
  /// If the existing user attributes dictionary already has a value for a given property, the old
  /// value is overwritten. Existing properties will not be affected.
  /// Useful for analytics and campaign audience filters you may define in the Superwall Dashboard.
  /// They should **not** be used as a source of truth for sensitive information.
  ///
  /// Here's how you might set user attributes after retrieving your user's data:
  ///
  ///  ```
  ///  NSDictionary *userAttributes = @{ key : value, key2 : value2};
  ///  [[Superwall sharedInstance] setUserAttributes:userAttributes];
  ///  ```
  ///
  /// - Parameters:
  ///   - attributes: An `NSDictionary` used to describe any custom
  /// attributes you'd like to store for the user. Values can be any JSON encodable value, `URL`s or `Date`s.
  /// Note: Keys beginning with `$` are reserved for Superwall and will be dropped. Arrays and dictionaries
  /// as values are not supported at this time, and will be dropped.
  @available(swift, obsoleted: 1.0)
  @objc public func setUserAttributes(_ attributes: NSDictionary) {
    var swiftDictionary: [String: Any?] = [:]
    let keys = attributes.allKeys.compactMap { $0 as? String }
    for key in keys {
      let keyValue = attributes.value(forKey: key) as Any?
      swiftDictionary[key] = keyValue
    }

    dependencyContainer.attributionFetcher?.forgetSyncedDeviceIdentifiers(
      ifChangedBy: swiftDictionary
    )
    mergeAttributes(swiftDictionary)
  }

  /// The Objective-C method for removing user attributes for use in your paywalls and the dashboard.
  ///
  ///  Example:
  ///  ```
  ///  [[Superwall sharedInstance] removeUserAttributes:@[@"key1", @"key2"]];
  ///  ```
  ///
  /// - Parameter keys: An array containing the keys you wish to remove from the user attributes dictionary.
  @available(swift, obsoleted: 1.0)
  @objc public func removeUserAttributes(_ keys: [String]) {
    let userAttributes: [String: Any?] = keys.reduce([:]) { dictionary, key in
      var dictionary = dictionary
      dictionary[key] = Any?.none
      return dictionary
    }
    setUserAttributes(userAttributes)
  }

  /// Merges attributes set from a paywall and notifies the delegate. Runs the
  /// same overwrite check as ``setUserAttributes(_:)-1wq0n``, so a paywall that
  /// writes one of the SDK-owned keys is answered by a resync too.
  func setUserAttributesFromPaywall(_ attributes: [String: Any]) {
    dependencyContainer.attributionFetcher?.forgetSyncedDeviceIdentifiers(
      ifChangedBy: attributes
    )
    dependencyContainer.identityManager.mergeUserAttributesAndNotify(attributes)
  }

  private func mergeAttributes(_ attributes: [String: Any?]) {
    var customAttributes: [String: Any?] = [:]

    for key in attributes.keys {
      if let value = attributes[key] {
        if key.starts(with: "$") {
          // preserve $ for Superwall-only values
          continue
        }
        if JSONSerialization.isValidJSONObject([key: value]) {
          customAttributes[key] = Self.sanitizeAttribute(key: key, value: value)
        }
      }
    }

    dependencyContainer.identityManager.mergeUserAttributes(customAttributes)
  }

  /// Validates attribute values that have server-side schema constraints.
  ///
  /// The checkout API rejects `context.identity.email` unless it is either a
  /// valid email address or `null`. Apps that set a placeholder like `"none"`
  /// would silently break the Stripe checkout flow, so the SDK parses the
  /// value through ``Email`` and drops it when invalid.
  private static func sanitizeAttribute(key: String, value: Any?) -> Any? {
    guard let stringValue = value as? String else {
      return value
    }

    switch key {
    case "email":
      guard let email = Email(stringValue) else {
        Logger.debug(
          logLevel: .warn,
          scope: .identityManager,
          message: "Invalid email user attribute — sending null to server"
        )
        return nil
      }
      return email.rawValue

    default:
      return value
    }
  }
}
