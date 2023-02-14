//
//  SuperwallSubscriptionStatusLogic.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 17/03/2022.
//

import Foundation
import SuperwallKit


enum SuperwallSubscriptionStatusLogic {
  static func text(
    subscriptionStatus: SubscriptionStatus
  ) -> String {
    switch subscriptionStatus {
    case .active:
      return "You currently have an active subscription. Therefore, the paywall will never show. For the purposes of this app, delete and reinstall the app to clear subscriptions."
    default:
      return "You do not have an active subscription so the paywall will show when clicking the button."
    }
  }
}
