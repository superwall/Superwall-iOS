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

enum InternalEventName: String {
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
