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

    /// Whether `sheet` is this kind of sheet.
    func matches(_ sheet: CustomerCenterSheet?) -> Bool {
      switch (sheet, self) {
      case (.manageSubscriptions, .manageSubscriptions), (.refund, .refund): return true
      default: return false
      }
    }
  }

  /// Whether a `false` write from a boolean sheet binding should clear `sheet`.
  ///
  /// SwiftUI writes `false` when the sheet that binding drives goes away — but it also writes it
  /// when the *getter* flips false for another reason: a different sheet was requested, or the
  /// screen stopped owning the sheet. Clearing unconditionally therefore lets one binding tear
  /// down the sheet another has just opened, and run `sheetDidDismiss()` — receipt refresh
  /// included — against a sheet that was never showing. Only the sheet actually up may clear
  /// itself.
  static func dismissalClears(_ current: CustomerCenterSheet?, _ kind: SheetKind) -> Bool {
    kind.matches(current)
  }
}

/// What StoreKit's sheets are handed: the manage sheet's subscription group and the refund sheet's
/// transaction. The modifier hands StoreKit these values and no others, so the gate that holds a
/// sheet back compares against exactly what StoreKit was given.
///
/// StoreKit reads each from the render *before* the one that presents its sheet. Both come from
/// `sheet`, the same state that presents them, so presenting in the render they change in hands
/// StoreKit the previous value: no group, and the manage sheet opens with no subscriptions on it,
/// or transaction 0, and the refund request fails. So each sheet waits until the modifier has
/// rendered its parameter, which `StoreKitSheetRenderRecord` records.
struct StoreKitSheetParameters: Equatable {
  /// Empty when the request has no subscription group.
  var manageGroupId = ""
  var refundTransactionId: UInt64 = 0

  init(manageGroupId: String = "", refundTransactionId: UInt64 = 0) {
    self.manageGroupId = manageGroupId
    self.refundTransactionId = refundTransactionId
  }

  /// What `sheet` hands StoreKit's sheets.
  init(for sheet: CustomerCenterSheet?) {
    switch sheet {
    case .manageSubscriptions(let groupId):
      self.init(manageGroupId: groupId ?? "")
    case let .refund(transactionId, _):
      self.init(refundTransactionId: transactionId)
    default:
      self.init()
    }
  }
}

/// What one surface last rendered into StoreKit's sheets.
///
/// Per surface rather than on the view model: it changes on the way into every StoreKit sheet and
/// on the way out, and on the view model each change re-rendered the whole Customer Center rather
/// than the one modifier that reads it.
final class StoreKitSheetRenderRecord: ObservableObject {
  @Published var parameters = StoreKitSheetParameters()
}

/// Internal rather than private so a test can drive the sheet bindings directly. The gate they
/// apply has been wrong twice — once inert, once over-eager — and both times the bug was in the
/// binding rather than in the rule it calls, which a test of the rule alone cannot catch.
@available(iOS 15.0, *)
struct CustomerCenterSheetsModifier: ViewModifier {
  @ObservedObject var viewModel: CustomerCenterViewModel
  let surfaceDepth: Int
  @StateObject private var rendered: StoreKitSheetRenderRecord
  @Environment(\.customerCenterStrings) private var strings

  /// - Parameter rendered: Where this surface records what it rendered into StoreKit's sheets.
  ///   A test supplies one to read back; otherwise the modifier keeps its own.
  init(
    viewModel: CustomerCenterViewModel,
    surfaceDepth: Int,
    rendered: StoreKitSheetRenderRecord? = nil
  ) {
    _viewModel = ObservedObject(wrappedValue: viewModel)
    self.surfaceDepth = surfaceDepth
    _rendered = StateObject(wrappedValue: rendered ?? StoreKitSheetRenderRecord())
  }

  /// Every screen still in the stack applies this modifier, so without a check they'd all try to
  /// present the same sheet. Only the screen that was on top when the sheet was requested
  /// presents it; see ``CustomerCenterViewModel/sheetOwnerDepth``. Gating the bindings rather than
  /// the modifier keeps the view tree stable — swapping modifiers mid-update is what stopped the
  /// manage sheet appearing once before.
  ///
  /// Only the getters are gated on ownership. A setter only has to know that a write is about the
  /// sheet that's actually up; see ``CustomerCenterSheetOwnership/dismissalClears(_:_:)``.
  private var ownsSheet: Bool {
    viewModel.sheetOwnerDepth == surfaceDepth
  }

  var isManagePresented: Binding<Bool> {
    storeKitSheetBinding(.manageSubscriptions, rendered: rendered.parameters) { viewModel in
      Task { await viewModel.sheetDidDismiss() }
    }
  }

