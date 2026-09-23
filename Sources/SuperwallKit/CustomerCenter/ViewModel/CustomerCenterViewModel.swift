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
    didSet {
      if let sheet { lastPresentedSheet = sheet }
      sheetOwnerDepth = sheet == nil ? nil : pushDepth
    }
  }
  @Published var restoreState: CustomerCenterRestoreState = .idle
  @Published private(set) var refundResult: (productId: String, status: CustomerCenterRefundStatus)?
  // Not `private(set)`: the update-banner logic lives in
  // `CustomerCenterViewModel+UpdateBanner.swift`, and `private` is file-scoped.
  @Published var showsUpdateBanner = false
  @Published private(set) var showsDuplicateBanner = false
  /// The Customer Center's own screens pushed above the root and still in the stack, whether
  /// through the host's `UINavigationController` or by a `NavigationLink`.
  @Published private(set) var pushedSurfaces = PushedSurfaces()
  /// How deep the screen on top sits; `0` for the root. A sheet is presented by the screen at this
  /// depth when it's requested.
  var pushDepth: Int { pushedSurfaces.depth }
  /// The depth of the screen that presents ``sheet``: the one on top when it was requested.
  ///
  /// Fixed at the request rather than following ``pushDepth``. A request can land while the screen
  /// that made it is being popped, because its button stays live while the request awaits a
  /// transaction. Following the depth, the outgoing screen presented the sheet, then the root
  /// presented it again once the pop finished: two refund requests for one tap. `nil` once that
  /// screen has left the stack, so no other screen picks up a sheet that went with it.
  private(set) var sheetOwnerDepth: Int?
  /// What the sheet modifiers have rendered into StoreKit's sheets, one update behind ``sheet``. A
  /// StoreKit sheet only presents once this has caught up; see `StoreKitSheetParameters` for why.
  @Published var renderedStoreKitSheetParameters = StoreKitSheetParameters()

  let configuration: CustomerCenterConfiguration
  let strings: CustomerCenterStrings
  var callbacks = CustomerCenterCallbacks()
  var presentationMode: CustomerCenterPresentationStyle = .sheet
  private(set) var pendingSurvey: PendingSurvey?

  /// Locale for date formatting, matching the locale the localized strings resolve against:
  /// `DeviceHelper.preferredLocaleIdentifier`, the device's preferred language. Not
  /// `SuperwallOptions.localeIdentifier`, which applies only when there are no preferred
  /// languages at all.
  var locale: Locale { dependencies.environment.locale }

  // Not `private`: the support-email extension in `CustomerCenterViewModel+Support.swift`
  // reads these, and `private` is file-scoped.
  let dependencies: CustomerCenterDependencies
  let dismissDebounceInterval: TimeInterval
  private let isChangePlanSheetAvailable: Bool
  // Not `private`: the catalogue fill in `CustomerCenterViewModel+Catalogue.swift` updates these.
  var products: [String: ProductDisplayInfo] = [:]
  private var familyShared: Set<String> = []
  /// Lets an `apply` that a newer one has overtaken drop its older snapshot.
  var applyGeneration = 0
  /// Products whose display info is still coming from the Superwall catalogue.
  var awaitingCatalogue: Set<String> = []
  var catalogueTask: Task<Void, Never>?
  // Not `private`: read by `CustomerCenterViewModel+Refund.swift`.
  var pendingRefundProductId: String?
  private var pendingAction: PendingAction?
  /// An action deferred from `answerSurvey` until the survey sheet has finished dismissing.
  /// Performing it immediately would present a new sheet while the old one is still animating
  /// out, which iOS 15/16 can silently drop.
  private var pendingActionAfterSheetDismiss: PendingAction?
  /// The most recent non-nil ``sheet``, so ``sheetDidDismiss()`` knows whether the sheet that
  /// just closed was a StoreKit store sheet requiring a receipt refresh.
  private var lastPresentedSheet: CustomerCenterSheet?
  var updateWarningDismissed = false
  /// Version read from the App Store, used when the host didn't configure one.
  var fetchedAppStoreVersion: String?
  var hasCheckedAppStoreVersion = false
  private var hasTrackedOpen = false
  var didDismiss = false
  /// Active entitlement identifiers from the latest `CustomerInfo`, for support diagnostics.
  var activeEntitlementIds: [String] = []
  private var cancellables = Set<AnyCancellable>()

  // Not `private`: the dismissal state below, `didDismiss` and `dismissDebounceInterval` are read
  // by `CustomerCenterViewModel+Dismissal.swift`.

  /// Number of Customer Center surfaces (root + any pushed screens) currently on screen.
  /// Incremented/decremented by ``surfaceDidAppear()``/``surfaceDidDisappear()``. When this
  /// reaches zero and stays zero past the debounce, the Customer Center is genuinely gone.
  var visibleSurfaceCount = 0
  var dismissDebounceTask: Task<Void, Never>?
  /// Set by a host that knows this disappearance is a cover rather than a teardown. Cleared the
  /// next time a surface appears. See ``suppressDismissalUntilNextAppearance()``.
  var isDismissalSuppressed = false

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
    configuration.warnAboutConfigurationProblems()
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
          screen: hasAnyPurchases(info) ? .management : .noPurchases,
          presentation: presentationMode
        )
      )
    }
    // Last, and deliberately so: this makes a network call, and everything above it — the first
    // render and the open event — must not wait on it.
    //
    // That orders open before the *lookup*, not before every close: `apply` above still awaits a
    // StoreKit round trip, so closing while the spinner is up can still emit close first. Moving
    // open ahead of `apply` would fix that and put the whole tracking pipeline in front of first
    // paint, which is the worse trade.
    await refreshAppStoreVersion()
  }

  private func apply(customerInfo: CustomerInfo, refetchProducts: Bool) async {
    applyGeneration += 1
    let generation = applyGeneration
    let ids = Set(customerInfo.subscriptions.map(\.productId) + customerInfo.nonSubscriptions.map(\.productId))
    if refetchProducts {
      let fetchedProducts = await dependencies.products.products(for: ids)
      var shared: Set<String> = []
      for id in customerInfo.subscriptions.filter({ $0.store == .appStore }).map(\.productId)
      where await dependencies.transactionLookup.isFamilyShared(productId: id) {
        shared.insert(id)
      }
      guard generation == applyGeneration else { return }
      products = fetchedProducts
      familyShared = shared
      awaitingCatalogue = Self.catalogueProductIds(in: customerInfo).subtracting(fetchedProducts.keys)
    }
    renderPurchases(customerInfo)
    activeEntitlementIds = customerInfo.entitlements.filter(\.isActive).map(\.id)
    state = hasAnyPurchases(customerInfo) ? .management : .noPurchases
    recomputeUpdateBanner()
    let activeStores = Set(customerInfo.subscriptions.filter(\.isActive).map(\.store))
    showsDuplicateBanner = configuration.warnsAboutDuplicateSubscriptions
      && activeStores.contains(.appStore)
      && !activeStores.isDisjoint(with: [.stripe, .paddle, .superwall])
    if refetchProducts {
      fillFromCatalogue(customerInfo, generation: generation)
    }
  }

  func renderPurchases(_ customerInfo: CustomerInfo) {
    let builder = PurchasePresentationBuilder(strings: strings, locale: dependencies.environment.locale)
    purchases = builder.build(customerInfo: customerInfo, products: products, awaitingCatalogue: awaitingCatalogue)
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
    callbacks.didSelectAction?(action, resolved.path.id, purchase?.publicPurchase)
    await dependencies.tracker.track(
      InternalSuperwallEvent.CustomerCenterAction(action: action, pathId: resolved.path.id, productId: purchase?.productId)
    )
    if let survey = resolved.path.survey, !survey.options.isEmpty, !resolved.destination.isWebManagement {
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
    callbacks.didCompleteSurvey?(pendingSurvey.survey.id, optionId, action, pendingAction.resolved.path.id)
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
    case .webManageUnavailable:
      sheet = .webManageUnavailable
    case .refund(let productId):
      if let transactionId = await dependencies.transactionLookup.latestTransactionID(for: productId) {
        pendingRefundProductId = productId
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
      let proceed = await gate()
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
}

// MARK: - Pushed screens

// In this file rather than its own so it can assign the `private(set)` state it maintains.
@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  /// Records a screen the Customer Center has pushed. Claiming again under the same `id` changes
  /// nothing, so a screen can claim each time it appears.
  func claimPushedSurface(_ id: UUID, depth: Int) {
    updatePushedSurfaces { $0.claim(id, depth: depth) }
  }

  /// Forgets a pushed screen once it has left the stack. Not for a screen that is only covered:
  /// it's still in the stack, and still where its sheets belong.
  func releasePushedSurface(_ id: UUID) {
    updatePushedSurfaces { $0.release(id) }
  }

  private func updatePushedSurfaces(_ update: (inout PushedSurfaces) -> Void) {
    var surfaces = pushedSurfaces
    update(&surfaces)
    // Every assignment publishes, and screens claim on every appearance.
    guard surfaces != pushedSurfaces else { return }
    let remaining = Set(surfaces.claims.map(\.id))
    let departed = pushedSurfaces.claims.filter { !remaining.contains($0.id) }
    if let owner = sheetOwnerDepth, departed.contains(where: { $0.depth <= owner }) {
      sheetOwnerDepth = nil
    }
    pushedSurfaces = surfaces
  }
}
