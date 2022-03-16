//
//  WelcomeView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 14/03/2022.
//

import SwiftUI

struct WelcomeView: View {
  @State private var name: String = ""
  @State private var showTableView = false

  var body: some View {
    NavigationView {
      ZStack {
        VStack(alignment: .center, spacing: 60) {
          logo()
          Spacer()
          Text("Welcome! Enter your name to get started. Your name will be added to the Paywall user attributes, which can then be accessed and displayed within your paywall.")
            .lineSpacing(5)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
          inputField()
          Spacer()
          signInButton()
        }
        .padding()
        .frame(maxHeight: .infinity)
        .background(Color.neutral)

        NavigationLink(
          isActive: $showTableView,
          destination: {
            PaywallOptionsTableView()
          },
          label: {
            EmptyView()
          }
        ).hidden()
      }
      .navigationBarHidden(true)
      .navigationTitle("")
    }
    .navigationViewStyle(.stack)
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
  private func signInButton() -> some View {
    BrandedButton(title: "Continue") {
      PaywallService.setName(to: name)
      showTableView = true
    }
  }
}

struct WelcomeView_Previews: PreviewProvider {
  static var previews: some View {
    WelcomeView()
  }
}
