//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 03/06/2025.
//

import Foundation

struct PaywallPreloading: Codable, Equatable {
  let schedule: [PreloadingStep]
}

struct PreloadingStep: Codable, Equatable {
  let placements: [PreloadablePlacement]
  let delay: Milliseconds

  enum CodingKeys: String, CodingKey {
    case placements
    case delay = "delayMs"
  }
}

struct PreloadablePlacement: Codable, Equatable {
  let placement: String
}
