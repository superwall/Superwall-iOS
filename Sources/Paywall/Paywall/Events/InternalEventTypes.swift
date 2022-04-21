//
//  InternalEventTypes.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation
import StoreKit

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
  case triggerFire(triggerResult: TriggerResult)

  case transactionStart(paywallInfo: PaywallInfo, product: SKProduct)
  case transactionComplete(paywallInfo: PaywallInfo, product: SKProduct)
  case transactionFail(paywallInfo: PaywallInfo, product: SKProduct?, message: String)
  case transactionAbandon(paywallInfo: PaywallInfo, product: SKProduct)

  case subscriptionStart(paywallInfo: PaywallInfo, product: SKProduct)
  case freeTrialStart(paywallInfo: PaywallInfo, product: SKProduct)
  case transactionRestore(paywallInfo: PaywallInfo, product: SKProduct?)
  case nonRecurringProductPurchase(paywallInfo: PaywallInfo, product: SKProduct)
}
