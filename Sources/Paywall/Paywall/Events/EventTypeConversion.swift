//
//  InternalEventName.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum EventTypeConversion {
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
