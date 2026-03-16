//
//  PaywallPageViewInfo.swift
//
//
//  Created by Yusuf Tör on 16/03/2026.
//

import Foundation

/// Contains page-specific details for a multi-page paywall page view.
public struct PaywallPageViewInfo {
  /// The unique identifier for the page node.
  public let pageNodeId: String

  /// The zero-based index of the page in the paywall flow.
  public let pageIndex: Int

  /// The display name of the page.
  public let pageName: String

  /// How the user navigated to the page (e.g. "entry", "swipe", "tap").
  public let navigationType: String
}
