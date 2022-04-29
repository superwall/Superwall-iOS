//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Transaction: Encodable {
    /// When the transaction started.
    let startAt: Date

    /// When the transaction ended.
    var completeAt: Date?

      /// When the transaction failed.
    var failAt: Date?

      /// When the transaction was abandoned.
    var abandonAt: Date?

    enum Outcome: String, Encodable {
      case completed
      case failed
      case abandoned
      case restored
      case restoreFailed = "restore_failed"
      case noTransaction = "no_transaction"
    }
    /// The outcome of the transaction
    var outcome: Outcome?

    /// The product from the transaction
    let product: Product

    enum CodingKeys: String, CodingKey {
      case startAt = "transaction_start_ts"
      case completeAt = "transaction_complete_ts"
      case failAt = "transaction_fail_ts"
      case abandonAt = "transaction_abandon_ts"
      case outcome = "transaction_outcome"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(startAt, forKey: .startAt)
      try container.encodeIfPresent(failAt, forKey: .failAt)
      try container.encodeIfPresent(completeAt, forKey: .completeAt)
      try container.encodeIfPresent(abandonAt, forKey: .abandonAt)
      try container.encodeIfPresent(outcome, forKey: .outcome)

      try product.encode(to: encoder)
    }
  }
}
