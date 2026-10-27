//
//  NotificationTokenManager.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//

import Combine
import Foundation

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

// MARK: - Manager

/// Reports the device's APNs token and notification permission to Superwall
/// in a `notification_token` event, and tracks opens of the notifications
/// Superwall sends.
///
/// The state is sent when it changes (token, permission, opt in/out), when the
/// user changes (identify and reset), and otherwise at most once a day as a
/// heartbeat. Until the `user_notifications` feature flag is on for the app
/// nothing is sent, but the state is kept so it's sent as soon as it is.
///
/// Every operation runs one at a time, in the order it was called, so the
/// state is only ever read and written by one operation.
final class NotificationTokenManager {
  struct Identity: Equatable {
    let aliasId: String
    let appUserId: String?
  }

  /// How long an unchanged state goes before it's sent again.
  static let heartbeatInterval: TimeInterval = 24 * 60 * 60

  private unowned let storage: Storage
  private let coordinator = SerialTaskCoordinator()
  private let notificationSettings: () async -> NotificationSettingsSnapshot
  private let isFeatureEnabled: () -> Bool
  private let isTrackingAllowed: () -> Bool
  private let identity: () -> Identity
  private let track: (Trackable) async -> Void
  private let apnsEnvironment: () -> ApnsEnvironment
  private let apnsTopic: String
  private let appVersion: String
  private let sdkVersion: String
  private let now: () -> Date
  private var cancellables: Set<AnyCancellable> = []

  init(
    storage: Storage,
    notificationSettings: @escaping () async -> NotificationSettingsSnapshot,
    isFeatureEnabled: @escaping () -> Bool,
    isTrackingAllowed: @escaping () -> Bool,
    identity: @escaping () -> Identity,
    track: @escaping (Trackable) async -> Void,
    apnsEnvironment: @escaping () -> ApnsEnvironment = { NotificationTokenLogic.currentApnsEnvironment },
    apnsTopic: String = Bundle.main.bundleIdentifier ?? "",
    appVersion: String,
    sdkVersion: String,
    now: @escaping () -> Date = Date.init
  ) {
    self.storage = storage
    self.notificationSettings = notificationSettings
    self.isFeatureEnabled = isFeatureEnabled
    self.isTrackingAllowed = isTrackingAllowed
    self.identity = identity
    self.track = track
    self.apnsEnvironment = apnsEnvironment
    self.apnsTopic = apnsTopic
    self.appVersion = appVersion
    self.sdkVersion = sdkVersion
    self.now = now
  }

  // MARK: - Triggers

