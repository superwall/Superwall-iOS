//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/07/2024.
//

import Foundation

protocol Capability: Encodable {
  var name: String { get }
}

struct PaywallEventReceiverCapability: Capability {
  let name = "paywall_event_receiver"

  let eventNames = [
    SuperwallEventObjc.restoreStart.description,
    SuperwallEventObjc.restoreComplete.description,
    SuperwallEventObjc.restoreFail.description,
    SuperwallEventObjc.transactionRestore.description,
    SuperwallEventObjc.transactionStart.description,
    SuperwallEventObjc.transactionComplete.description,
    SuperwallEventObjc.transactionFail.description,
    SuperwallEventObjc.transactionAbandon.description,
    SuperwallEventObjc.transactionTimeout.description,
    SuperwallEventObjc.paywallOpen.description,
    SuperwallEventObjc.paywallClose.description
  ]
}

struct MultiplePaywallUrlsCapability: Capability {
  let name = "multiple_paywall_urls"
}

struct ConfigRefreshCapability: Capability {
  let name = "config_refresh"
}

struct ConfigCaching: Capability {
  let name = "config_caching"
}

struct WebViewTextInteractionCapability: Capability {
  let name = "webview_text_interaction"
}

/// The SDK finishes custom store checkouts that the paywall runs itself, through
/// the checkout endpoint configured on the custom store, without a `PurchaseController`.
struct CustomStoreCheckoutCapability: Capability {
  let name = "custom_store_checkout"
}
