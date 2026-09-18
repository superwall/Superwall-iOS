//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/06/2024.
//

import Foundation

enum PaywallManagerLogic {
  enum Outcome {
    case loadWebView
    case replacePaywall
  }
  static func handleCachedPaywall(
    newPaywall: Paywall,
    oldPaywall: Paywall,
    isForPresentation: Bool
  ) -> [Outcome] {
    guard isForPresentation else {
      return []
    }

    if newPaywall.cacheKey != oldPaywall.cacheKey {
      return [.replacePaywall, .loadWebView]
    }
    return []
  }
}
