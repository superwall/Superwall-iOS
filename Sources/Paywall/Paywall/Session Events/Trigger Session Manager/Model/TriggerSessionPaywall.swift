//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//
// swiftlint:disable nesting

import Foundation

extension TriggerSession {
  struct Paywall: Codable {
    /// Database ID of the paywall.
    let databaseId: String

    /// Indicates whether there's a free trial or not.
    let substitutionPrefix: String?

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
    var webviewLoading: LoadingInfo

    /// Loading info of the paywall response.
    var responseLoading: LoadingInfo

    init(
      databaseId: String,
      substitutionPrefix: String?,
      webviewLoading: LoadingInfo,
      responseLoading: LoadingInfo
    ) {
      self.databaseId = databaseId
      self.substitutionPrefix = substitutionPrefix
      self.webviewLoading = webviewLoading
      self.responseLoading = responseLoading
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      databaseId = try values.decode(String.self, forKey: .databaseId)
      substitutionPrefix = try values.decodeIfPresent(String.self, forKey: .substitutionPrefix)

      let openAt = try values.decodeIfPresent(Date.self, forKey: .paywallOpened)
      let closeAt = try values.decodeIfPresent(Date.self, forKey: .paywallClosed)
      let convertedAt = try values.decodeIfPresent(Date.self, forKey: .paywallConverted)
      action = Action(
        openAt: openAt,
        closeAt: closeAt,
        convertedAt: convertedAt
      )

      let webStartAt = try values.decodeIfPresent(Date.self, forKey: .webviewLoadStartAt)
      let webEndAt = try values.decodeIfPresent(Date.self, forKey: .webviewLoadEndAt)
      let webFailAt = try values.decodeIfPresent(Date.self, forKey: .webviewLoadFailAt)
      webviewLoading = LoadingInfo(
        startAt: webStartAt,
        endAt: webEndAt,
        failAt: webFailAt
      )

      let responseStartAt = try values.decodeIfPresent(Date.self, forKey: .responseLoadStartAt)
      let responseEndAt = try values.decodeIfPresent(Date.self, forKey: .responseLoadEndAt)
      let responseFailAt = try values.decodeIfPresent(Date.self, forKey: .responseLoadFailAt)
      responseLoading = LoadingInfo(
        startAt: responseStartAt,
        endAt: responseEndAt,
        failAt: responseFailAt
      )
    }

    enum CodingKeys: String, CodingKey {
      case databaseId = "paywall_id"

      case paywallOpened = "paywall_open_ts"
      case paywallClosed = "paywall_close_ts"
      case paywallConverted = "paywall_converted_ts"

      case substitutionPrefix = "paywall_substitution_prefix"

      case responseLoadStartAt = "paywall_response_load_start_ts"
      case responseLoadEndAt = "paywall_response_load_end_ts"
      case responseLoadFailAt = "paywall_response_load_fail_ts"

      case webviewLoadStartAt = "paywall_webview_load_start_ts"
      case webviewLoadEndAt = "paywall_webview_load_end_ts"
      case webviewLoadFailAt = "paywall_webview_load_fail_ts"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encode(databaseId, forKey: .databaseId)
      try container.encode(substitutionPrefix, forKey: .substitutionPrefix)

      try container.encodeIfPresent(action.openAt, forKey: .paywallOpened)
      try container.encodeIfPresent(action.closeAt, forKey: .paywallClosed)
      try container.encodeIfPresent(action.convertedAt, forKey: .paywallConverted)

      try container.encodeIfPresent(webviewLoading.startAt, forKey: .webviewLoadStartAt)
      try container.encodeIfPresent(webviewLoading.endAt, forKey: .webviewLoadEndAt)
      try container.encodeIfPresent(webviewLoading.failAt, forKey: .webviewLoadFailAt)

      try container.encodeIfPresent(responseLoading.startAt, forKey: .responseLoadStartAt)
      try container.encodeIfPresent(responseLoading.endAt, forKey: .responseLoadEndAt)
      try container.encodeIfPresent(responseLoading.failAt, forKey: .responseLoadFailAt)
    }
  }
}
