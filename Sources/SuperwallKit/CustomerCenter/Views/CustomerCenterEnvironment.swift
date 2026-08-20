//
//  CustomerCenterEnvironment.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
struct CustomerCenterTheme {
  var accent: Color?
  var background: Color?
  var text: Color?
  var buttonText: Color?
  var buttonBackground: Color?

  init(appearance: CustomerCenterConfiguration.Appearance, colorScheme: ColorScheme) {
    func color(_ pair: CustomerCenterConfiguration.Appearance.ColorPair?) -> Color? {
      guard let pair else { return nil }
      return UIColor(hex: colorScheme == .dark ? pair.dark : pair.light).map(Color.init)
    }
    accent = color(appearance.accent)
    background = color(appearance.background)
    text = color(appearance.text)
    buttonText = color(appearance.buttonText)
    buttonBackground = color(appearance.buttonBackground)
  }
}

extension UIColor {
  /// Parses `#RRGGBB` / `#RRGGBBAA` / `RRGGBB`.
  convenience init?(hex: String) {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.count == 6 || value.count == 8, let int = UInt64(value, radix: 16) else { return nil }
    let hasAlpha = value.count == 8
    let red = CGFloat((int >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
    let green = CGFloat((int >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
    let blue = CGFloat((int >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
    let alpha = hasAlpha ? CGFloat(int & 0xFF) / 255 : 1
    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }
}

@available(iOS 15.0, *)
private struct CustomerCenterStringsKey: EnvironmentKey {
  static let defaultValue = CustomerCenterStrings.english
}
@available(iOS 15.0, *)
private struct CustomerCenterThemeKey: EnvironmentKey {
  static let defaultValue = CustomerCenterTheme(appearance: .init(), colorScheme: .light)
}
@available(iOS 15.0, *)
extension EnvironmentValues {
  var customerCenterStrings: CustomerCenterStrings {
    get { self[CustomerCenterStringsKey.self] }
    set { self[CustomerCenterStringsKey.self] = newValue }
  }
  var customerCenterTheme: CustomerCenterTheme {
    get { self[CustomerCenterThemeKey.self] }
    set { self[CustomerCenterThemeKey.self] = newValue }
  }
}
