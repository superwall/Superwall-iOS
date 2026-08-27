//
//  PathsListView.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct PathsListView: View {
  @ObservedObject var viewModel: CustomerCenterViewModel
  let purchase: PurchasePresentation?
  /// `true` for a screen's main action list; `false` on a drilled-in purchase detail screen.
  var isScreenLevel = true
  @Environment(\.customerCenterStrings) private var strings
  @State private var loadingPathId: String?

  var body: some View {
    ForEach(viewModel.paths(for: purchase, isScreenLevel: isScreenLevel)) { resolved in
      Button {
        guard loadingPathId == nil else { return }
        loadingPathId = resolved.id
        Task {
          await viewModel.select(resolved, purchase: purchase)
          loadingPathId = nil
        }
      } label: {
        // No disclosure chevron: a chevron promises a push onto the navigation stack, and every
        // path here either presents a sheet, acts in place, or leaves the app. The rows that do
        // push — "See all purchases" and the purchase detail rows — are `NavigationLink`s and get
        // their chevron from SwiftUI.
        HStack {
          Text(title(for: resolved))
          Spacer()
          if loadingPathId == resolved.id {
            ProgressView()
          }
        }
      }
      .disabled(loadingPathId != nil)
      .accessibilityIdentifier("customer_center.path.\(resolved.id)")
    }
  }

  private func title(for resolved: ResolvedPath) -> String {
    let path = resolved.path
    if let title = path.title { return title }
    switch path.type {
    case .restore: return strings.string("customer_center_path_restore")
    case .manageSubscription:
      // "Cancel subscription" is right for the App Store path, where the row carries the
      // cancellation survey and opens Apple's cancel sheet. A web management page does more than
      // cancel, so naming it that way there undersells it.
      return resolved.destination.isWebManagement
        ? strings.string("customer_center_path_manage_subscription_web")
        : strings.string("customer_center_path_manage_subscription")
    case .refund: return strings.string("customer_center_path_refund")
    case .changePlan: return strings.string("customer_center_path_change_plan")
    case .contactSupport: return strings.string("customer_center_path_contact_support")
    case .url(let url, _): return url.host ?? url.absoluteString
    case .custom(let identifier): return identifier
    }
  }
}
