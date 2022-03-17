//
//  ImplicitlyTriggerPaywall.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 17/03/2022.
//

import SwiftUI
import Paywall

struct ImplicitlyTriggerPaywallView: View {
  @StateObject private var store = StoreKitService.shared
  @State private var count = 0

  var body: some View {
    VStack(spacing: 48) {
      InfoView(
        text: "The button below increments a counter. When the counter hits 3, it will track the event \"MyEvent\", which will implicitly trigger a specific paywall for the event.\n\nThis is because the event is tied to an active trigger on the Superwall Dashboard."
      )

      Divider()
        .background(Color.primaryTeal)
        .padding()

      PaywallSubscriptionStatusView()

      Spacer()

      Text("Count: \(count)")
        .font(.rubikBold(.six))

      HStack {
      BrandedButton(title: "Increment") {
        count += 1
        if count == 3 {
          Paywall.track("MyEvent", [:])
        }
      }
      BrandedButton(title: "Reset") {
        count = 0
      }
      }
      .padding()
    }
    .navigationTitle("Implicitly Triggering a Paywall")
    .frame(maxHeight: .infinity)
    .foregroundColor(.white)
    .background(Color.neutral)
  }
}

struct ImplicitlyTriggerPaywallView_Previews: PreviewProvider {
  static var previews: some View {
    ImplicitlyTriggerPaywallView()
  }
}
