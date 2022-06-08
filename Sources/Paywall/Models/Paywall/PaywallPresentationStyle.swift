//
//  PaywallPresentationStyle.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum PaywallPresentationStyle: String, Decodable {
  case sheet = "SHEET"
  case modal = "MODAL"
  case fullscreen = "FULLSCREEN"
  case fullscreenNoAnimation = "NO_ANIMATION"
  case push = "PUSH"

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(RawValue.self)
    self = PaywallPresentationStyle(rawValue: rawValue) ?? .fullscreen
  }
}
