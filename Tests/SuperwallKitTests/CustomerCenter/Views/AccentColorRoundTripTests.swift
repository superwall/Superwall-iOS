//
//  AccentColorRoundTripTests.swift
//  SuperwallKit
//
//  Created by Jordan Morgan on 21/08/2026.
//

import Testing
import UIKit
@testable import SuperwallKit

@Suite("Appearance accent round trip")
struct AccentColorRoundTripTests {
  @Test("a UIColor accent survives the hex round trip into a usable Color")
  func systemColorRoundTrip() {
    let pair = CustomerCenterConfiguration.Appearance.ColorPair(
      light: .systemPurple,
      dark: .systemTeal
    )

    let parsedLight = UIColor(hex: pair.light)
    let parsedDark = UIColor(hex: pair.dark)

    #expect(parsedLight != nil, "light hex \(pair.light) failed to parse")
    #expect(parsedDark != nil, "dark hex \(pair.dark) failed to parse")

    // And through the theme the views actually read.
    let appearance = CustomerCenterConfiguration.Appearance(accent: pair)
    let lightTheme = CustomerCenterTheme(appearance: appearance, colorScheme: .light)
    #expect(lightTheme.accent != nil, "theme produced no accent colour")
  }
}
