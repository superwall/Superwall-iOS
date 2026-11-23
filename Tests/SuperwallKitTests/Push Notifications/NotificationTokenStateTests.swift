//
//  NotificationTokenStateTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

private typealias Open = PrivateSuperwallEvents.NotificationOpen

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func payload(enabled: Bool = true, address: String = "deadbeef") -> NotificationTokenPayload {
  NotificationTokenPayload(
    address: address,
    apnsEnvironment: .sandbox,
    apnsTopic: "com.example.app",
    authorizationOptions: 7,
    permissionStatus: .authorized,
    enabled: enabled,
    appVersion: "2.3.4",
    sdkVersion: "4.19.2"
  )
}

private func open(_ sendId: String) -> Open {
  Open(sendId: sendId, contactPointId: nil, openedAt: now)
}

/// Applies `updates` in order to an empty state.
private func state(_ updates: NotificationReportingUpdate...) -> NotificationReportingState {
  updates.reduce(NotificationReportingState()) { $1.reduce($0) }
}

@Suite("NotificationReportingUpdate reducers")
struct NotificationReportingUpdateTests {
  @Test("loaded takes on what storage held")
  func loaded() {
    var registration = NotificationTokenState()
    registration.address = "ab"
    registration.enabled = false
    let lastSent = NotificationTokenLastSent(fingerprint: "f", sentAt: now)

    let loaded = state(.loaded(registration: registration, lastSent: lastSent, heldOpens: [open("1")]))
    #expect(loaded.isLoaded)
    #expect(loaded.registration == registration)
    #expect(loaded.lastSent == lastSent)
    #expect(loaded.heldOpens == [open("1")])

    let empty = state(.loaded(registration: nil, lastSent: nil, heldOpens: []))
    #expect(empty.isLoaded)
    #expect(empty.registration == NotificationTokenState())
  }

  @Test("tokenReceived, optedOut and optedIn change only their own field")
  func registrationChanges() {
    let optedOut = state(.tokenReceived(address: "ab"), .optedOut)
    #expect(optedOut.registration.address == "ab")
    #expect(optedOut.registration.enabled == false)

    let optedIn = optedOut.applying(.optedIn)
    #expect(optedIn.registration.address == "ab")
    #expect(optedIn.registration.enabled == true)
  }

  @Test("settingsRead stores the environment and permission, not the token or opt-out")
  func settingsRead() {
    let result = state(.optedOut, .settingsRead(payload(enabled: true, address: "other")))
    #expect(result.registration.apnsEnvironment == .sandbox)
    #expect(result.registration.apnsTopic == "com.example.app")
    #expect(result.registration.authorizationOptions == 7)
    #expect(result.registration.permissionStatus == .authorized)
    #expect(result.registration.address == nil)
    #expect(result.registration.enabled == false)
  }

  @Test("eventQueued numbers the event and forgets the last one sent")
  func eventQueued() {
    let sent = state(
      .eventQueued(fingerprint: "a"),
      .eventFinished(number: 1, payload: payload(enabled: true), isDelivered: true, date: now)
    )
    #expect(sent.lastSent == NotificationTokenLastSent(fingerprint: "a", sentAt: now))

    let queued = sent.applying(.eventQueued(fingerprint: "b"))
    #expect(queued.pendingEvent == NotificationReportingState.PendingEvent(number: 2, fingerprint: "b"))
    #expect(queued.lastEventNumber == 2)
    #expect(queued.lastSent == nil)
  }

  @Test("eventFinished records the latest event as sent only if it was delivered")
  func eventFinished() {
    let delivered = state(
      .eventQueued(fingerprint: "a"),
      .eventFinished(number: 1, payload: payload(enabled: true), isDelivered: true, date: now)
    )
    #expect(delivered.pendingEvent == nil)
    #expect(delivered.lastSent?.fingerprint == "a")
    #expect(delivered.registration.addressEnabledAtSuperwall == "deadbeef")

    let failed = state(
      .eventQueued(fingerprint: "a"),
      .eventFinished(number: 1, payload: payload(enabled: true), isDelivered: false, date: now)
    )
    #expect(failed.pendingEvent == nil)
    #expect(failed.lastSent == nil)
    #expect(failed.registration.addressEnabledAtSuperwall == nil)
  }

  @Test("eventFinished for an older event leaves the latest one pending")
  func eventFinished_olderEvent() {
    let result = state(
      .eventQueued(fingerprint: "a"),
      .eventQueued(fingerprint: "b"),
      .eventFinished(number: 1, payload: payload(enabled: true), isDelivered: true, date: now)
    )
    #expect(result.pendingEvent == NotificationReportingState.PendingEvent(number: 2, fingerprint: "b"))
    #expect(result.lastSent == nil)
    // It still says Superwall can send to the token.
    #expect(result.registration.addressEnabledAtSuperwall == "deadbeef")
  }

