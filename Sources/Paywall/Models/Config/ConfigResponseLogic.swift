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
      trigger.rules.forEach { rule in
        switch rule.experiment.variant.type {
        case .treatment:
          guard let paywallId = rule.experiment.variant.paywallId else {
            return
          }
          identifiers.insert(paywallId)
        default:
          break
        }
      }
    }
    return identifiers
  }
}
