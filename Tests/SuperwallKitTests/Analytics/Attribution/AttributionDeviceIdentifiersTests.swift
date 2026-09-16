import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct AttributionDeviceIdentifiersTests {
  private func makeFetcher(
    container: DependencyContainer,
    vendorId: @escaping () -> String = { "vendor-1" },
    attStatus: @escaping () -> Int? = { 3 },
    idfa: @escaping () -> String? = { "advertiser-1" },
    sync: @escaping ([String: Any?]) -> Void = { _ in }
  ) -> AttributionFetcher {
    // Storage is backed by the same files across containers, so a dictionary
    // left by an earlier test would be loaded here as a starting state.
    container.storage.delete(IntegrationAttributes.self)
    return AttributionFetcher(
      storage: container.storage,
      deviceHelper: container.deviceHelper,
      webEntitlementRedeemer: container.webEntitlementRedeemer,
      vendorIdProvider: vendorId,
      attStatusProvider: attStatus,
      idfaProvider: idfa,
      syncDeviceIdentifiers: sync
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
    fetcher.refreshDeviceIdentifiers()
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

    fetcher.refreshDeviceIdentifiers()
    fetcher.refreshDeviceIdentifiers()
    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")
    #expect(syncCount == 1)

    status = 2
    fetcher.refreshDeviceIdentifiers()
    #expect(fetcher.integrationAttributes["attStatus"] == "2")
    #expect(syncCount == 2)
  }

  @Test func resetKeepsTheInstallScopedAttributesForTheNewUser() {
    let container = DependencyContainer()
    var syncedAttributes: [String: Any?] = [:]
    var syncCount = 0
    let fetcher = makeFetcher(
      container: container,
      sync: {
        syncedAttributes = $0
        syncCount += 1
      }
    )
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(
      attributes: [
        "appsflyerId": "af-1",
        "amplitudeUserId": "person-1"
      ]
    )
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 1)
    #expect(syncedAttributes["appsflyerId"] == nil)

    // A reset deletes the user-specific copy and empties the user's attributes.
    container.storage.delete(IntegrationAttributes.self)
    fetcher.resetIntegrationAttributes()

    // The AppsFlyer id describes the device, so the new user keeps it. The
    // Amplitude user id describes the person who just signed out.
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(fetcher.integrationAttributes["amplitudeUserId"] == nil)
    #expect(fetcher.integrationAttributes["idfa"] == "advertiser-1")
    #expect(syncCount == 2)

    // The kept ids go back to the new user, alongside the device ones.
    #expect(syncedAttributes["appsflyerId"] as? String == "af-1")
    #expect(syncedAttributes["amplitudeUserId"] == nil)
    #expect(syncedAttributes["idfv"] as? String == "vendor-1")

    // And they're on disk again, so the next launch still refreshes and the
    // redeem that follows the reset doesn't ship empty metadata.
    let stored = container.storage.get(IntegrationAttributes.self)
    #expect(stored?["appsflyerId"] == "af-1")
    #expect(stored?["amplitudeUserId"] == nil)
  }

  @Test func resetKeepsTheDeviceKeysWhenNoProviderIdIsInstallScoped() {
    let container = DependencyContainer()
    let fetcher = makeFetcher(container: container)
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["amplitudeUserId": "person-1"])
    #expect(fetcher.integrationAttributes["amplitudeUserId"] == "person-1")

    container.storage.delete(IntegrationAttributes.self)
    fetcher.resetIntegrationAttributes()

    // Nothing of the old user's is left, but the device keys are the SDK's own,
    // so they stay and the activation refresh keeps working for the new user.
    #expect(fetcher.integrationAttributes["amplitudeUserId"] == nil)
    #expect(fetcher.integrationAttributes["idfv"] == "vendor-1")
    #expect(container.storage.get(IntegrationAttributes.self)?["amplitudeUserId"] == nil)
    #expect(container.storage.get(IntegrationAttributes.self)?["idfv"] == "vendor-1")
  }

  @Test func resetClearsEverythingWhenTheDeviceOffersNoIdentifiers() {
    let container = DependencyContainer()
    let fetcher = makeFetcher(
      container: container,
      vendorId: { "" },
      attStatus: { nil },
      idfa: { nil }
    )
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["amplitudeUserId": "person-1"])
    #expect(fetcher.integrationAttributes["amplitudeUserId"] == "person-1")

    container.storage.delete(IntegrationAttributes.self)
    fetcher.resetIntegrationAttributes()

    #expect(fetcher.integrationAttributes.isEmpty)
    #expect(container.storage.get(IntegrationAttributes.self) == nil)
  }

  @Test func resendsTheIdentifiersWhenSomethingElseDropsThem() {
    let container = DependencyContainer()
    var syncCount = 0
    let fetcher = makeFetcher(container: container, sync: { _ in syncCount += 1 })
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 1)

    // Nothing about the device changed, so there's nothing to say.
    fetcher.refreshDeviceIdentifiers()
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 1)

    // But an app that writes over one of the SDK's keys has to be answered,
    // otherwise the router loses the identifier until one of them changes.
    fetcher.forgetSyncedDeviceIdentifiers(ifTouching: ["email", "idfv"])
    fetcher.refreshDeviceIdentifiers()
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 2)
  }

  @Test func keepsQuietWhenTheAppWritesItsOwnAttributes() {
    let container = DependencyContainer()
    var syncCount = 0
    let fetcher = makeFetcher(container: container, sync: { _ in syncCount += 1 })
    defer { fetcher.cancelPendingOperations() }

    fetcher.mergeIntegrationAttributes(attributes: ["appsflyerId": "af-1"])
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 1)

    fetcher.forgetSyncedDeviceIdentifiers(ifTouching: ["email", "name"])
    fetcher.refreshDeviceIdentifiers()
    #expect(fetcher.integrationAttributes["appsflyerId"] == "af-1")
    #expect(syncCount == 1)
  }

  @Test func everyIntegrationAttributeIsScoped() {
    // Every case lands on one side of the split — the exhaustive switch in
    // `isInstallScoped` forces that. Bump both counts when adding a case, so
    // nobody adds an integration without picking a side.
    #expect(IntegrationAttribute.allCases.count == 23)
    #expect(IntegrationAttribute.installScopedKeys.count == 11)

    #expect(IntegrationAttribute.installScopedKeys.contains("appsflyerId"))
    #expect(IntegrationAttribute.installScopedKeys.contains("adjustId"))
    #expect(!IntegrationAttribute.installScopedKeys.contains("amplitudeUserId"))
    #expect(!IntegrationAttribute.installScopedKeys.contains("customerioId"))
  }

  @Test func resetDropsThePersonScopedAttributesWaitingOnTheTransactionId() {
    let container = DependencyContainer()
    let superwall = Superwall(dependencyContainer: container)
    superwall.enqueuedIntegrationAttributes = [
      .appsflyerId: "af-1",
      .amplitudeUserId: "person-1"
    ]

    // Called directly rather than through `reset()`, whose storage wipe and
    // config reset would reach well beyond this suite.
    superwall.resetEnqueuedIntegrationAttributes()

    let enqueued = superwall.enqueuedIntegrationAttributes
    #expect(enqueued?[.appsflyerId] == "af-1")
    #expect(enqueued?[.amplitudeUserId] == nil)
  }
}
