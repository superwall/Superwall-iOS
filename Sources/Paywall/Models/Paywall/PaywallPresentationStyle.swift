//
//  PaywallPresentationStyle.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

/// Used to override the presentation style of the paywall set on the dashboard.
@objc public enum PaywallPresentationStyle: Int, Decodable {
  /// A view presentation style that uses the modal presentation style`.pageSheet`.
  case modal
  /// A view presentation style in which the presented paywall slides up to cover the screen.
  case fullscreen
  /// A view presentation style in which the presented paywall covers the screen without animation.
  case fullscreenNoAnimation
  /// A view presentation style in which the presented paywall pushes on screen, as if pushed on to a navigation stack.
  case push
  /// Indicates that the presentation style to be used is the one set on the dashboard.
  case none

  enum InternalPresentationStyle: String {
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
