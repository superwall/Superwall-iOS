//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct RestoreInfo: Encodable {
    /// When the transaction restoration was initiated.
    var startAt: Date

    /// When the transaction restoration failed.
    var failedAt: Date?

    /// When the transaction restoration completed.
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
      case startAt = "restore_initiated_ts"
      case failedAt = "restore_failed_ts"
      case completedAt = "restore_complete_ts"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(startAt, forKey: .startAt)
      try container.encodeIfPresent(failedAt, forKey: .failedAt)
      try container.encodeIfPresent(completedAt, forKey: .completedAt)
    }
  }
}
