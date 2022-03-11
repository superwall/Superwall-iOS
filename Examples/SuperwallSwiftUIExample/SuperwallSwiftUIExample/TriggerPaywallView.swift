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
      Text("This button triggers a paywall for the event \"DidTriggerPaywall\". The paywall only shows when the event is tied to an active trigger on the Superwall Dashboard.")

      Button(
        action: {
          showPaywall.toggle()
        },
        label: {
          Text("Trigger Paywall")
        }
      )
      .padding()
    }
    .triggerPaywall(
      forEvent: "DidTriggerPaywall",
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
        print("did fail", error)
      }
    )
  }
}

struct TriggerPaywall_Previews: PreviewProvider {
  static var previews: some View {
    TriggerPaywallView()
  }
}
