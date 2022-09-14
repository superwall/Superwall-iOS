//
//  ExplicitlyTriggerPaywallView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import Paywall

struct ExplicitlyTriggerPaywallView: View {
  @StateObject private var store = StoreKitService.shared
  @State private var showPaywall = false

  var body: some View {
    VStack(spacing: 48) {
      InfoView(
        text: "The button below explicitly triggers a paywall for the event \"MyEvent\".\n\nThis is because the event is tied to an active trigger inside a Campaign on the Superwall Dashboard."
      )

      Divider()
        .background(Color.primaryTeal)
        .padding()

      PaywallSubscriptionStatusView(presentationType: .explicitlyTriggered)

      Spacer()

      BrandedButton(title: "Explicitly Trigger Paywall") {
        showPaywall.toggle()
      }
      .padding()
    }
    .navigationTitle("Explicitly Triggering a Paywall")
    .frame(maxHeight: .infinity)
    .triggerPaywall(
      forEvent: "MyEvent",
      shouldPresent: $showPaywall,
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
      onFail: { error in
        if error.code == 4000 {
          print("The user did not match any rules")
        } else if error.code == 4001 {
          print("The user is in a holdout group")
        } else {
          print("did fail", error)
        }
      }
    )
    .accentColor(.white)
    .foregroundColor(.white)
    .background(Color.neutral)
  }
}

struct TriggerPaywall_Previews: PreviewProvider {
  static var previews: some View {
    ExplicitlyTriggerPaywallView()
  }
}
