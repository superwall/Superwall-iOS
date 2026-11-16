//
//  TransactionContext.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//

import Foundation

/// Everything a purchase reads from and causes in the rest of the SDK:
/// looking up and buying the product, tracking, alerts, redeeming and what
/// the paywall shows.
/// ``AppTransactionContext`` provides the real one, and tests a fake that
/// records the calls.
protocol TransactionContext: AnyObject {
  var isUsingStoreKit2: Bool { get }
  var hasExternalPurchaseController: Bool { get }
  var isTestMode: Bool { get }
  var shouldObservePurchases: Bool { get }
  var paywallOptions: PaywallOptions { get }
  /// The placements that campaigns use as triggers.
  var triggers: Set<String> { get }

  /// The loaded product for a paywall slot's `Product.cacheKey`, or for a
  /// product id when no slot has it.
  func product(withId id: String) async -> StoreProduct?
  /// Loads the product with `id` from its store, for a purchase the SDK is
  /// observing.
  func loadProduct(withId id: String) async -> StoreProduct?
  /// Whether buying `product` from the App Store would start a free trial.
  /// Waits for the first purchases load, which decides it.
  func isAppStoreFreeTrialAvailable(for product: StoreProduct) async -> Bool
  /// The customer info, once any purchases load that could change
  /// `entitlementIds` has finished.
  func customerInfo(afterLoadAffecting entitlementIds: Set<String>) async -> CustomerInfo
  func makeStoreTransaction(from transaction: CustomStoreTransaction) async -> StoreTransaction

  func track(_ event: Trackable) async

  /// Buys through the purchase controller, which may be the app's.
  func purchaseWithPurchaseController(_ product: StoreProduct) async -> PurchaseResult
  /// Buys through the SDK's own StoreKit purchaser.
  func purchaseWithStoreKit(_ product: StoreProduct) async -> PurchaseResult
  /// Lets the tester pick what a purchase does. Returns `nil` when not in
  /// test mode, or where there's no test mode UI, and the purchase goes ahead.
  func purchaseInTestMode(
    _ product: StoreProduct,
    source: PurchaseSource
  ) async -> PurchaseResult?

  /// Shows an alert on the paywall, or on the top-most view controller.
  func presentAlert(title: String, message: String, source: GenericSource) async

  /// Reloads the purchased products, so the redeem after a purchase carries
  /// its receipt.
  func reloadPurchasedProducts() async
  /// Starts redeeming a purchase with Superwall in the background.
  func redeemAfterPurchase() -> Task<Void, Never>

  /// Remembers a StoreKit 2 transaction the SDK handled, so the observer
  /// doesn't report it a second time.
  func rememberHandledTransaction(_ transaction: StoreTransaction?) async
  func sessionDeviceAttributes() async -> [String: Any]
  /// Sends the queued placements now, so a purchase reaches Superwall promptly.
  func flushPlacements() async
  func scheduleNotifications(
    _ notifications: [LocalNotification],
    fromPaywallId paywallId: String
  ) async

  #if canImport(WebKit)
  @MainActor
  func info(of paywall: PaywallViewController) -> PaywallInfo
  @MainActor
  func introOfferToken(
    forProductId productId: String,
    on paywall: PaywallViewController
  ) -> IntroOfferToken?
  @MainActor
  func referenceName(
    forCacheKey cacheKey: String,
    on paywall: PaywallViewController
  ) -> String?
  @MainActor
  func notify(_ paywall: PaywallViewController, of message: PaywallMessage)
  @MainActor
  func updateLoading(_ change: PaywallLoadingChange, on paywall: PaywallViewController)
  @MainActor
  func markPurchaseCompleted(_ product: StoreProduct, on paywall: PaywallViewController)
  func dismiss(_ paywall: PaywallViewController, result: PaywallResult) async
  #endif
}

/// The real purchase side effects.
final class AppTransactionContext: TransactionContext {
  private let storeKitManager: StoreKitManager
  private let receiptManager: ReceiptManager
  private let purchaseController: PurchaseController
  private let placementsQueue: PlacementsQueue
  private let purchaseManager: PurchaseManager
  private let productsManager: ProductsManager
  private let postPurchaseRedeemer: PostPurchaseRedeeming
  private let factory: TransactionManager.Factory

  /// Tracks an event. Replaced in tests to observe what's tracked.
  var trackEvent: (Trackable) async -> Void = { event in
    _ = await Superwall.shared.track(event)
  }

  init(
    storeKitManager: StoreKitManager,
    receiptManager: ReceiptManager,
    purchaseController: PurchaseController,
    placementsQueue: PlacementsQueue,
    purchaseManager: PurchaseManager,
    productsManager: ProductsManager,
    postPurchaseRedeemer: PostPurchaseRedeeming,
    factory: TransactionManager.Factory
  ) {
    self.storeKitManager = storeKitManager
    self.receiptManager = receiptManager
    self.purchaseController = purchaseController
    self.placementsQueue = placementsQueue
    self.purchaseManager = purchaseManager
    self.productsManager = productsManager
    self.postPurchaseRedeemer = postPurchaseRedeemer
    self.factory = factory
  }

