//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation
import StoreKit

extension Paywall {
  static var queue = EventsQueue()

	@discardableResult
  static func track(
    _ name: String,
    _ params: [String: Any] = [:],
    _ custom: [String: Any] = [:],
    handleTrigger: Bool = true
  ) -> EventData {
    // Logger.superwallDebug(string: "[Track] \(name)")

    var eventParams: [String: Any] = [:]
    var delegateParams: [String: Any] = [:]
    delegateParams["isSuperwall"] = true

		// add a special property if it's one of ours
		if EventName(rawValue: name) != nil {
			eventParams["$is_standard_event"] = true
		} else {
			eventParams["$is_standard_event"] = false
		}

    // TODO: Brian, determine if you want to allow nested

    for key in params.keys {
      if let value = clean(input: params[key]) {
        let key = "$\(key)"
        eventParams[key] = value
        delegateParams[key] = value // no $ for delegate methods
      }
    }

    for key in custom.keys {
      if let value = clean(input: custom[key]) {
        if key.starts(with: "$") {
          delegateParams[key] = value // if they wanna use a dollar sign in their own events, let them
          Logger.debug(
            logLevel: .info,
            scope: .events,
            message: "Dropping Key",
            info: ["key": key, "name": name, "reason": "$ signs not allowed"],
            error: nil
          )
        } else {
          eventParams[key] = value
        }
      } else {
        Logger.debug(
          logLevel: .debug,
          scope: .events,
          message: "Dropping Key",
          info: ["key": key, "name": name, "reason": "Failed to serialize value"],
          error: nil
        )
      }
    }


    // skip calling disallowed events on their own system likely not needed
    // custom events wont work because StandardEventName and InternalEventName won't exist with their own event name
    if EventName(rawValue: name) != nil {
      Paywall.delegate?.trackAnalyticsEvent?(withName: name, params: delegateParams)
      Logger.debug(logLevel: .debug, scope: .events, message: "Logged Event", info: eventParams, error: nil)
    }

		if let event = StandardEventName(rawValue: name),
      event == .userAttributes {
			Store.shared.add(userAttributes: eventParams)
		}

		let eventData = EventData(
      id: UUID().uuidString,
      name: name,
      parameters: JSON(eventParams),
      createdAt: Date.init(timeIntervalSinceNow: 0).isoString
    )

		queue.addEvent(event: eventData.jsonData)
		if handleTrigger {
			Paywall.shared.handleTrigger(forEvent: eventData)
		}

		return eventData
  }

  // MARK: Public Events
  /// Standard events for use in conjunction with `Paywall.track(_ event: StandardEvent, _ params: [String: Any] = [:])`.
  public enum StandardEvent {
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
  public enum StandardEventName: String { //  add defs
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

  static func name(for event: StandardEvent) -> StandardEventName {
    switch event {
    case .deepLinkOpen:
      return .deepLinkOpen
    case .onboardingStart:
      return .onboardingStart
    case .onboardingComplete:
      return .onboardingComplete
    case .pushNotificationReceive:
      return .pushNotificationReceive
    case .pushNotificationOpen:
      return .pushNotificationOpen
    case .coreSessionStart:
      return .coreSessionStart
    case .coreSessionAbandon:
      return .coreSessionAbandon
    case .coreSessionComplete:
      return .coreSessionComplete
    case .logIn:
      return .logIn
    case .logOut:
      return .logOut
    case .userAttributes:
      return .userAttributes
    case .signUp:
      return .signUp
    case .base:
      return .base
    }
  }

  /// Used internally, please ignore.
  public enum StandardUserAttributeKey: String { //  add defs
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
  public enum StandardUserAttribute { //  add defs
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
  public enum EventName: String {
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

  enum InternalEvent {
    case firstSeen
    case appOpen
    case appLaunch
    case appClose
    case sessionStart

    case paywallResponseLoadStart(fromEvent: Bool, event: EventData?)
    case paywallResponseLoadNotFound(fromEvent: Bool, event: EventData?)
    case paywallResponseLoadFail(fromEvent: Bool, event: EventData?)
    case paywallResponseLoadComplete(fromEvent: Bool, event: EventData?, paywallInfo: PaywallInfo)

