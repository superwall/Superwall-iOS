//
//  TrackEventView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import SuperwallKit

struct TrackEventView: View {
  @Binding var isLoggedIn: Bool
  @State private var launchFeature = false

  init(isLoggedIn: Binding<Bool>) {
    _isLoggedIn = isLoggedIn
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
  }

  var body: some View {
    VStack(spacing: 48) {
      ScrollView {
        InfoView(
          text: "The Launch Feature button below registers an event \"campaign_trigger\".\n\nThis event has been added to a campaign on the Superwall dashboard.\n\nWhen this event is tracked, the rules in the campaign are evaluated.\n\nThe rules match and cause a paywall to show."
        )

        Divider()
          .background(Color.primaryTeal)
          .padding()

        SuperwallSubscriptionStatusView()
      }

      VStack(spacing: 25) {
        BrandedButton(title: "Launch Feature") {
          let handler = PaywallPresentationHandler()
          handler.onDismiss = { paywallInfo in
            print("The paywall dismissed. PaywallInfo:", paywallInfo)
          }
          handler.onPresent = { paywallInfo in
            print("The paywall presented. PaywallInfo:", paywallInfo)
          }
          handler.onError = { error in
            print("The paywall presentation failed with error \(error)")
          }
          Superwall.shared.register(event: "campaign_trigger", handler: handler) {
            // code in here can be remotely configured to execute. Either
            // (1) always after presentation or
            // (2) only if the user pays
            // code is always executed if no paywall is configured to show
            launchFeature = true
          }
        }
        BrandedButton(title: "Log Out") {
          Superwall.shared.reset()
          isLoggedIn = false
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
    .alert("Wrap your awesome features in register calls like this to remotely paywall your app. You can choose if these are paid features remotely.", isPresented: $launchFeature) {
      Button("OK", role: .cancel) { }
    }
  }
}

struct TrackEventView_Previews: PreviewProvider {
  static var previews: some View {
    TrackEventView(isLoggedIn: .constant(false))
  }
}
