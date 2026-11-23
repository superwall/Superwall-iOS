//
//  NotificationTokenState.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/11/2026.
//

import Foundation

typealias NotificationTokenStore = StateStore<NotificationTokenContext, NotificationReportingState>

/// What the SDK knows about the device's push registration. Persisted so it
/// survives launches, and so it can be sent as soon as notifications are
/// turned on for the app.
struct NotificationTokenState: Codable, Equatable {
  /// The lowercase hex of the APNs device token, once the app has passed it in.
  var address: String?
  /// `false` once the app opts the device out of Superwall notifications.
  var enabled = true
  var apnsEnvironment: ApnsEnvironment?
  var apnsTopic: String?
  var authorizationOptions: Int?
  var permissionStatus: NotificationPermissionStatus?
  /// Whether the newest token event known to have reached Superwall opted the
  /// device in. While it's `true`, Superwall believes it can send to the device.
  var isEnabledAtSuperwall = false
}

/// The last `notification_token` event that was sent.
struct NotificationTokenLastSent: Codable, Equatable {
  /// A hash of the event's parameters and the identity it was sent for.
  let fingerprint: String
  let sentAt: Date
}

// MARK: - Storage

/// The device's latest push token, its notification permission and whether
/// the app has opted it out of Superwall notifications.
///
/// Device-scoped, so it survives `reset()`: the token belongs to the install,
/// not the user, and the opt-out is the app's choice for the device. It's only
/// ever sent in a `notification_token` event, never as a user or device
/// attribute.
enum NotificationTokenStateStorage: Storable {
  static var key: String {
    "store.notificationTokenState"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = NotificationTokenState
}

/// A fingerprint of the last `notification_token` event sent and when it was
/// sent, so an unchanged state is only re-sent once a day.
enum NotificationTokenLastSentStorage: Storable {
  static var key: String {
    "store.notificationTokenLastSent"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = NotificationTokenLastSent
}

/// Notification opens that arrived before config, kept so they're still
/// counted if config only arrives on a later launch.
enum NotificationHeldOpensStorage: Storable {
  static var key: String {
    "store.notificationHeldOpens"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = [PrivateSuperwallEvents.NotificationOpen]
}

// MARK: - State

/// Everything ``NotificationTokenManager`` keeps track of. Changed only by
/// ``NotificationReportingUpdate`` reducers, which ``NotificationTokenAction``s
/// apply.
struct NotificationReportingState: Equatable {
  /// A token event that was queued and hasn't been heard back about.
  struct PendingEvent: Equatable {
    /// Each event gets its own number, since the same state can be queued
    /// more than once.
    let number: Int
    let fingerprint: String
  }

  /// The most opens kept while config hasn't arrived.
  static let maxHeldOpens = 50

  /// Whether what earlier launches saved has been read from storage.
  private(set) var isLoaded = false
  /// The device's registration. Saved to storage.
  private(set) var registration = NotificationTokenState()
  /// The last token event that reached Superwall, unless another has been
  /// queued since. Saved to storage.
  private(set) var lastSent: NotificationTokenLastSent?
  /// The latest token event queued but not yet delivered. Superwall ends up
  /// with its state once it lands, so the same state isn't queued twice.
  private(set) var pendingEvent: PendingEvent?
  /// The number given to the last token event queued.
  private(set) var lastEventNumber = 0
  /// The number of the newest token event known to have reached Superwall.
  private(set) var lastDeliveredNumber = 0
  /// Opens waiting for config to say whether notifications are on, oldest
  /// first. Saved to storage.
  private(set) var heldOpens: [PrivateSuperwallEvents.NotificationOpen] = []
}

/// The ways ``NotificationReportingState`` can change.
enum NotificationReportingUpdate: Reducer {
  /// What earlier launches saved was read from storage.
  case loaded(
    registration: NotificationTokenState?,
    lastSent: NotificationTokenLastSent?,
    heldOpens: [PrivateSuperwallEvents.NotificationOpen]
  )
  /// The app passed in the device's token.
  case tokenReceived(address: String)
  /// The app opted the device out of Superwall notifications.
  case optedOut
  /// The app opted the device back in.
  case optedIn
  /// The system's notification settings were read for a token event.
  case settingsRead(NotificationTokenPayload)
  /// A token event was queued. Superwall's state isn't known again until it
  /// lands, so the last one sent is forgotten.
  case eventQueued(fingerprint: String)
  /// A token event's upload finished, or it was dropped before being sent.
  ///
  /// Only the latest event's result says what Superwall ends up with, so an
  /// older one changes nothing but whether the device is enabled there.
  case eventFinished(number: Int, enabled: Bool, isDelivered: Bool, date: Date)
  /// A notification was opened before config arrived.
  case openHeld(PrivateSuperwallEvents.NotificationOpen)
  /// The held opens were taken, to be sent or dropped.
  case heldOpensTaken

