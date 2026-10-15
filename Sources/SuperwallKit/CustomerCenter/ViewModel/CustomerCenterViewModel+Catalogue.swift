//
//  CustomerCenterViewModel+Catalogue.swift
//
//
//  Created by Yusuf Tör on 23/09/2026.
//

import Foundation

// MARK: - Product details

extension CustomerCenterViewModel {
  /// Products the Superwall catalogue may know but StoreKit never will: those bought outside the
  /// App Store.
  static func catalogueProductIds(in customerInfo: CustomerInfo) -> Set<String> {
    let subscriptions = customerInfo.subscriptions.filter { $0.store != .appStore }.map(\.productId)
    let purchases = customerInfo.nonSubscriptions.filter { $0.store != .appStore }.map(\.productId)
    return Set(subscriptions + purchases)
  }

  /// Fetches what StoreKit couldn't supply from the Superwall catalogue, after the screen has
  /// drawn. Until it answers, the cards it affects show placeholders rather than holding the whole
  /// screen behind the spinner; when it fails, they show what they can without it.
  func fillFromCatalogue(_ customerInfo: CustomerInfo, generation: Int) {
    let ids = awaitingCatalogue
    if ids.isEmpty {
      return
    }
    catalogueTask?.cancel()
    catalogueTask = Task { [weak self, dependencies] in
      let filled = await dependencies.products.catalogueProducts(for: ids)
      guard let self, generation == self.applyGeneration else { return }
      self.products.merge(filled) { _, new in new }
      self.awaitingCatalogue = []
      self.renderPurchases(customerInfo)
    }
  }

  /// Fetches product details and family sharing for the purchases in `customerInfo`. Returns
  /// `false`, changing nothing, when a newer apply has overtaken this one.
  ///
  /// StoreKit gets ``storeKitProductsWait`` to answer. When it fails — offline, say — its lookup
  /// retries for around half a minute, and the purchases are already known from `customerInfo`;
  /// so the cards are drawn with whatever details are already known, and filled in when StoreKit
  /// answers.
  func refreshProducts(for customerInfo: CustomerInfo, generation: Int) async -> Bool {
    let ids = Set(customerInfo.subscriptions.map(\.productId) + customerInfo.nonSubscriptions.map(\.productId))
    let lookup = Task { [dependencies] in await dependencies.products.products(for: ids) }
    let fetchedProducts = await CustomerCenterDeadline.value(of: lookup, within: storeKitProductsWait)
    var shared: Set<String> = []
    for id in customerInfo.subscriptions.filter({ $0.store == .appStore }).map(\.productId)
    where await dependencies.transactionLookup.isFamilyShared(productId: id) {
      shared.insert(id)
    }
    guard generation == applyGeneration else { return false }
    if let fetchedProducts {
      products = fetchedProducts
    } else {
      fillFromStoreKit(lookup, customerInfo: customerInfo, generation: generation)
    }
    familyShared = shared
    awaitingCatalogue = Self.catalogueProductIds(in: customerInfo).subtracting(products.keys)
    return true
  }

  /// Adds StoreKit's product details once they arrive, after the screen was drawn without them.
  func fillFromStoreKit(
    _ lookup: Task<[String: ProductDisplayInfo], Never>,
    customerInfo: CustomerInfo,
    generation: Int
  ) {
    Task { [weak self] in
      let fetched = await lookup.value
      guard let self, generation == self.applyGeneration else { return }
      self.products.merge(fetched) { _, new in new }
      self.awaitingCatalogue.subtract(fetched.keys)
      self.renderPurchases(customerInfo)
    }
  }
}