  var isUsingStoreKit2: Bool {
    purchaseManager.isUsingSK2
  }

  var hasExternalPurchaseController: Bool {
    factory.makeHasExternalPurchaseController()
  }

  var isTestMode: Bool {
    factory.makeTestModeManager().isTestMode
  }

  var shouldObservePurchases: Bool {
    factory.makeSuperwallOptions().shouldObservePurchases
  }

  var paywallOptions: PaywallOptions {
    factory.makeSuperwallOptions().paywalls
  }

  var triggers: Set<String> {
    factory.makeTriggers()
  }

  func product(withId id: String) async -> StoreProduct? {
    return await storeKitManager.product(withId: id)
  }

  func loadProduct(withId id: String) async -> StoreProduct? {
    let products = try? await productsManager.products(
      identifiers: [id],
      forPaywall: nil,
      placement: nil
    )
    return products?.first
  }

  func isAppStoreFreeTrialAvailable(for product: StoreProduct) async -> Bool {
    return await receiptManager.isFreeTrialAvailable(
      for: product,
      waitingFor: factory.initialPurchasesLoad
    )
  }

  func customerInfo(afterLoadAffecting entitlementIds: Set<String>) async -> CustomerInfo {
    if factory.purchasesLoadCouldChange(entitlementIds: entitlementIds) {
      await factory.initialPurchasesLoad?.value
    }
    return await MainActor.run {
      Superwall.shared.customerInfo
    }
  }

  func makeStoreTransaction(from transaction: CustomStoreTransaction) async -> StoreTransaction {
    return await factory.makeStoreTransaction(from: transaction)
  }

  func track(_ event: Trackable) async {
    await trackEvent(event)
  }

  func purchaseWithPurchaseController(_ product: StoreProduct) async -> PurchaseResult {
    return await purchaseController.purchase(product: product)
  }

  func purchaseWithStoreKit(_ product: StoreProduct) async -> PurchaseResult {
    return await factory.purchase(product: product)
  }

  func purchaseInTestMode(
    _ product: StoreProduct,
    source: PurchaseSource
  ) async -> PurchaseResult? {
    #if canImport(WebKit)
    let testModeManager = factory.makeTestModeManager()
    guard testModeManager.isTestMode else {
      return nil
    }
    let handler = TestModeTransactionHandler(testModeManager: testModeManager)
    return await handler.handlePurchase(product: product, purchaseSource: source)
    #else
    return nil
    #endif
  }

  func presentAlert(title: String, message: String, source: GenericSource) async {
    await TransactionAlert.present(title: title, message: message, source: source)
  }

  func reloadPurchasedProducts() async {
    await receiptManager.loadPurchasedProducts(config: nil)
  }

  func redeemAfterPurchase() -> Task<Void, Never> {
    let postPurchaseRedeemer = postPurchaseRedeemer
    return Task {
      await postPurchaseRedeemer.redeemAfterPurchase()
    }
  }

  func rememberHandledTransaction(_ transaction: StoreTransaction?) async {
    guard
      #available(iOS 17.2, macOS 14.2, watchOS 10.2, tvOS 17.2, *),
      let purchaser = purchaseManager.purchaser as? ProductPurchaserSK2,
      let id = transaction?.sk2Transaction?.id
    else {
      return
    }
    await purchaser.sk2ObserverModePurchaseDetector.insertToCachedTransactionIds([id])
  }

  func sessionDeviceAttributes() async -> [String: Any] {
    return await factory.makeSessionDeviceAttributes()
  }

  func flushPlacements() async {
    await placementsQueue.flushInternal()
  }

  func scheduleNotifications(
    _ notifications: [LocalNotification],
    fromPaywallId paywallId: String
  ) async {
    await NotificationScheduler.shared.scheduleNotifications(
      notifications,
      fromPaywallId: paywallId,
      factory: factory
    )
  }

  #if canImport(WebKit)
  @MainActor
  func info(of paywall: PaywallViewController) -> PaywallInfo {
    return paywall.info
  }

  @MainActor
  func introOfferToken(
    forProductId productId: String,
    on paywall: PaywallViewController
  ) -> IntroOfferToken? {
    return paywall.introOfferTokenManager.getValidToken(for: productId)
  }

  @MainActor
  func referenceName(
    forCacheKey cacheKey: String,
    on paywall: PaywallViewController
  ) -> String? {
    return paywall.paywall.referenceName(forCacheKey: cacheKey)
  }

  @MainActor
  func notify(_ paywall: PaywallViewController, of message: PaywallMessage) {
    paywall.webView.messageHandler.handle(message)
  }

  @MainActor
  func updateLoading(_ change: PaywallLoadingChange, on paywall: PaywallViewController) {
    paywall.updateLoading(change)
  }

  @MainActor
  func markPurchaseCompleted(_ product: StoreProduct, on paywall: PaywallViewController) {
    paywall.markPurchaseCompleted(product)
  }

  func dismiss(_ paywall: PaywallViewController, result: PaywallResult) async {
    await Superwall.shared.dismiss(paywall, result: result)
  }
  #endif
}
