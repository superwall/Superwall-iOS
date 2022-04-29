//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Products: Encodable {
    /// The identifiers of the products, e.g. `com.fitnessai.annual_89.99_7`
    let platformIdentifiers: [String]
    /// The loading start and end times, as well as duration.
    var loadingInfo: LoadingInfo

    enum CodingKeys: String, CodingKey {
      case ids = "product_ids"
      case platformIdentifiers = "product_platform_identifiers"
      case loadDuration = "products_load_duration"
      case loadStartAt = "products_load_start_ts"
      case loadEndAt = "products_load_end_ts"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(platformIdentifiers, forKey: .platformIdentifiers)
      try container.encode(loadingInfo.startAt, forKey: .loadStartAt)
      try container.encode(loadingInfo.endAt, forKey: .loadEndAt)
      try container.encode(loadingInfo.duration, forKey: .loadDuration)
    }
  }
}