    case paywallProductsLoadStart(fromEvent: Bool, event: EventData?, paywallInfo: PaywallInfo)
    case paywallProductsLoadFail(fromEvent: Bool, event: EventData?, paywallInfo: PaywallInfo)
    case paywallProductsLoadComplete(fromEvent: Bool, event: EventData?, paywallInfo: PaywallInfo)

    case paywallWebviewLoadStart(paywallInfo: PaywallInfo)
    case paywallWebviewLoadFail(paywallInfo: PaywallInfo)
    case paywallWebviewLoadComplete(paywallInfo: PaywallInfo)

    case paywallOpen(paywallInfo: PaywallInfo)
    case paywallClose(paywallInfo: PaywallInfo)
    case triggerFire(triggerInfo: TriggerInfo)

    case transactionStart(paywallInfo: PaywallInfo, product: SKProduct)
    case transactionComplete(paywallInfo: PaywallInfo, product: SKProduct)
    case transactionFail(paywallInfo: PaywallInfo, product: SKProduct?, message: String)
    case transactionAbandon(paywallInfo: PaywallInfo, product: SKProduct)

    case subscriptionStart(paywallInfo: PaywallInfo, product: SKProduct)
    case freeTrialStart(paywallInfo: PaywallInfo, product: SKProduct)
    case transactionRestore(paywallInfo: PaywallInfo, product: SKProduct?)
    case nonRecurringProductPurchase(paywallInfo: PaywallInfo, product: SKProduct)
  }

  enum InternalEventName: String { //  add defs
    case firstSeen = "first_seen"
    case appOpen = "app_open"
    case appLaunch = "app_launch"
    case appClose = "app_close"
    case sessionStart = "session_start"
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
    case paywallProductsLoadStart = "paywallProductsLoad_start"
    case paywallProductsLoadFail = "paywallProductsLoad_fail"
    case paywallProductsLoadComplete = "paywallProductsLoad_complete"
    case paywallWebviewLoadStart = "paywallWebviewLoad_start"
    case paywallWebviewLoadFail = "paywallWebviewLoad_fail"
    case paywallWebviewLoadComplete = "paywallWebviewLoad_complete"
  }

  private static func name(for event: InternalEvent) -> InternalEventName {
    switch event {
    case .firstSeen:
      return .firstSeen
    case .appOpen:
      return .appOpen
    case .sessionStart:
      return .sessionStart
    case .appLaunch:
      return .appLaunch
    case .appClose:
      return .appClose
    case .triggerFire:
      return .triggerFire
    case .paywallOpen:
      return .paywallOpen
    case .paywallClose:
      return .paywallClose
    case .transactionStart:
      return .transactionStart
    case .transactionComplete:
      return .transactionComplete
    case .subscriptionStart:
      return .subscriptionStart
    case .freeTrialStart:
      return .freeTrialStart
    case .transactionRestore:
      return .transactionRestore
    case .nonRecurringProductPurchase:
      return .nonRecurringProductPurchase
    case .transactionFail:
      return .transactionFail
    case .transactionAbandon:
      return .transactionAbandon
    case .paywallResponseLoadStart:
      return .paywallResponseLoadStart
    case .paywallResponseLoadNotFound:
      return .paywallResponseLoadNotFound
    case .paywallResponseLoadFail:
      return .paywallResponseLoadFail
    case .paywallResponseLoadComplete:
      return .paywallResponseLoadComplete
    case .paywallProductsLoadStart:
      return .paywallProductsLoadStart
    case .paywallProductsLoadFail:
      return .paywallProductsLoadFail
    case .paywallProductsLoadComplete:
      return .paywallProductsLoadComplete
    case .paywallWebviewLoadStart:
      return .paywallWebviewLoadStart
    case .paywallWebviewLoadFail:
      return .paywallWebviewLoadFail
    case .paywallWebviewLoadComplete:
      return .paywallWebviewLoadComplete
      }
  }

