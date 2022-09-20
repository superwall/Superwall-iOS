//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import Foundation
import StoreKit

extension TransactionModel {
  struct Payment: Codable {
    /// The ID of a product being bought.
    let productIdentifier: String

    /// The number of items the user wants to purchase.
    let quantity: Int

    /// The ID for the discount offer to apply to the payment.
    let discountIdentifier: String?

    init(from payment: SKPayment) {
      self.productIdentifier = payment.productIdentifier
      self.quantity = payment.quantity
      self.discountIdentifier = payment.paymentDiscount?.identifier
    }
  }
}
