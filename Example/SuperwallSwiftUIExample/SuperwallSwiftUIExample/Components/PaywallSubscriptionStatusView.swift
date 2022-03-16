//
//  PaywallSubscriptionStatusView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI

struct PaywallSubscriptionStatusView: View {
  @StateObject private var store = StoreKitService.shared

  var body: some View {
    Group {
      if store.isSubscribed {
        Text("You currently have an active subscription. Therefore, the paywall will not show when clicking this button. For the purposes of this app, delete and reinstall the app to clear subscriptions.")
      } else {
        Text("You do not have an active subscription so the paywall will show when clicking this button.")
      }
    }
    .multilineTextAlignment(.center)
    .padding(.horizontal)
    .lineSpacing(5)
  }
}

struct PaywallSubscriptionStatusView_Previews: PreviewProvider {
  static var previews: some View {
    PaywallSubscriptionStatusView()
  }
}
