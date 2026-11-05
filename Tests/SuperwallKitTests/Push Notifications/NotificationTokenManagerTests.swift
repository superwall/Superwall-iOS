//
//  NotificationTokenManagerTests.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//
// swiftlint:disable all

import Testing
import Foundation
import UserNotifications
import Combine
@testable import SuperwallKit

/// Controls everything `NotificationTokenManager` reads, and records what it tracks.
private final class Harness: @unchecked Sendable {
  private let lock = NSLock()

  var featureEnabled = true
  var trackingAllowed = true
  var identity = NotificationTokenManager.Identity(aliasId: "$SuperwallAlias:1", appUserId: nil)
  var settings = NotificationSettingsSnapshot(
    authorizationStatus: .authorized,
    alertSetting: .enabled,
    badgeSetting: .enabled,
    soundSetting: .enabled
  )
  var now = Date(timeIntervalSince1970: 1_800_000_000)
  var settingsReads = 0
  /// Whether the queue accepts the events it's given.
  var isQueueAccepting = true
  /// Whether queued events reach Superwall straight away. When `false`, the
  /// delivery handlers wait in `pendingDeliveries`.
  var deliversImmediately = true
  var pendingDeliveries: [PlacementsQueue.DeliveryHandler] = []

  private var _tracked: [Trackable] = []
  var tracked: [Trackable] {
    lock.withLock { _tracked }
  }
  func recordForTest(_ event: Trackable) {
    lock.withLock { _tracked.append(event) }
  }
  var tokenEvents: [PrivateSuperwallEvents.NotificationToken] {
    tracked.compactMap { $0 as? PrivateSuperwallEvents.NotificationToken }
  }

  let storage: StorageMock

  init(storage: StorageMock = StorageMock(cache: CacheMock())) {
    self.storage = storage
  }

  func makeManager() -> NotificationTokenManager {
    return NotificationTokenManager(
      storage: storage,
      notificationSettings: { [unowned self] in
        self.settingsReads += 1
        return self.settings
      },
      isFeatureEnabled: { [unowned self] in self.featureEnabled },
      isFeatureEnabledOnceConfigured: { [unowned self] in self.featureEnabled },
      isTrackingAllowed: { [unowned self] in self.trackingAllowed },
      identity: { [unowned self] in self.identity },
      track: { [unowned self] event, onDelivery in
        self.lock.withLock { self._tracked.append(event) }
        if !self.isQueueAccepting {
          return false
        }
        if self.deliversImmediately {
          onDelivery(true)
        } else {
          self.pendingDeliveries.append(onDelivery)
        }
        return true
      },
      apnsEnvironment: { .sandbox },
      apnsTopic: "com.example.app",
      appVersion: "2.3.4",
      sdkVersion: "4.18.3",
      now: { [unowned self] in self.now }
    )
  }
}

private let token = Data([0xde, 0xad, 0xbe, 0xef, 0x00, 0x01])