  func reduce(_ state: NotificationReportingState) -> NotificationReportingState {
    state.applying(self)
  }
}

extension NotificationReportingState {
  /// The state after `update`. The only place the fields change.
  func applying(_ update: NotificationReportingUpdate) -> NotificationReportingState {
    var state = self
    switch update {
    case let .loaded(registration, lastSent, heldOpens):
      state.isLoaded = true
      state.registration = registration ?? NotificationTokenState()
      state.lastSent = lastSent
      state.heldOpens = heldOpens
    case .tokenReceived(let address):
      state.registration.address = address
    case .optedOut:
      state.registration.enabled = false
    case .optedIn:
      state.registration.enabled = true
    case .settingsRead(let payload):
      state.registration.apnsEnvironment = payload.apnsEnvironment
      state.registration.apnsTopic = payload.apnsTopic
      state.registration.authorizationOptions = payload.authorizationOptions
      state.registration.permissionStatus = payload.permissionStatus
    case .eventQueued(let fingerprint):
      state.lastEventNumber += 1
      state.pendingEvent = PendingEvent(
        number: state.lastEventNumber,
        fingerprint: fingerprint
      )
      state.lastSent = nil
    case let .eventFinished(number, enabled, isDelivered, date):
      if isDelivered,
        number > state.lastDeliveredNumber {
        state.lastDeliveredNumber = number
        state.registration.isEnabledAtSuperwall = enabled
      }
      guard
        let pendingEvent = state.pendingEvent,
        pendingEvent.number == number
      else {
        break
      }
      state.pendingEvent = nil
      if isDelivered {
        state.lastSent = NotificationTokenLastSent(
          fingerprint: pendingEvent.fingerprint,
          sentAt: date
        )
      }
    case .openHeld(let open):
      state.heldOpens.append(open)
      let extra = state.heldOpens.count - Self.maxHeldOpens
      if extra > 0 {
        state.heldOpens.removeFirst(extra)
      }
    case .heldOpensTaken:
      state.heldOpens = []
    }
    return state
  }

  /// Whether a token event with `fingerprint` should be queued.
  func shouldQueueEvent(
    for payload: NotificationTokenPayload,
    fingerprint: String,
    isTrackingAllowed: Bool,
    now: Date
  ) -> Bool {
    // With tracking off, the only thing sent is an opt-out Superwall hasn't
    // had, for a device it believes it can send to.
    if !isTrackingAllowed {
      if payload.enabled {
        return false
      }
      if !registration.isEnabledAtSuperwall {
        return false
      }
    }
    if let pendingEvent = pendingEvent {
      // The same state is on its way. A different one would land after the
      // last one sent, so this has to follow it even if it matches that.
      return pendingEvent.fingerprint != fingerprint
    }
    return NotificationTokenManager.shouldSend(
      fingerprint: fingerprint,
      lastSent: lastSent,
      now: now
    )
  }
}

// MARK: - Actions

/// Everything the manager's actions need. ``NotificationTokenManager``
/// provides it in the SDK, and tests provide a fake.
protocol NotificationTokenContext: AnyObject {
  var store: NotificationTokenStore { get }

  /// The current time.
  var currentDate: Date { get }

