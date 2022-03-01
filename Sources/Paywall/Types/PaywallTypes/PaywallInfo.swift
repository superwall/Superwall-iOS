//
//  PaywallInfo.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

/// `PaywallInfo` is the primary class used to distinguish one paywall from another. Used primarily in `Paywall.present(onPresent:onDismiss)`'s completion handlers.
public final class PaywallInfo: NSObject {
  /// Superwall's internal identifier for this paywall.
  let id: String

  /// The identifier set for this paywall in Superwall's web dashboard.
  public let identifier: String

  /// What experiment this paywall presentation is a party of
  public let experimentId: String?

  /// What variant this user saw
  public let variantId: String?

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

  public let responseLoadStartTime: String?
  public let responseLoadCompleteTime: String?
  public let responseLoadDuration: Double?

  public let webViewLoadStartTime: String?
  public let webViewLoadCompleteTime: String?
  public let webViewLoadDuration: Double?

  public let productsLoadStartTime: String?
  public let productsLoadCompleteTime: String?
  public let productsLoadDuration: Double?

  init(
    id: String,
    identifier: String,
    name: String,
    slug: String,
    url: URL?,
    productIds: [String],
    fromEventData: EventData?,
    calledByIdentifier: Bool = false,
    responseLoadStartTime: Date?,
    responseLoadCompleteTime: Date?,
    webViewLoadStartTime: Date?,
    webViewLoadCompleteTime: Date?,
    productsLoadStartTime: Date?,
    productsLoadCompleteTime: Date?,
    variantId: String? = nil,
    experimentId: String? = nil
  ) {
    self.id = id
    self.identifier = identifier
    self.name = name
    self.slug = slug
    self.url = url
    self.productIds = productIds
    self.presentedByEventWithName = fromEventData?.name
    self.presentedByEventAt = fromEventData?.createdAt
    self.presentedByEventWithId = fromEventData?.id.lowercased()
    self.variantId = variantId
    self.experimentId = experimentId

    if fromEventData != nil {
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
    if let startTime = productsLoadStartTime,
      let endTime = productsLoadCompleteTime {
      self.productsLoadDuration = endTime.timeIntervalSince1970 - startTime.timeIntervalSince1970
    } else {
      self.productsLoadDuration = nil
    }
  }
}
