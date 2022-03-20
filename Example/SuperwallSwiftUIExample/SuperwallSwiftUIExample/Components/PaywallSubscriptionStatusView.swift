//
//  PaywallSubscriptionStatusView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI

struct PaywallSubscriptionStatusView: View {
  var presentationType: PresentationType
  @StateObject private var store = StoreKitService.shared
  var text: String {
    return PaywallSubscriptionStatusLogic.text(
      forPresentationType: presentationType,
      isSubscribed: store.isSubscribed
    )
  }

  var body: some View {
    Text(text)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
      .lineSpacing(5)
  }
}

struct PaywallSubscriptionStatusView_Previews: PreviewProvider {
  static var previews: some View {
    PaywallSubscriptionStatusView(presentationType: .presented)
  }
}