  /// The refund's outcome arrives through the sheet's completion rather than its dismissal.
  var refundBinding: Binding<Bool> {
    storeKitSheetBinding(.refund, rendered: rendered.parameters)
  }

  /// The binding one of StoreKit's sheets presents from.
  ///
  /// - Parameters:
  ///   - rendered: What this surface last rendered into StoreKit's sheets. Evaluated only once
  ///     everything else says the sheet is due: it reads a `@StateObject`, which only exists once
  ///     the modifier is installed, so a test drives the binding with a value of its own.
  ///   - afterDismissal: Runs once the sheet this binding presented has closed and been cleared.
  func storeKitSheetBinding(
    _ kind: CustomerCenterSheetOwnership.SheetKind,
    rendered: @autoclosure @escaping () -> StoreKitSheetParameters,
    afterDismissal: @escaping @MainActor (CustomerCenterViewModel) -> Void = { _ in }
  ) -> Binding<Bool> {
    .init(
      get: {
        ownsSheet
          && kind.matches(viewModel.sheet)
          && rendered() == StoreKitSheetParameters(for: viewModel.sheet)
      },
      set: { [viewModel] isPresented in
        Self.onMainThread {
          guard !isPresented, CustomerCenterSheetOwnership.dismissalClears(viewModel.sheet, kind) else { return }
          viewModel.sheet = nil
          afterDismissal(viewModel)
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
  private var onItemSheetDismiss: () -> Void {
    {
      if viewModel.pendingSurvey != nil { viewModel.cancelSurvey() }
      Task { await viewModel.sheetDidDismiss() }
    }
  }

  func body(content: Content) -> some View {
    let parameters = StoreKitSheetParameters(for: viewModel.sheet)
    content
      .modifier(ManageSubscriptionsSheet(isPresented: isManagePresented, groupId: parameters.manageGroupId))
      .refundRequestSheet(for: parameters.refundTransactionId, isPresented: refundBinding) { result in
        let status: CustomerCenterRefundStatus
        switch result {
        case .success(.success): status = .success
        case .success(.userCancelled): status = .userCancelled
        case .success: status = .error
        case .failure: status = .error
        }
        Task { await viewModel.refundRequestDidFinish(status: status) }
      }
      // Records what the StoreKit sheets above were just rendered with. The write lands after that
      // render, so the presentation it lets through comes in a later update than the one StoreKit
      // took its parameter from. `onChange` would land at the same point; a task is used because
      // it also runs for the value a surface first appears with, which `onChange` only does from
      // iOS 17.
      .task(id: parameters) { @MainActor [rendered] in
        guard rendered.parameters != parameters else { return }
        rendered.parameters = parameters
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

/// Internal so a test can check which of StoreKit's manage sheets a request goes to.
@available(iOS 15.0, *)
struct ManageSubscriptionsSheet: ViewModifier {
  let isPresented: Binding<Bool>
  /// Empty when the request has no subscription group.
  let groupId: String

  /// The manage sheet without a group. StoreKit's group variant, available from iOS 17, opens on
  /// "You don't have any subscriptions" when handed an empty group, rather than on the customer's
  /// subscriptions. That's observed in the StoreKit test environment; Apple doesn't document what
  /// either variant does with an empty group. So a request with no group comes here, as every
  /// request does before iOS 17.
  var plainSheetIsPresented: Binding<Bool> { isPresented.only(when: groupId.isEmpty) }
  /// The manage sheet opened on `groupId`.
  var groupSheetIsPresented: Binding<Bool> { isPresented.only(when: !groupId.isEmpty) }

  func body(content: Content) -> some View {
    // Nothing here may branch on `groupId`. It is derived from `viewModel.sheet` and changes as the
    // sheet is about to present, and swapping which modifier is applied then tears down the one
    // that was about to present, so the sheet never appears. Both variants are applied instead,
    // and only one can be presented. `#available` is constant for the process, so branching on it
    // is safe.
    if #available(iOS 17.0, *) {
      content
        .manageSubscriptionsSheet(isPresented: plainSheetIsPresented)
        .manageSubscriptionsSheet(isPresented: groupSheetIsPresented, subscriptionGroupID: groupId)
    } else {
      content.manageSubscriptionsSheet(isPresented: isPresented)
    }
  }
}

private extension Binding where Value == Bool {
  /// This binding while `condition` holds. Otherwise a sheet that is never presented and whose
  /// writes go nowhere, so it can't dismiss the sheet that is.
  func only(when condition: Bool) -> Binding<Bool> {
    Binding(
      get: { condition && wrappedValue },
      set: { newValue in
        if condition { wrappedValue = newValue }
      }
    )
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
