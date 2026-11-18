//
//  CustomerCenterContrastTests.swift
//
//
//  Created by Vidur Saini on 18/11/2026.
//

import Testing
import SwiftUI
import UIKit
@testable import SuperwallKit

/// Text colours must keep the 4.5:1 WCAG asks of text against what they sit on, in both
/// appearances. Computed from the resolved colours rather than a render, so it fails on the colour
/// itself and not on anti-aliasing.
@Suite("Customer Center contrast")
struct CustomerCenterContrastTests {
  private struct RGB {
    let red: Double
    let green: Double
    let blue: Double
  }

  private func rgb(_ color: UIColor, _ style: UIUserInterfaceStyle, over background: RGB? = nil) -> RGB {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
      .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    guard let background else { return RGB(red: red, green: green, blue: blue) }
    return RGB(
      red: red * alpha + background.red * (1 - alpha),
      green: green * alpha + background.green * (1 - alpha),
      blue: blue * alpha + background.blue * (1 - alpha)
    )
  }

  private func luminance(_ color: RGB) -> Double {
    func linear(_ value: Double) -> Double {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
  }

  private func ratio(_ first: RGB, _ second: RGB) -> Double {
    let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
    return (lighter + 0.05) / (darker + 0.05)
  }

  /// The cards behind the text: the grouped cell colour, and in dark mode the lighter one a sheet
  /// uses.
  private func cards(_ style: UIUserInterfaceStyle) -> [RGB] {
    let card = rgb(.secondarySystemGroupedBackground, style)
    guard style == .dark else { return [card] }
    let sheet = UITraitCollection(traitsFrom: [
      UITraitCollection(userInterfaceStyle: .dark),
      UITraitCollection(userInterfaceLevel: .elevated)
    ])
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    UIColor.secondarySystemGroupedBackground.resolvedColor(with: sheet)
      .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [card, RGB(red: red, green: green, blue: blue)]
  }

  @Test(
    "badge text keeps 4.5:1 on its tint and on the card",
    arguments: [
      (Color.customerCenterGreenText, UIColor.systemGreen),
      (Color.customerCenterOrangeText, UIColor.systemOrange),
      (Color.customerCenterRedText, UIColor.systemRed),
      (Color.customerCenterGrayText, UIColor.systemGray)
    ]
  )
  func badgeText(text: Color, tint: UIColor) {
    for style in [UIUserInterfaceStyle.light, .dark] {
      for card in cards(style) {
        let foreground = rgb(UIColor(text), style)
        let background = rgb(tint.withAlphaComponent(0.15), style, over: card)
        #expect(ratio(foreground, background) >= 4.5, "\(style == .dark ? "dark" : "light") tint")
        #expect(ratio(foreground, card) >= 4.5, "\(style == .dark ? "dark" : "light") card")
      }
    }
  }

  @Test("secondary text keeps 4.5:1 on the card and the grouped background")
  func secondaryText() {
    for style in [UIUserInterfaceStyle.light, .dark] {
      for background in cards(style) + [rgb(.systemGroupedBackground, style)] {
        let foreground = rgb(UIColor(Color.customerCenterSecondaryText), style, over: background)
        #expect(ratio(foreground, background) >= 4.5)
      }
    }
  }
}
