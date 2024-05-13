//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/05/2024.
//

import Foundation

struct GeoInfo: Codable {
  let city: String?
  let country: String?
  let longitude: Double?
  let latitude: Double?
  let region: String?
  let regionCode: String?
  let metroCode: String?
  let postalCode: String?
  let timezone: String?
}
