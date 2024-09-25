//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/09/2024.
//

import Foundation

final class AttributionPoster {
  private let attributionFetcher = AttributionFetcher()
  private let collectAdServicesAttribution: Bool
  private unowned let storage: Storage
  private unowned let network: Network

  private var adServicesTokenToPostIfNeeded: String? {
    get async throws {
      #if os(tvOS) || os(watchOS)
      return nil
      #else
      guard #available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *) else {
        return nil
      }

      guard storage.get(AdServicesAttributesStorage.self) == nil else {
        return nil
      }

      await Superwall.shared.track(InternalSuperwallEvent.AdServicesAttribution(state: .start))
      return try await attributionFetcher.adServicesToken
      #endif
    }
  }

  init(
    collectAdServicesAttribution: Bool,
    network: Network,
    storage: Storage
  ) {
    self.collectAdServicesAttribution = collectAdServicesAttribution
    self.network = network
    self.storage = storage
  }

  // Should match OS availability in https://developer.apple.com/documentation/ad_services
  @available(iOS 14.3, tvOS 14.3, watchOS 6.2, macOS 11.1, macCatalyst 14.3, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  func getAdServicesAttributesIfNeeded() async {
    do {
      guard collectAdServicesAttribution else {
        return
      }
      guard let attributionToken = try await adServicesTokenToPostIfNeeded else {
        return
      }

      let attributes = try await network.getAttributes(from: attributionToken)
      attributes.token = attributionToken

      storage.save(attributes, forType: AdServicesAttributesStorage.self)

      // Remove the token because it changes after 24hrs and will be stored
      // in complete event anyway.
      var attributesDict = attributes.dictionary(withSnakeCase: true) ?? [:]
      attributesDict["token"] = nil

      Superwall.shared.setUserAttributes(attributesDict)

      await Superwall.shared.track(
        InternalSuperwallEvent.AdServicesAttribution(state: .complete(attributes))
      )
    } catch {
      await Superwall.shared.track(
        InternalSuperwallEvent.AdServicesAttribution(state: .fail(error))
      )
    }
  }
}
