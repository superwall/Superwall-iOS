//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation

extension Paywall {
    
    internal static var _queue = Queue();
    
    // TODO: Brian, decide what to do with this
    
    internal static func _track(_ name: String, _ params: [String: Any] = [:], _ custom: [String: Any] = [:]) {
        
        Logger.superwallDebug(string: "[Track] \(name)")
        
        var eventParams = [String: Any]()
        var delegateParams = [String: Any]()
        delegateParams["isSuperwall"] = true
        
        // TODO: Brian, determine if you want to allow nested
        
        for k in params.keys {
            if let v = clean(input: params[k]) {
                let key = "$\(k)"
                eventParams[key] = v
                delegateParams[k] = v // no $ for delegate methods
            } else {
                Logger.superwallDebug(string: "Warning: dropping key \"\(k)\" for event \"\(name)\"", error: SuperwallEventError(message: "Could not serialize. FYI arrays & dicts aren't allowed!"))
            }
        }
        
        for k in custom.keys {
            if let v = clean(input: custom[k]) {
                if k.starts(with: "$") {
                    delegateParams[k] = v // if they wanna use a dollar sign in their own events, let them
                    Logger.superwallDebug(string: "Warning: dropping key \"\(k)\" for event \"\(name)\"", error: SuperwallEventError(message: "$ signs are reserved for us, chump!"))
                } else {
                    eventParams[k] = v
                }
            } else {
                Logger.superwallDebug(string: "Warning: dropping key \"\(k)\" for event \"\(name)\"", error: SuperwallEventError(message: "Could not serialize. FYI arrays & dicts aren't allowed!"))
            }
        }
        


        
        // We want to send this event off right away & we might need to process it in
        // somewhat real time so we send it to the api instead of the collector. 
        if (name == "user_attributes"){
            Network.shared.identify(identifyRequest: IdentifyRequest(parameters: JSON(eventParams), created_at: JSON(Date.init(timeIntervalSinceNow: 0).isoString))) {
                (result) in
                print(result)
            }
            return
        }
        
        // skip calling user_attributes on their own system, likely not needed
        if StandardEventName(rawValue: name) != nil || InternalEventName(rawValue: name) != nil {
            Paywall.delegate?.shouldTrack?(event: name, params: delegateParams)
        }

        
        let eventData: JSON = [
            "event_id": JSON(UUID().uuidString),
            "event_name": JSON(name),
            "parameters": JSON(eventParams),
            "created_at": JSON(Date.init(timeIntervalSinceNow: 0).isoString),
        ]
        _queue.addEvent(event: eventData)
//        let jsonString = eventData.rawString(.utf8, options: .init()) // prevent pretty print
//        print(eventData)
        // TODO: Brian, decide what to do with this
        
    }
    
    // MARK: Public Events
    public enum StandardEvent {
        case deepLinkOpen(deepLinkUrl: String)
        case onboardingStart
        case onboardingComplete
        case pushNotificationReceive(superwallId: String? = nil)
        case pushNotificationOpen(superwallId: String? = nil)
        case coreSessionStart // tell us if they bagan to use the main function of your application i.e. call this on "workout_started"
        case coreSessionAbandon // i.e. call this on "workout_cancelled"
        case coreSessionComplete // i.e. call this on "workout_complete"
        case signUp
        case logIn
        case logOut
        case userAttributes(standard: [StandardUserAttributeKey: Any?], custom: [String: Any?])
        case base(name: String, params: [String: Any])
    }
        
    public enum StandardEventName: String { //  add defs
        case deepLinkOpen = "deepLink_open"
        case onboardingStart = "onboarding_start"
        case onboardingComplete = "onboarding_complete"
        case pushNotificationReceive = "pushNotification_receive"
        case pushNotificationOpen = "pushNotification_open"
        case coreSessionStart = "coreSession_start" // tell us if they bagan to use the main function of your application i.e. call this on "workout_started"
        case coreSessionAbandon = "coreSession_abandon" // i.e. call this on "workout_cancelled"
        case coreSessionComplete = "coreSession_complete" // i.e. call this on "workout_complete"
        case authSignUp = "auth_signUp"
        case authLogIn = "auth_logIn"
        case authLogOut = "auth_LogOut"
        case userAttributes = "user_attributes"
        case base = "base"
    }
    
