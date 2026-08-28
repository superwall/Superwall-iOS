//
//  CustomerCenterConfiguration+Appearance.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Foundation
import UIKit

extension CustomerCenterConfiguration {
  // MARK: - Appearance

  /// Colour overrides for the Customer Center.
  ///
  /// Only the accent is applied. Slots for background, text and button colours existed here
  /// before anything read them; exposing colours that reach no pixel would have meant either
  /// honouring them later or removing them later, and removing them from a public, `Codable`,
  /// Objective-C-exposed type is a breaking change. They come back when they're wired up.
  @objc(SWKCustomerCenterAppearance)
  @objcMembers
  public final class Appearance: NSObject, Codable {
    /// Tints controls and links. `nil` uses the system accent.
    public var accent: ColorPair?

    public init(accent: ColorPair? = nil) {
      self.accent = accent
    }

    override public func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? Appearance else { return false }
      return accent == other.accent
    }

    override public var hash: Int {
      var hasher = Hasher()
      hasher.combine(accent)
      return hasher.finalize()
    }

    /// A light/dark color pair stored as hex strings (`#RRGGBB` or `#RRGGBBAA`).
    @objc(SWKCustomerCenterColorPair)
    @objcMembers
    public final class ColorPair: NSObject, Codable {
      public var light: String
      public var dark: String

      public init(light: String, dark: String) {
        self.light = light
        self.dark = dark
      }

      @nonobjc public convenience init(light: UIColor, dark: UIColor) {
        self.init(light: light.hexString, dark: dark.hexString)
      }

      override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ColorPair else { return false }
        return light == other.light && dark == other.dark
      }

      override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(light)
        hasher.combine(dark)
        return hasher.finalize()
      }
    }
  }
}

extension UIColor {
  /// `#RRGGBBAA` representation.
  var hexString: String {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return String(
      format: "#%02X%02X%02X%02X",
      Int(round(red * 255)),
      Int(round(green * 255)),
      Int(round(blue * 255)),
      Int(round(alpha * 255))
    )
  }
}
