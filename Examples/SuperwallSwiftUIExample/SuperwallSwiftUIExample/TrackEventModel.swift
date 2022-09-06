//
//  TrackEventModel.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 06/09/2022.
//

import Foundation
import Paywall

final class TrackEventModel {
  func trackEvent() {
    Paywall.track(
      event: "MyEvent",
      onSkip: { reason in
        switch reason {
        case .noRuleMatch:
          print("The user did not match any rules")
        case .holdout(let experiment):
          print("The user is in a holdout group, with experiment id: \(experiment.id), group id: \(experiment.groupId), paywall id: \(experiment.variant.paywallId ?? "")")
        case .unknownEvent(let error):
          print("did fail", error)
        }
      },
      onPresent: { paywallInfo in
        print("paywall info is", paywallInfo)
      },
      onDismiss: { result in
        switch result.state {
        case .closed:
          print("User dismissed the paywall.")
        case .purchased(productId: let productId):
          print("Purchased a product with id \(productId), then dismissed.")
        case .restored:
          print("Restored purchases, then dismissed.")
        }
      }
    )
  }
}
