//
//  PublicEvents.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

public extension Paywall {
  /// Standard events for use in conjunction with `Paywall.track(_ event: StandardEvent, _ params: [String: Any] = [:])`.
  enum StandardEvent {
    /// Standard even used to track when a user opens your application by way of a deep link.
    case deepLinkOpen(deepLinkUrl: URL)
    /// Standard even used to track when a user begins onboarding.
    case onboardingStart
    /// Standard even used to track when a user completes onboarding.
    case onboardingComplete
    /// Standard even used to track when a user receives a push notification.
    case pushNotificationReceive(superwallId: String? = nil)
    /// Standard even used to track when a user launches your application by way of a push notification.
    case pushNotificationOpen(superwallId: String? = nil)
    /// Standard even used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout begins.
    case coreSessionStart // i.e. call this on "workout_started"
    /// Standard even used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout is cancelled or aborted.
    case coreSessionAbandon // i.e. call this on "workout_cancelled"
    /// Standard even used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout is completed.
    case coreSessionComplete // i.e. call this on "workout_complete"
    /// Standard even used to track when a user signs up.
    case signUp
    /// Standard even used to track when a user logs in to your application.
    case logIn
    /// Standard even used to track when a user logs out of your application. Not to be confused with `Paywall.reset()` — this event is strictly for analytical purposes.
    case logOut
    /// WARNING: Use `setUserAttributes(_ standard: StandardUserAttribute..., custom: [String: Any?] = [:])` instead.
    case userAttributes(standard: [StandardUserAttributeKey: Any?], custom: [String: Any?])
    /// WARNING: This is used internally, ignore please
    case base(name: String, params: [String: Any])
  }

  /// Used internally, please ignore.
  enum StandardEventName: String { //  add defs
    case deepLinkOpen = "deepLink_open"
    case onboardingStart = "onboarding_start"
    case onboardingComplete = "onboarding_complete"
    case pushNotificationReceive = "pushNotification_receive"
    case pushNotificationOpen = "pushNotification_open"
    case coreSessionStart = "coreSession_start" // i.e. call this on "workout_started"
    case coreSessionAbandon = "coreSession_abandon" // i.e. call this on "workout_cancelled"
    case coreSessionComplete = "coreSession_complete" // i.e. call this on "workout_complete"
    case signUp = "sign_up"
    case logIn = "log_in"
    case logOut = "log_out"
    case userAttributes = "user_attributes"
    case base = "base"
  }

  /// Used internally, please ignore.
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

  /// Standard user attributes to be used in conjunction with `setUserAttributes(_ standard: StandardUserAttribute..., custom: [String: Any?] = [:])`.
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

  /// These are the types of events we send to Paywall's delegate `shouldTrack` method
  enum EventName: String {
    case firstSeen = "first_seen"
    case appOpen = "app_open"
    case appLaunch = "app_launch"
    case sessionStart = "session_start"
    case appClose = "app_close"
    case triggerFire = "trigger_fire"
    case paywallOpen = "paywall_open"
    case paywallClose = "paywall_close"
    case transactionStart = "transaction_start"
    case transactionFail = "transaction_fail"
    case transactionAbandon = "transaction_abandon"
    case transactionComplete = "transaction_complete"
    case subscriptionStart = "subscription_start"
    case freeTrialStart = "freeTrial_start"
    case transactionRestore = "transaction_restore"
    case nonRecurringProductPurchase = "nonRecurringProduct_purchase"
    case paywallResponseLoadStart = "paywallResponseLoad_start"
    case paywallResponseLoadNotFound = "paywallResponseLoad_notFound"
    case paywallResponseLoadFail = "paywallResponseLoad_fail"
    case paywallResponseLoadComplete = "paywallResponseLoad_complete"
    case paywallWebviewLoadStart = "paywallWebviewLoad_start"
    case paywallWebviewLoadFail = "paywallWebviewLoad_fail"
    case paywallWebviewLoadComplete = "paywallWebviewLoad_complete"
  }

