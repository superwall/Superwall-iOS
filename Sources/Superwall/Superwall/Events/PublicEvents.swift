//
//  PublicEvents.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

public extension Superwall {
  /// Tracks a custom analytical event with optional parameters.
  ///
  /// Any event you track is recorded in the Superwall Dashboard. You can use these events to create implicit triggers. See <doc:TrackingEvents> for more info.
  ///
  /// - Parameter name: The name of your event
  /// - Parameter params: Custom parameters you'd like to include in your event. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// Here's how you might track an event:
  /// ```swift
  /// Superwall.track(
  ///   "onboarding_skip",
  ///   ["steps_completed": 4]
  /// )
  /// ```
  @available(*, unavailable, renamed: "track(event:params:)")
  @objc static func track(
    _ name: String,
    _ params: [String: Any] = [:]
  ) {
    let trackableEvent = UserInitiatedEvent.Track(
      rawName: name,
      canImplicitlyTriggerPaywall: true,
      customParameters: params
    )
    Superwall.track(trackableEvent)
  }

  /// Set user attributes for use in your paywalls and the dashboard.
  ///
  /// If the existing user attributes dictionary already has a value for a given property, the old value is overwritten. Other existing properties will not be affected.
  /// Useful for analytics and conditional paywall rules you may define in the Superwall Dashboard. They should **not** be used as a source of truth for sensitive information.
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
  /// Superwall.setUserAttributes(attributes)
  ///  ```
  /// See <doc:SettingUserAttributes> for more.
  ///
  ///
  /// - Parameter custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  static func setUserAttributes(_ attributes: [String: Any?]) {
    mergeAttributes(attributes)
  }

  /// The Objective-C method for setting user attributes for use in your paywalls and the dashboard. **Note**: Please use ``Superwall/Superwall/setUserAttributes(_:)`` if you're using Swift.
  ///
  /// If the existing user attributes dictionary already has a value for a given property, the old value is overwritten. Other existing properties will not be affected.
  /// Useful for analytics and conditional paywall rules you may define in the web dashboard. They should not be used as a source of truth for sensitive information.
  ///
  /// - Parameter attributes: A `NSDictionary` used to describe user attributes and any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// We make our best effort to pick out "known" user attributes and set them to our names. For exampe `{"first_name": "..." }` and `{"firstName": "..."}` will both be translated into `$first_name` for use in Superwall where we require a first name.
  ///
  ///  Example:
  ///  ```
  ///  NSDictionary *userAttributes = @{ key : value, key2 : value2};
  ///  [Superwall setUserAttributesDictionary: userAttributes];
  ///  ```
  @available(swift, obsoleted: 1.0)
  @objc static func setUserAttributesDictionary(_ attributes: NSDictionary) {
    if let anyAttributes = attributes as? [String: Any] {
      mergeAttributes(anyAttributes)
    } else if let anyAttributes = attributes as? [String: Any?] {
      mergeAttributes(anyAttributes)
    } else {
      mergeAttributes([:])
    }
  }

  private static func mergeAttributes(_ attributes: [String: Any?]) {
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
    let result = track(trackableEvent)

    let eventParams = result.parameters.eventParams
    IdentityManager.shared.mergeUserAttributes(eventParams)
  }

  /// Handles a deep link sent to your app to open a preview of your paywall.
  ///
  /// You can preview your paywall on-device before going live by utilizing paywall previews. This uses a deep link to render a preview of a paywall you've configured on the Superwall dashboard on your device. See <doc:InAppPreviews> for more.
  static func handleDeepLink(_ url: URL) {
    track(InternalSuperwallEvent.DeepLink(url: url))
    Task {
      await SWDebugManager.shared.handle(deepLinkUrl: url)
    }
  }
}
