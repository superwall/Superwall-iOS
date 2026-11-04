//
//  CustomerCenterPlatform.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// The SwiftUI the Customer Center uses that only iOS has, with the macOS
// equivalent beside it, so the screens themselves read the same on both.

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
