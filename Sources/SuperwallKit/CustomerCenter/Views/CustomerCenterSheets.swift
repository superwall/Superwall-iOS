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

/// Rules the sheet bindings apply, as free functions so they can be exercised directly rather than
/// restated by a test.
enum CustomerCenterSheetOwnership {
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

/// What StoreKit's sheets are handed: the manage sheet's subscription group and the refund sheet's
/// transaction, as the sheet modifiers pass them.
///
/// StoreKit reads each from the render *before* the one that presents its sheet. Both come from
/// `sheet`, the same state that presents them, so presenting in the render they change in hands
/// StoreKit the previous value: no group, and the manage sheet opens with no subscriptions on it,
/// or transaction 0, and the refund request fails. So each sheet waits until the modifier has
/// rendered its parameter, which ``CustomerCenterViewModel/renderedStoreKitSheetParameters`` records.
struct StoreKitSheetParameters: Equatable {
  var manageGroupId = ""
  var refundTransactionId: UInt64 = 0
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
  /// present the same sheet. Only the screen that was on top when the sheet was requested
  /// presents it; see ``CustomerCenterViewModel/sheetOwnerDepth``. Gating the bindings rather than
  /// the modifier keeps the view tree stable — swapping modifiers mid-update is what stopped the
  /// manage sheet appearing once before.
  ///
  /// Only the getters are gated on ownership. The setters are gated on the sheet's identity
  /// instead, because the screen that presented a sheet must always be able to clear it, even
  /// after it has stopped owning it — popped with the sheet still up, say. A vetoed dismissal
  /// would leave `sheet` set and `sheetDidDismiss()` unrun.
  private var ownsSheet: Bool {
    viewModel.sheetOwnerDepth == surfaceDepth
  }

  var isManagePresented: Binding<Bool> {
    .init(
      get: {
        guard ownsSheet, case .manageSubscriptions = viewModel.sheet, hasRenderedStoreKitSheetParameters else {
          return false
        }
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
        guard ownsSheet, case .refund = viewModel.sheet, hasRenderedStoreKitSheetParameters else { return false }
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
        guard ownsSheet else { return nil }
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
  /// What this render hands StoreKit's sheets.
  private var storeKitSheetParameters: StoreKitSheetParameters {
    StoreKitSheetParameters(manageGroupId: manageGroupId ?? "", refundTransactionId: refundTransactionId)
  }
  /// Whether StoreKit's sheets have already been rendered with what this render hands them, so one
  /// may present. See `StoreKitSheetParameters`.
  private var hasRenderedStoreKitSheetParameters: Bool {
    storeKitSheetParameters == viewModel.renderedStoreKitSheetParameters
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
      // Records what the StoreKit sheets above have just been rendered with. A task rather than
      // `onChange`, so the record, and the presentation it lets through, arrives in an update of its
      // own instead of the one StoreKit reads from.
      .task(id: storeKitSheetParameters) { @MainActor [viewModel, storeKitSheetParameters] in
        guard viewModel.renderedStoreKitSheetParameters != storeKitSheetParameters else { return }
        viewModel.renderedStoreKitSheetParameters = storeKitSheetParameters
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
    // The branch must not depend on `groupId`. It is derived from `viewModel.sheet` and changes as
    // the sheet is about to present, and swapping which modifier is applied then tears down the one
    // that was about to present, so the sheet never appears. `#available` is constant for the
    // process, so branching on it is safe.
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
