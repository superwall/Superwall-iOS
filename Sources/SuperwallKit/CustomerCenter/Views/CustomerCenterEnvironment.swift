//
//  CustomerCenterEnvironment.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

#if canImport(WebKit)
import SwiftUI

struct CustomerCenterTheme {
  var accent: Color?

  init(appearance: CustomerCenterConfiguration.Appearance, colorScheme: ColorScheme) {
    func color(_ pair: CustomerCenterConfiguration.Appearance.ColorPair?) -> Color? {
      guard let pair else { return nil }
      return PlatformColor(hex: colorScheme == .dark ? pair.dark : pair.light).map(Color.init)
    }
    accent = color(appearance.accent)
  }
}

private struct CustomerCenterStringsKey: EnvironmentKey {
  static let defaultValue = CustomerCenterStrings.english
}
private struct CustomerCenterThemeKey: EnvironmentKey {
  static let defaultValue = CustomerCenterTheme(appearance: .init(), colorScheme: .light)
}
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
#endif