  /// Tracks a standard event with properties (See `Paywall.StandardEvent` for options). Properties are optional and can be added only if needed. You'll be able to reference properties when creating rules for when paywalls show up.
  /// - Parameter event: A `StandardEvent` enum, which takes default parameters as inputs.
  /// - Parameter params: Custom parameters you'd like to include in your event. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// Example:
  /// ```swift
  /// Paywall.track(.deepLinkOpen(url: someURL))
  /// Paywall.track(.signUp, ["campaignId": "12312341", "source": "Facebook Ads"]
  /// ```
  static func track(
    _ event: StandardEvent,
    _ params: [String: Any] = [:]
  ) {
    switch event {
    case .deepLinkOpen(let deepLinkUrl):
      track(
        eventName: EventTypeConversion.name(for: event),
        params: ["url": deepLinkUrl.absoluteString],
        customParams: params
      )
      SWDebugManager.shared.handle(deepLink: deepLinkUrl)
    case .pushNotificationReceive(let pushNotificationId):
      if let id = pushNotificationId {
        track(
          eventName: EventTypeConversion.name(for: event),
          params: ["push_notification_id": id],
          customParams: params
        )
      } else {
        track(
          eventName: EventTypeConversion.name(for: event),
          customParams: params
        )
      }
    case .pushNotificationOpen(let pushNotificationId):
      if let id = pushNotificationId {
        track(
          eventName: EventTypeConversion.name(for: event),
          params: ["push_notification_id": id],
          customParams: params
        )
      } else {
        track(
          eventName: EventTypeConversion.name(for: event),
          customParams: params
        )
      }
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

      track(
        eventName: EventTypeConversion.name(for: event),
        params: standard,
        customParams: custom
      )
    case let .base(name, params):
      track(name, [:], params)
    default:
      track(eventName: EventTypeConversion.name(for: event))
    }
  }

  /// Tracks a custom event with properties. Remember to check `Paywall.StandardEvent` to determine if you should be tracking a standard event instead. Properties are optional and can be added only if needed. You'll be able to reference properties when creating rules for when paywalls show up.
  /// - Parameter event: The name of your custom event
  /// - Parameter params: Custom parameters you'd like to include in your event. Remember, keys begining with `$` are reserved for Superwall and will be dropped. They will however be included in `PaywallDelegate.shouldTrack(event: String, params: [String: Any])` for your own records. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// Example:
  /// ```swift
  /// Paywall.track("onboarding_skip", ["steps_completed": 4])
  /// ```
  @objc static func track(_ name: String, _ params: [String: Any]) {
    track(.base(name: name, params: params))
  }

  /// Warning: Should prefer `track` if using Swift
  /// Tracks a event with properties. Remember to check `Paywall.StandardEvent` to determine if you should use a string which maps to standard event name. Properties are optional and can be added only if needed. You'll be able to reference properties when creating rules for when paywalls show up.
  /// - Parameter event: The name of your custom event
  /// - Parameter params: Custom parameters you'd like to include in your event. Remember, keys begining with `$` are reserved for Superwall and will be dropped. They will however be included in `PaywallDelegate.shouldTrack(event: String, params: [String: Any])` for your own records. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  /// Example:
  /// ```objective-c
  /// [Paywall trackWithName:@"onboarding_skip" params:NSDictionary()];
  /// ```
  @objc static func track(name: String, params: NSDictionary? = [:]) {
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

  /// Sets additional information on the user object in Superwall. Useful for analytics and conditional paywall rules you may define in the web dashboard. Remember, attributes are write-only by the SDK, and only require your public key. They should not be used as a source of truth for sensitive information.
  /// - Parameter custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  ///  Example:
  ///  ```swift
  ///  Superwall.setUserAttributes(properties)
  ///  ```
  static func setUserAttributes(_ custom: [String: Any?] = [:]) {
    var map: [StandardUserAttributeKey: Any] = [:]
    map[.applicationInstalledAt] = DeviceHelper.shared.appInstallDate
    track(.userAttributes(standard: map, custom: custom))
  }

  /// *Note* Please use `setUserAttributes` if you're using Swift.
  /// Sets additional information on the user object in Superwall. Useful for analytics and conditional paywall rules you may define in the web dashboard. Remember, attributes are write-only by the SDK, and only require your public key. They should not be used as a source of truth for sensitive information.
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

  // MARK: - Deprecated Functions

  /// Sets additional information on the user object in Superwall. Useful for analytics and conditional paywall rules you may define in the web dashboard. Remember, attributes are write-only by the SDK, and only require your public key. They should not be used as a source of truth for sensitive information.
  /// - Parameter standard: Zero or more `SubscriberUserAttribute` enums describing standard user attributes.
  /// - Parameter custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  ///  Example:
  ///  ```swift
  ///  Superwall.setUserAttributes(.firstName("Jake"), .lastName("Mor"), custom: properties)
  ///  ```
  @available(*, deprecated)
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
}