  private static func eventParams(for product: SKProduct?, paywallInfo: PaywallInfo, otherParams: [String: Any]? = nil) -> [String: Any] {
    var output: [String: Any] = [
      "paywall_id": paywallInfo.id,
      "paywall_identifier": paywallInfo.identifier,
      "paywall_slug": paywallInfo.slug,
      "paywall_name": paywallInfo.name,
      "paywall_url": paywallInfo.url?.absoluteString ?? "unknown",
      "presented_by_event_name": paywallInfo.presentedByEventWithName as Any,
      "presented_by_event_id": paywallInfo.presentedByEventWithId as Any,
      "presented_by_event_timestamp": paywallInfo.presentedByEventAt as Any,
      "presented_by": paywallInfo.presentedBy as Any,
      "paywall_product_ids": paywallInfo.productIds.joined(separator: ","),
      "paywall_response_load_start_time": paywallInfo.responseLoadStartTime as Any,
      "paywall_response_load_complete_time": paywallInfo.responseLoadCompleteTime as Any,
      "paywall_response_load_duration": paywallInfo.responseLoadDuration as Any,
      "paywall_webview_load_start_time": paywallInfo.webViewLoadStartTime as Any,
      "paywall_webview_load_complete_time": paywallInfo.webViewLoadCompleteTime as Any,
      "paywall_webview_load_duration": paywallInfo.webViewLoadDuration as Any,
      "paywall_products_load_start_time": paywallInfo.productsLoadStartTime as Any,
      "paywall_products_load_complete_time": paywallInfo.productsLoadCompleteTime as Any,
      "paywall_products_load_duration": paywallInfo.productsLoadDuration as Any
    ]

    for key in output.keys {
      if key.contains("_load_"),
        let output = output[key] {
        print(key, output)
      }
    }
    print( "========== _load_ vars")

    let levels = ["primary", "secondary", "tertiary"]

    for (id, level) in levels.enumerated() {
      let key = "\(level)_product_id"
      output[key] = ""
      if id < paywallInfo.productIds.count {
        output[key] = paywallInfo.productIds[id]
      }
    }

    if let product = product {
      output["product_id"] = product.productIdentifier
      for key in product.legacyEventData.keys {
        if let value = product.legacyEventData[key] {
          output["product_\(key.camelCaseToSnakeCase())"] = value
        }
      }
    }

    if let otherParams = otherParams {
      for key in otherParams.keys {
        if let value = otherParams[key] {
          output[key] = value
        }
      }
    }

    return output
  }

  static func track(
    _ event: InternalEvent,
    _ customParams: [String: Any] = [:]
  ) {
    switch event {
    case .paywallWebviewLoadStart(let paywallInfo),
      .paywallWebviewLoadFail(let paywallInfo),
      .paywallWebviewLoadComplete(let paywallInfo),
      .paywallOpen(let paywallInfo),
      .paywallClose(let paywallInfo):
      track(
        eventName: name(for: event),
        params: eventParams(for: nil, paywallInfo: paywallInfo),
        customParams: customParams
      )
    case let .transactionFail(paywallInfo, product, message):
      track(
        eventName: name(for: event),
        params: eventParams(for: product, paywallInfo: paywallInfo, otherParams: ["message": message]),
        customParams: customParams
      )
    case let .transactionRestore(paywallInfo, product):
      track(
        eventName: name(for: event),
        params: eventParams(for: product, paywallInfo: paywallInfo),
        customParams: customParams
      )
    case let .transactionStart(paywallInfo, product),
      let .transactionAbandon(paywallInfo, product),
      let .transactionComplete(paywallInfo, product),
      let .subscriptionStart(paywallInfo, product),
      let .freeTrialStart(paywallInfo, product),
      let .nonRecurringProductPurchase(paywallInfo, product):

      track(
        eventName: name(for: event),
        params: eventParams(for: product, paywallInfo: paywallInfo),
        customParams: customParams
      )

    case let .paywallResponseLoadStart(fromEvent, eventData),
      let .paywallResponseLoadNotFound(fromEvent, eventData),
      let .paywallResponseLoadFail(fromEvent, eventData):
      track(
        eventName: name(for: event),
        params: ["isTriggeredFromEvent": fromEvent, "eventName": eventData?.name ?? ""],
        customParams: customParams
      )
    case let .paywallResponseLoadComplete(fromEvent, eventData, paywallInfo),
      let .paywallProductsLoadStart(fromEvent, eventData, paywallInfo),
      let .paywallProductsLoadFail(fromEvent, eventData, paywallInfo),
      let .paywallProductsLoadComplete(fromEvent, eventData, paywallInfo):
      let params = eventParams(
        for: nil,
        paywallInfo: paywallInfo,
        otherParams: ["isTriggeredFromEvent": fromEvent, "eventName": eventData?.name ?? ""]
      )
      track(eventName: name(for: event), params: params, customParams: customParams)
    case .triggerFire(let triggerInfo):
      track(eventName: name(for: event), params: [
        "variant_id": triggerInfo.variantId as Any,
        "experiment_id": triggerInfo.experimentId as Any,
        "paywall_identifier": triggerInfo.paywallIdentifier as Any,
        "result": triggerInfo.result
      ])
    default:
      track(eventName: name(for: event))
    }
  }

