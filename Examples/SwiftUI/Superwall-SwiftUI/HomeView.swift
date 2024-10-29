//
//  HomeView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import SuperwallKit

struct HomeView: View {
  @Binding var isLoggedIn: Bool
  @State private var launchFeature = false

  init(isLoggedIn: Binding<Bool>) {
    _isLoggedIn = isLoggedIn
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
  }

  var firstName: String {
    Superwall.shared.userAttributes["firstName"] as? String ?? ""
  }

  var body: some View {
    VStack(spacing: 48) {
      ScrollView {
        InfoView(
          text: "The Launch Feature button below registers a placement \"campaign_trigger\".\n\nThis placement has been added to a campaign on the Superwall dashboard.\n\nWhen this placement is registered, the audience filters in the campaign are evaluated.\n\nThe audience matches and causes a paywall to show."
        )

        Divider()
          .background(Color.primaryTeal)
          .padding()

        SuperwallEntitlementsView()
      }

      VStack(spacing: 25) {
        BrandedButton(title: "Launch Feature") {
          let handler = PaywallPresentationHandler()
          handler.onDismiss { paywallInfo, paywallResult in
            print("The paywall dismissed. PaywallInfo: \(paywallInfo), PaywallResult: \(paywallResult)")
          }
          handler.onPresent { paywallInfo in
            print("The paywall presented. PaywallInfo:", paywallInfo)
          }
          handler.onError { error in
            print("The paywall presentation failed with error \(error)")
          }
          handler.onSkip { reason in
            switch reason {
            case .holdout(let experiment):
              print("Paywall not shown because user is in a holdout group in Experiment: \(experiment.id)")
            case .noAudienceMatch:
              print("Paywall not shown because user doesn't match any audience.")
            case .placementNotFound:
              print("Paywall not shown because this placement isn't part of a campaign.")
            }
          }

          Superwall.shared.register(placement: "campaign_trigger", handler: handler) {
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
    .navigationTitle("Hello \(firstName)")
    .alert(
      "Launched Feature",
      isPresented: $launchFeature,
      actions: {
        Button("OK", role: .cancel) {}
      },
      message: {
        Text("Wrap your awesome features in register calls like this to remotely paywall your app. You can remotely decide whether these are paid features.")
      }
    )
  }
}

struct HomeView_Previews: PreviewProvider {
  static var previews: some View {
    HomeView(isLoggedIn: .constant(false))
  }
}
