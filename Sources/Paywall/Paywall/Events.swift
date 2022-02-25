//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation
import StoreKit




extension Paywall {
    
    internal static var _queue = EventsQueue();
    

	@discardableResult
	internal static func _track(_ name: String, _ params: [String: Any] = [:], _ custom: [String: Any] = [:], handleTrigger: Bool = true) -> EventData {
        
//        Logger.superwallDebug(string: "[Track] \(name)")
		
        var eventParams = [String: Any]()
        var delegateParams = [String: Any]()
        delegateParams["isSuperwall"] = true
		
		// add a special property if it's one of ours
		if EventName(rawValue: name) != nil {
			eventParams["$is_standard_event"] = true
		} else {
			eventParams["$is_standard_event"] = false
		}
        
        // TODO: Brian, determine if you want to allow nested
        
        for k in params.keys {
            if let v = clean(input: params[k]) {
                let key = "$\(k)"
                eventParams[key] = v
                delegateParams[k] = v // no $ for delegate methods
            }
        }
        
        for k in custom.keys {
            if let v = clean(input: custom[k]) {
                if k.starts(with: "$") {
                    delegateParams[k] = v // if they wanna use a dollar sign in their own events, let them
					Logger.debug(logLevel: .info, scope: .events, message: "Dropping Key", info: ["key":k, "name": name, "reason": "$ signs not allowed"], error: nil)
//					Logger.sup
                } else {
                    eventParams[k] = v
                }
            } else {
				Logger.debug(logLevel: .debug, scope: .events, message: "Dropping Key", info: ["key":k, "name": name, "reason": "Failed to serialize value"], error: nil)
            }
        }
        
        
        // skip calling disallowed events on their own system likely not needed
        // custom events wont work because StandardEventName and InternalEventName won't exist with their own event name
        if EventName(rawValue: name) != nil {
			Paywall.delegate?.trackAnalyticsEvent?(withName: name, params: delegateParams)
			Logger.debug(logLevel: .debug, scope: .events, message: "Logged Internal Event", info: eventParams, error: nil)
        }
		
		
		if let e = StandardEventName(rawValue: name), e == .userAttributes {
			Store.shared.add(userAttributes: eventParams)
		}
        
		
		let eventData = EventData(id: UUID().uuidString, name: name, parameters: JSON(eventParams), createdAt: Date.init(timeIntervalSinceNow: 0).isoString)
		
		_queue.addEvent(event: eventData.jsonData)
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
        case coreSessionStart // tell us if they bagan to use the main function of your application i.e. call this on "workout_started"
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
        case coreSessionStart = "coreSession_start" // tell us if they bagan to use the main function of your application i.e. call this on "workout_started"
        case coreSessionAbandon = "coreSession_abandon" // i.e. call this on "workout_cancelled"
        case coreSessionComplete = "coreSession_complete" // i.e. call this on "workout_complete"
        case signUp = "sign_up"
        case logIn = "log_in"
        case logOut = "log_out"
        case userAttributes = "user_attributes"
        case base = "base"
    }
    
