//
//  File.swift
//  
//
//  Created by Jake Mor on 3/22/23.
//

import Foundation

public enum FeatureGatingBehavior: String, Codable {
  case gated = "GATED"
  case nonGated = "NON_GATED"

  enum CodingKeys: String, CodingKey {
    case gated = "GATED"
    case nonGated = "NON_GATED"
  }
}
