//
//  SuperwallAPI.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

enum BaseApi {
  static let scheme = "https"
  static var host: String {
    switch Paywall.networkEnvironment {
    case .release:
      return "api.superwall.me"
    case .releaseCandidate:
      return "api.superwallcanary.com"
    case .developer:
      return "api.superwall.dev"
    }
  }
  static let version1 = "/api/v1/"
}

enum AnalyticsApi {
  static let scheme = "https"
  static var host: String {
    switch Paywall.networkEnvironment {
    case .release:
      return "collector.superwall.me"
    case .releaseCandidate:
      return "collector.superwallcanary.com"
    case .developer:
      return "collector.superwall.dev"
    }
  }
  static let version1 = "/api/v1/"
}
