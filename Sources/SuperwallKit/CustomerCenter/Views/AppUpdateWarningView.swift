//
//  AppUpdateWarningView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct AppUpdateWarningView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings
  @Environment(\.openURL) private var openURL

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Text(strings.string("customer_center_update_title")).font(.headline)
        Text(strings.string("customer_center_update_message")).font(.subheadline).foregroundStyle(.secondary)
        HStack {
          if let url = viewModel.appStoreURL {
            Button(strings.string("customer_center_update_action")) { openURL(url) }
              .buttonStyle(.borderedProminent)
              .accessibilityIdentifier("customer_center.update")
          }
          Button(strings.string("customer_center_update_continue")) { viewModel.continueAfterUpdateWarning() }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("customer_center.update_continue")
        }
      }
      .padding(.vertical, 4)
    }
  }
}
