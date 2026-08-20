//
//  PathsListView.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct PathsListView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  let purchase: PurchasePresentation?
  @Environment(\.customerCenterStrings) private var strings
  @State private var loadingPathId: String?

  var body: some View {
    ForEach(viewModel.paths(for: purchase)) { resolved in
      Button {
        guard loadingPathId == nil else { return }
        loadingPathId = resolved.id
        Task {
          await viewModel.select(resolved, purchase: purchase)
          loadingPathId = nil
        }
      } label: {
        HStack {
          Text(title(for: resolved.path))
          Spacer()
          if loadingPathId == resolved.id {
            ProgressView()
          } else {
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
          }
        }
      }
      .disabled(loadingPathId != nil)
      .accessibilityIdentifier("customer_center.path.\(resolved.id)")
    }
  }

  private func title(for path: CustomerCenterConfiguration.Path) -> String {
    if let title = path.title { return title }
    switch path.type {
    case .restore: return strings.string("customer_center_path_restore")
    case .manageSubscription: return strings.string("customer_center_path_manage_subscription")
    case .refund: return strings.string("customer_center_path_refund")
    case .changePlan: return strings.string("customer_center_path_change_plan")
    case .contactSupport: return strings.string("customer_center_path_contact_support")
    case .url(let url, _): return url.host ?? url.absoluteString
    case .custom(let identifier): return identifier
    }
  }
}
