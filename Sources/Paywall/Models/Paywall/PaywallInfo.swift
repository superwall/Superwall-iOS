//
//  PaywallInfo.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//
// swiftlint:disable cyclomatic_complexity

import Foundation
import StoreKit

/// Contains information about a given paywall.
///
/// This is returned in the `paywallState` after presenting a paywall with ``Paywall/Paywall/track(event:params:paywallOverrides:paywallState:)``.
public final class PaywallInfo: NSObject {
  /// Superwall's internal ID for this paywall.
  let id: String

  /// The identifier set for this paywall in the Superwall dashboard.
  public let identifier: String

  /// The trigger experiment that caused the paywall to present.
  ///
  /// An experiment is a set of paywall variants determined by probabilities. An experiment will result in a user seeing a paywall unless they are in a holdout group.
  public let experiment: Experiment?

  /// The name set for this paywall in Superwall's web dashboard.
  public let name: String
  public let slug: String

  /// The URL where this paywall is hosted.
  public let url: URL?

  /// The name of the event that triggered this Paywall. Defaults to `nil` if `triggeredByEvent` is false.
  public let presentedByEventWithName: String?

  /// The Superwall internal id (for debugging) of the event that triggered this Paywall. Defaults to `nil` if `triggeredByEvent` is false.
  public let presentedByEventWithId: String?

  /// The ISO date string (sorry) describing when the event triggered this paywall. Defaults to `nil` if `triggeredByEvent` is false.
  public let presentedByEventAt: String?

  /// How the paywall was presented, either 'programmatically', 'identifier', or 'event'
  public let presentedBy: String

  /// An array of product IDs that this paywall is displaying in `[Primary, Secondary, Tertiary]` order.
  public let productIds: [String]

  /// An iso date string indicating when the paywall response began loading.
  public let responseLoadStartTime: String?

  /// An iso date string indicating when the paywall response finished loading.
  public let responseLoadCompleteTime: String?

  /// The time it took to load the paywall response.
  public let responseLoadDuration: TimeInterval?

  /// An iso date string indicating when the paywall webview began loading.
  public let webViewLoadStartTime: String?

  /// An iso date string indicating when the paywall webview finished loading.
  public let webViewLoadCompleteTime: String?

  /// The time it took to load the paywall website.
  public let webViewLoadDuration: TimeInterval?

  /// An iso date string indicating when the paywall products began loading.
  public let productsLoadStartTime: String?

  /// An iso date string indicating when the paywall products finished loading.
  public let productsLoadCompleteTime: String?

  /// An iso date string indicating when the paywall products failed to load.
  public let productsLoadFailTime: String?

  /// The time it took to load the paywall products.
  public let productsLoadDuration: TimeInterval?

  /// The paywall.js version installed on the paywall website.
  public let paywalljsVersion: String?

  init(
    id: String,
    identifier: String,
    name: String,
    slug: String,
    url: URL?,
    productIds: [String],
    fromEventData eventData: EventData?,
    calledByIdentifier: Bool = false,
    responseLoadStartTime: Date?,
    responseLoadCompleteTime: Date?,
    webViewLoadStartTime: Date?,
    webViewLoadCompleteTime: Date?,
    productsLoadStartTime: Date?,
    productsLoadFailTime: Date?,
    productsLoadCompleteTime: Date?,
    experiment: Experiment? = nil,
    paywalljsVersion: String? = nil
  ) {
    self.id = id
    self.identifier = identifier
    self.name = name
    self.slug = slug
    self.url = url
    self.productIds = productIds
    self.presentedByEventWithName = eventData?.name
    self.presentedByEventAt = eventData?.createdAt.isoString
    self.presentedByEventWithId = eventData?.id.lowercased()
    self.experiment = experiment
    self.paywalljsVersion = paywalljsVersion

    if eventData != nil {
      self.presentedBy = "event"
    } else if calledByIdentifier {
      self.presentedBy = "identifier"
    } else {
      self.presentedBy = "programmatically"
    }

    self.responseLoadStartTime = responseLoadStartTime?.isoString ?? ""
    self.responseLoadCompleteTime = responseLoadStartTime?.isoString ?? ""

    if let startTime = responseLoadStartTime,
      let endTime = responseLoadCompleteTime {
      self.responseLoadDuration = endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970
    } else {
      self.responseLoadDuration = nil
    }

    self.webViewLoadStartTime = webViewLoadStartTime?.isoString ?? ""
    self.webViewLoadCompleteTime = webViewLoadCompleteTime?.isoString ?? ""
    if let startTime = webViewLoadStartTime,
      let endTime = webViewLoadCompleteTime {
      self.webViewLoadDuration = endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970
    } else {
      self.webViewLoadDuration = nil
    }

    self.productsLoadStartTime = productsLoadStartTime?.isoString ?? ""
    self.productsLoadCompleteTime = productsLoadCompleteTime?.isoString ?? ""
    self.productsLoadFailTime = productsLoadFailTime?.isoString ?? ""
    if let startTime = productsLoadStartTime,
      let endTime = productsLoadCompleteTime {
      self.productsLoadDuration = endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970
    } else {
      self.productsLoadDuration = nil
    }
  }

