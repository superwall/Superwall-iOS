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
    let nthView: Int
    /// The number of triggers.  Differs from `nthView`, because holdouts are counted per user.
    let nthTrigger: Int
    /// Nth impression for the specific paywall being shown per user.
    let nthViewForThisPaywall: Int
    /// The number of impressions for a viewed paywall in this app session per user.
    let nthViewForAppSession: Int
    /// Qhen the user last viewed a paywall per user.
    let lastViewAt: Date
    /// When the user last SHOULD HAVE viewed a paywall per user. They may not have actually viewed, due to being in a holdout  group.
    let lastTriggerAt: Date
    /// When the user last viewed THIS paywall per user.
    let lastViewForThisPaywallAt: Date
  }
}
