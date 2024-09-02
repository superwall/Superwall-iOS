//
//  SuperwallSubscriptionStatusView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI
import SuperwallKit

struct SuperwallSubscriptionStatusView: View {
  @StateObject private var entitlements = Superwall.shared.entitlements // ensures didSetActiveEntitlements is auto updating
  var text: String {
    if entitlements.didSetActiveEntitlements {
      if entitlements.active.isEmpty {
        return "You do not have any active entitlements so the paywall will always show when tapping the button."
      } else {
        return "You currently have an active entitlement. The audience filter is configured to only show a paywall if there are no entitlements so the paywall will never show. For the purposes of this app, delete and reinstall the app to clear entitlements."
      }
    } else {
      return "Loading active entitlements."
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
