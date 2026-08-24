//
//  AccountDetailsSection.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct AccountDetailsSection: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings
  @State private var copied = false

  var body: some View {
    Section(strings.string("customer_center_account_details")) {
      HStack {
        VStack(alignment: .leading) {
          Text(strings.string("customer_center_user_id")).font(.caption).foregroundStyle(.secondary)
          Text(viewModel.userId).font(.footnote).lineLimit(1).truncationMode(.middle)
        }
        Spacer()
        Button(strings.string(copied ? "customer_center_copied" : "customer_center_copy")) {
          UIPasteboard.general.string = viewModel.userId
          copied = true
        }
        .font(.footnote)
        .accessibilityIdentifier("customer_center.copy_user_id")
      }
      if let date = viewModel.originalDownloadDate {
        HStack {
          Text(strings.string("customer_center_original_download_date")).font(.footnote)
          Spacer()
          Text(date, style: .date).font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
  }
}