@Suite(.serialized)
struct NotificationTokenManagerTests {
  @Test func sendsTokenWithExactParameters() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.count == 1)
    let event = harness.tokenEvents[0]
    #expect(event.rawName == "notification_token")
    #expect(event.canImplicitlyTriggerPaywall == false)

    let params = event.audienceFilterParams
    #expect(Set(params.keys) == [
      "channel", "address", "apnsEnvironment", "apnsTopic", "authorizationOptions",
      "permissionStatus", "enabled", "appVersion", "sdkVersion"
    ])
    #expect(params["channel"] as? String == "apns")
    #expect(params["address"] as? String == "deadbeef0001")
    #expect(params["apnsEnvironment"] as? String == "SANDBOX")
    #expect(params["apnsTopic"] as? String == "com.example.app")
    #expect(params["authorizationOptions"] as? Int == 7)
    #expect(params["permissionStatus"] as? String == "AUTHORIZED")
    #expect(params["enabled"] as? Bool == true)
    #expect(params["appVersion"] as? String == "2.3.4")
    #expect(params["sdkVersion"] as? String == "4.18.3")
  }

  @Test func withoutToken_sendsNothingAndDoesNotReadSettings() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.refresh()
    manager.setEnabled(false)
    await manager.waitUntilIdle()

    #expect(harness.tracked.isEmpty)
    #expect(harness.settingsReads == 0)
  }

  // MARK: - Dedup and heartbeat

  @Test func unchangedState_isNotResentWithinADay() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()

    harness.now = harness.now.addingTimeInterval(23 * 60 * 60)
    manager.refresh()
    manager.setPushToken(token)
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.count == 1)
  }

  @Test func unchangedState_isResentAfterADay() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()

    harness.now = harness.now.addingTimeInterval(24 * 60 * 60)
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 2)

    // The heartbeat restarts the clock.
    harness.now = harness.now.addingTimeInterval(60 * 60)
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 2)
  }

  @Test func heartbeatSurvivesRelaunch() async {
    let harness = Harness()
    let first = harness.makeManager()
    first.setPushToken(token)
    await first.waitUntilIdle()
    #expect(harness.tokenEvents.count == 1)

    // A new launch with the same storage and nothing changed.
    harness.now = harness.now.addingTimeInterval(60)
    let relaunched = harness.makeManager()
    relaunched.refresh()
    await relaunched.waitUntilIdle()
    #expect(harness.tokenEvents.count == 1)
  }

  @Test func tokenChange_isSent() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setPushToken(token)
    manager.setPushToken(Data([0x01, 0x02]))
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.map { $0.payload.address } == ["deadbeef0001", "0102"])
  }

  @Test func authorizationChange_isSent() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()

    harness.settings = NotificationSettingsSnapshot(authorizationStatus: .denied)
    manager.refresh()
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.count == 2)
    #expect(harness.tokenEvents[1].payload.permissionStatus == .denied)
    #expect(harness.tokenEvents[1].payload.authorizationOptions == 0)
  }

  @Test func identify_isSent() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()

    harness.identity = .init(aliasId: "$SuperwallAlias:1", appUserId: "user_1")
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 2)

    // Same user again: nothing new.
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 2)
  }

  @Test func reset_isSent() async {
    let harness = Harness()
    harness.identity = .init(aliasId: "$SuperwallAlias:1", appUserId: "user_1")
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()

    // `reset()` drops the user id and generates a new alias.
    harness.identity = .init(aliasId: "$SuperwallAlias:2", appUserId: nil)
    manager.refresh()
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.count == 2)
  }

  @Test func optOutAndOptIn_areSent() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setPushToken(token)
    manager.setEnabled(false)
    manager.setEnabled(false)
    manager.setEnabled(true)
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.map { $0.payload.enabled } == [true, false, true])
  }

  @Test func optOut_persistsAcrossLaunches() async {
    let harness = Harness()
    let manager = harness.makeManager()
    manager.setPushToken(token)
    manager.setEnabled(false)
    await manager.waitUntilIdle()

    let relaunched = harness.makeManager()
    harness.now = harness.now.addingTimeInterval(25 * 60 * 60)
    relaunched.refresh()
    await relaunched.waitUntilIdle()

    #expect(harness.storage.get(NotificationTokenStateStorage.self)?.enabled == false)
    #expect(harness.tokenEvents.last?.payload.enabled == false)
  }

  @Test func optOutBeforeToken_appliesToFirstSend() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.setEnabled(false)
    manager.setPushToken(token)
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.map { $0.payload.enabled } == [false])
  }

  // MARK: - Feature flag

  @Test func flagOff_cachesStateAndSendsNothing() async {
    let harness = Harness()
    harness.featureEnabled = false
    let manager = harness.makeManager()

    manager.setPushToken(token)
    manager.setEnabled(false)
    await manager.waitUntilIdle()

    #expect(harness.tracked.isEmpty)
    #expect(harness.storage.get(NotificationTokenLastSentStorage.self) == nil)
    let state = harness.storage.get(NotificationTokenStateStorage.self)
    #expect(state?.address == "deadbeef0001")
    #expect(state?.enabled == false)
    #expect(state?.apnsEnvironment == .sandbox)
    #expect(state?.apnsTopic == "com.example.app")
    #expect(state?.authorizationOptions == 7)
    #expect(state?.permissionStatus == .authorized)
  }

  @Test func flagTurningOn_flushesCachedStateOnce() async {
    let harness = Harness()
    harness.featureEnabled = false
    let flagOff = harness.makeManager()
    flagOff.setPushToken(token)
    await flagOff.waitUntilIdle()
    #expect(harness.tracked.isEmpty)

    // Next launch: config arrives with the flag on, and the app doesn't pass
    // the token in again.
    harness.featureEnabled = true
    let manager = harness.makeManager()
    manager.refresh()
    manager.refresh()
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.count == 1)
    #expect(harness.tokenEvents.first?.payload.address == "deadbeef0001")
  }

  @Test func flagTurningOn_viaConfig_triggersSend() async throws {
    let harness = Harness()
    harness.featureEnabled = false
    let manager = harness.makeManager()
    manager.setPushToken(token)
    await manager.waitUntilIdle()

    let configState = CurrentValueSubject<ConfigState, Error>(.retrieving)
    let identity = PassthroughSubject<Bool, Error>()
    manager.listen(
      configState: configState,
      hasIdentity: identity.eraseToAnyPublisher(),
      notificationCenter: NotificationCenter()
    )

    var config = Config.stub()
    config.featureFlags.userNotifications = true
    harness.featureEnabled = true
    configState.send(.retrieved(config))

    try await Task.sleep(nanoseconds: 100_000_000)
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 1)
  }

  @Test func trackingNotAllowed_sendsWhenAllowedAgain() async {
    let harness = Harness()
    harness.trackingAllowed = false
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()
    #expect(harness.tracked.isEmpty)

    harness.trackingAllowed = true
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 1)
  }

  @Test func eventDroppedByQueue_isNotMarkedAsSent() async {
    let harness = Harness()
    // The options allow tracking but the queue hasn't heard yet, so it drops it.
    harness.isQueueAccepting = false
    let manager = harness.makeManager()

    manager.setPushToken(token)
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 1)
    #expect(harness.storage.get(NotificationTokenLastSentStorage.self) == nil)

    harness.isQueueAccepting = true
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 2)
    #expect(harness.storage.get(NotificationTokenLastSentStorage.self) != nil)
  }

  @Test func failedDelivery_isResent() async {
    let harness = Harness()
    harness.deliversImmediately = false
    let manager = harness.makeManager()

    manager.setEnabled(false)
    manager.setPushToken(token)
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 1)

    // Still on its way, so it isn't queued again.
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 1)

    // The upload fails, or the queue is emptied by a tracking change.
    harness.pendingDeliveries.removeFirst()(false)
    #expect(harness.storage.get(NotificationTokenLastSentStorage.self) == nil)

    harness.deliversImmediately = true
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.map { $0.payload.enabled } == [false, false])
    #expect(harness.storage.get(NotificationTokenLastSentStorage.self) != nil)
  }

  @Test func optOutInOut_whileUndelivered_endsOptedOut() async {
    let harness = Harness()
    harness.deliversImmediately = false
    let manager = harness.makeManager()

    manager.setPushToken(token)
    manager.setEnabled(false)
    manager.setEnabled(true)
    manager.setEnabled(false)
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.map { $0.payload.enabled } == [true, false, true, false])

    // They land in order; only the last one is recorded as sent.
    for deliver in harness.pendingDeliveries {
      deliver(true)
    }
    manager.refresh()
    await manager.waitUntilIdle()
    #expect(harness.tokenEvents.count == 4)
  }

  @Test func revertingToTheSentState_whileAnotherIsUndelivered_isSent() async {
    let harness = Harness()
    let manager = harness.makeManager()
    manager.setPushToken(token)
    await manager.waitUntilIdle()

    // Opting out is on its way when the app opts back in.
    harness.deliversImmediately = false
    manager.setEnabled(false)
    manager.setEnabled(true)
    await manager.waitUntilIdle()

    #expect(harness.tokenEvents.map { $0.payload.enabled } == [true, false, true])
  }

  @Test func undeliveredEvent_isResentAfterRelaunch() async {
    let harness = Harness()
    harness.deliversImmediately = false
    let manager = harness.makeManager()
    manager.setPushToken(token)
    await manager.waitUntilIdle()

    // The app quits before the queue is flushed.
    harness.deliversImmediately = true
    let relaunched = harness.makeManager()
    relaunched.refresh()
    await relaunched.waitUntilIdle()

    #expect(harness.tokenEvents.count == 2)
  }

  // MARK: - Opens

  @Test func trackOpen_onlyForSuperwallNotifications() async {
    let harness = Harness()
    let manager = harness.makeManager()

    manager.trackOpen(userInfo: ["aps": ["alert": "Hi"]])
    manager.trackOpen(userInfo: ["sw": ["sendId": "send_1", "cpId": "cp_1"]])
    await manager.waitUntilIdle()

    let opens = harness.tracked.compactMap { $0 as? PrivateSuperwallEvents.NotificationOpen }
    #expect(harness.tracked.count == 1)
    #expect(opens.first?.sendId == "send_1")
    #expect(opens.first?.contactPointId == "cp_1")
  }

  @Test func trackOpen_waitsForConfig() async throws {
    let harness = Harness()
    let config = PassthroughSubject<Bool, Never>()
    let manager = NotificationTokenManager(
      storage: harness.storage,
      notificationSettings: { harness.settings },
      isFeatureEnabled: { false },
      isFeatureEnabledOnceConfigured: {
        await config.values.first { _ in true } ?? false
      },
      isTrackingAllowed: { true },
      identity: { harness.identity },
      track: { event, _ in
        harness.recordForTest(event)
        return true
      },
      appVersion: "2.3.4",
      sdkVersion: "4.18.3"
    )

    // A tap launches the app before config has arrived.
    manager.trackOpen(userInfo: ["sw": ["sendId": "send_1"]])
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(harness.tracked.isEmpty)

    config.send(true)
    try await Task.sleep(nanoseconds: 100_000_000)
    await manager.waitUntilIdle()
    #expect(harness.tracked.count == 1)
  }

  @Test func trackOpen_flagOff_sendsNothing() async {
    let harness = Harness()
    harness.featureEnabled = false
    let manager = harness.makeManager()

    manager.trackOpen(userInfo: ["sw": ["sendId": "send_1", "cpId": "cp_1"]])
    await manager.waitUntilIdle()

    #expect(harness.tracked.isEmpty)
  }

  // MARK: - Fingerprint

  @Test func fingerprint_changesWithIdentityAndParameters() {
    let payload = NotificationTokenPayload(
      address: "ab",
      apnsEnvironment: .production,
      apnsTopic: "t",
      authorizationOptions: 4,
      permissionStatus: .authorized,
      enabled: true,
      appVersion: "1",
      sdkVersion: "2"
    )
    let anonymous = NotificationTokenManager.Identity(aliasId: "a", appUserId: nil)
    let identified = NotificationTokenManager.Identity(aliasId: "a", appUserId: "u")
    let base = NotificationTokenManager.fingerprint(of: payload, for: anonymous)

    #expect(base == NotificationTokenManager.fingerprint(of: payload, for: anonymous))
    #expect(base != NotificationTokenManager.fingerprint(of: payload, for: identified))
    #expect(base.count == 64)
  }
}
