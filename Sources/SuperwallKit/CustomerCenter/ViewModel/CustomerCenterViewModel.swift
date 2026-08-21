//
//  CustomerCenterViewModel.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Combine
import Foundation

/// Drives the Customer Center UI: loads customer info and products, resolves paths, and performs actions.
@available(iOS 15.0, *)
@MainActor
final class CustomerCenterViewModel: ObservableObject {
  typealias PendingSurvey = (path: CustomerCenterConfiguration.Path, survey: CustomerCenterConfiguration.FeedbackSurvey)
  typealias PendingAction = (resolved: ResolvedPath, purchase: PurchasePresentation?)

  @Published private(set) var state: CustomerCenterScreenState = .loading
  @Published private(set) var purchases: [PurchasePresentation] = []
  @Published var sheet: CustomerCenterSheet? {
    didSet { if let sheet { lastPresentedSheet = sheet } }
  }
  @Published var restoreState: CustomerCenterRestoreState = .idle
  @Published private(set) var refundResult: (productId: String, status: CustomerCenterRefundStatus)?
  @Published private(set) var showsUpdateBanner = false
  @Published private(set) var showsDuplicateBanner = false

  let configuration: CustomerCenterConfiguration
  let strings: CustomerCenterStrings
  var callbacks = CustomerCenterCallbacks()
  var presentationMode = "sheet"
  private(set) var pendingSurvey: PendingSurvey?

  private let dependencies: CustomerCenterDependencies
  private let dismissDebounceInterval: TimeInterval
  private let isChangePlanSheetAvailable: Bool
  private var products: [String: ProductDisplayInfo] = [:]
  private var familyShared: Set<String> = []
  private var pendingAction: PendingAction?
  /// An action deferred from `answerSurvey` until the survey sheet has finished dismissing.
  /// Performing it immediately would present a new sheet while the old one is still animating
  /// out, which iOS 15/16 can silently drop.
  private var pendingActionAfterSheetDismiss: PendingAction?
  /// The most recent non-nil ``sheet``, so ``sheetDidDismiss()`` knows whether the sheet that
  /// just closed was a StoreKit store sheet requiring a receipt refresh.
  private var lastPresentedSheet: CustomerCenterSheet?
  private var updateWarningDismissed = false
  private var hasTrackedOpen = false
  private var didDismiss = false
  private var cancellables = Set<AnyCancellable>()

  /// Number of Customer Center surfaces (root + any pushed screens) currently on screen.
  /// Incremented/decremented by ``surfaceDidAppear()``/``surfaceDidDisappear()``. When this
  /// reaches zero and stays zero past the debounce, the Customer Center is genuinely gone.
  private var visibleSurfaceCount = 0
  private var dismissDebounceTask: Task<Void, Never>?

