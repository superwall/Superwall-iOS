//
//  SuperwallSubscriptionStatusView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI

struct SuperwallSubscriptionStatusView: View {
  @StateObject private var store = StoreKitService.shared
  var text: String {
    return SuperwallSubscriptionStatusLogic.text(
      isSubscribed: store.isSubscribed.value
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
