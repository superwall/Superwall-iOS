//
//  PublicEvents.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

public extension Superwall {
  /// Sets user attributes for use in paywalls and the Superwall dashboard.
  ///
  /// If the existing user attributes dictionary already has a value for a given property, the old
  /// value is overwritten. Existing properties will not be affected.
  /// Useful for analytics and conditional paywall rules you may define in the Superwall Dashboard.
  /// They should **not** be used as a source of truth for sensitive information.
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
  /// Superwall.shared.setUserAttributes(attributes)
  ///  ```
  /// See <doc:SettingUserAttributes> for more.
  ///
  /// - Parameter attributes: A `[String: Any?]` dictionary used to describe any custom
  /// attributes you'd like to store for the user. Values can be any JSON encodable value, `URL`s or `Date`s.
  /// Note: Keys beginning with `$` are reserved for Superwall and will be dropped. Arrays and dictionaries
  /// as values are not supported at this time, and will be dropped.
  func setUserAttributes(_ attributes: [String: Any?]) {
    mergeAttributes(attributes)
  }

  /// The Objective-C method for setting user attributes for use in your paywalls and the dashboard.
  ///
  /// If the existing user attributes dictionary already has a value for a given property, the old
  /// value is overwritten. Existing properties will not be affected.
  /// Useful for analytics and conditional paywall rules you may define in the Superwall Dashboard.
  /// They should **not** be used as a source of truth for sensitive information.
  ///
  /// Here's how you might set user attributes after retrieving your user's data:
  ///
  ///  ```
  ///  NSDictionary *userAttributes = @{ key : value, key2 : value2};
  ///  [[Superwall sharedInstance] setUserAttributesDictionary: userAttributes];
  ///  ```
  ///
  /// - Parameter attributes: An `NSDictionary` used to describe any custom
  /// attributes you'd like to store for the user. Values can be any JSON encodable value, `URL`s or `Date`s.
  /// Note: Keys beginning with `$` are reserved for Superwall and will be dropped. Arrays and dictionaries
  /// as values are not supported at this time, and will be dropped.
  @available(swift, obsoleted: 1.0)
  @objc func setUserAttributesDictionary(_ attributes: NSDictionary) {
    if let anyAttributes = attributes as? [String: Any] {
      mergeAttributes(anyAttributes)
    } else if let anyAttributes = attributes as? [String: Any?] {
      mergeAttributes(anyAttributes)
    } else {
      mergeAttributes([:])
    }
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
  @objc func removeUserAttributes(_ keys: [String]) {
    let userAttributes: [String: Any?] = keys.reduce([:]) { dictionary, key in
      var dictionary = dictionary
      dictionary[key] = nil
      return dictionary
    }
    setUserAttributes(userAttributes)
  }

  private func mergeAttributes(_ attributes: [String: Any?]) {
    Task {
      var customAttributes: [String: Any] = [:]

      for key in attributes.keys {
        if let value = attributes[key] {
          if key.starts(with: "$") {
            // preserve $ for Superwall-only values
            continue
          }
          customAttributes[key] = value
        }
      }

      let trackableEvent = InternalSuperwallEvent.Attributes(
        customParameters: customAttributes
      )
      let result = await track(trackableEvent)
      let eventParams = result.parameters.eventParams
      dependencyContainer.identityManager.mergeUserAttributes(eventParams)
    }
  }
}
