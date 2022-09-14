//
//  PaywallOptionsListView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI
import UIKit

struct PaywallOptionsListView: View {
  init() {
    UITableView.appearance().backgroundColor = .neutral
  }

  var body: some View {
    List {
      NavigationLink(destination: ExplicitlyTriggerPaywallView()) {
        Text("Explicitly Triggering a Paywall")
          .padding()
      }
      NavigationLink(destination: ImplicitlyTriggerPaywallView()) {
        Text("Implicitly Triggering a Paywall")
          .padding()
      }
    }
    .scrollDisabled(true)
    .scrollContentBackground(.hidden)
    .listRowBackground(Color.neutral)
  }
}

struct PaywallOptionsListView_Previews: PreviewProvider {
  static var previews: some View {
    PaywallOptionsListView()
  }
}
