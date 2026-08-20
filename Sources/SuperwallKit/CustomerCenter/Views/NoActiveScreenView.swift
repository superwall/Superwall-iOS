//
//  NoActiveScreenView.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct NoActiveScreenView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text(viewModel.configuration.noActiveScreen.title ?? strings.string("customer_center_no_active_title"))
            .font(.headline)
          Text(viewModel.configuration.noActiveScreen.subtitle ?? strings.string("customer_center_no_active_subtitle"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("customer_center.no_active")
      }
      Section { PathsListView(viewModel: viewModel, purchase: nil) }
      if viewModel.configuration.showsAccountDetails { AccountDetailsSection(viewModel: viewModel) }
    }
    .listStyle(.insetGrouped)
    .navigationBarTitleDisplayMode(.inline)
  }
}
