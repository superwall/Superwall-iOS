//
//  UIColor+Hex.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

extension UIColor {
  convenience init(hexString: String) {
    let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: hex).scanHexInt64(&int)

    let alpha, red, green, blue: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (alpha, red, green, blue) = (255, 0, 0, 0)
    }
    self.init(
      red: CGFloat(red) / 255,
      green: CGFloat(green) / 255,
      blue: CGFloat(blue) / 255,
      alpha: CGFloat(alpha) / 255
    )
  }

  var readableOverlayColor: UIColor {
    return isDarkColor ? .white : .black
  }

  private var isDarkColor: Bool {
    var red, green, blue, alpha: CGFloat
    (red, green, blue, alpha) = (0, 0, 0, 0)
    self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let lum = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    return  lum < 0.50
  }
}
