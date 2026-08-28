//
//  CustomerCenterSheets.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import SafariServices
import StoreKit
import SwiftUI

@available(iOS 15.0, *)
extension View {
  func customerCenterSheets(viewModel: CustomerCenterViewModel) -> some View {
    modifier(CustomerCenterSheetsModifier(viewModel: viewModel))
  }
}

@available(iOS 15.0, *)
private struct CustomerCenterSheetsModifier: ViewModifier {
  @ObservedObject var viewModel: CustomerCenterViewModel
  @Environment(\.customerCenterStrings) private var strings
  @Environment(\.customerCenterSurfaceDepth) private var depth

  /// Every screen still in the stack applies this modifier, so without a check they'd all try to
  /// present the same sheet. Gating the bindings rather than the modifier keeps the view tree
  /// stable — swapping modifiers mid-update is what stopped the manage sheet appearing once
  /// before.
  private var isTopmost: Bool { depth == viewModel.pushDepth }

  private var isManagePresented: Binding<Bool> {
    .init(
      get: { if case .manageSubscriptions = viewModel.sheet { return true } else { return false } },
      set: { if !$0 { viewModel.sheet = nil; Task { await viewModel.sheetDidDismiss() } } }
    )
  }
  private var refundBinding: Binding<Bool> {
    .init(
      get: { if case .refund = viewModel.sheet { return true } else { return false } },
      set: { if !$0, case .refund = viewModel.sheet { viewModel.sheet = nil } }
    )
  }
  private var itemSheet: Binding<CustomerCenterSheet?> {
    .init(
      get: {
        switch viewModel.sheet {
        case .survey, .changePlan, .safari, .noMailApp, .webManageUnavailable: return viewModel.sheet
        default: return nil
        }
      },
      set: { viewModel.sheet = $0 }
    )
  }
  private var manageGroupId: String? {
    if case .manageSubscriptions(let id) = viewModel.sheet { return id }
    return nil
  }
  private var refundTransactionId: UInt64 {
    if case .refund(let id, _) = viewModel.sheet { return id }
    return 0
  }
  private var refundProductId: String {
    if case .refund(_, let pid) = viewModel.sheet { return pid }
    return ""
  }
  private var onItemSheetDismiss: () -> Void {
    {
      if viewModel.pendingSurvey != nil { viewModel.cancelSurvey() }
      Task { await viewModel.sheetDidDismiss() }
    }
  }

  func body(content: Content) -> some View {
    content
      .modifier(ManageSubscriptionsSheet(isPresented: isManagePresented, groupId: manageGroupId))
      .refundRequestSheet(for: refundTransactionId, isPresented: refundBinding) { result in
        let status: CustomerCenterRefundStatus
        switch result {
        case .success(.success): status = .success
        case .success(.userCancelled): status = .userCancelled
        case .success: status = .error
        case .failure: status = .error
        }
        let productId = refundProductId
        Task { await viewModel.refundSheetDidFinish(productId: productId, status: status) }
      }
      .sheet(item: itemSheet, onDismiss: onItemSheetDismiss) { sheet in
        switch sheet {
        case .survey:
          FeedbackSurveyView(viewModel: viewModel)
        case let .changePlan(groupId, productIds):
          ChangePlanSheet(groupId: groupId, productIds: productIds)
        case .safari(let url):
          SafariView(url: url).ignoresSafeArea()
        case .noMailApp(let email):
          Text(strings.string("customer_center_no_mail_app", email)).padding()
        case .webManageUnavailable:
          Text(strings.string("customer_center_web_manage_unavailable")).padding()
        default:
          EmptyView()
        }
      }
  }
}

@available(iOS 15.0, *)
private struct ManageSubscriptionsSheet: ViewModifier {
  let isPresented: Binding<Bool>
  let groupId: String?
  func body(content: Content) -> some View {
    // The branch must not depend on `groupId`. It is derived from `viewModel.sheet`, so it becomes
    // non-nil in the very same update that flips `isPresented` to true — and swapping which
    // modifier is applied during that update tears down the one that was about to present, so the
    // sheet never appears. `#available` is constant for the process, so branching on it is safe.
    if #available(iOS 17.0, *) {
      content.manageSubscriptionsSheet(
        isPresented: isPresented,
        subscriptionGroupID: groupId ?? ""
      )
    } else {
      content.manageSubscriptionsSheet(isPresented: isPresented)
    }
  }
}

@available(iOS 15.0, *)
private struct ChangePlanSheet: View {
  let groupId: String?
  let productIds: [String]?
  var body: some View {
    if #available(iOS 17.0, *) {
      if let productIds, productIds.count >= 2 {
        SubscriptionStoreView(productIDs: productIds)
      } else if let groupId {
        SubscriptionStoreView(groupID: groupId)
      } else {
        EmptyView()
      }
    } else {
      EmptyView()  // resolver hides changePlan below iOS 17
    }
  }
}

struct SafariView: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
