//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/09/2022.
//

import Foundation
import StoreKit
@testable import Paywall

final class ProductsManagerMock: ProductsManager {
  let productCompletionResult: Result<Set<SKProduct>, Error>

  init(productCompletionResult: Result<Set<SKProduct>, Error>) {
    self.productCompletionResult = productCompletionResult
  }

  override func products(
    withIdentifiers identifiers: Set<String>,
    completion: @escaping ProductsManager.ProductRequestCompletionBlock
  ) {
    completion(productCompletionResult)
  }
}
