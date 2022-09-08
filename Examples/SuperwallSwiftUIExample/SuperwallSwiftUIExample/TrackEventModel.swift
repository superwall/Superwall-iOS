//
//  TrackEventModel.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 06/09/2022.
//

// import Combine
import Paywall

final class TrackEventModel {
  // private var cancellable: AnyCancellable?

  func trackEvent() {
    Paywall.track(
      event: "MyEvent"
    ) { paywallState in
      switch paywallState {
      case .presented(let paywallInfo):
        print("paywall info is", paywallInfo)
      case .dismissed(let result):
        switch result.state {
        case .closed:
          print("User dismissed the paywall.")
        case .purchased(productId: let productId):
          print("Purchased a product with id \(productId), then dismissed.")
        case .restored:
          print("Restored purchases, then dismissed.")
        }
      case .skipped(let reason):
        switch reason {
        case .noRuleMatch:
          print("The user did not match any rules")
        case .holdout(let experiment):
          print("The user is in a holdout group, with experiment id: \(experiment.id), group id: \(experiment.groupId), paywall id: \(experiment.variant.paywallId ?? "")")
        case .triggerNotFound:
          print("The trigger wasn't found on the dashboard.")
        case .error(let error):
          print("Failed to present paywall. Consider a native paywall fallback", error)
        }
      }
    }
  }

  // The below function gives an example of how to track an event using Combine publishers:

  /*
   func trackEventUsingCombine() {
   cancellable = Paywall
     .track(event: "MyEvent")
     .sink { paywallState in
       switch paywallState {
       case .presented(let paywallInfo):
         print("paywall info is", paywallInfo)
       case .dismissed(let result):
         switch result.state {
         case .closed:
           print("User dismissed the paywall.")
         case .purchased(productId: let productId):
           print("Purchased a product with id \(productId), then dismissed.")
         case .restored:
           print("Restored purchases, then dismissed.")
         }
       case .skipped(let reason):
         switch reason {
         case .noRuleMatch:
           print("The user did not match any rules")
         case .holdout(let experiment):
           print("The user is in a holdout group, with experiment id: \(experiment.id), group id: \(experiment.groupId), paywall id: \(experiment.variant.paywallId ?? "")")
         case .triggerNotFound:
           print("The trigger wasn't found on the dashboard.")
         case .error(let error):
           print("Failed to present paywall. Consider a native paywall fallback", error)
         }
       }
     }
   */
}
