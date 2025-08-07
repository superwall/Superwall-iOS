//
//  PaywallPresentationStyle.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

/// Used to override the presentation style of the paywall set on the dashboard.
@objc(SWKPaywallPresentationStyle)
public enum PaywallPresentationStyle: Int, Codable, Sendable {
  /// A view presentation style that uses the modal presentation style `.pageSheet`.
  case modal

  /// A view presentation style in which the presented paywall slides up to cover the screen.
  case fullscreen

  /// A view presentation style in which the presented paywall covers the screen without animation.
  case fullscreenNoAnimation

  /// A view presentation style in which the presented paywall pushes on screen, as if pushed on to a navigation stack.
  case push

  /// A view presentation style in which the presented paywall slides up to cover 62% of the screen.
  case drawer

  /// Indicates that the presentation style to be used is the one set on the dashboard.
  case none

  /// A view presentation style in which the presented paywall pops over the top of the view.
  case popup

  enum InternalPresentationStyle: String {
    case modal = "MODAL"
    case fullscreen = "FULLSCREEN"
    case fullscreenNoAnimation = "NO_ANIMATION"
    case push = "PUSH"
    case drawer = "DRAWER"
    case none = "NONE"
    case popup = "POPUP"
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
    case .drawer:
      presentationStyle = .drawer
    case .none:
      presentationStyle = .none
    case .popup:
      presentationStyle = .popup
    }
    self = presentationStyle
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    let internalPresentationStyle: InternalPresentationStyle
    switch self {
    case .modal:
      internalPresentationStyle = .modal
    case .fullscreen:
      internalPresentationStyle = .fullscreen
    case .fullscreenNoAnimation:
      internalPresentationStyle = .fullscreenNoAnimation
    case .push:
      internalPresentationStyle = .push
    case .drawer:
      internalPresentationStyle = .drawer
    case .none:
      internalPresentationStyle = .none
    case .popup:
      internalPresentationStyle = .popup
    }

    try container.encode(internalPresentationStyle.rawValue)
  }
}
