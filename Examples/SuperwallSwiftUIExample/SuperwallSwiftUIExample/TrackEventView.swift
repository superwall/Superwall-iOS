//
//  ExplicitlyTriggerPaywallView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import Paywall

struct TrackEventView: View {
  @StateObject private var store = StoreKitService.shared
  @State private var showPaywall = false

  init() {
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
  }

  var body: some View {
    VStack(spacing: 48) {
      InfoView(
        text: "The button below tracks an event \"MyEvent\".\n\nWhen this event is tracked, a set of rules are evaluated to determine whether to show a paywall. This logic is remotely configured inside a campaign on the Superwall dashboard.\n\nFor simplicity, we have configured this event to always show a paywall."
      )

      Divider()
        .background(Color.primaryTeal)
        .padding()

      PaywallSubscriptionStatusView()

      Spacer()

      BrandedButton(title: "Track event") {
        showPaywall.toggle()
        Paywall.track(
          event: "event",
          params: [:]
        )
      }
      .padding()
    }
    .frame(maxHeight: .infinity)
    .track(
      event: "MyEvent",
      shouldTrack: $showPaywall,
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
      },
      onSkip: { reason in
        switch reason {
        case .noRuleMatch:
          print("The user did not match any rules")
        case .holdout(let experiment):
          print("The user is in a holdout group, with experiment id: \(experiment.id), group id: \(experiment.groupId), paywall id: \(experiment.variant.paywallId ?? "")")
        case .unknownEvent(let error):
          print("did fail", error)
        }
      }
    )
    .foregroundColor(.white)
    .background(Color.neutral)
    .navigationBarTitleDisplayMode(.inline)
    .navigationTitle("Hello \(PaywallService.name)")
  }
}

struct TriggerPaywall_Previews: PreviewProvider {
  static var previews: some View {
    TrackEventView()
  }
}
