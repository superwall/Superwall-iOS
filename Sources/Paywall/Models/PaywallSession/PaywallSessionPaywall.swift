//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Paywall: Encodable {
    /// Database ID of the paywall.
    let id: Int
    
    /// Loading info of the paywall webview.
    var webViewLoading: LoadingInfo

    enum CodingKeys: String, CodingKey {
      case id = "paywall_id"
      case webViewLoadDuration = "paywall_webview_load_duration"
      case webViewLoadStartAt = "paywall_webview_load_start_ts"
      case webViewLoadEndAt = "paywall_webview_load_end_ts"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encode(id, forKey: .id)
      try container.encode(webViewLoading.startAt, forKey: .webViewLoadStartAt)
      try container.encodeIfPresent(webViewLoading.endAt, forKey: .webViewLoadEndAt)
      try container.encodeIfPresent(webViewLoading.duration, forKey: .webViewLoadDuration)
    }
  }
}
