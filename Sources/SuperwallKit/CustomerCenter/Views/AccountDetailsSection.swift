//
//  AccountDetailsSection.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

#if canImport(WebKit)
import SwiftUI

struct AccountDetailsSection: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings
  @State private var copied = false
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Section {
      HStack {
        VStack(alignment: .leading) {
          Text(strings.string("customer_center_user_id"))
            .font(.caption)
            .foregroundStyle(Color.customerCenterSecondaryText)
          Text(viewModel.userId).font(.footnote).lineLimit(1).truncationMode(.middle)
        }
        Spacer()
        Button {
          #if os(macOS)
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(viewModel.userId, forType: .string)
          #else
          UIPasteboard.general.string = viewModel.userId
          #endif
          copied = true
        } label: {
          // At least 44 by 44 points to tap, keeping the text where it was.
          Text(strings.string(copied ? "customer_center_copied" : "customer_center_copy"))
            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .font(.footnote)
        .accessibilityIdentifier("customer_center.copy_user_id")
      }
      if let date = viewModel.originalDownloadDate {
        // Stacked at accessibility text sizes, so neither side breaks mid-word.
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading) {
            Text(strings.string("customer_center_original_download_date")).font(.footnote)
            Text(date, style: .date).font(.footnote).foregroundStyle(Color.customerCenterSecondaryText)
          }
        } else {
          HStack {
            Text(strings.string("customer_center_original_download_date")).font(.footnote)
            Spacer()
            Text(date, style: .date).font(.footnote).foregroundStyle(Color.customerCenterSecondaryText)
          }
        }
      }
    } header: {
      Text(strings.string("customer_center_account_details")).foregroundStyle(Color.customerCenterSecondaryText)
    }
  }
}
#endif
