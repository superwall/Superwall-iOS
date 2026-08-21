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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
          Button(strings.string("customer_center_update_continue")) {
            // Animated here rather than in the view model so the banner's removal from the list
            // is part of the same transaction. `withAnimation(nil)` runs the change unanimated,
            // which is what Reduce Motion should get.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
              viewModel.continueAfterUpdateWarning()
            }
          }
          .buttonStyle(.bordered)
          .accessibilityIdentifier("customer_center.update_continue")
        }
      }
      .padding(.vertical, 4)
    }
  }
}
