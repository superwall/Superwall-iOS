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

  private static let styles: [UIUserInterfaceStyle] = [.light, .dark]
  private static let badges: [(Color, UIColor)] = [
    (Color.customerCenterGreenText, UIColor.systemGreen),
    (Color.customerCenterOrangeText, UIColor.systemOrange),
    (Color.customerCenterRedText, UIColor.systemRed),
    (Color.customerCenterGrayText, UIColor.systemGray)
  ]

  private func traits(
    _ style: UIUserInterfaceStyle,
    elevated: Bool = false,
    highContrast: Bool = false
  ) -> UITraitCollection {
    UITraitCollection(traitsFrom: [
      UITraitCollection(userInterfaceStyle: style),
      UITraitCollection(userInterfaceLevel: elevated ? .elevated : .base),
      UITraitCollection(accessibilityContrast: highContrast ? .high : .normal)
    ])
  }

  private func rgb(_ color: UIColor, _ traits: UITraitCollection, over background: RGB? = nil) -> RGB {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
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
  private func cards(_ style: UIUserInterfaceStyle, highContrast: Bool = false) -> [RGB] {
    let card = rgb(.secondarySystemGroupedBackground, traits(style, highContrast: highContrast))
    guard style == .dark else { return [card] }
    let sheet = rgb(
      .secondarySystemGroupedBackground,
      traits(style, elevated: true, highContrast: highContrast)
    )
    return [card, sheet]
  }

  /// Everything the secondary text and close icon sit on: the cards and the grouped background.
  private func backgrounds(_ style: UIUserInterfaceStyle, highContrast: Bool = false) -> [RGB] {
    cards(style, highContrast: highContrast)
      + [rgb(.systemGroupedBackground, traits(style, highContrast: highContrast))]
  }

  @Test(
    "badge text keeps 4.5:1 on its tint and on the card",
    arguments: badges
  )
  func badgeText(text: Color, tint: UIColor) {
    for style in Self.styles {
      for card in cards(style) {
        let foreground = rgb(UIColor(text), traits(style))
        let background = rgb(tint.withAlphaComponent(0.15), traits(style), over: card)
        #expect(ratio(foreground, background) >= 4.5, "\(style == .dark ? "dark" : "light") tint")
        #expect(ratio(foreground, card) >= 4.5, "\(style == .dark ? "dark" : "light") card")
      }
    }
  }

  @Test("secondary text keeps 4.5:1 on the card and the grouped background")
  func secondaryText() {
    for style in Self.styles {
      for background in backgrounds(style) {
        let foreground = rgb(UIColor(Color.customerCenterSecondaryText), traits(style), over: background)
        #expect(ratio(foreground, background) >= 4.5)
      }
    }
  }

  /// What the close button sits on: the page behind the list, in a sheet or not.
  private func pageBackgrounds(_ style: UIUserInterfaceStyle, highContrast: Bool = false) -> [RGB] {
    [false, true].map { elevated in
      rgb(.systemGroupedBackground, traits(style, elevated: elevated, highContrast: highContrast))
    }
  }

  @Test("close icon keeps 4.5:1 on the page")
  func closeIcon() {
    for style in Self.styles {
      for background in pageBackgrounds(style) {
        let foreground = rgb(UIColor(Color.customerCenterCloseIcon), traits(style), over: background)
        #expect(ratio(foreground, background) >= 4.5)
      }
    }
  }

  /// Turning on Increase Contrast must never make a colour stand out less than the system colour
  /// it replaces does with the setting on, nor less than it does itself with the setting off.
  @Test(
    "Increase Contrast never lowers contrast",
    arguments: badges + [
      (Color.customerCenterSecondaryText, UIColor.secondaryLabel)
    ]
  )
  func increaseContrast(color: Color, system: UIColor) {
    expectIncreaseContrastHelps(color, over: system) { style, _ in backgrounds(style, highContrast: true) }
  }

  @Test("Increase Contrast never lowers the close icon's contrast")
  func increaseContrastCloseIcon() {
    expectIncreaseContrastHelps(.customerCenterCloseIcon, over: .secondaryLabel) { style, elevated in
      [rgb(.systemGroupedBackground, traits(style, elevated: elevated, highContrast: true))]
    }
  }

  /// Checks `color` on each background, resolved for the same appearance as the background, in
  /// a sheet (`elevated`) or not.
  private func expectIncreaseContrastHelps(
    _ color: Color,
    over system: UIColor,
    on backgrounds: (UIUserInterfaceStyle, _ elevated: Bool) -> [RGB]
  ) {
    for style in Self.styles {
      for elevated in [false, true] {
        let highTraits = traits(style, elevated: elevated, highContrast: true)
        let normalTraits = traits(style, elevated: elevated)
        for background in backgrounds(style, elevated) {
          let high = ratio(rgb(UIColor(color), highTraits, over: background), background)
          let normal = ratio(rgb(UIColor(color), normalTraits, over: background), background)
          let systemHigh = ratio(rgb(system, highTraits, over: background), background)
          #expect(high >= normal - 0.01, "\(style == .dark ? "dark" : "light") against itself")
          #expect(high >= systemHigh - 0.01, "\(style == .dark ? "dark" : "light") against the system colour")
        }
      }
    }
  }
}
