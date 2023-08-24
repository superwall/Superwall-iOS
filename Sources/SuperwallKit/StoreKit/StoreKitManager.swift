import Foundation
import Combine

actor StoreKitManager {
  /// Coordinates: The purchasing, restoring and retrieving of products; the checking
  /// of transactions; and the determining of the user's subscription status.
  lazy var coordinator = factory.makeStoreKitCoordinator()
  private unowned let factory: StoreKitCoordinatorFactory
  private lazy var receiptManager = ReceiptManager(delegate: self)

  private(set) var productsById: [String: StoreProduct] = [:]
  private struct ProductProcessingResult {
    let productIdsToLoad: Set<String>
    let substituteProductsById: [String: StoreProduct]
    let products: [Product]
  }

  init(factory: StoreKitCoordinatorFactory) {
    self.factory = factory
  }

  func getProductVariables(for paywall: Paywall) async -> [ProductVariable] {
    guard let output = try? await getProducts(
      withIds: paywall.productIds,
      forPaywall: paywall.name
    ) else {
      return []
    }

    let variables = paywall.products.compactMap { product -> ProductVariable? in
      guard let storeProduct = output.productsById[product.id] else {
        return nil
      }
      return ProductVariable(
        type: product.type,
        attributes: storeProduct.attributesJson
      )
    }

    return variables
  }

  func getProducts(
    withIds responseProductIds: [String],
    forPaywall paywallName: String? = nil,
    responseProducts: [Product] = [],
    substituting substituteProducts: PaywallProducts? = nil
  ) async throws -> (productsById: [String: StoreProduct], products: [Product]) {
    let processingResult = removeAndStore(
      substituteProducts: substituteProducts,
      fromResponseProductIds: responseProductIds,
      responseProducts: responseProducts
    )

    let products = try await products(
      identifiers: processingResult.productIdsToLoad,
      forPaywall: paywallName
    )

    var productsById = processingResult.substituteProductsById

    for product in products {
      productsById[product.productIdentifier] = product
      self.productsById[product.productIdentifier] = product
    }

    return (productsById, processingResult.products)
  }

  /// For each product to substitute, this removes the response product at the given index and stores
  /// the substitute product in memory.
  private func removeAndStore(
    substituteProducts: PaywallProducts?,
    fromResponseProductIds responseProductIds: [String],
    responseProducts: [Product]
  ) -> ProductProcessingResult {
    var responseProductIds = responseProductIds
    var substituteProductsById: [String: StoreProduct] = [:]
    var products: [Product] = responseProducts

    func storeAndSubstitute(
      _ product: StoreProduct,
      type: ProductType,
      index: Int
    ) {
      let id = product.productIdentifier
      substituteProductsById[id] = product
      self.productsById[id] = product
      let product = Product(type: type, id: id)
      products[guarded: index] = product
      responseProductIds.remove(safeAt: index)
    }

    if let primaryProduct = substituteProducts?.primary {
      storeAndSubstitute(
        primaryProduct,
        type: .primary,
        index: 0
      )
    }
    if let secondaryProduct = substituteProducts?.secondary {
      storeAndSubstitute(
        secondaryProduct,
        type: .secondary,
        index: 1
      )
    }
    if let tertiaryProduct = substituteProducts?.tertiary {
      storeAndSubstitute(
        tertiaryProduct,
        type: .tertiary,
        index: 2
      )
    }

    return ProductProcessingResult(
      productIdsToLoad: Set(responseProductIds),
      substituteProductsById: substituteProductsById,
      products: products
    )
  }
}

// MARK: - Restoration
extension StoreKitManager {
  @MainActor
  func tryToRestore(_ paywallViewController: PaywallViewController) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Attempting Restore"
    )

    paywallViewController.loadingState = .loadingPurchase

    let restorationResult = await coordinator.txnRestorer.restorePurchases()

    await processRestoration(
      restorationResult: restorationResult,
      paywallViewController: paywallViewController
    )
  }

  /// After restoring, it checks to see whether the user is actually subscribed or not.
  ///
  /// This is accessed by both the transaction manager and the restoration manager.
  @MainActor
  func processRestoration(
    restorationResult: RestorationResult,
    paywallViewController: PaywallViewController
  ) async {
    let hasRestored = restorationResult == .restored

    if !Superwall.shared.dependencyContainer.delegateAdapter.hasPurchaseController {
      await refreshReceipt()
      if hasRestored {
        await loadPurchasedProducts()
      }
    }

    let isUserSubscribed = Superwall.shared.subscriptionStatus == .active

    if hasRestored && isUserSubscribed {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transactions Restored"
      )
      await transactionWasRestored(paywallViewController: paywallViewController)
    } else {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transactions Failed to Restore"
      )

      paywallViewController.presentAlert(
        title: Superwall.shared.options.paywalls.restoreFailed.title,
        message: Superwall.shared.options.paywalls.restoreFailed.message,
        closeActionTitle: Superwall.shared.options.paywalls.restoreFailed.closeButtonTitle
      )
    }
  }

  private func transactionWasRestored(paywallViewController: PaywallViewController) async {
    let paywallInfo = await paywallViewController.info

    let trackedEvent = InternalSuperwallEvent.Transaction(
      state: .restore,
      paywallInfo: paywallInfo,
      product: nil,
      model: nil
    )
    await Superwall.shared.track(trackedEvent)

    if Superwall.shared.options.paywalls.automaticallyDismiss {
      await Superwall.shared.dismiss(paywallViewController, result: .restored)
    }
  }
}

// MARK: - Receipt API
extension StoreKitManager {
  /// This refreshes the device receipt.
  ///
  /// - Warning: This will prompt the user to log in, so only do this on
  /// when restoring or after purchasing.
  func refreshReceipt() async {
    Logger.debug(
      logLevel: .debug,
      scope: .storeKitManager,
      message: "Refreshing App Store receipt."
    )
    await receiptManager.refreshReceipt()
  }

  /// Loads the purchased products from the receipt,
  func loadPurchasedProducts() async {
    Logger.debug(
      logLevel: .debug,
      scope: .storeKitManager,
      message: "Loading purchased products from the App Store receipt."
    )
    await receiptManager.loadPurchasedProducts()
  }

  /// Determines whether a free trial is available based on the product the user is purchasing.
  ///
  /// A free trial is available if the user hasn't already purchased within the subscription group of the
  /// supplied product. If it isn't a subscription-based product or there are other issues retrieving the products,
  /// the outcome will default to whether or not the user has already purchased that product.
  func isFreeTrialAvailable(for product: StoreProduct) async -> Bool {
    return await receiptManager.isFreeTrialAvailable(for: product)
  }
}

// MARK: - ProductsFetcher
extension StoreKitManager: ProductsFetcher {
  nonisolated func products(
    identifiers: Set<String>,
    forPaywall paywallName: String?
  ) async throws -> Set<StoreProduct> {
    return try await coordinator.productFetcher.products(
      identifiers: identifiers,
      forPaywall: paywallName
    )
  }
}
