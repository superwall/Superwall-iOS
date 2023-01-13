//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/09/2022.
//

import Foundation
import StoreKit
@testable import SuperwallKit

final class ProductsFetcherSK1Mock: ProductsFetcherSK1 {
  let productCompletionResult: Result<Set<StoreProduct>, Error>

  init(productCompletionResult: Result<Set<StoreProduct>, Error>) {
    self.productCompletionResult = productCompletionResult
    super.init()
  }

  override func products(identifiers: Set<String>) async throws -> Set<StoreProduct> {
    return try productCompletionResult.get()
  }
}
