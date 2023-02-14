//
//  SuperwallSubscriptionStatusView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI
import SuperwallKit

struct SuperwallSubscriptionStatusView: View {
  @StateObject private var superwall = Superwall.shared
  var text: String {
    return SuperwallSubscriptionStatusLogic.text(
      subscriptionStatus: superwall.subscriptionStatus
    )
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
