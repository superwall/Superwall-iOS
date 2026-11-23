//
//  EnrichmentTrackingTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 05/11/2026.
//

import Combine
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

  @Test func getEnrichment_whenTrackingTurnsOffBeforeTheReply_dropsIt() async throws {
    let (deviceHelper, network, dependencyContainer) = makeDeviceHelper(behavior: .all)
    network.onGetEnrichment = {
      dependencyContainer.configManager.options.eventTrackingBehavior = .none
    }

    try await deviceHelper.getEnrichment()

    #expect(network.getEnrichmentCallCount == 1)
    #expect(deviceHelper.enrichment == nil)
  }

  /// Enrichment fetched before the app opted out, or restored from disk, isn't used.
  @Test func deviceAttributes_withTrackingOff_leaveOutEnrichment() async {
    let (deviceHelper, _, dependencyContainer) = makeDeviceHelper(behavior: .all)
    deviceHelper.enrichment = Enrichment(user: JSON([:]), device: JSON(["demandScore": 42]))

    let withTracking = await deviceHelper.getTemplateDevice()
    #expect(withTracking["demandScore"] as? Int == 42)

    dependencyContainer.configManager.options.eventTrackingBehavior = .none
    let withoutTracking = await deviceHelper.getTemplateDevice()
    #expect(withoutTracking["demandScore"] == nil)
  }

  /// A request waiting for the app to come to the foreground isn't sent if the
  /// app opts out meanwhile.
  @Test func networkEnrichment_whenTrackingTurnsOffInTheBackground_isNotSent() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSessionMock(factory: dependencyContainer)
    let network = Network(
      urlSession: urlSession,
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let applicationState = CurrentValueSubject<ApplicationState, Never>(.background)
    let request = EnrichmentRequest(user: JSON([:]), device: JSON([:]))

    let task = Task {
      try await network.getEnrichment(
        request: request,
        injectedApplicationStatePublisher: applicationState.eraseToAnyPublisher(),
        maxRetry: 0,
        timeout: nil
      )
    }
    try? await Task.sleep(nanoseconds: 100_000_000)
    dependencyContainer.configManager.options.eventTrackingBehavior = .none
    applicationState.send(.active)

    await #expect(throws: NetworkError.trackingDisabled) {
      try await task.value
    }
    #expect(!urlSession.didRequest)
  }

  /// Every attempt, retries included, checks before sending.
  @Test func request_whenSendingIsNotAllowed_failsWithoutRetrying() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSession(factory: dependencyContainer)
    let attempts = AttemptCount()
    let endpoint = Endpoint<EndpointKinds.Superwall, Enrichment>.enrichment(
      request: EnrichmentRequest(user: JSON([:]), device: JSON([:])),
      maxRetry: 3,
      timeout: nil,
      canSend: {
        attempts.increment()
        return false
      }
    )

    await #expect(throws: NetworkError.trackingDisabled) {
      try await urlSession.request(endpoint, data: SuperwallRequestData(factory: dependencyContainer))
    }
    #expect(attempts.value == 1)
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

private final class AttemptCount: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }

  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }
}
