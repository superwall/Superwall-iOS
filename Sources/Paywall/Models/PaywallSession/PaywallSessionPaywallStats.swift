//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct PaywallStats: Encodable {
    /// The number of impressions for a viewed paywall per user (holdouts excluded).
    var nthView: Int

    /// The number of triggers.  Differs from `nthView`, because holdouts are counted per user.
    var nthTrigger: Int

    /// Nth impression for the specific paywall being shown per user.
    var nthViewForThisPaywall: Int

    /// The number of impressions for a viewed paywall in this app session per user.
    var nthViewForAppSession: Int

    /// Qhen the user last viewed a paywall per user.
    var lastViewedAt: Date

    /// When the user last SHOULD HAVE viewed a paywall per user. They may not have actually viewed, due to being in a holdout  group.
    var lastTriggeredAt: Date
    
    /// When the user last viewed THIS paywall per user.
    var lastViewedThisPaywallAt: Date

    enum CodingKeys: String, CodingKey {
      case nthView = "paywall_nth_view"
      case nthTrigger = "paywall_nth_trigger"
      case nthViewForThisPaywall = "paywall_nth_view_for_this_paywall"
      case nthViewForAppSession = "paywall_nth_view_for_app_session"
      case lastViewedAt = "paywall_last_view_ts"
      case lastTriggeredAt = "paywall_last_trigger_ts"
      case lastViewedThisPaywallAt = "paywall_last_view_for_this_paywall_ts"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(nthView, forKey: .nthView)
      try container.encode(nthTrigger, forKey: .nthTrigger)
      try container.encode(nthViewForThisPaywall, forKey: .nthViewForThisPaywall)
      try container.encode(nthViewForAppSession, forKey: .nthViewForAppSession)
      try container.encode(lastViewedAt, forKey: .lastViewedAt)
      try container.encode(lastTriggeredAt, forKey: .lastTriggeredAt)
      try container.encode(lastViewedThisPaywallAt, forKey: .lastViewedThisPaywallAt)
    }
  }
}
