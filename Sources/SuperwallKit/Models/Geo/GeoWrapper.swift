//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/05/2024.
//

import Foundation

struct GeoWrapper: Codable {
  let info: GeoInfo

  enum CodingKeys: String, CodingKey {
    case info = "geoInfo"
  }
}
