//
//  TriggerPaywallView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import Paywall

struct TriggerPaywallView: View {
  @State private var showPaywall = false

  var body: some View {
    VStack {
      Text("The button triggers a paywall for the event \"Upsell\".\n\nThe paywall only shows when the event is tied to an active trigger on the Superwall Dashboard."
      )
      .lineSpacing(5)
      .padding(.horizontal)
      .padding(.vertical, 48)
      .multilineTextAlignment(.center)

      BrandedButton(title: "Trigger Paywall") {
        showPaywall.toggle()
      }
      .padding(.horizontal)

      Spacer()
    }
    .navigationTitle("Triggering a Paywall")
    .frame(maxHeight: .infinity)
    .triggerPaywall(
      forEvent: "Upsell",
      shouldPresent: $showPaywall,
      onPresent: { paywallInfo in
        debugPrint("paywall info is", paywallInfo)
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
        print("did fail", error)
      }
    )
    .foregroundColor(.white)
    .background(Color.neutral)
  }
}

struct TriggerPaywall_Previews: PreviewProvider {
  static var previews: some View {
    TriggerPaywallView()
  }
}
