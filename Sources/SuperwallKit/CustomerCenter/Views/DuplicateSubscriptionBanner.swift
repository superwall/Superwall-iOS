//
//  DuplicateSubscriptionBanner.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct DuplicateSubscriptionBanner: View {
  @Environment(\.customerCenterStrings) private var strings
  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        Label(strings.string("customer_center_duplicate_title"), systemImage: "exclamationmark.triangle.fill")
          .font(.headline)
        Text(strings.string("customer_center_duplicate_message")).font(.subheadline).foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
      .accessibilityIdentifier("customer_center.duplicate_warning")
    }
  }
}