  @Test("the newest delivered event decides which token is enabled at Superwall")
  func eventFinished_enabledAtSuperwall() {
    let optedOut = state(
      .eventQueued(fingerprint: "a"),
      .eventQueued(fingerprint: "b"),
      .eventFinished(number: 2, payload: payload(enabled: false), isDelivered: true, date: now),
      // The older opt-in reports back after the opt-out.
      .eventFinished(number: 1, payload: payload(enabled: true), isDelivered: true, date: now)
    )
    #expect(optedOut.registration.addressEnabledAtSuperwall == nil)
    #expect(optedOut.lastSent?.fingerprint == "b")
  }

  @Test("openHeld keeps the newest opens up to the limit")
  func openHeld() {
    var result = NotificationReportingState()
    for index in 0...NotificationReportingState.maxHeldOpens {
      result = result.applying(.openHeld(open("\(index)")))
    }
    #expect(result.heldOpens.count == NotificationReportingState.maxHeldOpens)
    #expect(result.heldOpens.first?.sendId == "1")
    #expect(result.heldOpens.last?.sendId == "\(NotificationReportingState.maxHeldOpens)")

    #expect(result.applying(.heldOpensTaken).heldOpens.isEmpty)
  }
}

@Suite("NotificationReportingState.shouldQueueEvent")
struct NotificationShouldQueueEventTests {
  private func shouldQueue(
    _ state: NotificationReportingState,
    enabled: Bool = true,
    address: String = "deadbeef",
    fingerprint: String = "a",
    isTrackingAllowed: Bool = true,
    at date: Date = now
  ) -> Bool {
    state.shouldQueueEvent(
      for: payload(enabled: enabled, address: address),
      fingerprint: fingerprint,
      isTrackingAllowed: isTrackingAllowed,
      now: date
    )
  }

  private let sentA = state(
    .eventQueued(fingerprint: "a"),
    .eventFinished(number: 1, payload: payload(enabled: true), isDelivered: true, date: now)
  )

  @Test("a state that was never sent is queued")
  func neverSent() {
    #expect(shouldQueue(NotificationReportingState()))
  }

  @Test("the state last sent is queued again only after a day")
  func lastSent() {
    #expect(shouldQueue(sentA) == false)
    #expect(shouldQueue(sentA, fingerprint: "b"))
    #expect(shouldQueue(sentA, at: now.addingTimeInterval(NotificationTokenManager.heartbeatInterval)))
  }

  @Test("a state on its way isn't queued twice, but a different one follows it")
  func pending() {
    let pendingB = sentA.applying(.eventQueued(fingerprint: "b"))
    #expect(shouldQueue(pendingB, fingerprint: "b") == false)
    // Back to the state last sent, which has to land after the pending one.
    #expect(shouldQueue(pendingB, fingerprint: "a"))
  }

  @Test("with tracking off only an opt-out Superwall hasn't had is queued")
  func trackingOff() {
    // Superwall has the device as enabled.
    #expect(shouldQueue(sentA, enabled: false, fingerprint: "out", isTrackingAllowed: false))
    #expect(shouldQueue(sentA, enabled: true, fingerprint: "other", isTrackingAllowed: false) == false)

    // Superwall never had the token.
    #expect(
      shouldQueue(NotificationReportingState(), enabled: false, isTrackingAllowed: false) == false
    )

    // The device's token has changed to one Superwall hasn't had.
    #expect(
      shouldQueue(sentA, enabled: false, address: "new", fingerprint: "out", isTrackingAllowed: false) == false
    )

    // Superwall already has the opt-out.
    let optedOut = sentA
      .applying(.eventQueued(fingerprint: "out"))
      .applying(.eventFinished(number: 2, payload: payload(enabled: false), isDelivered: true, date: now))
    #expect(shouldQueue(optedOut, enabled: false, fingerprint: "out", isTrackingAllowed: false) == false)
  }
}

/// Records what the actions save.
private final class FakeNotificationContext: NotificationTokenContext {
  enum Save: Equatable {
    case registration(NotificationTokenState)
    case lastSent(NotificationTokenLastSent?)
    case heldOpens([Open])
  }

  let store = NotificationTokenStore(initial: NotificationReportingState())
  var currentDate = now
  private(set) var saves: [Save] = []

  func save(_ registration: NotificationTokenState) {
    saves.append(.registration(registration))
  }

  func save(lastSent: NotificationTokenLastSent?) {
    saves.append(.lastSent(lastSent))
  }

  func save(heldOpens: [Open]) {
    saves.append(.heldOpens(heldOpens))
  }

  @discardableResult
  func dispatch(_ action: NotificationTokenAction) -> NotificationTokenAction.Outcome {
    store.dispatch(action, in: self)
  }
}

@Suite("NotificationTokenAction")
struct NotificationTokenActionTests {
  @Test("load takes on storage's values without saving them back")
  func load() {
    let context = FakeNotificationContext()
    var registration = NotificationTokenState()
    registration.address = "ab"

    context.dispatch(.load(registration: registration, lastSent: nil, heldOpens: [open("1")]))

    #expect(context.store.state.registration == registration)
    #expect(context.store.state.heldOpens == [open("1")])
    #expect(context.saves.isEmpty)
  }

