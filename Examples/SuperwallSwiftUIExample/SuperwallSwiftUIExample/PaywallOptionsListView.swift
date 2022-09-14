//
//  PaywallOptionsListView.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 15/03/2022.
//

import SwiftUI
import UIKit

struct PaywallOptionsListView: View {
  @Binding var path: [Destination]

  init(path: Binding<[Destination]>) {
    self._path = path
    UITableView.appearance().backgroundColor = .neutral
  }

  var body: some View {
    List {
      Button(
        action: {
          path.append(.explicit)
        },
        label: {
          Text("Explicitly Triggering a Paywall")
            .padding()
        }
      )

      Button(
        action: {
          path.append(.implicit)
        },
        label: {
          Text("Implicitly Triggering a Paywall")
            .padding()
        }
      )
    }
    .foregroundColor(.neutral)
    .scrollDisabled(true)
    .scrollContentBackground(.hidden)
    .listRowBackground(Color.neutral)
  }
}

struct PaywallOptionsListView_Previews: PreviewProvider {
  static var previews: some View {
    PaywallOptionsListView(path: .constant([]))
  }
}
