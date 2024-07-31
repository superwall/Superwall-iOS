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
    case setDelegate
    case replacePaywall
    case updatePaywall
  }
  static func handleCachedPaywall(
    newPaywall: Paywall,
    oldPaywall: Paywall,
    isPreloading: Bool,
    isForPresentation: Bool
  ) -> [Outcome] {
    var outcome: [Outcome] = []

    guard isForPresentation else {
      return outcome
    }

    if newPaywall.cacheKey != oldPaywall.cacheKey {
      outcome.append(.replacePaywall)
      outcome.append(.loadWebView)
      if !isPreloading {
        outcome.append(.setDelegate)
      }
    } else if !isPreloading {
      outcome.append(.setDelegate)
      outcome.append(.updatePaywall)
    }
    return outcome
  }
}
