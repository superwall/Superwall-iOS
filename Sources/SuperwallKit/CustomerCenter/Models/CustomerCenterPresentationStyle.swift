//
//  CustomerCenterPresentationStyle.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/11/2026.
//

import Foundation

/// How the Customer Center is put on screen, for ``CustomerCenterViewController`` and
/// ``CustomerCenterView`` alike. Also reported on ``SuperwallEvent/customerCenterOpen(screen:presentation:)``.
@objc(SWKCustomerCenterPresentationStyle)
public enum CustomerCenterPresentationStyle: Int, Sendable {
  /// Presented as a sheet. The Customer Center brings its own navigation and a close button.
  case sheet

  /// Inside navigation you own: a ``CustomerCenterViewController`` pushed onto your
  /// `UINavigationController`, or a ``CustomerCenterView`` placed in your SwiftUI navigation.
  /// Renders into your navigation bar and leaves it entirely alone — your title, your back button,
  /// your appearance — and pushes its own screens onto your stack.
  case embedded

  var analyticsName: String {
    switch self {
    case .sheet: return "sheet"
    case .embedded: return "embedded"
    }
  }
}
