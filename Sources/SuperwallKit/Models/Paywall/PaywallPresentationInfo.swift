//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/06/2024.
//

import Foundation

/// Information about the presentation of the paywall.
@objc(SWKPaywallPresentationInfo)
@objcMembers
public final class PaywallPresentationInfo: NSObject, Codable {
  /// The presentation style of the paywall.
  public let style: PaywallPresentationStyle

  // Objective-C compatibility properties (stored privately)
  private let _styleObjc: PaywallPresentationStyleObjc
  private let _drawerHeight: NSNumber?
  private let _drawerCornerRadius: NSNumber?

  /// The delay in milliseconds before switching from the loading view to
  /// the paywall view.
  public let delay: Int

  private enum CodingKeys: String, CodingKey {
    case style
    case delay
  }

  init(
    style: PaywallPresentationStyle = .modal,
    delay: Int
  ) {
    self.style = style
    self._styleObjc = style.toObjcStyle()
    self._drawerHeight = style.drawerHeight
    self._drawerCornerRadius = style.drawerCornerRadius
    self.delay = delay
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.style = try container.decode(PaywallPresentationStyle.self, forKey: .style)
    self.delay = try container.decode(Int.self, forKey: .delay)
    self._styleObjc = style.toObjcStyle()
    self._drawerHeight = style.drawerHeight
    self._drawerCornerRadius = style.drawerCornerRadius
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(style, forKey: .style)
    try container.encode(delay, forKey: .delay)
  }
}

// MARK: - Objective-C Compatibility
extension PaywallPresentationInfo {
  /// The presentation style of the paywall (Objective-C compatible).
  @available(swift, obsoleted: 1.0)
  @objc public var styleObjc: PaywallPresentationStyleObjc {
    return _styleObjc
  }

  /// The height for drawer presentation style when using Objective-C API.
  @available(swift, obsoleted: 1.0)
  @objc public var drawerHeight: NSNumber? {
    return _drawerHeight
  }

  /// The corner radius for drawer presentation style when using Objective-C API.
  @available(swift, obsoleted: 1.0)
  @objc public var drawerCornerRadius: NSNumber? {
    return _drawerCornerRadius
  }
}
