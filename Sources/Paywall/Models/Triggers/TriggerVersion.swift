//
//  TriggerVersion.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum TriggerVersion: Decodable, Hashable {
  // swiftlint:disable:next identifier_name
  case v1
  // swiftlint:disable:next identifier_name
  case v2(TriggerV2)

  enum Keys: String, CodingKey {
    case triggerVersion
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: TriggerVersion.Keys.self)
    let triggerVersion = try values.decode(String.self, forKey: .triggerVersion)

    switch triggerVersion {
    case "V1":
      self = .v1
    case "V2":
      self = .v2(try TriggerV2(from: decoder))
    default:
      self = .v1
    }
  }
}
