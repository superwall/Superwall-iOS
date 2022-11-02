//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/09/2022.
//

import Foundation
import StoreKit
@testable import SuperwallKit

final class ProductsManagerMock: ProductsManager {
  let productCompletionResult: Result<Set<SKProduct>, Error>

  init(productCompletionResult: Result<Set<SKProduct>, Error>) {
    self.productCompletionResult = productCompletionResult
    super.init()
  }

  override func getProducts(identifiers: Set<String>) async throws -> Set<SKProduct> {
    return try productCompletionResult.get()
  }
}