    private static func name(for event: StandardEvent) -> StandardEventName {
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
            return .authLogIn
        case .logOut:
            return .authLogOut
        case .userAttributes:
            return .userAttributes
        case .signUp:
            return .authSignUp
        case .base:
            return .base
        }
    }
    
    public enum StandardEventKey: String {
        case eventTime
        case timeZone
        case paywallId
        case productId
        case deepLinkUrl
        case pushNotificationId
    }
    
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

    public enum StandardUserAttribute { //  add defs
        case id(_ s: String)
        case firstName(_ s: String)
        case lastName(_ s: String)
        case email(_ s: String)
        case phone(_ s: String)
        case fullPhone(_ s: String)
        case phoneCountryCode(_ s: String)
        case fcmToken(_ s: String)
        case apnsToken(_ s: String)
        case createdAt(_ d: Date)
    }
    
    internal enum InternalEvent {
        case appInstall
        case appOpen
        case appClose
        
        case paywallResponseLoadStart
        case paywallResponseLoadFail
        case paywallResponseLoadComplete
        
        case paywallWebviewLoadStart(paywallId: String)
        case paywallWebviewLoadFail(paywallId: String)
        case paywallWebviewLoadComplete(paywallId: String)
        
        case paywallOpen(paywallId: String)
        case paywallClose(paywallId: String)
       
        case transactionStart(paywallId: String, productId: String)
        case transactionComplete(paywallId: String, productId: String)
        case transactionFail(paywallId: String, productId: String, message: String)
        case transactionAbandon(paywallId: String, productId: String)
        
        case subscriptionStart(paywallId: String, productId: String)
        case freeTrialStart(paywallId: String, productId: String)
        case transactionRestore(paywallId: String, productId: String)
        case nonRecurringProductPurchase(paywallId: String, productId: String)
    }

    
    internal enum InternalEventName: String { //  add defs
        case appInstall = "app_install"
        case appOpen = "app_open"
        case appClose = "app_close"
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
        case paywallResponseLoadFail = "paywallResponseLoad_fail"
        case paywallResponseLoadComplete = "paywallResponseLoad_complete"
        
        case paywallWebviewLoadStart = "paywallWebviewLoad_start"
        case paywallWebviewLoadFail = "paywallWebviewLoad_fail"
        case paywallWebviewLoadComplete = "paywallWebviewLoad_complete"
        
    }

    private static func name(for event: InternalEvent) -> InternalEventName {
        switch event {
        case .appInstall:
            return .appInstall
        case .appOpen:
            return .appOpen
        case .appClose:
            return .appClose
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
        case .paywallResponseLoadFail:
            return .paywallResponseLoadFail
        case .paywallResponseLoadComplete:
            return .paywallResponseLoadComplete
        case .paywallWebviewLoadStart:
            return .paywallWebviewLoadStart
        case .paywallWebviewLoadFail:
            return .paywallWebviewLoadFail
        case .paywallWebviewLoadComplete:
            return .paywallWebviewLoadComplete
        }
    }
    
    internal static func track(_ event: InternalEvent, _ customParams: [String: Any] = [:]) {
        switch event {
        case .paywallWebviewLoadStart(let paywallId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId], customParams: customParams)
        case .paywallWebviewLoadFail(let paywallId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId], customParams: customParams)
        case .paywallWebviewLoadComplete(let paywallId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId], customParams: customParams)
        case .paywallOpen(let paywallId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId], customParams: customParams)
        case .paywallClose(let paywallId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId], customParams: customParams)
        case .transactionStart(let paywallId, let productId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId], customParams: customParams)
        case .transactionFail(let paywallId, let productId, let message):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId, "message": message], customParams: customParams)
        case .transactionAbandon(let paywallId, let productId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId], customParams: customParams)
        case .transactionComplete(let paywallId, let productId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId], customParams: customParams)
        case .subscriptionStart(let paywallId, let productId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId], customParams: customParams)
        case .freeTrialStart(let paywallId, let productId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId], customParams: customParams)
        case .transactionRestore(let paywallId, let productId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId], customParams: customParams)
        case .nonRecurringProductPurchase(let paywallId, let productId):
            _track(eventName: name(for: event), params: ["paywall_id": paywallId, "product_id": productId], customParams: customParams)
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
                    } else {
                        return nil
                    }
                }
            }
        }
        
        return nil
    }
    

    
    public static func track(_ event: StandardEvent, _ params: [String: Any] = [:]) {
        switch event {
        case .deepLinkOpen(let deepLinkUrl):
            _track(eventName: name(for: event), params: ["url": deepLinkUrl], customParams: params)
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
    
    public static func track(_ name: String, _ params: [String: Any]) {
        track(.base(name: name, params: params))
    }
    
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
    
}



struct SuperwallEventError: LocalizedError {
    var message: String
}
