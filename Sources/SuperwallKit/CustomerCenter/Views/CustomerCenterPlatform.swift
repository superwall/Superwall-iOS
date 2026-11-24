//
//  CustomerCenterPlatform.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// The SwiftUI the Customer Center uses that only iOS has, with the macOS
// equivalent beside it, so the screens themselves read the same on both.

#if canImport(WebKit)
import SwiftUI

enum CustomerCenterPlatform {
  /// Whether StoreKit can show its refund sheet: on every supported iOS, and on
  /// macOS from 14.
  static var isRefundSheetAvailable: Bool {
    #if os(macOS)
    if #available(macOS 14.0, *) {
      return true
    }
    return false
    #else
    return true
    #endif
  }
}

extension View {
  /// Grouped rows with rounded sections: `insetGrouped` on iOS, `inset` on macOS.
  @ViewBuilder
  func customerCenterListStyle() -> some View {
    #if os(macOS)
    listStyle(.inset)
    #else
    listStyle(.insetGrouped)
    #endif
  }

  /// Room for the Customer Center in a sheet. A Mac sheet takes its size from
  /// its content, and a list has none of its own, so it would open collapsed.
  @ViewBuilder
  func customerCenterSheetFrame() -> some View {
    #if os(macOS)
    frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 680)
    #else
    self
    #endif
  }

  /// A compact title. A Mac window shows its title one way, so there's nothing to set.
  @ViewBuilder
  func customerCenterInlineTitle() -> some View {
    #if os(macOS)
    self
    #else
    navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

extension ToolbarItemPlacement {
  /// Where the close and cancel buttons go: trailing in the navigation bar on
  /// iOS, and where a Mac puts a sheet's cancel button.
  static var customerCenterDismissal: ToolbarItemPlacement {
    #if os(macOS)
    return .cancellationAction
    #else
    return .navigationBarTrailing
    #endif
  }
}

extension Color {
  /// The background behind the Customer Center's lists.
  static var customerCenterGroupedBackground: Color {
    #if os(macOS)
    return Color(nsColor: .windowBackgroundColor)
    #else
    return Color(uiColor: .systemGroupedBackground)
    #endif
  }

  /// Secondary text. The system's secondary label is 3.3:1 on the grouped background in light
  /// mode, under the 4.5:1 WCAG asks of text, so light mode uses a darker grey (4.7:1). Dark mode
  /// keeps the system colour, which passes.
  static var customerCenterSecondaryText: Color {
    customerCenterDynamic(
      light: PlatformColor(hexString: "#6C6C70"),
      dark: .customerCenterSecondaryLabel,
      system: .customerCenterSecondaryLabel
    )
  }

  /// The close button's icon. A fixed grey rather than `.secondary`, which renders as the tint at
  /// reduced opacity on iOS 26's glass button and can fall under the 3:1 an icon needs (1.6:1 with
  /// a light accent). This is 4.9:1 light and 5.1:1 dark on the glass, and more on an opaque bar.
  static var customerCenterCloseIcon: Color {
    customerCenterDynamic(
      light: PlatformColor(hexString: "#6C6C70"),
      dark: PlatformColor(hexString: "#AEAEB2"),
      system: .customerCenterSecondaryLabel
    )
  }

  // Text versions of the badge colours, each at least 4.5:1 on its badge's 15% tint and on the
  // card, in both appearances, including the lighter card of a sheet in dark mode. Dark mode keeps
  // the system green and orange, which already pass.
  static let customerCenterGreenText = customerCenterDynamic(
    light: PlatformColor(hexString: "#207B37"),
    dark: .systemGreen,
    system: .systemGreen
  )
  static let customerCenterOrangeText = customerCenterDynamic(
    light: PlatformColor(hexString: "#A15919"),
    dark: .systemOrange,
    system: .systemOrange
  )
  static let customerCenterRedText = customerCenterDynamic(
    light: PlatformColor(hexString: "#C22B2E"),
    dark: PlatformColor(hexString: "#FF7779"),
    system: .systemRed
  )
  static let customerCenterGrayText = customerCenterDynamic(
    light: PlatformColor(hexString: "#6A6A6E"),
    dark: PlatformColor(hexString: "#A6A6AA"),
    system: .systemGray
  )

  /// `light` in light mode and `dark` in dark mode. With Increase Contrast on, `system` is used
  /// instead whenever it contrasts more with the page, as the system colours then become darker
  /// in light mode and lighter in dark mode, so turning the setting on never lowers the contrast.
  static func customerCenterDynamic(light: PlatformColor, dark: PlatformColor, system: PlatformColor) -> Color {
    #if os(macOS)
    return Color(nsColor: NSColor(name: nil) { appearance in
      let match = appearance.bestMatch(
        from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]
      )
      let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
      let chosen = isDark ? dark : light
      let isHighContrast = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
      if !isHighContrast {
        return chosen
      }
      var chosenRGB: NSColor?
      var systemRGB: NSColor?
      var page: NSColor?
      appearance.performAsCurrentDrawingAppearance {
        chosenRGB = chosen.usingColorSpace(.sRGB)
        systemRGB = system.usingColorSpace(.sRGB)
        page = NSColor.windowBackgroundColor.usingColorSpace(.sRGB)
      }
      guard
        let chosenRGB,
        let systemRGB,
        let page
      else {
        return chosen
      }
      return customerCenterStandsOutMore(systemRGB, than: chosenRGB, on: page) ? systemRGB : chosen
    })
    #else
    return Color(uiColor: UIColor { traits in
      let isDark = traits.userInterfaceStyle == .dark
      let chosen = isDark ? dark : light
      if traits.accessibilityContrast != .high {
        return chosen
      }
      let systemRGB = system.resolvedColor(with: traits)
      let chosenRGB = chosen.resolvedColor(with: traits)
      let page = UIColor.systemGroupedBackground.resolvedColor(with: traits)
      return customerCenterStandsOutMore(systemRGB, than: chosenRGB, on: page) ? systemRGB : chosen
    })
    #endif
  }

  /// Whether `color` contrasts more than `other` with `page`, the background behind the screen.
  /// Each is laid over the page first, so a faded grey counts as the colour it looks like there.
  private static func customerCenterStandsOutMore(
    _ color: PlatformColor,
    than other: PlatformColor,
    on page: PlatformColor
  ) -> Bool {
    var pageRed: CGFloat = 0, pageGreen: CGFloat = 0, pageBlue: CGFloat = 0, pageAlpha: CGFloat = 0
    page.getRed(&pageRed, green: &pageGreen, blue: &pageBlue, alpha: &pageAlpha)
    func linear(_ value: CGFloat) -> CGFloat {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    func luminance(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGFloat {
      0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
    let pageLuminance = luminance(pageRed, pageGreen, pageBlue)
    func contrast(_ color: PlatformColor) -> CGFloat {
      var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
      color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
      let colorLuminance = luminance(
        red * alpha + pageRed * (1 - alpha),
        green * alpha + pageGreen * (1 - alpha),
        blue * alpha + pageBlue * (1 - alpha)
      )
      return (max(colorLuminance, pageLuminance) + 0.05) / (min(colorLuminance, pageLuminance) + 0.05)
    }
    return contrast(color) > contrast(other)
  }
}

extension PlatformColor {
  /// The system's secondary label colour.
  static var customerCenterSecondaryLabel: PlatformColor {
    #if os(macOS)
    return .secondaryLabelColor
    #else
    return .secondaryLabel
    #endif
  }
}

/// The navigation the Customer Center supplies for itself: one column of
/// pushed screens.
///
/// On macOS 12, `NavigationView` splits into a sidebar and a detail column,
/// and the stack style that stops it is iOS-only, so `NavigationStack` is used
/// where there is one.
struct CustomerCenterNavigationContainer<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    #if os(macOS)
    if #available(macOS 13.0, *) {
      NavigationStack { content() }
    } else {
      NavigationView { content() }
    }
    #else
    NavigationView { content() }.navigationViewStyle(.stack)
    #endif
  }
}
#endif
