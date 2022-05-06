//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension TriggerSession {
  struct Products: Encodable {
    /// The available products, with their order mapped to primary, secondary and tertiary.
    var allProducts: [SWProduct]

    /// The loading start, end and fail times.
    var loadingInfo: LoadingInfo

    enum CodingKeys: String, CodingKey {
      case allProducts = "paywall_products"

      case loadStartAt = "paywall_products_load_start_ts"
      case loadFail = "paywall_products_load_fail_ts"
      case loadEndAt = "paywall_products_load_end_ts"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(allProducts, forKey: .allProducts)
      try container.encodeIfPresent(loadingInfo.startAt, forKey: .loadStartAt)
      try container.encodeIfPresent(loadingInfo.endAt, forKey: .loadEndAt)
      try container.encodeIfPresent(loadingInfo.failAt, forKey: .loadFail)
    }
  }
}