  func eventParams(
    forProduct product: SKProduct? = nil,
    otherParams: [String: Any]? = nil
  ) -> [String: Any] {
    var output: [String: Any] = [
      "paywall_id": id,
      "paywalljs_version": paywalljsVersion as Any,
      "paywall_identifier": identifier,
      "paywall_slug": slug,
      "paywall_name": name,
      "paywall_url": url?.absoluteString ?? "unknown",
      "presented_by_event_name": presentedByEventWithName as Any,
      "presented_by_event_id": presentedByEventWithId as Any,
      "presented_by_event_timestamp": presentedByEventAt as Any,
      "presented_by": presentedBy as Any,
      "paywall_product_ids": productIds.joined(separator: ","),
      "paywall_response_load_start_time": responseLoadStartTime as Any,
      "paywall_response_load_complete_time": responseLoadCompleteTime as Any,
      "paywall_response_load_duration": responseLoadDuration as Any,
      "paywall_webview_load_start_time": webViewLoadStartTime as Any,
      "paywall_webview_load_complete_time": webViewLoadCompleteTime as Any,
      "paywall_webview_load_duration": webViewLoadDuration as Any,
      "paywall_products_load_start_time": productsLoadStartTime as Any,
      "paywall_products_load_complete_time": productsLoadCompleteTime as Any,
      "paywall_products_load_fail_time": productsLoadCompleteTime as Any,
      "paywall_products_load_duration": productsLoadDuration as Any
    ]

    if let triggerSession = SessionEventsManager.shared.triggerSession.activeTriggerSession,
      let databaseId = triggerSession.paywall?.databaseId,
      databaseId == id {
      output["trigger_session_id"] = triggerSession.id
      output["experiment_id"] = triggerSession.trigger.experiment?.id
      output["variant_id"] = triggerSession.trigger.experiment?.variant.id
    }

    var loadingVars: [String: Any] = [:]
    for key in output.keys {
      if key.contains("_load_"),
        let output = output[key] {
        loadingVars[key] = output
      }
    }

    Logger.debug(
      logLevel: .debug,
      scope: .paywallEvents,
      message: "Paywall loading timestamps",
      info: loadingVars
    )

    let levels = ["primary", "secondary", "tertiary"]

    for (id, level) in levels.enumerated() {
      let key = "\(level)_product_id"
      output[key] = ""
      if id < productIds.count {
        output[key] = productIds[id]
      }
    }

    if let product = product {
      output["product_id"] = product.productIdentifier
      for key in product.legacyEventData.keys {
        if let value = product.legacyEventData[key] {
          output["product_\(key.camelCaseToSnakeCase())"] = value
        }
      }
    }

    if let otherParams = otherParams {
      for key in otherParams.keys {
        if let value = otherParams[key] {
          output[key] = value
        }
      }
    }

    return output
  }
}
