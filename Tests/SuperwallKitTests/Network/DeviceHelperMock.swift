//
//  File.swift
//
//
//  Created by Yusuf Tör on 18/08/2022.
//

import Foundation
@testable import SuperwallKit

final class DeviceHelperMock: DeviceHelper {
  var internalLocale: String?
  var getEnrichmentCalled = false

  override var localeIdentifier: String {
    return internalLocale ?? super.localeIdentifier
  }

  override func getEnrichment(
    maxRetry: Int? = nil,
    timeout: Seconds? = nil
  ) async throws {
    getEnrichmentCalled = true
    // Don't actually fetch enrichment in tests - just return immediately
  }

  override func getTemplateDevice() async -> [String: Any] {
    // Return mock device attributes without async calls
    return [
      "publicApiKey": "test_key",
      "platform": "iOS",
      "appUserId": "",
      "aliases": ["test_alias"],
      "vendorId": "test_vendor_id",
      "appVersion": "1.0.0"
    ]
  }
}