  init(
    configuration: CustomerCenterConfiguration,
    dependencies: CustomerCenterDependencies,
    strings: CustomerCenterStrings,
    isChangePlanSheetAvailable: Bool? = nil,
    // Comfortably longer than a UINavigationController push/pop (~0.35s). During a pop the
    // outgoing screen's `onDisappear` can land before the root's `onAppear`, so the count dips to
    // zero mid-transition; the debounce has to outlast that or a dismissal fires while the user is
    // still inside. Only delays how soon `didDismiss` reaches the host, which nothing is gated on.
    dismissDebounceInterval: TimeInterval = 0.6
  ) {
    self.configuration = configuration
    self.dependencies = dependencies
    self.strings = strings
    self.dismissDebounceInterval = dismissDebounceInterval
    if let isChangePlanSheetAvailable {
      self.isChangePlanSheetAvailable = isChangePlanSheetAvailable
    } else if #available(iOS 17.0, *) {
      self.isChangePlanSheetAvailable = true
    } else {
      self.isChangePlanSheetAvailable = false
    }
    dependencies.customerInfo.customerInfoPublisher
      .dropFirst()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] info in
        guard let self else { return }
        Task { await self.apply(customerInfo: info, refetchProducts: true) }
      }
      .store(in: &cancellables)
  }

  // MARK: - Loading

  func load() async {
    let info = await dependencies.customerInfo.fetchCustomerInfo()
    await apply(customerInfo: info, refetchProducts: true)
    if !hasTrackedOpen {
      hasTrackedOpen = true
      await dependencies.tracker.track(
        InternalSuperwallEvent.CustomerCenterOpen(
          screen: state == .management ? "management" : "no_purchases",
          presentation: presentationMode
        )
      )
    }
  }

  private func apply(customerInfo: CustomerInfo, refetchProducts: Bool) async {
    let ids = Set(customerInfo.subscriptions.map(\.productId) + customerInfo.nonSubscriptions.map(\.productId))
    if refetchProducts {
      products = await dependencies.products.products(for: ids)
      var shared: Set<String> = []
      for id in customerInfo.subscriptions.filter({ $0.store == .appStore }).map(\.productId)
      where await dependencies.transactionLookup.isFamilyShared(productId: id) {
        shared.insert(id)
      }
      familyShared = shared
    }
    let builder = PurchasePresentationBuilder(strings: strings)
    purchases = builder.build(customerInfo: customerInfo, products: products)
    state = hasAnyPurchases(customerInfo) ? .management : .noPurchases
    showsUpdateBanner = !updateWarningDismissed
      && configuration.support.shouldWarnToUpdate
      && AppVersionComparator.isInstalledVersion(
        dependencies.environment.appVersion,
        olderThan: configuration.support.latestAppVersion
      )
    let activeStores = Set(customerInfo.subscriptions.filter(\.isActive).map(\.store))
    showsDuplicateBanner = configuration.warnsAboutDuplicateSubscriptions
      && activeStores.contains(.appStore)
      && !activeStores.isDisjoint(with: [.stripe, .paddle, .superwall])
  }

  /// Whether `info` represents any purchase the Customer Center should show as "management" —
  /// a subscription, a non-subscription transaction, or an active entitlement (which covers
  /// manually granted and cross-store entitlements that have no local transaction).
  private func hasAnyPurchases(_ info: CustomerInfo) -> Bool {
    !info.subscriptions.isEmpty || !info.nonSubscriptions.isEmpty || info.entitlements.contains { $0.isActive }
  }

  // MARK: - Paths

  var userId: String { dependencies.environment.userId }
  var originalDownloadDate: Date? { dependencies.environment.originalDownloadDate }
  var appStoreURL: URL? { dependencies.environment.appStoreURL }

  /// Resolves the paths to show.
  /// - Parameters:
  ///   - purchase: The purchase the paths apply to, if any.
  ///   - isScreenLevel: `true` for a screen's main action list (management / no-purchases), where
  ///     restore is always available; `false` for a drilled-in purchase detail screen.
  func paths(for purchase: PurchasePresentation?, isScreenLevel: Bool = true) -> [ResolvedPath] {
    let screen = state == .noPurchases ? configuration.noPurchasesScreen : configuration.managementScreen
    let context = PathResolutionContext(
      purchase: purchase,
      product: purchase?.productId.flatMap { products[$0] },
      isFamilyShared: purchase?.productId.map { familyShared.contains($0) } ?? false,
      supportEmailAvailable: supportEmailAvailable,
      webManagementURL: dependencies.environment.webManagementURL,
      isChangePlanSheetAvailable: isChangePlanSheetAvailable,
      canOpenURLs: dependencies.urlOpener.canOpenURLs && !dependencies.environment.isAppExtension,
      isScreenLevel: isScreenLevel
    )
    return CustomerCenterPathResolver.resolve(screen.paths, context: context)
  }

  func select(_ resolved: ResolvedPath, purchase: PurchasePresentation?) async {
    let action = CustomerCenterAction(pathType: resolved.path.type)
    callbacks.didSelectAction?(action, purchase?.subscription)
    await dependencies.tracker.track(
      InternalSuperwallEvent.CustomerCenterAction(action: action, pathId: resolved.path.id, productId: purchase?.productId)
    )
    if let survey = resolved.path.survey, !survey.options.isEmpty {
      pendingSurvey = (resolved.path, survey)
      pendingAction = (resolved, purchase)
      sheet = .survey(pathId: resolved.path.id)
      return
    }
    await perform(resolved, purchase: purchase)
  }

  func answerSurvey(optionId: String) async {
    guard let pendingSurvey, let pendingAction else { return }
    let action = CustomerCenterAction(pathType: pendingAction.resolved.path.type)
    callbacks.didCompleteSurvey?(pendingSurvey.survey.id, optionId, action)
    await dependencies.tracker.track(InternalSuperwallEvent.CustomerCenterSurveyResponse(
      surveyId: pendingSurvey.survey.id,
      optionId: optionId,
      action: action,
      pathId: pendingAction.resolved.path.id,
      productId: pendingAction.purchase?.productId
    ))
    self.pendingSurvey = nil
    self.pendingAction = nil
    // Don't perform the follow-up action yet: it may present another sheet, and doing so while
    // the survey sheet is still animating out can be dropped on iOS 15/16. It's performed by
    // `sheetDidDismiss()` once the survey sheet has finished dismissing.
    pendingActionAfterSheetDismiss = pendingAction
    sheet = nil
  }

  func cancelSurvey() {
    pendingSurvey = nil
    pendingAction = nil
    pendingActionAfterSheetDismiss = nil
    if case .survey = sheet { sheet = nil }
  }

  private func perform(_ resolved: ResolvedPath, purchase: PurchasePresentation?) async {
    switch resolved.destination {
    case .restore:
      await performRestore()
    case .appleManageSheet(let groupId):
      sheet = .manageSubscriptions(groupId: groupId)
    case .webManage(let url):
      sheet = .safari(url)
    case .refund(let productId):
      if let transactionId = await dependencies.transactionLookup.latestTransactionID(for: productId) {
        sheet = .refund(transactionId: transactionId, productId: productId)
      } else {
        await refundSheetDidFinish(productId: productId, status: .error)
      }
    case let .changePlan(groupId, productIds):
      sheet = .changePlan(groupId: groupId, productIds: productIds)
    case .contactSupport:
      guard let url = supportMailtoURL else { return }
      // The path row itself is no longer gated on `canOpen` (see `supportEmailAvailable`), so
      // the fallback happens here at tap time: open the composer when we can, otherwise show
      // the address so the user can still reach support manually.
      if dependencies.urlOpener.canOpen(url) {
        dependencies.urlOpener.open(url)
      } else {
        sheet = .noMailApp(email: configuration.support.email ?? "")
      }
    case let .url(url, inApp):
      if inApp { sheet = .safari(url) } else { dependencies.urlOpener.open(url) }
    case .custom:
      break
    }
  }

  // MARK: - Restore

  func performRestore() async {
    if let gate = callbacks.shouldRestore {
      let proceed = await withCheckedContinuation { continuation in gate { continuation.resume(returning: $0) } }
      guard proceed else { return }
    }
    restoreState = .restoring
    let delay = Task { try? await Task.sleep(nanoseconds: 500_000_000) }
    let result = await dependencies.restore.restorePurchases()
    await delay.value
    let info = await dependencies.customerInfo.fetchCustomerInfo()
    await apply(customerInfo: info, refetchProducts: true)
    let hasPurchases = hasAnyPurchases(info)
    switch result {
    case .restored where hasPurchases: restoreState = .restored
    default: restoreState = .notFound
    }
  }

  // MARK: - Sheet callbacks

  func refundSheetDidFinish(productId: String, status: CustomerCenterRefundStatus) async {
    refundResult = (productId, status)
    callbacks.didCompleteRefund?(productId, status)
    await dependencies.tracker.track(
      InternalSuperwallEvent.CustomerCenterRefundRequest(productId: productId, status: status)
    )
    sheet = nil
  }

  /// Call when any Customer Center sheet finishes dismissing. Performs any action deferred by
  /// `answerSurvey`, then reloads to pick up changes. When the dismissed sheet was a StoreKit
  /// store sheet (manage subscriptions / change plan), receipts are reloaded first: cancelling
  /// auto-renew in Apple's sheet emits no `Transaction.updates`, so a plain cached
  /// customer-info read would miss the change.
  func sheetDidDismiss() async {
    let dismissed = lastPresentedSheet
    lastPresentedSheet = nil
    // Perform the deferred survey follow-up BEFORE the refetch, now that the previous sheet
    // has finished dismissing and a new one can be presented reliably.
    if let pending = pendingActionAfterSheetDismiss {
      pendingActionAfterSheetDismiss = nil
      await perform(pending.resolved, purchase: pending.purchase)
    }
    let info: CustomerInfo
    switch dismissed {
    case .manageSubscriptions, .changePlan:
      info = await dependencies.customerInfo.refreshReceipts()
    default:
      info = await dependencies.customerInfo.fetchCustomerInfo()
    }
    await apply(customerInfo: info, refetchProducts: true)
  }

  func continueAfterUpdateWarning() {
    updateWarningDismissed = true
    showsUpdateBanner = false
  }

  // swiftlint:disable:next large_tuple
  func historySections() -> (
    active: [PurchasePresentation],
    expired: [PurchasePresentation],
    other: [PurchasePresentation]
  ) {
    let subs = purchases.filter { $0.subscription != nil }
    return (subs.filter(\.isActive), subs.filter { !$0.isActive }, purchases.filter { $0.subscription == nil })
  }
}

