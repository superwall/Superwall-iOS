//
//  TrackEventView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import Superwall

struct TrackEventView: View {
  @Binding var isLoggedIn: Bool
  @StateObject private var store = StoreKitService.shared
  private let model = TrackEventModel()

  init(isLoggedIn: Binding<Bool>) {
    _isLoggedIn = isLoggedIn
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
  }

  var body: some View {
    VStack(spacing: 48) {
      InfoView(
        text: "The button below tracks an event \"MyEvent\".\n\nThis event has been added as a trigger in a campaign on the Superwall dashboard.\n\nWhen this event is tracked, the trigger is fired, which evaluates the rules set in the campaign.\n\nThe rules match and cause a paywall to show."
      )

      Divider()
        .background(Color.primaryTeal)
        .padding()

      SuperwallSubscriptionStatusView()

      Spacer()

      VStack(spacing: 25) {
        BrandedButton(title: "Track event") {
          model.trackEvent()
        }
        BrandedButton(title: "Log Out") {
          Task {
            await model.logOut()
            isLoggedIn = false
          }
        }
      }
      .padding()
    }
    .frame(maxHeight: .infinity)
    .foregroundColor(.white)
    .background(Color.neutral)
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden()
    .navigationTitle("Hello \(SuperwallService.name)")
  }
}

struct TrackEventView_Previews: PreviewProvider {
  static var previews: some View {
    TrackEventView(isLoggedIn: .constant(false))
  }
}
