//
//  EnrichmentTrackingTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 05/11/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

struct EnrichmentTrackingTests {
  private func makeDeviceHelper(
    behavior: EventTrackingBehavior
  ) -> (DeviceHelper, NetworkMock, DependencyContainer) {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.configManager.options.eventTrackingBehavior = behavior
    let network = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let deviceHelper = DeviceHelper(
      api: dependencyContainer.api,
      storage: dependencyContainer.storage,
      network: network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
    )
    return (deviceHelper, network, dependencyContainer)
  }

  @Test func getEnrichment_withTrackingOff_sendsNothing() async throws {
    let (deviceHelper, network, dependencyContainer) = makeDeviceHelper(behavior: .none)

    try await deviceHelper.getEnrichment()

    #expect(network.getEnrichmentCallCount == 0)
    #expect(deviceHelper.enrichment == nil)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test(arguments: [EventTrackingBehavior.all, .superwallOnly])
  func getEnrichment_withTrackingOn_fetchesEnrichment(
    behavior: EventTrackingBehavior
  ) async throws {
    let (deviceHelper, network, dependencyContainer) = makeDeviceHelper(behavior: behavior)

    try await deviceHelper.getEnrichment()

    #expect(network.getEnrichmentCallCount == 1)
    #expect(deviceHelper.enrichment?.device["demandScore"].int == 42)
    withExtendedLifetime(dependencyContainer) {}
  }

  /// The app can opt out while the device attributes are being built.
  @Test func getEnrichment_whenTrackingTurnsOffMidFetch_sendsNothing() async throws {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let deviceHelper = OptingOutDeviceHelper(
      api: dependencyContainer.api,
      storage: dependencyContainer.storage,
      network: network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
    )
    deviceHelper.onBuildAttributes = {
      dependencyContainer.configManager.options.eventTrackingBehavior = .none
    }

    try await deviceHelper.getEnrichment()

    #expect(network.getEnrichmentCallCount == 0)
    #expect(deviceHelper.enrichment == nil)
  }

  @Test func optingBackIn_fetchesEnrichment() async {
    let dependencyContainer = DependencyContainer()
    let deviceHelper = makeDeviceHelperMock(dependencyContainer)
    dependencyContainer.deviceHelper = deviceHelper
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    superwall.eventTrackingBehavior = .none
    superwall.eventTrackingBehavior = .all

    await waitUntil { deviceHelper.getEnrichmentCalled }
    #expect(deviceHelper.getEnrichmentCalled)
  }

  @Test func switchingBetweenTrackingModes_doesNotFetchEnrichment() async throws {
    let dependencyContainer = DependencyContainer()
    let deviceHelper = makeDeviceHelperMock(dependencyContainer)
    dependencyContainer.deviceHelper = deviceHelper
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    superwall.eventTrackingBehavior = .superwallOnly
    superwall.eventTrackingBehavior = .all
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(!deviceHelper.getEnrichmentCalled)
  }

  private func makeDeviceHelperMock(_ dependencyContainer: DependencyContainer) -> DeviceHelperMock {
    return DeviceHelperMock(
      api: dependencyContainer.api,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
    )
  }

  private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: () -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
  }
}

private final class OptingOutDeviceHelper: DeviceHelper {
  var onBuildAttributes: (() -> Void)?

  override func getTemplateDevice(reportingUnknownFieldsAsNull: Bool = false) async -> [String: Any] {
    onBuildAttributes?()
    return ["platform": "iOS"]
  }
}
