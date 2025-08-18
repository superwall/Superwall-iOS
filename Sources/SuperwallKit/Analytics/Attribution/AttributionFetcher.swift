//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/09/2024.
//

import Foundation
#if canImport(AdServices)
import AdServices
#endif

final class AttributionFetcher {
  var integrationAttributes: [String: Any] {
    queue.sync {
      _integrationAttributes
    }
  }
  private let queue = DispatchQueue(label: "com.superwall.attributionfetcher")
  private var _integrationAttributes: [String: Any] = [:]
  private unowned let storage: Storage
  private unowned let webEntitlementRedeemer: WebEntitlementRedeemer
  private unowned let deviceHelper: DeviceHelper

  var identifierForAdvertisers: String? {
    // should match available platforms here:
    // https://developer.apple.com/documentation/adsupport/asidentifiermanager/1614151-advertisingidentifier
    #if os(iOS) || os(tvOS) || os(macOS) || VISION_OS
    if #available(macOS 10.14, *) {
      let identifierManagerProxy = AttributionTypeFactory.asIdProxy()
      guard let identifierManagerProxy = identifierManagerProxy else {
        Logger.debug(
          logLevel: .warn,
          scope: .analytics,
          message: "AdSupport framework not imported. Attribution data incomplete."
        )
        return nil
      }

      guard let identifierValue = identifierManagerProxy.adsIdentifier else {
        return nil
      }

      return identifierValue.uuidString
    }
    #endif
    return nil
  }

  // should match OS availability in https://developer.apple.com/documentation/ad_services
  @available(iOS 14.3, tvOS 14.3, macOS 11.1, watchOS 6.2, macCatalyst 14.3, *)
  var adServicesToken: String? {
    get async throws {
      #if canImport(AdServices)
      return try await Task<String?, Error>.detached {
        #if targetEnvironment(simulator)
        return Self.simulatorAdServicesToken
        #else
        return try Self.realAdServicesToken
        #endif
      }.value
      #else
      Logger.debug(
        logLevel: .warn,
        scope: .analytics,
        message: "Tried to fetch AdServices attribution token on device without AdServices support."
      )
      return nil
      #endif
    }
  }

  #if canImport(AdServices)
  @available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *)
  private static var realAdServicesToken: String? {
    get throws {
      return try AAAttribution.attributionToken()
    }
  }

  #if targetEnvironment(simulator)
  private static var simulatorAdServicesToken: String? {
    #if DEBUG
    if let mockToken = ProcessInfo.processInfo.environment["SUPERWALL_MOCK_AD_SERVICES_TOKEN"] {
      Logger.debug(
        logLevel: .warn,
        scope: .analytics,
        message: "AdServices: mocking token: \(mockToken) for tests."
      )
      return mockToken
    }
    #endif

    Logger.debug(
      logLevel: .warn,
      scope: .analytics,
      message: "AdServices attribution token is not available in the simulator."
    )
    return nil
  }
  #endif
  #endif

  init(
    storage: Storage,
    deviceHelper: DeviceHelper,
    webEntitlementRedeemer: WebEntitlementRedeemer
  ) {
    self.storage = storage
    self.deviceHelper = deviceHelper
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self._integrationAttributes = storage.get(IntegrationAttributes.self) ?? [:]
  }

  func mergeIntegrationAttributes(
    attributes: [String: Any?],
    appTransactionId: String
  ) {
    queue.async { [weak self] in
      self?._mergeIntegrationAttributes(
        attributes: attributes,
        appTransactionId: appTransactionId
      )
    }
  }

  private func _mergeIntegrationAttributes(
    attributes: [String: Any?],
    appTransactionId: String
  ) {
    var mergedAttributes = _integrationAttributes

    mergedAttributes["idfa"] = identifierForAdvertisers

    let identifierForVendor = deviceHelper.vendorId
    mergedAttributes["idfv"] = identifierForVendor

    for key in attributes.keys {
      if let value = attributes[key] {
        mergedAttributes[key] = value
      } else {
        mergedAttributes[key] = nil
      }
    }

    Task {
      let attributes = InternalSuperwallEvent.IntegrationAttributes(
        audienceFilterParams: mergedAttributes
      )
      await Superwall.shared.track(attributes)
    }

    storage.save(mergedAttributes, forType: IntegrationAttributes.self)
    _integrationAttributes = mergedAttributes

    Task {
      await webEntitlementRedeemer.redeem(.integrationAttributes)
    }
  }
}
