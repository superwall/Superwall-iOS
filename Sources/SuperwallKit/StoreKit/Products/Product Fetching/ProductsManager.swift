//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//

import Foundation

protocol ProductFetchable: AnyObject {
  func products(
    identifiers: Set<String>,
    forPaywall paywall: Paywall?,
    placement: PlacementData?
  ) async throws -> Set<StoreProduct>
}

final class ProductsManager {
  private let storeKitVersion: SuperwallOptions.StoreKitVersion
  private let productsFetcher: ProductFetchable

  init(
    entitlementsInfo: EntitlementsInfo,
    storeKitVersion: SuperwallOptions.StoreKitVersion
  ) {
    self.storeKitVersion = storeKitVersion

    if #available(iOS 15.0, *),
      storeKitVersion == .storeKit2 {
      self.productsFetcher = ProductsFetcherSK2(entitlementsInfo: entitlementsInfo)
    } else {
      self.productsFetcher = ProductsFetcherSK1(entitlementsInfo: entitlementsInfo)
    }
  }

  func products(
    identifiers: Set<String>,
    forPaywall paywall: Paywall?,
    placement: PlacementData?
  ) async throws -> Set<StoreProduct> {
    return try await productsFetcher.products(
      identifiers: identifiers,
      forPaywall: paywall,
      placement: placement
    )
  }
}
