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
