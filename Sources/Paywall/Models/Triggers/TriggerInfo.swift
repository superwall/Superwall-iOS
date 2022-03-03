//
//  TriggerInfo.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

public final class TriggerInfo: NSObject {
  public let experimentId: String?
  public let variantId: String?

  // "holdout", "no_rule_match", "present"
  public let result: String
  public let paywallIdentifier: String?

  init(
    result: String,
    experimentId: String? = nil,
    variantId: String? = nil,
    paywallIdentifier: String? = nil
  ) {
    self.result = result
    self.experimentId = experimentId
    self.variantId = variantId
    self.paywallIdentifier = paywallIdentifier
  }
}
