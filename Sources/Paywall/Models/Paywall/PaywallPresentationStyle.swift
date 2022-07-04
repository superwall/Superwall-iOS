//
//  PaywallPresentationStyle.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

@objc public enum PaywallPresentationStyle: Int, Decodable {
  case sheet
  case modal
  case fullscreen
  case fullscreenNoAnimation
  case push
  case none

  enum InternalPresentationStyle: String {
    case sheet = "SHEET"
    case modal = "MODAL"
    case fullscreen = "FULLSCREEN"
    case fullscreenNoAnimation = "NO_ANIMATION"
    case push = "PUSH"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(InternalPresentationStyle.RawValue.self)
    let internalPresentationStyle = InternalPresentationStyle(rawValue: rawValue) ?? .fullscreen

    let presentationStyle: PaywallPresentationStyle
    switch internalPresentationStyle {
    case .sheet:
      presentationStyle = .sheet
    case .modal:
      presentationStyle = .modal
    case .fullscreen:
      presentationStyle = .fullscreen
    case .fullscreenNoAnimation:
      presentationStyle = .fullscreenNoAnimation
    case .push:
      presentationStyle = .push
    }
    self = presentationStyle
  }
}
