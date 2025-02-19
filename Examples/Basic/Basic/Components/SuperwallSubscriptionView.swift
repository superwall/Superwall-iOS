//
//  SuperwallSubscriptionView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI
import SuperwallKit

struct SuperwallSubscriptionView: View {
  @StateObject private var superwall = Superwall.shared // ensures subscriptionStatus is auto updating
  var text: String {
    // These are published properties that auto-update
    switch superwall.subscriptionStatus {
    case .unknown:
      return "Loading subscription status."
    case .inactive:
      return "You do not have an active subscription so a paywall will always show."
    case .active:
      return "You are subscribed so a paywall will not show. For the purposes of this app, delete and reinstall the app to clear your subscriptions."
    }
  }

  var body: some View {
    Text(text)
      .multilineTextAlignment(.center)
      .lineSpacing(5)
      .padding()
      .padding(.bottom, 20)
  }
}

#Preview {
  SuperwallSubscriptionView()
}
