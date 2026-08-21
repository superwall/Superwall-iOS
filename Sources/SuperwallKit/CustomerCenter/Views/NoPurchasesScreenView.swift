//
//  NoPurchasesScreenView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct NoPurchasesScreenView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings

  var body: some View {
    List {
      Section {
        let screen = viewModel.configuration.noPurchasesScreen
        VStack(alignment: .leading, spacing: 6) {
          Text(screen.title ?? strings.string("customer_center_no_purchases_title"))
            .font(.headline)
          Text(screen.subtitle ?? strings.string("customer_center_no_purchases_subtitle"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("customer_center.no_purchases")
      }
      Section { PathsListView(viewModel: viewModel, purchase: nil) }
      if viewModel.configuration.showsAccountDetails { AccountDetailsSection(viewModel: viewModel) }
    }
    .listStyle(.insetGrouped)
    .navigationBarTitleDisplayMode(.inline)
  }
}
