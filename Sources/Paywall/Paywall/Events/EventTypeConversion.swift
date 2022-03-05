//
//  InternalEventName.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum EventTypeConversion {
  static func name(for event: InternalEvent) -> InternalEventName {
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

  static func name(for event: Paywall.StandardEvent) -> Paywall.StandardEventName {
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
}
