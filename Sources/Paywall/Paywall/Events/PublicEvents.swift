//
//  PublicEvents.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable:all line_length

import Foundation

public extension Paywall {
  /// Tracks a custom analytical event with optional parameters.
  ///
  /// Any event you track is recorded in the Superwall Dashboard. You can use these events to create implicit triggers. See <doc:Triggering> for more info.
  ///
  /// - Parameter name: The name of your event
  /// - Parameter params: Custom parameters you'd like to include in your event. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// Here's how you might track an event:
  /// ```swift
  /// Paywall.track(
  ///   "onboarding_skip",
  ///   ["steps_completed": 4]
  /// )
  /// ```
  @objc static func track(
    _ name: String,
    _ params: [String: Any] = [:]
  ) {
    let trackableEvent = UserInitiatedEvent.Track(
      rawName: name,
      canImplicitlyTriggerPaywall: true,
      customParameters: params
    )
    Paywall.track(trackableEvent)
  }

  /// Set user attributes for use in your paywalls and the dashboard.
  ///
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
  /// Paywall.setUserAttributes(attributes)
  ///  ```
  /// See <doc:SettingUserAttributes> for more.
  ///
  ///
  /// - Parameter custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  static func setUserAttributes(_ attributes: [String: Any?] = [:]) {
    // TODO: In the next breaking version, change the Any? param value from optional to non-optional and add objc.

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

    let trackableEvent = UserInitiatedEvent.Attributes(
      customParameters: customAttributes
    )
    let result = track(trackableEvent)

    let eventParams = result.parameters.eventParams
    Storage.shared.addUserAttributes(eventParams)
  }

  /// Handles a deep link sent to your app to open a preview of your paywall.
  ///
  /// You can preview your paywall on-device before going live by utilizing paywall previews. This uses a deep link to render a preview of a paywall you've configured on the Superwall dashboard on your device. See <doc:InAppPreviews> for more.
  static func handleDeepLink(_ url: URL) {
    track(UserInitiatedEvent.DeepLink(url: url))
    SWDebugManager.shared.handle(deepLinkUrl: url)
  }
}