  @Test("a registration change is saved only when something changed")
  func registrationIsSavedOnChange() {
    let context = FakeNotificationContext()

    context.dispatch(.receiveToken(address: "ab"))
    context.dispatch(.receiveToken(address: "ab"))
    context.dispatch(.setEnabled(true))
    context.dispatch(.setEnabled(false))

    var expected = NotificationTokenState()
    expected.address = "ab"
    var optedOut = expected
    optedOut.enabled = false
    #expect(context.saves == [.registration(expected), .registration(optedOut)])
  }

  @Test("queueEvent claims a numbered event and removes the saved last-sent")
  func queueEvent() {
    let context = FakeNotificationContext()
    let first = context.dispatch(
      .queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: true)
    )
    #expect(first == .sendEvent(number: 1, isSentWhenTrackingIsOff: false))

    // The same state again is already on its way.
    let repeated = context.dispatch(
      .queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: true)
    )
    #expect(repeated == .done)

    context.dispatch(.finishEvent(number: 1, payload: payload(enabled: true), isDelivered: true))
    var enabledAtSuperwall = NotificationTokenState()
    enabledAtSuperwall.addressEnabledAtSuperwall = "deadbeef"
    #expect(context.saves == [
      .registration(enabledAtSuperwall),
      .lastSent(NotificationTokenLastSent(fingerprint: "a", sentAt: now))
    ])

    let next = context.dispatch(
      .queueEvent(payload: payload(enabled: false), fingerprint: "b", isTrackingAllowed: true)
    )
    // Superwall has this token opted in, so the opt-out may go with tracking off.
    #expect(next == .sendEvent(number: 2, isSentWhenTrackingIsOff: true))
    #expect(context.saves.last == .lastSent(nil))
  }

  @Test("queueEvent with tracking off claims nothing for a state that isn't an owed opt-out")
  func queueEvent_trackingOff() {
    let context = FakeNotificationContext()
    let outcome = context.dispatch(
      .queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: false)
    )
    #expect(outcome == .done)
    #expect(context.store.state.pendingEvent == nil)
    #expect(context.saves.isEmpty)
  }

  @Test("an opt-in landing while the app has opted out asks for another report")
  func finishEvent_optOutOwed() {
    let context = FakeNotificationContext()
    context.dispatch(.receiveToken(address: "deadbeef"))
    context.dispatch(.queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: true))
    // Held back: tracking is off and Superwall doesn't have the token yet.
    context.dispatch(.setEnabled(false))
    let optOut = context.dispatch(
      .queueEvent(payload: payload(enabled: false), fingerprint: "b", isTrackingAllowed: false)
    )
    #expect(optOut == .done)

    let landed = context.dispatch(.finishEvent(number: 1, payload: payload(), isDelivered: true))
    #expect(landed == .reportAgain)
  }

  @Test("an opt-in landing asks for nothing more when the app hasn't opted out or an event is on its way")
  func finishEvent_nothingOwed() {
    let optedIn = FakeNotificationContext()
    optedIn.dispatch(.queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: true))
    #expect(optedIn.dispatch(.finishEvent(number: 1, payload: payload(), isDelivered: true)) == .done)

    // The opt-out is already on its way behind the opt-in.
    let pending = FakeNotificationContext()
    pending.dispatch(.queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: true))
    pending.dispatch(.setEnabled(false))
    pending.dispatch(.queueEvent(payload: payload(enabled: false), fingerprint: "b", isTrackingAllowed: true))
    #expect(pending.dispatch(.finishEvent(number: 1, payload: payload(), isDelivered: true)) == .done)

    // The opt-in's upload failed, so Superwall has nothing to undo.
    let failed = FakeNotificationContext()
    failed.dispatch(.queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: true))
    failed.dispatch(.setEnabled(false))
    #expect(failed.dispatch(.finishEvent(number: 1, payload: payload(), isDelivered: false)) == .done)
  }

  @Test("finishEvent that fails saves nothing")
  func finishEvent_failed() {
    let context = FakeNotificationContext()
    context.dispatch(.queueEvent(payload: payload(), fingerprint: "a", isTrackingAllowed: true))
    context.dispatch(.finishEvent(number: 1, payload: payload(enabled: true), isDelivered: false))

    #expect(context.store.state.pendingEvent == nil)
    #expect(context.saves.isEmpty)
  }

  @Test("holdOpen saves the opens and takeHeldOpens hands them back once")
  func heldOpens() {
    let context = FakeNotificationContext()
    context.dispatch(.holdOpen(open("1")))
    context.dispatch(.holdOpen(open("2")))

    #expect(context.dispatch(.takeHeldOpens) == .opens([open("1"), open("2")]))
    #expect(context.dispatch(.takeHeldOpens) == .opens([]))
    #expect(context.saves == [
      .heldOpens([open("1")]),
      .heldOpens([open("1"), open("2")]),
      .heldOpens([])
    ])
  }
}
