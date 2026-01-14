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
    shouldDismiss: Bool,
    postPurchaseAction: PostPurchaseAction?
  )
  case initiateRestore
  case custom(string: String)
  case openedURL(url: URL)
  case openedUrlInSafari(_ url: URL)
  case openedDeepLink(url: URL)
  case customPlacement(name: String, params: JSON)
  case scheduleNotification(notification: LocalNotification)
  case userAttributesUpdated(attributes: JSON)
}
