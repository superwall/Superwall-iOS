import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct AttributionDeviceAttributesTests {
  private func makeFetcher(
    container: DependencyContainer,
    vendorId: @escaping () -> String = { "vendor-1" },
    attStatus: @escaping () -> Int? = { 3 },
    idfa: @escaping () -> String? = { "advertiser-1" },
    sync: @escaping ([String: Any?]) -> Void = { _ in }
  ) -> AttributionFetcher {
    return AttributionFetcher(
      storage: container.storage,
      deviceHelper: container.deviceHelper,
      webEntitlementRedeemer: container.webEntitlementRedeemer,
      vendorIdProvider: vendorId,
      attStatusProvider: attStatus,
      idfaProvider: idfa,
      syncDeviceAttributes: sync
    )
  }

  @Test func unchangedProviderRefreshesDeviceIdentifiersAndConsent() {
    let container = DependencyContainer()
    var status: Int? = 3
    var idfa: String? = "advertiser-1"
    var vendorId = "vendor-1"
    var syncedAttributes: [String: Any?] = [:]
    let fetcher = makeFetcher(
      container: container,
      vendorId: { vendorId },
      attStatus: { status },
      idfa: { idfa },
      sync: { syncedAttributes = $0 }
    )
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["attStatus"] == "3")
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")

    vendorId = "vendor-2"
    status = 2
    idfa = nil
    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
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
    var status: Int? = 0
    var idfa: String?
    let fetcher = makeFetcher(
      container: container,
      attStatus: { status },
      idfa: { idfa }
    )
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["attStatus"] == "0")

    status = 3
    idfa = "advertiser-1"
    fetcher.refreshDeviceAttributes()
    #expect(fetcher.integrationAttributes["attStatus"] == "3")
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")
  }

  @Test func omitsVendorIdWhenItIsUnavailable() {
    let container = DependencyContainer()
    var syncedAttributes: [String: Any?] = [:]
    let fetcher = makeFetcher(
      container: container,
      vendorId: { "" },
      sync: { syncedAttributes = $0 }
    )
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["idfv"] == nil)
    #expect(syncedAttributes["idfv"] as? NSNull != nil)
  }

  @Test func keepsIdfaWhileConsentIsUndecided() {
    let container = DependencyContainer()
    let fetcher = makeFetcher(
      container: container,
      attStatus: { 0 },
      idfa: { "advertiser-1" }
    )
    defer { fetcher.cancelPendingOperations() }

    // Before iOS 14.5 the IDFA is readable while ATT still reads
    // `notDetermined`, and a build that can't resolve `ATTrackingManager`
    // reports the same status, so the status mustn't gate the IDFA.
    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["attStatus"] == "0")
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")
  }

  @Test func omitsAttStatusWhereTheOsHasNoConsentPrompt() {
    let container = DependencyContainer()
    var syncedAttributes: [String: Any?] = [:]
    let fetcher = makeFetcher(
      container: container,
      attStatus: { nil },
      sync: { syncedAttributes = $0 }
    )
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["attStatus"] == nil)
    #expect(syncedAttributes["attStatus"] as? NSNull != nil)
  }

  @Test func onlySyncsUserAttributesWhenTheDeviceSnapshotChanges() {
    let container = DependencyContainer()
    var status: Int? = 3
    var syncCount = 0
    let fetcher = makeFetcher(
      container: container,
      attStatus: { status },
      sync: { _ in syncCount += 1 }
    )
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 1)

    fetcher.refreshDeviceAttributes()
    fetcher.refreshDeviceAttributes()
    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")
    #expect(syncCount == 1)

    status = 2
    fetcher.refreshDeviceAttributes()
    #expect(fetcher.integrationAttributes["attStatus"] == "2")
    #expect(syncCount == 2)

  }

  @Test func resyncSendsTheIdentifiersAgainAfterAReset() {
    let container = DependencyContainer()
    var syncCount = 0
    let fetcher = makeFetcher(container: container, sync: { _ in syncCount += 1 })
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 1)

    fetcher.resyncDeviceAttributes()
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")
    #expect(syncCount == 2)
  }
}
