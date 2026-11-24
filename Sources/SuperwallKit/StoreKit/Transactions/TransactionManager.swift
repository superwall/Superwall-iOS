//
//  File 2.swift
//
//
//  Created by Yusuf Tör on 20/10/2022.
//
// swiftlint:disable type_body_length file_length function_body_length

import Combine
import StoreKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class TransactionManager {
  private let factory: Factory
  typealias Factory = OptionsFactory
    & TriggerFactory
    & PurchasedTransactionsFactory
    & StoreTransactionFactory
    & DeviceHelperFactory
    & HasExternalPurchaseControllerFactory
    & RestoreAccessFactory
    & TestModeManagerFactory
    & ReceiptFactory
    & ConfigManagerFactory
  enum State {
    case observing
    case purchasing(PurchaseSource)
  }

  /// Everything a purchase causes outside this class.
  let context: TransactionContext

  /// Runs restores.
  let restoreFlow: RestoreFlow

  /// Runs purchases one at a time, in the order they were asked for, so a
  /// second purchase can't take over the first one's state while it waits on
  /// StoreKit.
  private let purchaseQueue = SerialTaskCoordinator()

  /// Set while a purchase runs on ``purchaseQueue``. A purchase started from
  /// inside it, such as by the app's purchase controller, runs straight away
  /// rather than waiting behind the one it's part of.
  @TaskLocal private static var isRunningPurchase = false

  init(
    context: TransactionContext,
    restoreContext: RestoreContext,
    factory: Factory
  ) {
    self.context = context
    self.restoreFlow = RestoreFlow(context: restoreContext)
    self.factory = factory
  }

  /// Creates a manager whose purchases and restores act on the SDK.
  convenience init(
    storeKitManager: StoreKitManager,
    receiptManager: ReceiptManager,
    purchaseController: PurchaseController,
    placementsQueue: PlacementsQueue,
    purchaseManager: PurchaseManager,
    productsManager: ProductsManager,
    postPurchaseRedeemer: PostPurchaseRedeeming,
    factory: Factory
  ) {
    self.init(
      context: AppTransactionContext(
        storeKitManager: storeKitManager,
        receiptManager: receiptManager,
        purchaseController: purchaseController,
        placementsQueue: placementsQueue,
        purchaseManager: purchaseManager,
        productsManager: productsManager,
        postPurchaseRedeemer: postPurchaseRedeemer,
        factory: factory
      ),
      restoreContext: AppRestoreContext(
        purchaseController: purchaseController,
        purchaseManager: purchaseManager,
        factory: factory
      ),
      factory: factory
    )
  }

  /// Purchases the given product and handles the result appropriately.
  ///
  /// This uses a `PurchasingCoordinator` to coordinate the purchasing from start to finish.
  ///
  /// - Parameters:
  ///   - productId: The ID of the product to purchase.
  ///   - paywallViewController: The `PaywallViewController` that the product is being
  ///   purchased from.
  @discardableResult
  func purchase(_ purchaseSource: PurchaseSource) async -> PurchaseResult {
    // The app's purchase controller calls the purchase function from inside
    // its own purchase, which is already on the queue.
    var isFromPurchaseController = false
    if case .purchaseFunc = purchaseSource {
      isFromPurchaseController = context.hasExternalPurchaseController
    }
    if Self.isRunningPurchase || isFromPurchaseController {
      return await performPurchase(purchaseSource)
    }
    return await withCheckedContinuation { continuation in
      purchaseQueue.enqueue { [weak self] in
        guard let self = self else {
          return continuation.resume(returning: .cancelled)
        }
        let result = await Self.$isRunningPurchase.withValue(true) {
          await self.performPurchase(purchaseSource)
        }
        continuation.resume(returning: result)
      }
    }
  }

  /// Runs `purchase(_:)`, on the purchase queue unless it's part of a
  /// purchase already running.
  private func performPurchase(_ purchaseSource: PurchaseSource) async -> PurchaseResult {
    let product: StoreProduct

    switch purchaseSource {
    #if canImport(WebKit)
    case .internal(let productId, _, _):
      // This is the slot's `Product.cacheKey`, which includes its billing plan
      // when it has one. `product(withId:)` resolves against the composite-keyed
      // map first and falls back to the Apple-ID map for custom and externally
      // cached products that aren't part of a paywall.
      let resolvedProduct = await context.product(withId: productId)
      guard let storeProduct = resolvedProduct else {
        Logger.debug(
          logLevel: .error,
          scope: .transactions,
          message:
            "Trying to purchase \(productId) but the product has failed to load. Visit https://superwall.com/l/missing-products to diagnose."
        )
        return .failed(PurchaseError.productUnavailable)
      }
      product = storeProduct
    #endif
    case .purchaseFunc(let storeProduct):
      product = storeProduct
    case .observeFunc:
      // This is a no-op, there's no way someone can call this func using observe.
      return .cancelled
    }
    let inFlightPurchase = await prepareToPurchase(
      product: product,
      purchaseSource: purchaseSource
    )

    let result = await purchase(product, purchaseSource: purchaseSource)

    // Return early if using a purchase controller and purchasing externally.
    // This avoids duplicate calls by the purchase function of the purchase
    // controller.
    if case .purchaseFunc = purchaseSource,
      context.hasExternalPurchaseController {
      // Not resetting coordinator here because we need it with the purchase controller
      // call.
      return result
    }

    await handle(
      result: result,
      state: .purchasing(purchaseSource),
      purchase: inFlightPurchase
    )

    return result
  }

  /// Tracks and shows the outcome of `purchase`, then ends it.
  ///
  /// - Parameter purchase: The purchase the result belongs to. Defaults to the
  ///   one in progress, read once, so a purchase that begins while this runs
  ///   is neither reported nor ended.
  func handle(
    result: PurchaseResult,
    state: State,
    purchase: InFlightPurchase? = nil
  ) async {
    let coordinator = factory.makePurchasingCoordinator()
    let purchase = purchase ?? coordinator.purchase
    defer {
      if let purchase = purchase {
        coordinator.finish(purchase)
      }
    }

    switch result {
    case .purchased:
      await didPurchase(purchase)
    case .failed(let error):
      guard
        let outcome = TransactionErrorLogic.handle(
          error,
          triggers: context.triggers,
          shouldShowPurchaseFailureAlert: context.paywallOptions.shouldShowPurchaseFailureAlert
        )
      else {
        await trackFailure(error: error, purchase: purchase)
        switch state {
        case .observing:
          break
        case .purchasing(let purchaseSource):
          #if canImport(WebKit)
          if case let .internal(_, paywallViewController, _) = purchaseSource {
            await context.updateLoading(.spinnerDismissed, on: paywallViewController)
          }
          #endif
        }
        return
      }
      switch outcome {
      case .cancelled:
        await trackCancelled(purchase: purchase)
      case .presentAlert:
        await trackFailure(error: error, purchase: purchase)
        switch state {
        case .observing:
          break
        case .purchasing(let purchaseSource):
          let bundle = LocalizationLogic.localizedBundle()
          await context.presentAlert(
            title: bundle.localizedString(
              forKey: "purchase_error_title",
              value: nil,
              table: nil
            ),
            message: error.safeLocalizedDescription,
            source: purchaseSource.toGenericSource()
          )
        }
      }
    case .pending:
      await handlePendingTransaction(purchase: purchase)
    case .cancelled:
      await trackCancelled(purchase: purchase)
    }
  }

  @available(iOS 17.2, macOS 14.2, visionOS 1.1, watchOS 10.2, tvOS 17.2, *)
  func logSK2ObserverModeTransaction(_ transaction: SK2Transaction) async {
    await logObservedPurchase(
      ofProductId: transaction.productID,
      startedOffer: transaction.offer != nil
    )
  }

  /// Tracks a purchase the app made itself as begun and succeeded, then ends
  /// it, so the next one can be observed.
  ///
  /// - Parameters:
  ///   - productId: The id of the product that was bought.
  ///   - startedOffer: Whether the purchase's transaction started an offer.
  func logObservedPurchase(
    ofProductId productId: String,
    startedOffer: Bool
  ) async {
    guard let product = await context.loadProduct(withId: productId) else {
      return
    }
    guard var purchase = await prepareToPurchase(
      product: product,
      purchaseSource: .observeFunc(product)
    ) else {
      return
    }

    let coordinator = factory.makePurchasingCoordinator()
    coordinator.observeOffer(startedOffer)
    purchase.isFreeTrialAvailable = startedOffer

    await didPurchase(purchase)
    coordinator.finish(purchase)
  }

  /// Restores purchases. See ``RestoreFlow/restore(_:presentsFailureAlert:)``.
  @MainActor
  @discardableResult
  func tryToRestore(
    _ restoreSource: RestoreSource,
    presentsFailureAlert: Bool = true
  ) async -> RestorationResult {
    return await restoreFlow.restore(
      restoreSource,
      presentsFailureAlert: presentsFailureAlert
    )
  }

  func didRestore(restoreSource: RestoreSource? = nil) async {
    await restoreFlow.didRestore(restoreSource: restoreSource)
  }

  private func purchase(
    _ product: StoreProduct,
    purchaseSource: PurchaseSource
  ) async -> PurchaseResult {
    // In test mode, show the test mode drawer instead of calling StoreKit
    if let result = await context.purchaseInTestMode(product, source: purchaseSource) {
      return result
    }

    // Custom products can only be purchased via an external PurchaseController.
    // Without one, the default SK1/SK2 purchasers have no underlying product to
    // transact against and bail silently, leaving the paywall stuck.
    if product.isCustomProduct,
      !context.hasExternalPurchaseController {
      Logger.debug(
        logLevel: .error,
        scope: .transactions,
        message: "Custom product \"\(product.productIdentifier)\" can only be purchased using a PurchaseController. "
          + "Set one via Superwall.configure(..., purchaseController:) to handle custom product purchases."
      )
      return .failed(PurchaseError.customProductWithoutPurchaseController)
    }

    // Attach intro offer token if available from the paywall
    #if canImport(WebKit)
    if case .internal(_, let paywallViewController, _) = purchaseSource {
      product.introOfferToken = await context.introOfferToken(
        forProductId: product.productIdentifier,
        on: paywallViewController
      )
    }
    #endif

    switch purchaseSource {
    #if canImport(WebKit)
    case .internal:
      return await context.purchaseWithPurchaseController(product)
    #endif
    case .purchaseFunc:
      return await context.purchaseWithStoreKit(product)
    case .observeFunc:
      // No-op, there's no way this can be called from observe.
      return .cancelled
    }
  }

  /// Cancels the transaction timeout when the application resigns active.
  ///
  /// When the purchase sheet appears, the application resigns active.

  // MARK: - Transaction lifecycle

  func trackFailure(error: Error, purchase: InFlightPurchase? = nil) async {
    guard let purchase = purchase ?? factory.makePurchasingCoordinator().purchase else {
      return
    }
    let source = purchase.source
    let product = purchase.product

    var isObserved = false
    if case .observeFunc = source {
      isObserved = true
    }

    switch source {
    #if canImport(WebKit)
    case .internal(_, let paywallViewController, _):
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Error",
        info: [
          "product_id": product.productIdentifier,
          "paywall_vc": paywallViewController
        ],
        error: error
      )

      let paywallInfo = await context.info(of: paywallViewController)
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(.failure(error.safeLocalizedDescription, product)),
        paywallInfo: paywallInfo,
        product: product,
        transaction: nil,
        source: .internal,
        isObserved: isObserved,
        storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1
      )
      await context.track(trackedEvent)
      await context.notify(paywallViewController, of: .transactionFail)
    #endif
    case .purchaseFunc,
      .observeFunc:
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Error",
        info: [
          "product_id": product.productIdentifier
        ],
        error: error
      )

      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(.failure(error.safeLocalizedDescription, product)),
        paywallInfo: .empty(),
        product: product,
        transaction: nil,
        source: .external,
        isObserved: isObserved,
        storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1
      )
      await context.track(trackedEvent)
    }
  }

  func observeSK1Transaction(for productId: String) async {
    guard let storeProduct = await context.loadProduct(withId: productId) else {
      Logger.debug(
        logLevel: .debug,
        scope: .superwallCore,
        message: "There's a purchase happening of a product with id \(productId), "
          + "but we couldn't retrieve it to observe its purchase."
      )
      return
    }
    await observeSK1Purchase(of: storeProduct)
  }

  /// Begins observing the purchase of a loaded product. The result is handled
  /// for this purchase, even if a later one has begun when it arrives.
  func observeSK1Purchase(of storeProduct: StoreProduct) async {
    let coordinator = factory.makePurchasingCoordinator()
    let purchase = await prepareToPurchase(
      product: storeProduct,
      purchaseSource: .observeFunc(storeProduct)
    )
    coordinator.awaitResult(forProductId: storeProduct.productIdentifier) { [weak self] result in
      Task {
        await self?.handle(
          result: result,
          state: .observing,
          purchase: purchase
        )
      }
    }
  }

  /// Tracks the analytics and logs the start of the transaction.
  ///
  /// - Parameters:
  ///   - customStoreCheckoutTransactionId: Set when the paywall runs a custom
  ///   store checkout itself: the transaction id Superwall generated for that
  ///   checkout. The checkout's own browser owns the paywall's loading state.
  /// - Returns: The purchase that began, or `nil` if the purchase controller
  ///   starts it itself.
  @discardableResult
  func prepareToPurchase(
    product: StoreProduct,
    purchaseSource: PurchaseSource,
    customStoreCheckoutTransactionId: String? = nil
  ) async -> InFlightPurchase? {
    // Always regenerate the custom transaction ID before a new purchase attempt.
    if product.isCustomProduct {
      product.customTransactionId = customStoreCheckoutTransactionId ?? UUID().uuidString
    }

    let isFreeTrialAvailable = await isFreeTrialAvailable(for: product)

    var isObserved = false
    if case .observeFunc = purchaseSource {
      isObserved = true
    }

    // Skip transaction start tracking if using StoreKit2 and the source is observeFunc
    let shouldTrackTransactionStart = !(context.isUsingStoreKit2 && isObserved)

    switch purchaseSource {
    #if canImport(WebKit)
    case .internal(_, let paywallViewController, _):
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Purchasing",
        info: ["paywall_vc": paywallViewController],
        error: nil
      )

      let paywallInfo = await context.info(of: paywallViewController)

      let transactionStart = InternalSuperwallEvent.Transaction(
        state: .start(product),
        paywallInfo: paywallInfo,
        product: product,
        transaction: nil,
        source: .internal,
        isObserved: isObserved,
        storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1
      )
      await context.track(transactionStart)
      await context.notify(paywallViewController, of: .transactionStart)

      if customStoreCheckoutTransactionId == nil {
        await context.updateLoading(.purchaseStarted, on: paywallViewController)
      }
    #endif
    case .purchaseFunc,
      .observeFunc:
      // If an external purchase controller is being used, skip because this will
      // get called by the purchase function of the purchase controller.
      if !context.shouldObservePurchases,
        context.hasExternalPurchaseController {
        return nil
      }

      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "External Transaction Purchasing"
      )

      if shouldTrackTransactionStart {
        let trackedEvent = InternalSuperwallEvent.Transaction(
          state: .start(product),
          paywallInfo: .empty(),
          product: product,
          transaction: nil,
          source: .external,
          isObserved: isObserved,
          storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1
        )
        await context.track(trackedEvent)
      }
    }

    var method = PurchaseMethod.storeKit(purchaseSource)
    #if canImport(WebKit)
    if customStoreCheckoutTransactionId != nil,
      case let .internal(productId, paywallViewController, shouldDismiss) = purchaseSource {
      method = .customStoreCheckout(
        paywall: paywallViewController,
        productId: productId,
        shouldDismiss: shouldDismiss
      )
    }
    #endif
    return factory.makePurchasingCoordinator().beginPurchase(
      of: product,
      method: method,
      isFreeTrialAvailable: isFreeTrialAvailable
    )
  }

  func isFreeTrialAvailable(for product: StoreProduct) async -> Bool {
    if product.isCustomProduct {
      return await isCustomProductFreeTrialAvailable(for: product)
    }

    // Same wait as `DependencyContainer.isFreeTrialAvailable`: the buy button
    // can be tapped while the first purchases load is still running.
    return await context.isAppStoreFreeTrialAvailable(for: product)
  }

  /// Custom products don't have StoreKit intro-offer state, so use entitlement history
  /// to decide whether a trial should count as available.
  private func isCustomProductFreeTrialAvailable(for product: StoreProduct) async -> Bool {
    guard product.hasFreeTrial else {
      return false
    }

    if product.entitlements.isEmpty {
      return false
    }

    // Same reason as the App Store branch above: config can be published before
    // the purchases load finishes, and until it does `customerInfo` is the copy
    // restored from disk. The `isPlaceholder` check below can't stand in for
    // this — the early publish only happens when a non-blank copy is saved,
    // which is exactly when `isPlaceholder` is false.
    //
    // Waiting on the same rule the paywall used, so the trial it advertised
    // and the transaction it produces are decided from the same state.
    let productEntitlementIds = Set(product.entitlements.map(\.id))
    let customerInfo = await context.customerInfo(afterLoadAffecting: productEntitlementIds)

    // If customer info hasn't loaded yet, assume the user has already had the
    // entitlement to avoid falsely counting a trial.
    if customerInfo.isPlaceholder {
      return false
    }

    let userEntitlementIds = Set(
      customerInfo.entitlements
        .filter { $0.latestProductId != nil || $0.store == .superwall || $0.isActive }
        .map(\.id)
    )

    return productEntitlementIds.isDisjoint(with: userEntitlementIds)
  }

  /// Dismisses the view controller, if the developer hasn't disabled the option.
  ///
  /// - Parameter purchase: The purchase that succeeded. Defaults to the one in
  ///   progress.
  func didPurchase(_ purchase: InFlightPurchase? = nil) async {
    guard let purchase = purchase ?? factory.makePurchasingCoordinator().purchase else {
      return
    }
    let source = purchase.source
    let product = purchase.product

    switch source {
    #if canImport(WebKit)
    case let .internal(_, paywallViewController, shouldDismiss):
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Succeeded",
        info: [
          "product_id": product.productIdentifier,
          "paywall_vc": paywallViewController
        ],
        error: nil
      )

      let transaction = await latestTransaction(for: purchase)
      await redeemAfterPurchase(for: product)
      await trackTransactionDidSucceed(transaction, purchase: purchase)
      await finalizeInternalPurchase(
        for: product,
        paywallViewController: paywallViewController,
        shouldDismiss: shouldDismiss
      )
    #endif
    case .purchaseFunc,
      .observeFunc:
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Succeeded",
        info: [
          "product_id": product.productIdentifier
        ],
        error: nil
      )

      let transaction = await latestTransaction(for: purchase)
      await redeemAfterPurchase(for: product)
      await trackTransactionDidSucceed(transaction, purchase: purchase)
    }
  }

  /// The purchase's transaction. For a custom product, it carries the product's
  /// `customTransactionId`, the id the purchase controller passed to its checkout.
  func latestTransaction(for purchase: InFlightPurchase) async -> StoreTransaction? {
    let product = purchase.product
    if product.isCustomProduct,
      let customTxnId = product.customTransactionId {
      let customTransaction = CustomStoreTransaction(
        customTransactionId: customTxnId,
        productIdentifier: product.productIdentifier,
        purchaseDate: purchase.purchaseDate
      )
      return await context.makeStoreTransaction(from: customTransaction)
    }

    return await factory.makePurchasingCoordinator().getLatestTransaction(for: purchase)
  }

  /// Pushes a successful purchase to Superwall with `/redeem`, which links it
  /// to the identified user and returns the user's entitlements (SW-5516).
  ///
  /// An App Store purchase reloads its receipts first, so `/redeem` carries
  /// them. A custom product has no receipt: its store reports the purchase to
  /// Superwall, and `/redeem` returns the entitlements it granted. The redeem
  /// runs in the background, so the purchase result and paywall dismissal
  /// don't wait for it. Skipped in test mode, which sets subscription state
  /// without real purchases.
  ///
  /// - Returns: The background redeem, or `nil` if none was started.
  @discardableResult
  func redeemAfterPurchase(for product: StoreProduct) async -> Task<Void, Never>? {
    if context.isTestMode {
      return nil
    }

    if !product.isCustomProduct {
      await context.reloadPurchasedProducts()
    }

    return context.redeemAfterPurchase()
  }

  #if canImport(WebKit)
  private func finalizeInternalPurchase(
    for product: StoreProduct,
    paywallViewController: PaywallViewController,
    shouldDismiss: Bool
  ) async {
    let shouldDismissPaywall = context.paywallOptions.automaticallyDismiss && shouldDismiss

    if shouldDismissPaywall {
      await context.dismiss(paywallViewController, result: .purchased(product))
      return
    }

    await context.updateLoading(.spinnerDismissed, on: paywallViewController)
  }

  #endif
  /// Track the cancelled
  ///
  /// - Parameters:
  ///   - canTriggerPaywall: Whether `transaction_abandon` may present a paywall
  ///   from a campaign that uses it as a trigger.
  ///   - notifiesPage: Whether the paywall's page is told of the abandon.
  ///   - purchase: The purchase that was abandoned. Defaults to the one in
  ///   progress.
  func trackCancelled(
    canTriggerPaywall: Bool = true,
    notifiesPage: Bool = true,
    purchase: InFlightPurchase? = nil
  ) async {
    guard let purchase = purchase ?? factory.makePurchasingCoordinator().purchase else {
      return
    }
    let source = purchase.source
    let product = purchase.product

    var isObserved = false
    if case .observeFunc = source {
      isObserved = true
    }

    switch source {
    #if canImport(WebKit)
    case .internal(_, let paywallViewController, _):
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Abandoned",
        info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController],
        error: nil
      )

      let paywallInfo = await context.info(of: paywallViewController)
      let transactionAbandon = InternalSuperwallEvent.Transaction(
        state: .abandon(product),
        paywallInfo: paywallInfo,
        product: product,
        transaction: nil,
        source: .internal,
        isObserved: isObserved,
        storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1,
        canTriggerPaywall: canTriggerPaywall
      )
      await context.track(transactionAbandon)
      if notifiesPage {
        await context.notify(paywallViewController, of: .transactionAbandon)
      }

      await context.updateLoading(.finished, on: paywallViewController)
    #endif
    case .purchaseFunc,
      .observeFunc:
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Abandoned",
        info: ["product_id": product.productIdentifier],
        error: nil
      )

      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .abandon(product),
        paywallInfo: .empty(),
        product: product,
        transaction: nil,
        source: .external,
        isObserved: isObserved,
        storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1
      )
      await context.track(trackedEvent)
    }
  }

  func handlePendingTransaction(purchase: InFlightPurchase? = nil) async {
    guard let purchase = purchase ?? factory.makePurchasingCoordinator().purchase else {
      return
    }
    let source = purchase.source
    let product = purchase.product

    var isObserved = false
    if case .observeFunc = source {
      isObserved = true
    }

    switch source {
    #if canImport(WebKit)
    case .internal(_, let paywallViewController, _):
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Pending",
        info: ["paywall_vc": paywallViewController],
        error: nil
      )

      let paywallInfo = await context.info(of: paywallViewController)

      let transactionFail = InternalSuperwallEvent.Transaction(
        state: .fail(.pending("Needs parental approval")),
        paywallInfo: paywallInfo,
        product: product,
        transaction: nil,
        source: .internal,
        isObserved: isObserved,
        storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1
      )
      await context.track(transactionFail)
      await context.notify(paywallViewController, of: .transactionFail)
    #endif
    case .purchaseFunc,
      .observeFunc:
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Transaction Pending",
        error: nil
      )

      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(.pending("Needs parental approval")),
        paywallInfo: .empty(),
        product: product,
        transaction: nil,
        source: .external,
        isObserved: isObserved,
        storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1
      )
      await context.track(trackedEvent)
    }

    let bundle = LocalizationLogic.localizedBundle()
    await context.presentAlert(
      title: bundle.localizedString(
        forKey: "purchase_pending_title",
        value: nil,
        table: nil
      ),
      message: bundle.localizedString(
        forKey: "purchase_pending_message",
        value: nil,
        table: nil
      ),
      source: source.toGenericSource()
    )
  }

  func trackTransactionDidSucceed(
    _ transaction: StoreTransaction?,
    purchase: InFlightPurchase? = nil
  ) async {
    guard let purchase = purchase ?? factory.makePurchasingCoordinator().purchase else {
      return
    }
    let source = purchase.source
    let product = purchase.product

    // Insert the transaction ID into the cache if observing. This prevents racing with
    // the SK2 observer.
    await context.rememberHandledTransaction(transaction)

    let didStartOffer: Bool

    if #available(iOS 17.2, macOS 14.2, visionOS 1.1, watchOS 10.2, tvOS 17.2, *),
      let sk2Transaction = transaction?.sk2Transaction {
      didStartOffer = sk2Transaction.offer != nil
    } else {
      didStartOffer = purchase.isFreeTrialAvailable
    }

    var isObserved = false
    if case .observeFunc = source {
      isObserved = true
    }

    let type: TransactionType = {
      if product.subscriptionPeriod == nil {
        return .nonRecurringProductPurchase
      } else if didStartOffer {
        return .freeTrialStart
      } else {
        return .subscriptionStart
      }
    }()

    let paywallInfo: PaywallInfo
    let eventSource: InternalSuperwallEvent.Transaction.Source
    // The product's intro offer is visible even when the user isn't eligible for it, so only
    // report a trial (and its end date) to the paywall when this transaction started one.
    let didStartFreeTrial = type == .freeTrialStart
    let trialEndDate = didStartFreeTrial ? product.trialPeriodEndDate : nil
    switch source {
    #if canImport(WebKit)
    case let .internal(cacheKey, paywallViewController, _):
      paywallInfo = await context.info(of: paywallViewController)
      eventSource = .internal
      await context.markPurchaseCompleted(product, on: paywallViewController)
      let referenceName = await context.referenceName(forCacheKey: cacheKey, on: paywallViewController)
      await context.notify(
        paywallViewController,
        of: .transactionComplete(
          trialEndDate: trialEndDate,
          productIdentifier: product.productIdentifier,
          didStartFreeTrial: didStartFreeTrial,
          product: referenceName
        )
      )
    #endif
    case .purchaseFunc,
      .observeFunc:
      paywallInfo = .empty()
      eventSource = .external
    }

    let deviceAttributes = await context.sessionDeviceAttributes()
    let trackedTransactionEvent = InternalSuperwallEvent.Transaction(
      state: .complete(product, transaction, type),
      paywallInfo: paywallInfo,
      product: product,
      transaction: transaction,
      source: eventSource,
      isObserved: isObserved,
      storeKitVersion: context.isUsingStoreKit2 ? .storeKit2 : .storeKit1,
      demandScore: deviceAttributes["demandScore"] as? Int,
      demandTier: deviceAttributes["demandTier"] as? String
    )
    await context.track(trackedTransactionEvent)
    await context.flushPlacements()

    switch type {
    case .nonRecurringProductPurchase:
      await context.track(
        InternalSuperwallEvent.NonRecurringProductPurchase(
          paywallInfo: paywallInfo,
          product: product,
          transaction: transaction
        )
      )
    case .freeTrialStart:
      await context.track(
        InternalSuperwallEvent.FreeTrialStart(
          paywallInfo: paywallInfo,
          product: product,
          transaction: transaction
        )
      )
      let notifications = paywallInfo.localNotifications.filter {
        $0.type == .trialStarted
      }
      await context.scheduleNotifications(
        notifications,
        fromPaywallId: paywallInfo.identifier
      )
    case .subscriptionStart:
      await context.track(
        InternalSuperwallEvent.SubscriptionStart(
          paywallInfo: paywallInfo,
          product: product,
          transaction: transaction
        )
      )
    }
  }
}
