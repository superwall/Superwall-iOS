//
//  SuperwallEntitlementsView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI
import SuperwallKit

struct SuperwallEntitlementsView: View {
  @StateObject private var entitlements = Superwall.shared.entitlements // ensures entitlements is auto updating
  var text: String {
    // These are published properties that auto-update
    switch entitlements.status {
    case .unknown:
      return "Loading active entitlements."
    case .inactive:
      return "You do not have any active entitlements so the paywall will always show when tapping the button."
    case .active:
      return "You currently have an active entitlement. The audience filter is configured to only show a paywall if there are no entitlements so the paywall will never show. For the purposes of this app, delete and reinstall the app to clear entitlements."
    }
  }

  var body: some View {
    Text(text)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
      .lineSpacing(5)
  }
}

struct SuperwallEntitlementsView_Previews: PreviewProvider {
  static var previews: some View {
    SuperwallEntitlementsView()
  }
}
