//
//  BundledPaywallsTests.swift
//
//
//  Created by Christo Todorov on 12/10/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Foundation
import Testing

@Suite(.serialized)
struct BundledPaywallsTests {
  static let documentURL = URL(string: "https://cdn.example.com/onboarding.html?sw_cache_key=1")!
  static let mirrorURL = URL(string: "https://mirror.example.com/onboarding.html")!
  static let imageURL = URL(string: "https://cdn.example.com/hero.png")!

  private func makeBundle(
    version: Int = 1,
    config: Config? = Config.stub().setting(\.buildId, to: "bundled_1"),
    documentHash: String = UUID().uuidString
  ) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("Superwall.bundle")
    let files = directory.appendingPathComponent("files")
    try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
    try Data("<img src=\"\(Self.imageURL)\">".utf8)
      .write(to: files.appendingPathComponent("\(documentHash).html"))
    try Data("png".utf8).write(to: files.appendingPathComponent("image.png"))
    if let config = config {
      try JSONEncoder.toSnakeCase.encode(config)
        .write(to: directory.appendingPathComponent("static_config.json"))
    }
    let manifest = """
    {
      "version": \(version),
      "createdAt": "2026-10-12T00:00:00.000Z",
      "paywalls": [{
        "identifier": "onboarding",
        "urls": ["\(Self.documentURL)", "\(Self.mirrorURL)"],
        "document": { "url": "\(Self.documentURL)", "file": "files/\(documentHash).html", "mimeType": "text/html" },
        "resources": [{ "url": "\(Self.imageURL)", "file": "files/image.png", "mimeType": "image/png" }]
      }]
    }
    """
    try Data(manifest.utf8).write(to: directory.appendingPathComponent("bundle.json"))
    return directory
  }

  @Test
  func appWithoutBundleHasNothingBundled() {
    let bundled = BundledPaywalls(directory: nil)
    #expect(bundled.config == nil)
    #expect(bundled.paywall(matching: [Self.documentURL]) == nil)
  }

  @Test
  func readsConfigAndMatchesAnyEndpointOfThePaywall() throws {
    let bundled = BundledPaywalls(directory: try makeBundle())
    #expect(bundled.config?.buildId == "bundled_1")
    #expect(bundled.paywall(matching: [Self.mirrorURL])?.identifier == "onboarding")
    #expect(bundled.paywall(matching: [URL(string: "https://cdn.example.com/onboarding.html?sw_cache_key=2")!]) == nil)
  }

  @Test
  func buildsAWebArchiveFromTheBundledFiles() throws {
    let bundled = BundledPaywalls(directory: try makeBundle())
    let paywall = try #require(bundled.paywall(matching: [Self.documentURL]))
    let archive = try bundled.webArchive(for: paywall)
    #expect(archive.mainResource.baseResource.url == Self.documentURL)
    #expect(archive.mainResource.baseResource.mimeType == "text/html")
    #expect(archive.webSubresources.map(\.url) == [Self.imageURL])
    #expect(archive.webSubresources.first?.data == Data("png".utf8))
  }

  @Test
  func ignoresABundleFromANewerFormat() throws {
    let bundled = BundledPaywalls(directory: try makeBundle(version: 2))
    #expect(bundled.config == nil)
    #expect(bundled.paywall(matching: [Self.documentURL]) == nil)
  }

  @Test
  func archiveManagerServesTheBundledPaywallOnlyForTheBundledVersion() async throws {
    let manager = PaywallArchiveManager(
      bundledPaywalls: BundledPaywalls(directory: try makeBundle())
    )
    let bundledPaywall = Paywall.stub().setting(\.url, to: Self.documentURL)
    let archiveURL = try #require(await manager.getBundledArchiveURL(for: bundledPaywall))
    #expect(archiveURL.pathExtension == "webarchive")
    #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    #expect(await manager.getBundledArchiveURL(for: bundledPaywall) == archiveURL)

    let republished = Paywall.stub()
      .setting(\.url, to: URL(string: "https://cdn.example.com/onboarding.html?sw_cache_key=2")!)
    #expect(await manager.getBundledArchiveURL(for: republished) == nil)
  }

  @Test
  func preloadingBuildsTheBundledArchiveWithoutAManifest() async throws {
    let directory = try makeBundle()
    let manager = PaywallArchiveManager(bundledPaywalls: BundledPaywalls(directory: directory))
    let paywall = Paywall.stub().setting(\.url, to: Self.documentURL)
    #expect(paywall.manifest == nil)

    await manager.preloadArchive(paywall: paywall)

    let archiveURL = try #require(await manager.getBundledArchiveURL(for: paywall))
    #expect(FileManager.default.fileExists(atPath: archiveURL.path))
  }

  @Test
  func firstLaunchOfflineUsesTheBundledConfig() async throws {
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    network.configReturnValue = .failure(NetworkError.unknown)
    let deviceHelper = DeviceHelperMock(
      api: dependencyContainer.api,
      storage: storage,
      network: network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
    )
    storage.save(SubscriptionStatus.inactive, forType: SubscriptionStatusKey.self)

    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer,
      bundledPaywalls: BundledPaywalls(directory: try makeBundle())
    )

    await configManager.fetchConfiguration()

    #expect(network.getConfigCalled)
    #expect(configManager.config?.buildId == "bundled_1")
    try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
  }

  @Test
  func firstLaunchOnlinePrefersFreshConfig() async throws {
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    network.configReturnValue = .success(.stub().setting(\.buildId, to: "fresh_456"))
    let deviceHelper = DeviceHelperMock(
      api: dependencyContainer.api,
      storage: storage,
      network: network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
    )
    storage.save(SubscriptionStatus.inactive, forType: SubscriptionStatusKey.self)

    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer,
      bundledPaywalls: BundledPaywalls(directory: try makeBundle())
    )

    await configManager.fetchConfiguration()

    #expect(configManager.config?.buildId == "fresh_456")
    try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
  }
}
