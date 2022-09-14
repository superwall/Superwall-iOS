//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension TriggerSession {
  struct Transaction: Codable, Equatable {
    /// The id of the transaction
    var id: String?

    /// When the transaction started.
    let startAt: Date?

    /// When the transaction ended.
    var endAt: Date?

    enum Outcome: String, Codable {
      case subscriptionStart = "SUBSCRIPTION_START"
      case trialStart = "TRIAL_START"
      case nonRecurringProductPurchase = "NON_RECURRING_PRODUCT_PURCHASE"
    }
    /// The outcome of the transaction
    var outcome: Outcome?

    struct Count: Codable, Equatable {
      var start: Int = 0
      var complete: Int = 0
      var fail: Int = 0
      var abandon: Int = 0
      var restore: Int = 0
    }
    /// The count for certain transaction actions.
    var count: Count?

    enum Status: String, Codable {
      case complete = "TRANSACTION_COMPLETE"
      case fail = "TRANSACTION_FAIL"
      case abandon = "TRANSACTION_ABANDON"
    }
    var status: Status?

    /// The product from the transaction
    let product: Product

    init(
      id: String? = nil,
      startAt: Date?,
      endAt: Date? = nil,
      outcome: Outcome? = nil,
      count: Count?,
      status: Status? = nil,
      product: Product
    ) {
      self.id = id
      self.startAt = startAt
      self.endAt = endAt
      self.outcome = outcome
      self.count = count
      self.status = status
      self.product = product
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      id = try values.decodeIfPresent(String.self, forKey: .id)
      startAt = try values.decodeIfPresent(Date.self, forKey: .startAt)
      endAt = try values.decodeIfPresent(Date.self, forKey: .endAt)
      outcome = try values.decodeIfPresent(Outcome.self, forKey: .outcome)

      let start = try values.decodeIfPresent(Int.self, forKey: .startCount)
      let complete = try values.decodeIfPresent(Int.self, forKey: .completeCount)
      let fail = try values.decodeIfPresent(Int.self, forKey: .failCount)
      let abandon = try values.decodeIfPresent(Int.self, forKey: .abandonCount)
      let restore = try values.decodeIfPresent(Int.self, forKey: .restoreCount)

      if let start,
        let complete,
        let fail,
        let abandon,
        let restore {
        self.count = Count(
          start: start,
          complete: complete,
          fail: fail,
          abandon: abandon,
          restore: restore
        )
      }
      status = try values.decodeIfPresent(Status.self, forKey: .status)

      product = try Product(from: decoder)
    }

    enum CodingKeys: String, CodingKey {
      case id = "transaction_id"
      case startAt = "transaction_start_ts"
      case endAt = "transaction_end_ts"

      case startCount = "transaction_start_count"
      case completeCount = "transaction_complete_count"
      case failCount = "transaction_fail_count"
      case abandonCount = "transaction_abandon_count"
      case restoreCount = "transaction_restore_count"

      case status = "transaction_status"

      case outcome = "transaction_outcome"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encodeIfPresent(id, forKey: .id)
      try container.encodeIfPresent(startAt, forKey: .startAt)
      try container.encodeIfPresent(endAt, forKey: .endAt)
      try container.encodeIfPresent(count?.start, forKey: .startCount)
      try container.encodeIfPresent(count?.complete, forKey: .completeCount)
      try container.encodeIfPresent(count?.fail, forKey: .failCount)
      try container.encodeIfPresent(count?.abandon, forKey: .abandonCount)
      try container.encodeIfPresent(count?.restore, forKey: .restoreCount)
      try container.encodeIfPresent(outcome, forKey: .outcome)
      try container.encodeIfPresent(status, forKey: .status)

      try product.encode(to: encoder)
    }
  }
}
