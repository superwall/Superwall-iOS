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

  @objc(SWKCustomerCenterAppearance)
  @objcMembers
  public final class Appearance: NSObject, Codable {
    public var accent: ColorPair?
    public var background: ColorPair?
    public var text: ColorPair?
    public var buttonText: ColorPair?
    public var buttonBackground: ColorPair?

    public init(
      accent: ColorPair? = nil,
      background: ColorPair? = nil,
      text: ColorPair? = nil,
      buttonText: ColorPair? = nil,
      buttonBackground: ColorPair? = nil
    ) {
      self.accent = accent
      self.background = background
      self.text = text
      self.buttonText = buttonText
      self.buttonBackground = buttonBackground
    }

    override public func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? Appearance else { return false }
      return accent == other.accent && background == other.background && text == other.text
        && buttonText == other.buttonText && buttonBackground == other.buttonBackground
    }

    override public var hash: Int {
      var hasher = Hasher()
      hasher.combine(accent)
      hasher.combine(background)
      hasher.combine(text)
      hasher.combine(buttonText)
      hasher.combine(buttonBackground)
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
