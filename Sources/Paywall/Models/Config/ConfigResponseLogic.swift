//
//  ConfigResponseLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum ConfigResponseLogic {
  static func getPaywallIds(fromTriggers triggers: Set<Trigger>) -> Set<String> {
    var identifiers: Set<String> = []

    triggers.forEach { trigger in
      switch trigger.triggerVersion {
      case .v1:
        break
      case .v2(let trigger):
        trigger.rules.forEach { rule in
          switch rule.variant {
          case .treatment(let treatment):
            identifiers.insert(treatment.paywallIdentifier)
          default:
            break
          }
        }
      }
    }
    return identifiers
  }

  static func getNames(of triggers: Set<Trigger>) -> Set<String> {
    let names = triggers
      .filter { $0.triggerVersion == .v1 }
      .map { $0.eventName }
    return Set(names)
  }
}
