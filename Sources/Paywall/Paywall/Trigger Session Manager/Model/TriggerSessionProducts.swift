//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension TriggerSession {
  struct Products: Codable {
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

    init(
      allProducts: [SWProduct],
      loadingInfo: LoadingInfo
    ) {
      self.allProducts = allProducts
      self.loadingInfo = loadingInfo
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      allProducts = try values.decode([SWProduct].self, forKey: .allProducts)

      let startAt = try values.decodeIfPresent(Date.self, forKey: .loadStartAt)
      let endAt = try values.decodeIfPresent(Date.self, forKey: .loadEndAt)
      let failAt = try values.decodeIfPresent(Date.self, forKey: .loadFail)
      loadingInfo = LoadingInfo(
        startAt: startAt,
        endAt: endAt,
        failAt: failAt
      )
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
