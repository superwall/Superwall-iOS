//
//  PaywallInfo.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//
// swiftlint:disable cyclomatic_complexity

import Foundation
import StoreKit

/// Contains information about a given paywall.
///
/// This is returned in the `paywallState` after presenting a paywall with ``Superwall/track(event:params:paywallOverrides:paywallHandler:)``.
@objc(SWKPaywallInfo)
@objcMembers
public final class PaywallInfo: NSObject {
  /// Superwall's internal ID for this paywall.
  let databaseId: String

  @available(*, unavailable, renamed: "databaseId")
  let id: String = ""

  /// The identifier set for this paywall in the Superwall dashboard.
  public let identifier: String

  /// The trigger experiment that caused the paywall to present.
  ///
  /// An experiment is a set of paywall variants determined by probabilities. An experiment will result in a user seeing a paywall unless they are in a holdout group.
  public let experiment: Experiment?

  /// The products associated with the paywall.
  public let products: [Product]

  /// The name set for this paywall in Superwall's web dashboard.
  public let name: String

  /// The URL where this paywall is hosted.
  public let url: URL

  /// The name of the event that triggered this Paywall. Defaults to `nil` if `triggeredByEvent` is false.
  public let presentedByEventWithName: String?

  /// The Superwall internal id (for debugging) of the event that triggered this Paywall. Defaults to `nil` if `triggeredByEvent` is false.
  public let presentedByEventWithId: String?

  /// The ISO date string describing when the event triggered this paywall. Defaults to `nil` if `triggeredByEvent` is false.
  public let presentedByEventAt: String?

  /// How the paywall was presented, either 'programmatically', 'identifier', or 'event'
  public let presentedBy: String

  /// An iso date string indicating when the paywall response began loading.
  public let responseLoadStartTime: String?

  /// An iso date string indicating when the paywall response finished loading.
  public let responseLoadCompleteTime: String?

  /// An iso date string indicating when the paywall response failed to load.
  public let responseLoadFailTime: String?

  /// The time it took to load the paywall response.
  public let responseLoadDuration: TimeInterval?

  /// An iso date string indicating when the paywall webview began loading.
  public let webViewLoadStartTime: String?

  /// An iso date string indicating when the paywall webview finished loading.
  public let webViewLoadCompleteTime: String?

  /// An iso date string indicating when the paywall webview failed to load.
  public let webViewLoadFailTime: String?

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

  public let isFreeTrialAvailable: Bool

  private unowned let sessionEventsManager: SessionEventsManager

  init(
    databaseId: String,
    identifier: String,
    name: String,
    url: URL,
    products: [Product],
    fromEventData eventData: EventData?,
    responseLoadStartTime: Date?,
    responseLoadCompleteTime: Date?,
    responseLoadFailTime: Date?,
    webViewLoadStartTime: Date?,
    webViewLoadCompleteTime: Date?,
    webViewLoadFailTime: Date?,
    productsLoadStartTime: Date?,
    productsLoadFailTime: Date?,
    productsLoadCompleteTime: Date?,
    experiment: Experiment? = nil,
    paywalljsVersion: String? = nil,
    isFreeTrialAvailable: Bool,
    sessionEventsManager: SessionEventsManager
  ) {
    self.databaseId = databaseId
    self.identifier = identifier
    self.name = name
    self.url = url
    self.presentedByEventWithName = eventData?.name
    self.presentedByEventAt = eventData?.createdAt.isoString
    self.presentedByEventWithId = eventData?.id.lowercased()
    self.experiment = experiment
    self.paywalljsVersion = paywalljsVersion
    self.products = products
    self.isFreeTrialAvailable = isFreeTrialAvailable

    if eventData != nil {
      self.presentedBy = "event"
    } else {
      self.presentedBy = "programmatically"
    }

    self.responseLoadStartTime = responseLoadStartTime?.isoString ?? ""
    self.responseLoadCompleteTime = responseLoadStartTime?.isoString ?? ""
    self.responseLoadFailTime = responseLoadFailTime?.isoString ?? ""

    if let startTime = responseLoadStartTime,
      let endTime = responseLoadCompleteTime {
      self.responseLoadDuration = endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970
    } else {
      self.responseLoadDuration = nil
    }

    self.webViewLoadStartTime = webViewLoadStartTime?.isoString ?? ""
    self.webViewLoadCompleteTime = webViewLoadCompleteTime?.isoString ?? ""
    self.webViewLoadFailTime = webViewLoadFailTime?.isoString ?? ""

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
    self.sessionEventsManager = sessionEventsManager
  }

  func eventParams(
    forProduct product: StoreProduct? = nil,
    otherParams: [String: Any]? = nil
  ) async -> [String: Any] {
    let productIds = products.map { $0.id }

    var output: [String: Any] = [
      "paywall_database_id": databaseId,
      "paywalljs_version": paywalljsVersion as Any,
      "paywall_identifier": identifier,
      "paywall_name": name,
      "paywall_url": url.absoluteString,
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
      "paywall_products_load_fail_time": productsLoadFailTime as Any,
      "paywall_products_load_duration": productsLoadDuration as Any,
      "is_free_trial_available": isFreeTrialAvailable as Any
    ]

    if let triggerSession = await sessionEventsManager.triggerSession.activeTriggerSession,
      let databaseId = triggerSession.paywall?.databaseId,
      databaseId == self.databaseId {
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
      if id < products.count {
        output[key] = productIds[id]
      }
    }

    if let product = product {
      output["product_id"] = product.productIdentifier
      for key in product.attributes.keys {
        if let value = product.attributes[key] {
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

// swiftlint:disable force_unwrapping
// MARK: - Stubbable
extension PaywallInfo: Stubbable {
  static func stub() -> PaywallInfo {
    let dependencyContainer = DependencyContainer()
    return PaywallInfo(
      databaseId: "abc",
      identifier: "1",
      name: "Test",
      url: URL(string: "https://www.google.com")!,
      products: [],
      fromEventData: nil,
      responseLoadStartTime: nil,
      responseLoadCompleteTime: nil,
      responseLoadFailTime: nil,
      webViewLoadStartTime: nil,
      webViewLoadCompleteTime: nil,
      webViewLoadFailTime: nil,
      productsLoadStartTime: nil,
      productsLoadFailTime: nil,
      productsLoadCompleteTime: nil,
      isFreeTrialAvailable: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager
    )
  }
}