  /// Saves the registration. Called with the store locked, in the order the
  /// changes were applied, so it mustn't wait.
  func save(_ registration: NotificationTokenState)

  /// Saves the last token event sent, or removes it when `nil`. Called with
  /// the store locked, so it mustn't wait.
  func save(lastSent: NotificationTokenLastSent?)

  /// Saves the opens waiting for config. Called with the store locked, so it
  /// mustn't wait.
  func save(heldOpens: [PrivateSuperwallEvents.NotificationOpen])
}

/// Every change to what the manager keeps track of. Each runs with the store
/// locked and saves what it changed.
enum NotificationTokenAction: StoreAction {
  /// What an action reports back, read in the same locked step as its change.
  enum Outcome: Equatable {
    case done
    /// A token event was claimed and should be tracked. The number matches
    /// its delivery result to it.
    case sendEvent(number: Int)
    /// The opens that were held, oldest first.
    case opens([PrivateSuperwallEvents.NotificationOpen])
  }

  /// Takes on what earlier launches saved.
  case load(
    registration: NotificationTokenState?,
    lastSent: NotificationTokenLastSent?,
    heldOpens: [PrivateSuperwallEvents.NotificationOpen]
  )
  /// Stores the device's token.
  case receiveToken(address: String)
  /// Opts the device in to or out of Superwall notifications.
  case setEnabled(Bool)
  /// Stores the settings read for a token event.
  case recordSettings(NotificationTokenPayload)
  /// Claims a token event for `payload` if one should be sent, returning
  /// ``Outcome/sendEvent(number:)`` if so.
  case queueEvent(
    payload: NotificationTokenPayload,
    fingerprint: String,
    isTrackingAllowed: Bool
  )
  /// Records whether a token event reached Superwall.
  case finishEvent(number: Int, enabled: Bool, isDelivered: Bool)
  /// Keeps an open until config arrives.
  case holdOpen(PrivateSuperwallEvents.NotificationOpen)
  /// Hands back the held opens and forgets them.
  case takeHeldOpens

  @discardableResult
  func execute(in context: NotificationTokenContext) -> Outcome {
    let store = context.store
    let before = store.state
    var outcome = Outcome.done

    switch self {
    case let .load(registration, lastSent, heldOpens):
      store.update(
        NotificationReportingUpdate.loaded(
          registration: registration,
          lastSent: lastSent,
          heldOpens: heldOpens
        )
      )
      // It's what storage already holds.
      return outcome
    case .receiveToken(let address):
      store.update(NotificationReportingUpdate.tokenReceived(address: address))
    case .setEnabled(let isEnabled):
      store.update(isEnabled ? NotificationReportingUpdate.optedIn : .optedOut)
    case .recordSettings(let payload):
      store.update(NotificationReportingUpdate.settingsRead(payload))
    case let .queueEvent(payload, fingerprint, isTrackingAllowed):
      let shouldQueue = before.shouldQueueEvent(
        for: payload,
        fingerprint: fingerprint,
        isTrackingAllowed: isTrackingAllowed,
        now: context.currentDate
      )
      if !shouldQueue {
        return outcome
      }
      store.update(NotificationReportingUpdate.eventQueued(fingerprint: fingerprint))
      outcome = .sendEvent(number: store.state.lastEventNumber)
    case let .finishEvent(number, enabled, isDelivered):
      store.update(
        NotificationReportingUpdate.eventFinished(
          number: number,
          enabled: enabled,
          isDelivered: isDelivered,
          date: context.currentDate
        )
      )
    case .holdOpen(let open):
      store.update(NotificationReportingUpdate.openHeld(open))
    case .takeHeldOpens:
      outcome = .opens(before.heldOpens)
      store.update(NotificationReportingUpdate.heldOpensTaken)
    }

    let after = store.state
    if after.registration != before.registration {
      context.save(after.registration)
    }
    if after.lastSent != before.lastSent {
      context.save(lastSent: after.lastSent)
    }
    if after.heldOpens != before.heldOpens {
      context.save(heldOpens: after.heldOpens)
    }
    return outcome
  }
}
