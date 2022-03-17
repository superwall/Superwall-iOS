//
//  PresentPaywallView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Paywall

struct PresentPaywallView: View {
  @State private var showPaywall = false

  var body: some View {
    VStack(spacing: 48) {
      InfoView(
        text: "The button below presents a paywall that has been set up on the Superwall dashboard.\n\nThe paywall assigned to the user is determined by your settings in the dashboard. Once a user is assigned a paywall, they will continue to see the same paywall, even when the paywall is turned off, unless you reassign them to a new one."
      )

      Divider()
        .background(Color.primaryTeal)
        .padding()

      PaywallSubscriptionStatusView(presentationType: .presented)

      Spacer()

      BrandedButton(title: "Present Paywall") {
        showPaywall.toggle()
      }
      .padding()
    }
    .navigationTitle("Paywall Presentation")
    .frame(maxHeight: .infinity)
    .presentPaywall(
      isPresented: $showPaywall,
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
    .foregroundColor(.white)
    .background(Color.neutral)
  }
}

struct PresentPaywallView_Previews: PreviewProvider {
  static var previews: some View {
    PresentPaywallView()
  }
}
