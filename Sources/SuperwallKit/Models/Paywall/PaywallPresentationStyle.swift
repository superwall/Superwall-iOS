//
//  PaywallPresentationStyle.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

/// Used to override the presentation style of the paywall set on the dashboard.
public enum PaywallPresentationStyle: Codable, Sendable, Equatable {
  /// A view presentation style that uses the modal presentation style `.pageSheet`.
  case modal

  /// A view presentation style in which the presented paywall slides up to cover the screen.
  case fullscreen

  /// A view presentation style in which the presented paywall covers the screen without animation.
  case fullscreenNoAnimation

  /// A view presentation style in which the presented paywall pushes on screen, as if pushed on to a navigation stack.
  case push

  /// A view presentation style in which the presented paywall slides up to cover a portion of the screen.
  ///
  /// If no height is specified, it will default to 70% of the screen.
  case drawer(height: Double?, cornerRadius: Double?)

  /// Indicates that the presentation style to be used is the one set on the dashboard.
  case none

  enum InternalPresentationStyle: String {
    case modal = "MODAL"
    case fullscreen = "FULLSCREEN"
    case fullscreenNoAnimation = "NO_ANIMATION"
    case push = "PUSH"
    case drawer = "DRAWER"
    case none = "NONE"
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case height
    case cornerRadius = "corner_radius"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let type = try container.decode(InternalPresentationStyle.RawValue.self, forKey: .type)
    let internalPresentationStyle = InternalPresentationStyle(rawValue: type) ?? .fullscreen
    switch internalPresentationStyle {
    case .modal:
      self = .modal
    case .fullscreen:
      self = .fullscreen
    case .fullscreenNoAnimation:
      self = .fullscreenNoAnimation
    case .push:
      self = .push
    case .drawer:
      let height = try container.decodeIfPresent(Double.self, forKey: .height)
      let cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius)
      self = .drawer(height: height, cornerRadius: cornerRadius)
    case .none:
      self = .none
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .modal:
      try container.encode(InternalPresentationStyle.modal.rawValue, forKey: .type)
    case .fullscreen:
      try container.encode(InternalPresentationStyle.fullscreen.rawValue, forKey: .type)
    case .fullscreenNoAnimation:
      try container.encode(InternalPresentationStyle.fullscreenNoAnimation.rawValue, forKey: .type)
    case .push:
      try container.encode(InternalPresentationStyle.push.rawValue, forKey: .type)
    case let .drawer(height, cornerRadius):
      try container.encode(InternalPresentationStyle.drawer.rawValue, forKey: .type)
      try container.encodeIfPresent(height, forKey: .height)
      try container.encodeIfPresent(cornerRadius, forKey: .cornerRadius)
    case .none:
      try container.encode(InternalPresentationStyle.none.rawValue, forKey: .type)
    }
  }

  /// Convert to Objective-C compatible enum
  func toObjcStyle() -> PaywallPresentationStyleObjc {
    switch self {
    case .modal:
      return .modal
    case .fullscreen:
      return .fullscreen
    case .fullscreenNoAnimation:
      return .fullscreenNoAnimation
    case .push:
      return .push
    case .drawer:
      return .drawer
    case .none:
      return .none
    }
  }

  /// Extract drawer height if present
  var drawerHeight: NSNumber? {
    if case .drawer(let height, _) = self {
      if let height = height {
        return NSNumber(value: height)
      }
    }
    return nil
  }

  /// Extract drawer corner radius if present
  var drawerCornerRadius: NSNumber? {
    if case .drawer(_, let cornerRadius) = self {
      if let cornerRadius = cornerRadius {
        return NSNumber(value: cornerRadius)
      }
    }
    return nil
  }

  // Added for backwards compatibility.
  // Remove in v5
  public static var drawer: PaywallPresentationStyle {
    return .drawer(height: nil, cornerRadius: nil)
  }
}

/// An enum representing the entitlement status of the user.
@objc(SWKPaywallPresentationStyle)
public enum PaywallPresentationStyleObjc: Int, Codable, Sendable {
  /// A view presentation style that uses the modal presentation style `.pageSheet`.
  case modal

  /// A view presentation style in which the presented paywall slides up to cover the screen.
  case fullscreen

  /// A view presentation style in which the presented paywall covers the screen without animation.
  case fullscreenNoAnimation

  /// A view presentation style in which the presented paywall pushes on screen, as if pushed on to a navigation stack.
  case push

  /// A view presentation style in which the presented paywall slides up to cover a portion of the screen.
  /// The height and corner radius can be customized via the PaywallPresentationInfo properties.
  case drawer

  /// Indicates that the presentation style to be used is the one set on the dashboard.
  case none

  /// Convert to Swift enum with associated values
  func toSwift(
    height: NSNumber? = nil,
    cornerRadius: NSNumber? = nil
  ) -> PaywallPresentationStyle {
    switch self {
    case .modal:
      return .modal
    case .fullscreen:
      return .fullscreen
    case .fullscreenNoAnimation:
      return .fullscreenNoAnimation
    case .push:
      return .push
    case .drawer:
      return .drawer(
        height: height?.doubleValue,
        cornerRadius: cornerRadius?.doubleValue
      )
    case .none:
      return .none
    }
  }
}
