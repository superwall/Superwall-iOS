//
//  PresentationTypeListView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI

struct PaywallNavigationView: View {
  init() {
    UITableView.appearance().backgroundColor = .neutral
    UINavigationBar.appearance().largeTitleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
  }

  var body: some View {
    NavigationView {
      VStack {
        Image("logo")
          .resizable()
          .scaledToFit()
          .frame(width: 200)
        Text("Demo app")
          .foregroundColor(.white)
          .italic()

        List {
          NavigationLink(destination: PresentPaywallView()) {
            Text("Presenting a Paywall")
              .padding()
          }
          NavigationLink(destination: TriggerPaywallView()) {
            Text("Triggering a Paywall")
              .padding()
          }
        }
        .listRowBackground(Color.neutral)

        Spacer()
      }
      .background(Color.neutral)
      .navigationBarHidden(true)
      .navigationTitle("")
    }
    .navigationViewStyle(.stack)
    .accentColor(.primaryTeal)
  }
}

struct PaywallNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    PaywallNavigationView()
  }
}
