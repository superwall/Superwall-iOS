//
//  WelcomeView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 14/03/2022.
//

import SwiftUI

struct WelcomeView: View {
  @Binding var isLoggedIn: Bool
  @State private var name: String = ""

  var body: some View {
    NavigationStack {
      ZStack {
        VStack(alignment: .center, spacing: 60) {
          logo()
          Spacer()
          Text("Welcome! Enter your name to get started. Your name will be added to the Superwall user attributes, which can then be accessed and displayed within your paywall.")
            .lineSpacing(5)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
          inputField()
          Spacer()
          logInButton()
        }
        .padding()
        .frame(maxHeight: .infinity)
        .background(Color.neutral)
      }
      .navigationDestination(isPresented: $isLoggedIn) {
        TrackEventView(isLoggedIn: $isLoggedIn)
      }
      .navigationBarHidden(true)
      .navigationTitle("")
    }
    .accentColor(.primaryTeal)
  }

  private func logo() -> some View {
    VStack(spacing: 0) {
      Image("logo")
        .resizable()
        .scaledToFit()
        .frame(width: 200)
      Text("Example app")
        .foregroundColor(.white)
        .italic()
    }
  }

  private func inputField() -> some View {
    TextField(
      "Enter your name",
      text: $name
    )
    .textContentType(.name)
    .textInputAutocapitalization(.never)
    .padding()
    .background(Color.white)
    .clipShape(Capsule())
  }

  @ViewBuilder
  private func logInButton() -> some View {
    BrandedButton(title: "Log In") {
      Task {
        SuperwallService.setName(to: name)
        await SuperwallService.logIn()
        isLoggedIn = true
      }
    }
  }
}

struct WelcomeView_Previews: PreviewProvider {
  static var previews: some View {
    WelcomeView(isLoggedIn: .constant(false))
  }
}
