//
//  SuperwallSubscriptionStatusView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI
import SuperwallKit

struct SuperwallSubscriptionStatusView: View {
  @StateObject private var superwall = Superwall.shared // ensures subscriptionStatus is auto updating
  var text: String {
    switch superwall.subscriptionStatus {
    case .active:
      return "You currently have an active subscription. Therefore, the paywall will never show. For the purposes of this app, delete and reinstall the app to clear subscriptions."
    case .inactive:
      return "You do not have an active subscription so the paywall will show when clicking the button."
    case .unknown:
      return "Your subscription status is unknown"
    }
  }

  var body: some View {
    Text(text)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
      .lineSpacing(5)
  }
}

struct SuperwallSubscriptionStatusView_Previews: PreviewProvider {
  static var previews: some View {
    SuperwallSubscriptionStatusView()
  }
}
