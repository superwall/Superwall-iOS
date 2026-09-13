import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct AttributionDeviceAttributesTests {
  @Test func unchangedProviderRefreshesDeviceIdentifiersAndConsent() {
    let container = DependencyContainer()
    var device = ["idfv": "vendor-1", "idfa": "advertiser-1", "attStatus": "3"]
    var syncedAttributes: [String: Any?] = [:]
    let fetcher = AttributionFetcher(
      storage: container.storage,
      deviceHelper: container.deviceHelper,
      webEntitlementRedeemer: container.webEntitlementRedeemer,
      deviceAttributesProvider: { device },
      syncDeviceAttributes: { syncedAttributes = $0 }
    )
    defer { fetcher.cancelPendingOperations() }
    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"], appTransactionId: "tx-1")
    #expect(fetcher.integrationAttributes["attStatus"] == "3")
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")

    device = ["idfv": "vendor-2", "attStatus": "2"]
    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"], appTransactionId: "tx-1")
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(fetcher.integrationAttributes["idfv"] == "vendor-2")
    #expect(fetcher.integrationAttributes["attStatus"] == "2")
    #expect(fetcher.integrationAttributes["idfa"] == nil)
    #expect(syncedAttributes["idfa"] as? NSNull != nil)
    #expect(syncedAttributes["idfv"] as? String == "vendor-2")
    #expect(syncedAttributes["attStatus"] as? String == "2")
  }

  @Test func activationRefreshesWithoutSettingProviderAgain() {
    let container = DependencyContainer()
    var device = ["idfv": "vendor-1", "attStatus": "0"]
    let fetcher = AttributionFetcher(
      storage: container.storage,
      deviceHelper: container.deviceHelper,
      webEntitlementRedeemer: container.webEntitlementRedeemer,
      deviceAttributesProvider: { device },
      syncDeviceAttributes: { _ in }
    )
    defer { fetcher.cancelPendingOperations() }
    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"], appTransactionId: "tx-1")
    #expect(fetcher.integrationAttributes["attStatus"] == "0")
    device = ["idfv": "vendor-1", "idfa": "advertiser-1", "attStatus": "3"]
    fetcher.refreshDeviceAttributes()
    #expect(fetcher.integrationAttributes["attStatus"] == "3")
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")
  }
}
