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
}
