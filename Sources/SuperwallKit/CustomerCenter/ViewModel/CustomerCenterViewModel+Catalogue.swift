//
//  CustomerCenterViewModel+Catalogue.swift
//
//
//  Created by Yusuf Tör on 23/09/2026.
//

import Foundation

// MARK: - Web product details

@available(iOS 15.0, *)
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
}