  /// Re-checks the state whenever config arrives with the feature flag on,
  /// the user's identity is set (configure, identify and reset), and the app
  /// becomes active, which is when a permission change made in Settings shows.
  func listen(
    configState: CurrentValueSubject<ConfigState, Error>,
    hasIdentity: AnyPublisher<Bool, Error>,
    notificationCenter: NotificationCenter = .default
  ) {
    configState
      .compactMap { $0.getConfig()?.featureFlags.userNotifications }
      .removeDuplicates()
      .filter { $0 }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] _ in self?.refresh() }
      )
      .store(in: &cancellables)

    hasIdentity
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] _ in self?.refresh() }
      )
      .store(in: &cancellables)

    if let didBecomeActive = SystemInfo.applicationDidBecomeActiveNotification {
      notificationCenter
        .publisher(for: didBecomeActive)
        .sink { [weak self] _ in self?.refresh() }
        .store(in: &cancellables)
    }
  }

  /// Stores the APNs device token and sends it if it's new.
  func setPushToken(_ deviceToken: Data) {
    let address = NotificationTokenLogic.hexString(from: deviceToken)
    enqueue { manager in
      await manager.update { $0.address = address }
    }
  }

  /// Opts the device in to or out of Superwall notifications.
  func setEnabled(_ enabled: Bool) {
    enqueue { manager in
      await manager.update { $0.enabled = enabled }
    }
  }

  /// Sends the state if it changed, the user changed or a day has passed.
  func refresh() {
    enqueue { manager in
      await manager.update { _ in }
    }
  }

  /// Tracks `notification_open` if Superwall sent the notification.
  func trackOpen(userInfo: [AnyHashable: Any]) {
    guard let event = NotificationTokenLogic.notificationOpen(fromUserInfo: userInfo) else {
      return
    }
    enqueue { manager in
      await manager.track(event)
    }
  }

  /// Waits for every operation enqueued so far to finish.
  func waitUntilIdle() async {
    await withCheckedContinuation { continuation in
      coordinator.enqueue {
        continuation.resume()
      }
    }
  }

  // MARK: - Sending

  private func enqueue(_ operation: @escaping (NotificationTokenManager) async -> Void) {
    coordinator.enqueue { [weak self] in
      guard let self = self else {
        return
      }
      await operation(self)
    }
  }

  private func update(_ change: (inout NotificationTokenState) -> Void) async {
    let storedState = storage.get(NotificationTokenStateStorage.self) ?? NotificationTokenState()
    var state = storedState
    change(&state)

    // Without a token there's nothing to send, so don't ask the system for
    // the notification settings yet.
    guard let address = state.address else {
      save(state, ifChangedFrom: storedState)
      return
    }

    let settings = await notificationSettings()
    let payload = NotificationTokenPayload(
      address: address,
      apnsEnvironment: apnsEnvironment(),
      apnsTopic: apnsTopic,
      authorizationOptions: NotificationTokenLogic.authorizationOptions(from: settings),
      permissionStatus: NotificationTokenLogic.permissionStatus(from: settings.authorizationStatus),
      enabled: state.enabled,
      appVersion: appVersion,
      sdkVersion: sdkVersion
    )
    state.apnsEnvironment = payload.apnsEnvironment
    state.apnsTopic = payload.apnsTopic
    state.authorizationOptions = payload.authorizationOptions
    state.permissionStatus = payload.permissionStatus
    save(state, ifChangedFrom: storedState)

    // Kept until the feature flag is on, which `listen` re-checks for.
    guard isFeatureEnabled() else {
      return
    }
    // Not sent, so not marked as sent: it goes once tracking is allowed again.
    guard isTrackingAllowed() else {
      return
    }

    let fingerprint = Self.fingerprint(of: payload, for: identity())
    let lastSent = storage.get(NotificationTokenLastSentStorage.self)
    guard Self.shouldSend(
      fingerprint: fingerprint,
      lastSent: lastSent,
      now: now()
    ) else {
      return
    }

    await track(PrivateSuperwallEvents.NotificationToken(payload: payload))
    storage.save(
      NotificationTokenLastSent(fingerprint: fingerprint, sentAt: now()),
      forType: NotificationTokenLastSentStorage.self
    )
  }

  private func save(
    _ state: NotificationTokenState,
    ifChangedFrom storedState: NotificationTokenState
  ) {
    guard state != storedState else {
      return
    }
    storage.save(state, forType: NotificationTokenStateStorage.self)
  }

  static func shouldSend(
    fingerprint: String,
    lastSent: NotificationTokenLastSent?,
    now: Date
  ) -> Bool {
    guard let lastSent = lastSent else {
      return true
    }
    if lastSent.fingerprint != fingerprint {
      return true
    }
    return now.timeIntervalSince(lastSent.sentAt) >= heartbeatInterval
  }

  /// A hash of everything sent and who it was sent for. It's stored instead of
  /// the identity and token themselves.
  static func fingerprint(
    of payload: NotificationTokenPayload,
    for identity: Identity
  ) -> String {
    var fields = payload.parameters
    fields["aliasId"] = identity.aliasId
    fields["appUserId"] = identity.appUserId ?? ""

    let data = (try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])) ?? Data()
    let canonical = String(data: data, encoding: .utf8) ?? ""
    let hash = canonical.sha256() ?? []
    return hash.map { String(format: "%02x", $0) }.joined()
  }
}
