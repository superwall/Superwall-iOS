//
//  ReviewType.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/11/2026.
//

/// Which store review a paywall asked for.
enum ReviewType: String, Decodable {
  case inApp = "in-app"
  case external
}
