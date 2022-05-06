//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension TriggerSession {
  struct Paywall: Encodable {
    /// Database ID of the paywall.
    let databaseId: String

    /// Indicates whether there's a free trial or not.
    let substitutionPostfix: TemplateSubstitutionsPrefix

    struct Action: Encodable {
      /// When the paywall was opened.
      var openAt: Date?

      /// When the paywall was closed.
      var closeAt: Date?

      /// When a user purchased a product.
      var convertedAt: Date?
    }
    
    /// Timestamps to do with paywall actions
    var action = Action()

    /// Loading info of the paywall webview.
    var webViewLoading: LoadingInfo

    /// Loading info of the paywall response.
    var responseLoading: LoadingInfo

    enum CodingKeys: String, CodingKey {
      case databaseId = "paywall_id"

      case paywallOpened = "paywall_open_ts"
      case paywallClosed = "paywall_close_ts"
      case paywallConverted = "paywall_converted_ts"

      case substitutionPostfix = "paywall_substitution_postfix"

      case responseLoadStartAt = "paywall_response_load_start_ts"
      case responseLoadEndAt = "paywall_response_load_end_ts"
      case responseLoadFailAt = "paywall_response_load_fail_ts"

      case webViewLoadStartAt = "paywall_webview_load_start_ts"
      case webViewLoadEndAt = "paywall_webview_load_end_ts"
      case webViewLoadFailAt = "paywall_webview_load_fail_ts"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encode(databaseId, forKey: .databaseId)
      try container.encode(substitutionPostfix, forKey: .substitutionPostfix)

      try container.encodeIfPresent(action.openAt, forKey: .paywallOpened)
      try container.encodeIfPresent(action.closeAt, forKey: .paywallClosed)
      try container.encodeIfPresent(action.convertedAt, forKey: .paywallConverted)

      try container.encodeIfPresent(webViewLoading.startAt, forKey: .webViewLoadStartAt)
      try container.encodeIfPresent(webViewLoading.endAt, forKey: .webViewLoadEndAt)
      try container.encodeIfPresent(webViewLoading.failAt, forKey: .webViewLoadFailAt)

      try container.encodeIfPresent(responseLoading.startAt, forKey: .responseLoadStartAt)
      try container.encodeIfPresent(responseLoading.endAt, forKey: .responseLoadEndAt)
      try container.encodeIfPresent(responseLoading.failAt, forKey: .responseLoadFailAt)
    }
  }
}
