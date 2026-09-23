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
  /// - Parameter surfaceDepth: How deep this screen sits in the Customer Center's own pushed
  ///   stack; `0` for the root. Passed rather than read from the environment because a modifier
  ///   resolves its `@Environment` against the values *above* it, so a caller that applied this
  ///   outside its `.environment(...)` writes would silently read the default and the gate would
  ///   stop working.
  func customerCenterSheets(viewModel: CustomerCenterViewModel, surfaceDepth: Int = 0) -> some View {
    modifier(CustomerCenterSheetsModifier(viewModel: viewModel, surfaceDepth: surfaceDepth))
  }
}

/// Which surface owns sheet presentation. A free function so the rule the modifier applies can be
/// exercised directly rather than restated by a test.
enum CustomerCenterSheetOwnership {
  static func isTopmost(surfaceDepth: Int, pushDepth: Int) -> Bool {
    surfaceDepth == pushDepth
  }

  /// The kind of sheet a boolean binding stands for. `CustomerCenterSheet`'s own cases carry
  /// associated values, and a dismissal only needs to know which case it belongs to.
  enum SheetKind {
    case manageSubscriptions
    case refund
  }

  /// Whether a `false` write from a boolean sheet binding should clear `sheet`.
  ///
  /// SwiftUI writes `false` when the sheet that binding drives goes away — but it also writes it
  /// when the *getter* flips false for another reason, which happens to every surface that stops
  /// being topmost. Clearing unconditionally therefore lets a covered screen tear down the sheet
  /// the visible one just opened, and run `sheetDidDismiss()` — receipt refresh included —
  /// against a sheet that was never showing. Only the sheet actually up may clear itself.
  static func dismissalClears(_ current: CustomerCenterSheet?, _ kind: SheetKind) -> Bool {
    switch (current, kind) {
    case (.manageSubscriptions, .manageSubscriptions), (.refund, .refund): return true
    default: return false
    }
  }
}

/// Internal rather than private so a test can drive the sheet bindings directly. The gate they
/// apply has been wrong twice — once inert, once over-eager — and both times the bug was in the
/// binding rather than in the rule it calls, which a test of the rule alone cannot catch.
@available(iOS 15.0, *)
struct CustomerCenterSheetsModifier: ViewModifier {
  @ObservedObject var viewModel: CustomerCenterViewModel
  let surfaceDepth: Int
  @Environment(\.customerCenterStrings) private var strings

  /// Every screen still in the stack applies this modifier, so without a check they'd all try to
  /// present the same sheet. Gating the bindings rather than the modifier keeps the view tree
  /// stable — swapping modifiers mid-update is what stopped the manage sheet appearing once
  /// before.
  ///
  /// Only the getters are gated on depth. The setters are gated on the sheet's identity instead:
  /// gating them on depth too would let a screen lose the right to clear a sheet it already has
  /// open, since the depth drops when the screen is popped without regard for whether a sheet is
  /// up — the dismissal would be vetoed, `sheetDidDismiss()` would never run, and the root would
  /// re-present the stale sheet the moment it became topmost again.
  private var isTopmost: Bool {
    CustomerCenterSheetOwnership.isTopmost(
      surfaceDepth: surfaceDepth,
      pushDepth: viewModel.pushDepth
    )
  }

  var isManagePresented: Binding<Bool> {
    .init(
      get: {
        guard isTopmost, case .manageSubscriptions = viewModel.sheet else { return false }
        return true
      },
      set: { [viewModel] isPresented in
        Self.onMainThread {
          guard
            !isPresented,
            CustomerCenterSheetOwnership.dismissalClears(viewModel.sheet, .manageSubscriptions)
          else {
            return
          }
          viewModel.sheet = nil
          Task { await viewModel.sheetDidDismiss() }
        }
      }
    )
  }
  var refundBinding: Binding<Bool> {
    .init(
      get: {
        // Held back until StoreKit has been handed the transaction — see
        // `renderedRefundTransactionId`.
        guard
          isTopmost,
          case .refund(let transactionId, _) = viewModel.sheet,
          transactionId == viewModel.renderedRefundTransactionId
        else {
          return false
        }
        return true
      },
      set: { [viewModel] isPresented in
        Self.onMainThread {
          guard !isPresented, CustomerCenterSheetOwnership.dismissalClears(viewModel.sheet, .refund) else { return }
          viewModel.sheet = nil
        }
      }
    )
  }

  /// StoreKit writes the `isPresented` bindings of its sheet modifiers from the background thread
  /// its presentation finishes on. The view model is main-actor state that SwiftUI observes, and
  /// publishing it from there is what Xcode reports as "Publishing changes from background threads
  /// is not allowed". SwiftUI's own writes arrive on the main thread and are applied at once:
  /// deferring those as well would leave the getter saying the sheet is up after SwiftUI has been
  /// told it isn't.
  nonisolated static func onMainThread(_ work: @escaping @MainActor () -> Void) {
    guard Thread.isMainThread else {
      Task { @MainActor in work() }
      return
    }
    MainActor.assumeIsolated(work)
  }
  private var itemSheet: Binding<CustomerCenterSheet?> {
    .init(
      get: {
        guard isTopmost else { return nil }
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
        Task { await viewModel.refundRequestDidFinish(status: status) }
      }
      // Reports the transaction once the refund sheet above has rendered with it. A task rather
      // than `onChange`, so the report — and the presentation it lets through — arrives in an
      // update of its own instead of the one StoreKit is still reading.
      .task(id: refundTransactionId) { @MainActor [viewModel, refundTransactionId] in
        guard viewModel.renderedRefundTransactionId != refundTransactionId else { return }
        viewModel.renderedRefundTransactionId = refundTransactionId
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
