//
//  PublicEvents.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

public extension Paywall {
  /// Tracks a custom analytical event with optional parameters.
  ///
  /// Any event you track is recorded in the Superwall Dashboard. You can use these events to create implicit triggers. See <doc:Triggering> for more info.
  ///
  /// There are a list of ``Paywall/Paywall/StandardEvent``s that can be tracked  to determine if you should be tracking a standard event instead. You'll be able to reference properties when creating rules for when paywalls show up.
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
    _ params: [String: Any]
  ) {
    track(
      UserInitiatedEvent.Track(
        rawName: name,
        canTriggerPaywall: true
      ),
      customParameters: params
    )
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
    //TODO: In the next breaking version, change the Any? param value from optional to non-optional

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

    let result = track(
      UserInitiatedEvent.Attributes(),
      customParameters: customAttributes
    )
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

  // MARK: - Deprecated

  /// Standard events for use in conjunction with  ``Paywall/Paywall/track(_:_:)-7gc4r``.
  @available(*, deprecated)
  enum StandardEvent {
    /// Standard event used to track when a user opens your application via a deep link.
    case deepLinkOpen(deepLinkUrl: URL)
    /// Standard event used to track when a user begins onboarding.
    case onboardingStart
    /// Standard event used to track when a user completes onboarding.
    case onboardingComplete
    /// Standard event used to track when a user receives a push notification.
    case pushNotificationReceive(superwallId: String? = nil)
    /// Standard event used to track when a user launches your application by way of a push notification.
    case pushNotificationOpen(superwallId: String? = nil)
    /// Standard event used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout begins.
    case coreSessionStart // i.e. call this on "workout_started"
    /// Standard event used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout is cancelled or aborted.
    case coreSessionAbandon // i.e. call this on "workout_cancelled"
    /// Standard event used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout is completed.
    case coreSessionComplete // i.e. call this on "workout_complete"
    /// Standard event used to track when a user signs up.
    case signUp
    /// Standard event used to track when a user logs in to your application.
    case logIn
    /// Standard event used to track when a user logs out of your application. Not to be confused with `Paywall.reset()` — this event is strictly for analytical purposes.
    case logOut
    /// **WARNING**: Use ``Paywall/Paywall/setUserAttributes(_:custom:)`` instead.
    case userAttributes(standard: [StandardUserAttributeKey: Any?], custom: [String: Any?])
    /// **WARNING**: This is used internally, ignore please
    case base(name: String, params: [String: Any])
  }

  /// Used internally, please ignore.
  @available(*, deprecated)
  enum StandardUserAttributeKey: String { //  add defs
    case id = "id"
    case applicationInstalledAt = "application_installed_at"
    case firstName = "first_name"
    case lastName = "last_name"
    case email = "email"
    case phone = "phone"
    case fullPhone = "full_phone"
    case phoneCountryCode = "phone_country_code"
    case fcmToken = "fcm_token"
    case apnsToken = "apns_token"
    case createdAt = "created_at"
  }

  /// Standard user attributes to be used in conjunction with ``Paywall/Paywall/setUserAttributes(_:custom:)``.
  @available(*, deprecated)
  enum StandardUserAttribute { //  add defs
    /// Standard user attribute containing your user's identifier. This attribute is automatically added and you don't really need to include it.
    case id(_ id: String)
    /// Standard user attribute containing your user's first name.
    case firstName(_ firstName: String)
    /// Standard user attribute containing your user's last name.
    case lastName(_ lastName: String)
    /// Standard user attribute containing your user's email address.
    case email(_ email: String)
    /// Standard user attribute containing your user's phone number, without a country code.
    case phone(_ phone: String)
    /// Standard user attribute containing your user's full phone number, country code included.
    case fullPhone(_ phone: String)
    /// Standard user attribute containing your user's telephone country code.
    case phoneCountryCode(_ countryCode: String)
    /// Standard user attribute containing your user's FCM token to send push notifications via Firebase.
    case fcmToken(_ fcmToken: String)
    /// Standard user attribute containing your user's APNS token to send push notification via APNS.
    case apnsToken(_ apnsToken: String)
    /// Standard user attribute containing your user's account creation date.
    case createdAt(_ date: Date)
  }

  /// Warning: Should prefer ``track(_:_:)-2vkwo`` if using Swift.
  /// Tracks a event with properties.
  ///
  /// Remember to check ``Paywall/Paywall/StandardEvent`` to determine if you should use a string which maps to standard event name. Properties are optional and can be added only if needed. You'll be able to reference properties when creating rules for when paywalls show up.
  /// - Parameter event: The name of your custom event
  /// - Parameter params: Custom parameters you'd like to include in your event. Remember, keys begining with `$` are reserved for Superwall and will be dropped. They will however be included in `PaywallDelegate.shouldTrack(event: String, params: [String: Any])` for your own records. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// Here's how you might track an event:
  /// ```objective-c
  /// [Paywall trackWithName:@"onboarding_skip" params:NSDictionary()];
  /// ```
  @available(*, deprecated, renamed: "track(_:_:)")
  @objc static func track(
    name: String,
    params: NSDictionary? = [:]
  ) {
    if let stringParameterMap = params as? [String: Any] {
      track(.base(name: name, params: stringParameterMap))
    } else {
      Logger.debug(
        logLevel: .debug,
        scope: .events,
        message: "Unable to Track Event",
        info: ["message": "Not of Type [String: Any]"],
        error: nil
      )
    }
  }

  /// *Note*: Please use ``Paywall/Paywall/setUserAttributes(_:)`` if you're using Swift.
  /// Set user attributes for use in your paywalls and the dashboard.
  ///
  /// Useful for analytics and conditional paywall rules you may define in the web dashboard. They should not be used as a source of truth for sensitive information.
  ///
  /// - Parameter attributes: A `NSDictionary` used to describe user attributes and any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// We make our best effort to pick out "known" user attributes and set them to our names. For exampe `{"first_name": "..." }` and `{"firstName": "..."}` will both be translated into `$first_name` for use in Superwall where we require a first name.
  ///
  ///  Example:
  ///  ```swift
  ///  var userAttributes: NSDictionary = NSDictionary()
  ///  userAttributes.setValue(value: "Jake", forKey: "first_name");
  ///  Superwall.setUserAttributes(userAttributes)
  ///  ```
  @available(*, deprecated, renamed: "setUserAttributes(_:)")
  @objc static func setUserAttributesDictionary(attributes: NSDictionary = [:]) {
    var map: [StandardUserAttributeKey: Any] = [:]
    map[.applicationInstalledAt] = DeviceHelper.shared.appInstallDate
    for (anyKey, value) in attributes {
      if let key = anyKey as? String {
        switch key {
        case "firstName", "first_name":
          map[.firstName] = value
        case "id", "ID":
          map[.id] = value
        case "lastName", "last_name":
          map[.firstName] = value
        case "email":
          map[.email] = value
        case "phone":
          map[.phone] = value
        case "full_phone", "fullPhone":
          map[.fullPhone] = value
        case "phone_country_code", "phoneCountryCode":
          map[.phoneCountryCode] = value
        case "fcm_token", "fcmToken":
          map[.fcmToken] = value
        case "apns_token", "apnsToken", "APNS":
          map[.apnsToken] = value
        case "createdAt", "created_at":
          map[.createdAt] = value
        default:
          break
        }
      }
    }
    if let anyAttributes = attributes as? [String: Any] {
      track(.userAttributes(standard: map, custom: anyAttributes))
    } else {
      track(.userAttributes(standard: map, custom: [:]))
    }
  }

  /// Set user attributes for use in your paywalls and the dashboard.
  ///
  /// Useful for analytics and conditional paywall rules you may define in the web dashboard. They should not be used as a source of truth for sensitive information.
  ///
  /// - Parameter standard: Zero or more `SubscriberUserAttribute` enums describing standard user attributes.
  /// - Parameter custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  ///  Example:
  ///  ```swift
  ///  Superwall.setUserAttributes(.firstName("Jake"), .lastName("Mor"), custom: properties)
  ///  ```
  @available(*, deprecated, renamed: "setUserAttributes(_:)")
  static func setUserAttributes(
    _ standard: StandardUserAttribute...,
    custom: [String: Any?] = [:]
  ) {
    var map: [StandardUserAttributeKey: Any] = [:]
    map[.applicationInstalledAt] = DeviceHelper.shared.appInstallDate
    standard.forEach {
      switch $0 {
      case .id(let id):
        map[.id] = id
      case .firstName(let firstName):
        map[.firstName] = firstName
      case .lastName(let lastName):
        map[.lastName] = lastName
      case .email(let email):
        map[.email] = email
      case .phone(let phone):
        map[.phone] = phone
      case .fullPhone(let phone):
        map[.fullPhone] = phone
      case .phoneCountryCode(let countryCode):
        map[.phoneCountryCode] = countryCode
      case .fcmToken(let fcmToken):
        map[.fcmToken] = fcmToken
      case .apnsToken(let apnsToken):
        map[.apnsToken] = apnsToken
      case .createdAt(let date):
        map[.createdAt] = date
      }
    }
    track(.userAttributes(standard: map, custom: custom))
  }

  /// Tracks a standard analytical event with optional parameters (See ``Paywall/Paywall/StandardEvent`` for the types of events available).
  ///
  /// Properties are optional and can be added only if needed. You'll be able to reference properties when creating rules for when paywalls show up.
  /// - Parameter event: A `StandardEvent` enum, which takes default parameters as inputs.
  /// - Parameter params: Custom parameters you'd like to include in your event. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// Here's how you might track a deep link or a sign-up event:
  /// ```swift
  /// Paywall.track(.deepLinkOpen(url: someURL))
  /// Paywall.track(.signUp, ["campaignId": "12312341", "source": "Facebook Ads"]
  /// ```
  @available(*, deprecated, message: "For deep links, use the dedicated function Paywall.handleDeepLink(_:). For all other tracking, use track(_:_:).")
  static func track(
    _ event: StandardEvent,
    _ params: [String: Any] = [:]
  ) {
    switch event {
    case .deepLinkOpen(let url):
      track(UserInitiatedEvent.DeepLink(url: url))
      SWDebugManager.shared.handle(deepLinkUrl: url)
    case .pushNotificationReceive(let pushNotificationId):
      let trackedEvent = UserInitiatedEvent.PushNotification(
        state: .receive,
        pushNotificationId: pushNotificationId
      )
      Paywall.track(trackedEvent, customParameters: params)
    case .pushNotificationOpen(let pushNotificationId):
      let trackedEvent = UserInitiatedEvent.PushNotification(
        state: .open,
        pushNotificationId: pushNotificationId
      )
      Paywall.track(trackedEvent, customParameters: params)
    case let .userAttributes(standardAttributes, customAttributes):
      var standard: [String: Any] = [:]
      for key in standardAttributes.keys {
        if let value = standardAttributes[key] {
          standard[key.rawValue] = value
        }
      }

      var custom: [String: Any] = [:]

      for key in customAttributes.keys {
        if let value = customAttributes[key] {
          if !key.starts(with: "$") { // preserve $ for use
            custom[key] = value
          }
        }
      }

      let result = Paywall.track(
        UserInitiatedEvent.Attributes(),
        customParameters: custom
      )
      let eventParams = result.parameters.eventParams
      Storage.shared.addUserAttributes(eventParams)
    case let .base(name, params):
      Paywall.track(
        UserInitiatedEvent.Track(
          rawName: name,
          canTriggerPaywall: true
        ),
        customParameters: params
      )
    default:
      let name = EventTypeConversion.name(for: event).rawValue
      Paywall.track(
        UserInitiatedEvent.Track(
          rawName: name,
          canTriggerPaywall: true
        )
      )
    }
  }
}