    internal static func name(for event: StandardEvent) -> StandardEventName {
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
        /// Standard user attribute containing your user's internal identifier. This attribute is automatically added and you don't really need to include it.
        case id(_ s: String)
        /// Standard user attribute containing your user's first name.
        case firstName(_ s: String)
        /// Standard user attribute containing your user's last name.
        case lastName(_ s: String)
        /// Standard user attribute containing your user's email address.
        case email(_ s: String)
        /// Standard user attribute containing your user's phone number, without a country code.
        case phone(_ s: String)
        /// Standard user attribute containing your user's full phone number, country code included.
        case fullPhone(_ s: String)
        /// Standard user attribute containing your user's telephone country code.
        case phoneCountryCode(_ s: String)
        /// Standard user attribute containing your user's FCM token to send push notifications via Firebase.
        case fcmToken(_ s: String)
        /// Standard user attribute containing your user's APNS token to send push notification via APNS.
        case apnsToken(_ s: String)
        /// Standard user attribute containing your user's account creation date.
        case createdAt(_ d: Date)
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
    
    internal enum InternalEvent {
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

    
    internal enum InternalEventName: String { //  add defs
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
			"paywall_products_load_duration": paywallInfo.productsLoadDuration as Any,
        ]
		
		for k in output.keys {
			if k.contains("_load_") {
				print(k, output[k]!)
			}
		}
		print( "========== _load_ vars")
		
		let levels = ["primary", "secondary", "tertiary"]
		
		for (i,l) in levels.enumerated() {
			let key = "\(l)_product_id"
			output[key] = ""
			if i < paywallInfo.productIds.count {
				output[key] = paywallInfo.productIds[i]
			}
		}
		
        if let p = product {
            output["product_id"] = p.productIdentifier
            for k in p.legacyEventData.keys {
                if let v = p.legacyEventData[k] {
                    output["product_\(k.camelCaseToSnakeCase())"] = v
                }
            }
        }
        
        if let p = otherParams {
            for k in p.keys {
                if let v = p[k] {
                    output[k] = v
                }
            }
        }
        
        return output
        
    }
    
    internal static func track(_ event: InternalEvent, _ customParams: [String: Any] = [:]) {
        switch event {
			
			case 	.paywallWebviewLoadStart(let paywallInfo),
					.paywallWebviewLoadFail(let paywallInfo),
					.paywallWebviewLoadComplete(let paywallInfo),
					.paywallOpen(let paywallInfo),
					.paywallClose(let paywallInfo):
				
					_track(eventName: name(for: event), params: eventParams(for: nil, paywallInfo: paywallInfo), customParams: customParams)
			
			case 	.transactionFail(let paywallInfo, let product, let message):
				
					_track(eventName: name(for: event), params: eventParams(for: product, paywallInfo: paywallInfo, otherParams: ["message": message]), customParams: customParams)
			
			case 	.transactionRestore(let paywallInfo, let product):
					
					_track(eventName: name(for: event), params: eventParams(for: product, paywallInfo: paywallInfo), customParams: customParams)
				
			case 	.transactionStart(let paywallInfo, let product),
					.transactionAbandon(let paywallInfo, let product),
					.transactionComplete(let paywallInfo, let product),
					.subscriptionStart(let paywallInfo, let product),
					.freeTrialStart(let paywallInfo, let product),
					.nonRecurringProductPurchase(let paywallInfo, let product):
				
					_track(eventName: name(for: event), params: eventParams(for: product, paywallInfo: paywallInfo), customParams: customParams)

			case 	.paywallResponseLoadStart(let fromEvent, let eventData),
					.paywallResponseLoadNotFound(let fromEvent, let eventData),
					.paywallResponseLoadFail(let fromEvent, let eventData):
					_track(eventName: name(for: event), params: ["isTriggeredFromEvent": fromEvent, "eventName": eventData?.name ?? ""], customParams: customParams)
				
			case 	.paywallResponseLoadComplete(let fromEvent, let eventData, let paywallInfo),
					.paywallProductsLoadStart(let fromEvent, let eventData, let paywallInfo),
					.paywallProductsLoadFail(let fromEvent, let eventData, let paywallInfo),
					.paywallProductsLoadComplete(let fromEvent, let eventData, let paywallInfo):
				
					let p = eventParams(for: nil, paywallInfo: paywallInfo, otherParams: ["isTriggeredFromEvent": fromEvent, "eventName": eventData?.name ?? ""])
					_track(eventName: name(for: event), params: p, customParams: customParams)
            case .triggerFire(let triggerInfo):
                    _track(eventName: name(for: event), params: [
                        "variant_id": triggerInfo.variantId as Any,
                        "experiment_id": triggerInfo.experimentId as Any,
                        "paywall_identifier": triggerInfo.paywallIdentifier as Any,
                        "result": triggerInfo.result
                    ])
			default:
					_track(eventName: name(for: event))
        }
    }
    
    internal static func _track(eventName: InternalEventName, params: [String: Any] = [:], customParams: [String: Any] = [:]) {
        // force all internal events to have global params
        _track(eventName.rawValue, params, customParams)
    }
    
    internal static func _track(eventName: StandardEventName, params: [String: Any] = [:], customParams: [String: Any] = [:]) {
        _track(eventName.rawValue, params, customParams)
    }
    
    internal static func clean(input: Any?) -> Any? {
        if let _ = input as? NSArray {
            return nil
        } else if let _ = input as? NSDictionary {
            return nil
        } else {
            if let v = input {
                let j = JSON(v)
                if j.error == nil {
                    return v
                } else {
                    if let d = v as? Date {
                        return d.isoString
                    } else if let d = v as? URL {
                        return d.absoluteString
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
    public static func track(_ event: StandardEvent, _ params: [String: Any] = [:]) {
        switch event {
        case .deepLinkOpen(let deepLinkUrl):
            _track(eventName: name(for: event), params: ["url": deepLinkUrl.absoluteString], customParams: params)
            SWDebugManager.shared.handle(deepLink: deepLinkUrl)
        case .pushNotificationReceive(let pushNotificationId):
            if let id = pushNotificationId {
                _track(eventName: name(for: event), params: ["push_notification_id": id], customParams: params)
            } else {
                _track(eventName: name(for: event), customParams: params)
            }
        case .pushNotificationOpen(let pushNotificationId):
            if let id = pushNotificationId {
                _track(eventName: name(for: event), params: ["push_notification_id": id], customParams: params)
            } else {
                _track(eventName: name(for: event), customParams: params)
            }
        case .userAttributes(let standardAttributes, let customAttributes):
            
            var standard = [String: Any]()
            
            for k in standardAttributes.keys {
                if let v = standardAttributes[k] {
                    standard[k.rawValue] = v
                }
            }
            
            var custom = [String: Any]()
            
            for k in customAttributes.keys {
                if let v = customAttributes[k] {
                    if !k.starts(with: "$") { // preserve $ for internal use
                        custom[k] = v
                    }
                }
            }
            
            _track(eventName: name(for: event), params: standard, customParams: custom)
        case .base(let name, let params):
            _track(name, [:], params)
        default:
            _track(eventName: name(for: event))
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
			Logger.debug(logLevel: .debug, scope: .events, message: "Unable to Track Event", info: ["message": "Not of Type [String: Any]"], error: nil)
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
            
        var map = [StandardUserAttributeKey: Any]()
        map[.applicationInstalledAt] = DeviceHelper.shared.appInstallDate
        standard.forEach {
            switch $0 {
            case .id(let s):
                map[.id] = s
            case .firstName(let s):
                map[.firstName] = s
            case .lastName(let s):
                map[.lastName] = s
            case .email(let s):
                map[.email] = s
            case .phone(let s):
                map[.phone] = s
            case .fullPhone(let s):
                map[.fullPhone] = s
            case .phoneCountryCode(let s):
                map[.phoneCountryCode] = s
            case .fcmToken(let s):
                map[.fcmToken] = s
            case .apnsToken(let s):
                map[.apnsToken] = s
            case .createdAt(let d):
                map[.createdAt] = d
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
		var map = [StandardUserAttributeKey: Any]()
		map[.applicationInstalledAt] = DeviceHelper.shared.appInstallDate
		track(.userAttributes(standard: map, custom: custom))
	}
    
    /// *Note* Please use `setUserAttributes` if you're using Swift.
    /// Sets additional information on the user object in Superwall. Useful for analytics and conditional paywall rules you may define in the web dashboard. Remember, attributes are write-only by the SDK, and only require your public key. They should not be used as a source of truth for sensitive information.
    /// - Parameter attributes: A `NSDictionary` used to describe user attributes and any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
    ///
    /// We make our best effort to pick out "known" user attributes and set them to our internal names. For exampe `{"first_name": "..." }` and `{"firstName": "..."}` will both be translated into `$first_name` for use in Superwall where we require a first name.
    ///
    ///  Example:
    ///  ```swift
    ///  var userAttributes: NSDictionary = NSDictionary()
    ///  userAttributes.setValue(value: "Jake", forKey: "first_name");
    ///  Superwall.setUserAttributes(userAttributes)
    ///  ```
    @objc public static func setUserAttributesDictionary(attributes: NSDictionary = [:]) {
        var map = [StandardUserAttributeKey: Any]()
        map[.applicationInstalledAt] = DeviceHelper.shared.appInstallDate
        for (anyKey, value) in attributes {
            if let key = anyKey as? String {
                switch (key) {
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
                    break;
                }
            }
        }
        if let anyAttributes = attributes as? [String:Any] {
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
      .processCamelCaseRegex(pattern:digitsFirstPattern)?.lowercased() ?? self.lowercased()
  }
    
    

  fileprivate func processCamelCaseRegex(pattern: String) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: count)
    return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
  }
}
