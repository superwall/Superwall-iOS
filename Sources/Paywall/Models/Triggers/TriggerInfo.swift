//
//  TriggerInfo.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

/// `TriggerInfo` contains infromation for tracking the result of a trigger fire event. Triggers as basically entrypoints in your applicaiton where you can conditionally show a paywall. This object contains infromation to tell you about what the result of that trigger was.
public final class TriggerInfo: NSObject {

  /// What experiement was found as a result of this trigger. `nil` if there were not matching rules
  public let experimentId: String?
  /// What variant of that experiment was shown to a user. `nil` if there were no matching rules
  public let variantId: String?

  // "holdout", "no_rule_match", "present"
  /// Result tells us what happened as a result of the trigger. It can be `holdout`, `no_rule_match` or `present`. `no_rule_match` means that we looked at the the rules associated with the trigger but found none matching that user and therefore the user didn not see a paywall as a result of the trigger
  public let result: String
    
  /// The paywall identifier of the variant the user saw. If result is not `present`, this will be `nil`
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
