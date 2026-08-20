//
//  DebugPaywallOverrides.swift
//  SuperwallKit
//
//  Created by Konrad Roj on 04/08/2026.
//

import Foundation

struct DebugPaywallOverrides: Equatable {
  enum Appearance: String {
    case light
    case dark
    case system

    var interfaceStyle: InterfaceStyle? {
      switch self {
      case .light:
        return .light
      case .dark:
        return .dark
      case .system:
        return nil
      }
    }
  }

  var freeTrialOverride: Bool?
  var appearance: Appearance?
  var localeIdentifier: String?
  var shouldPresent: Bool

  var isEmpty: Bool {
    freeTrialOverride == nil
      && appearance == nil
      && localeIdentifier == nil
      && !shouldPresent
  }

  init(
    freeTrialOverride: Bool? = nil,
    appearance: Appearance? = nil,
    localeIdentifier: String? = nil,
    shouldPresent: Bool = false
  ) {
    self.freeTrialOverride = freeTrialOverride
    self.appearance = appearance
    self.localeIdentifier = localeIdentifier
    self.shouldPresent = shouldPresent
  }

  init(url: URL) {
    switch SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .trialState)?.lowercased() {
    case "eligible":
      freeTrialOverride = true
    case "ineligible":
      freeTrialOverride = false
    default:
      freeTrialOverride = nil
    }

    if let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .appearance)?.lowercased() {
      appearance = Appearance(rawValue: value)
    } else {
      appearance = nil
    }

    if let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .locale),
      !value.isEmpty {
      localeIdentifier = value
    } else {
      localeIdentifier = nil
    }

    if let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .present)?.lowercased() {
      shouldPresent = ["true", "1", "yes"].contains(value)
    } else {
      shouldPresent = false
    }
  }
}
