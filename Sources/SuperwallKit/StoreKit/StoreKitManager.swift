import Foundation
import Combine

final class StoreKitManager {
  var productsById: [String: StoreProduct] = [:]

  private lazy var receiptManager = ReceiptManager(delegate: self)
  private struct ProductProcessingResult {
    let productIdsToLoad: Set<String>
    let substituteProductsById: [String: StoreProduct]
    let products: [Product]
  }

  /// Coordinates: The purchasing, restoring and retrieving of products; the checking
  /// of transactions; and the determining of the user's subscription status.
  var coordinator: StoreKitCoordinator!
  private let factory: StoreKitCoordinatorFactory

  init(factory: StoreKitCoordinatorFactory) {
    self.factory = factory
  }

  func postInit() {
    coordinator = factory.makeStoreKitCoordinator()
  }

	func getProductVariables(for paywall: Paywall) async -> [ProductVariable] {
    guard let output = try? await getProducts(withIds: paywall.productIds) else {
      return []
    }
    var variables: [ProductVariable] = []

    for product in paywall.products {
      if let storeProduct = output.productsById[product.id] {
        let variable = ProductVariable(
          type: product.type,
          attributes: storeProduct.attributesJson
        )
        variables.append(variable)
      }
    }

    return variables
	}

  /// This refreshes the device receipt.
  ///
  /// - Warning: This will prompt the user to log in, so only do this on
  /// when restoring or after purchasing.
  @discardableResult
  func refreshReceipt() async -> Bool {
    return await receiptManager.refreshReceipt()
  }

  /// Loads the purchased products from the receipt and stores them in `productsById`.
  @discardableResult
  func loadPurchasedProducts() async -> Bool {
    guard let purchasedProducts = await receiptManager.loadPurchasedProducts() else {
      return false
    }
    purchasedProducts.forEach { productsById[$0.productIdentifier] = $0 }
    return true
  }

  /// Determines whether a free trial is available based on the product the user is purchasing.
  ///
  /// A free trial is available if the user hasn't already purchased within the subscription group of the
  /// supplied product. If it isn't a subscription-based product or there are other issues retrieving the products,
  /// the outcome will default to whether or not the user has already purchased that product.
  func isFreeTrialAvailable(for product: StoreProduct) -> Bool {
    return receiptManager.isFreeTrialAvailable(for: product)
  }

  func getProducts(
    withIds responseProductIds: [String],
    responseProducts: [Product] = [],
    substituting substituteProducts: PaywallProducts? = nil
  ) async throws -> (productsById: [String: StoreProduct], products: [Product]) {
    let processingResult = removeAndStore(
      substituteProducts: substituteProducts,
      fromResponseProductIds: responseProductIds,
      responseProducts: responseProducts
    )

    let products = try await products(identifiers: processingResult.productIdsToLoad)

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

// MARK: - ReceiptManagerDelegate
extension StoreKitManager: ProductsFetcher {
  func products(identifiers: Set<String>) async throws -> Set<StoreProduct> {
    return try await coordinator.productFetcher.products(identifiers: identifiers)
  }
}

// MARK: - Subscription Status Checker
extension StoreKitManager: SubscriptionStatusChecker {
  /// Do not call this directly.
  func isSubscribed() -> Bool {
    return !receiptManager.activePurchases.isEmpty
  }
}
