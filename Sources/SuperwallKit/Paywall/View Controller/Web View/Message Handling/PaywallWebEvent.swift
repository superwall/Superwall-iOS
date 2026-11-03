//
//  PaywallWebEvent.swift
//  Superwall
//
//  Created by Yusuf Tör on 07/03/2022.
//

import Foundation

enum PaywallWebEvent: Equatable {
  case closed
  case initiatePurchase(
    productId: String,
    shouldDismiss: Bool
  )
  case initiateRestore
  case customStoreCheckout(CustomStoreCheckout)
  /// Sent by the SDK, not the page: the paywall was dismissed or presented
  /// again, so a custom store checkout it started can't report how it ends.
  case endCustomStoreCheckout
  case custom(string: String)
  case openedURL(url: URL)
  case openedUrlInSafari(_ url: URL)
  case openedDeepLink(url: URL)
  case customPlacement(name: String, params: JSON)
  case scheduleNotification(notification: LocalNotification)
  case userAttributesUpdated(attributes: JSON)
  case requestCallback(
    name: String,
    behavior: CustomCallbackBehavior,
    requestId: String,
    variables: JSON?
  )
}