  static func track(
    eventName: InternalEventName,
    params: [String: Any] = [:],
    customParams: [String: Any] = [:]
  ) {
    // force all events to have global params
    track(eventName.rawValue, params, customParams)
  }

  static func track(
    eventName: StandardEventName,
    params: [String: Any] = [:],
    customParams: [String: Any] = [:]
  ) {
    track(eventName.rawValue, params, customParams)
  }

  static func clean(input: Any?) -> Any? {
    if input is NSArray {
      return nil
    } else if input is NSDictionary {
      return nil
    } else {
      if let input = input {
        let json = JSON(input)
        if json.error == nil {
          return input
        } else {
          if let date = input as? Date {
            return date.isoString
          } else if let url = input as? URL {
            return url.absoluteString
          } else {
            return nil
          }
        }
      }
    }

    return nil
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
  public static func track(
    _ event: StandardEvent,
    _ params: [String: Any] = [:]
  ) {
    switch event {
    case .deepLinkOpen(let deepLinkUrl):
      track(
        eventName: name(for: event),
        params: ["url": deepLinkUrl.absoluteString],
        customParams: params
      )
      SWDebugManager.shared.handle(deepLink: deepLinkUrl)
    case .pushNotificationReceive(let pushNotificationId):
      if let id = pushNotificationId {
        track(
          eventName: name(for: event),
          params: ["push_notification_id": id],
          customParams: params
        )
      } else {
        track(eventName: name(for: event), customParams: params)
      }
    case .pushNotificationOpen(let pushNotificationId):
      if let id = pushNotificationId {
        track(eventName: name(for: event), params: ["push_notification_id": id], customParams: params)
      } else {
        track(eventName: name(for: event), customParams: params)
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

      track(eventName: name(for: event), params: standard, customParams: custom)
    case let .base(name, params):
      track(name, [:], params)
    default:
      track(eventName: name(for: event))
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
  @objc public static func track(_ name: String, _ params: [String: Any]) {
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
  @objc public static func track(name: String, params: NSDictionary? = [:]) {
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
  /// - Parameter standard: Zero or more `SubscriberUserAttribute` enums describing standard user attributes.
  /// - Parameter custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  ///  Example:
  ///  ```swift
  ///  Superwall.setUserAttributes(.firstName("Jake"), .lastName("Mor"), custom: properties)
  ///  ```
  @available(*, deprecated)
  public static func setUserAttributes(_ standard: StandardUserAttribute..., custom: [String: Any?] = [:]) {
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

  /// Sets additional information on the user object in Superwall. Useful for analytics and conditional paywall rules you may define in the web dashboard. Remember, attributes are write-only by the SDK, and only require your public key. They should not be used as a source of truth for sensitive information.
  /// - Parameter custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///
  ///  Example:
  ///  ```swift
  ///  Superwall.setUserAttributes(properties)
  ///  ```
  public static func setUserAttributes(_ custom: [String: Any?] = [:]) {
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
  @objc public static func setUserAttributesDictionary(attributes: NSDictionary = [:]) {
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
}

struct SuperwallEventError: LocalizedError {
  var message: String
}

extension String {
  func camelCaseToSnakeCase() -> String {
    let acronymPattern = "([A-Z]+)([A-Z][a-z]|[0-9])"
    let fullWordsPattern = "([a-z])([A-Z]|[0-9])"
    let digitsFirstPattern = "([0-9])([A-Z])"
    return self.processCamelCaseRegex(pattern: acronymPattern)?
      .processCamelCaseRegex(pattern: fullWordsPattern)?
      .processCamelCaseRegex(pattern: digitsFirstPattern)?
      .lowercased() ?? self.lowercased()
  }

  // swiftlint:disable:next strict_fileprivate
  fileprivate func processCamelCaseRegex(pattern: String) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: count)
    return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
  }
  // swiftlint:disable:next file_length
}
