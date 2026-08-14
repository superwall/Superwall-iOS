//
//  PaywallPreviewList.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 30/07/2026.
//

import Foundation

/// The response from `GET /v2/paywalls/preview-list`.
struct PaywallPreviewList: Decodable {
  /// The paywalls available to preview, capped server-side.
  let data: [PaywallSummary]
}