// MARK: - Visibility-driven dismissal

@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  /// Call from any Customer Center surface's `onAppear` — the root view, and any screen it
  /// pushes itself (purchase detail, purchase history, purchase detail rows). In embedded mode
  /// (`usesExistingNavigation`) the host owns the navigation stack, so pushing one of these
  /// screens removes the previous surface from the hierarchy without the Customer Center
  /// actually closing. Counting concurrently visible surfaces (instead of a single boolean)
  /// correctly tracks nested pushes, and cancels any pending dismissal from a prior disappear.
  func surfaceDidAppear() {
    visibleSurfaceCount += 1
    dismissDebounceTask?.cancel()
    dismissDebounceTask = nil
  }

  /// Call from the matching `onDisappear` of any surface that called ``surfaceDidAppear()``.
  /// When the count drops to zero, waits a short debounce before dismissing — a push/pop
  /// transition can briefly have both the old and new surface on screen, or neither, so a
  /// single runloop turn isn't enough to distinguish "navigating within the Customer Center"
  /// from "the Customer Center was torn down". If another surface appears before the debounce
  /// elapses, ``surfaceDidAppear()`` cancels it and no dismissal happens.
  func surfaceDidDisappear() {
    visibleSurfaceCount = max(0, visibleSurfaceCount - 1)
    guard visibleSurfaceCount == 0 else { return }
    dismissDebounceTask?.cancel()
    dismissDebounceTask = Task { [weak self, dismissDebounceInterval] in
      try? await Task.sleep(nanoseconds: UInt64(dismissDebounceInterval * 1_000_000_000))
      guard !Task.isCancelled else { return }
      guard let self, self.visibleSurfaceCount == 0 else { return }
      self.dismiss()
    }
  }

  func dismiss() {
    guard !didDismiss else { return }
    didDismiss = true
    dismissDebounceTask?.cancel()
    dismissDebounceTask = nil
    callbacks.didDismiss?()
    Task { await dependencies.tracker.track(InternalSuperwallEvent.CustomerCenterClose()) }
  }
}

// MARK: - Support email

@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  var supportMailtoURL: URL? {
    SupportEmailComposer.mailtoURL(
      email: configuration.support.email,
      subject: strings.string("customer_center_support_subject"),
      body: strings.string("customer_center_support_body"),
      diagnostics: diagnostics
    )
  }

  private var diagnostics: SupportEmailDiagnostics {
    let env = dependencies.environment
    let active = purchases.filter(\.isActive).compactMap(\.productId)
    return .init(
      userId: env.userId,
      appVersion: env.appVersion,
      osVersion: env.osVersion,
      deviceModel: env.deviceModel,
      sdkVersion: env.sdkVersion,
      activeEntitlementIds: active,
      isSandbox: env.isSandbox
    )
  }

  /// Whether to show the contact-support path.
  ///
  /// Gated only on a support email being configured. `canOpenURL("mailto:…")` returns false on
  /// device unless the host app declares `mailto` in `LSApplicationQueriesSchemes`, so
  /// pre-gating on it would hide the path entirely for most apps. The tap handler falls back to
  /// a sheet showing the address instead.
  var supportEmailAvailable: Bool { supportMailtoURL != nil }
}
