//
//  NotificationTokenManager.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//

import Combine
import Foundation

/// Reports the device's APNs token and notification permission to Superwall
/// in a `notification_token` event, and tracks opens of the notifications
/// Superwall sends.
///
/// The state is sent when it changes (token, permission, opt in/out), when the
/// user changes (identify and reset), and otherwise at most once a day as a
/// heartbeat. Until the `user_notifications` feature flag is on for the app
/// nothing is sent, but the state is kept so it's sent as soon as it is.
///
/// What it keeps track of lives in a ``NotificationTokenStore``. Everything
/// the app or the SDK asks of it runs one at a time on `coordinator`, in the
/// order it was asked, and reads storage there, never on the caller's thread.
final class NotificationTokenManager: NotificationTokenContext {
  struct Identity: Equatable {
    let aliasId: String
    let appUserId: String?
  }

  /// How long an unchanged state goes before it's sent again.
  static let heartbeatInterval: TimeInterval = 24 * 60 * 60

  let store = NotificationTokenStore(initial: NotificationReportingState())

  private unowned let storage: Storage
  private let coordinator = SerialTaskCoordinator()
  private let notificationSettings: () async -> NotificationSettingsSnapshot
  private let hasConfig: () -> Bool
  private let isFeatureEnabled: () -> Bool
  private let isTrackingAllowed: () -> Bool
  private let identity: () -> Identity
  /// Tracks the event and returns whether it was queued for sending.
  /// The handler is called with whether the event reached Superwall, if it
  /// was queued.
  private let track: (Trackable, @escaping PlacementsQueue.DeliveryHandler) async -> Bool
  private let apnsEnvironment: () -> ApnsEnvironment
  private let apnsTopic: String
  private let appVersion: String
  private let sdkVersion: String
  private let now: () -> Date
  private var cancellables: Set<AnyCancellable> = []

  init(
    storage: Storage,
    notificationSettings: @escaping () async -> NotificationSettingsSnapshot,
    hasConfig: @escaping () -> Bool,
    isFeatureEnabled: @escaping () -> Bool,
    isTrackingAllowed: @escaping () -> Bool,
    identity: @escaping () -> Identity,
    track: @escaping (Trackable, @escaping PlacementsQueue.DeliveryHandler) async -> Bool,
    apnsEnvironment: @escaping () -> ApnsEnvironment = { NotificationTokenLogic.currentApnsEnvironment },
    apnsTopic: String = Bundle.main.bundleIdentifier ?? "",
    appVersion: String,
    sdkVersion: String,
    now: @escaping () -> Date = Date.init
  ) {
    self.storage = storage
    self.notificationSettings = notificationSettings
    self.hasConfig = hasConfig
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

  /// Re-checks the state whenever config arrives or its feature flag changes,
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
      await manager.report(after: .receiveToken(address: address))
    }
  }

  /// Opts the device in to or out of Superwall notifications.
  func setEnabled(_ enabled: Bool) {
    enqueue { manager in
      await manager.report(after: .setEnabled(enabled))
    }
  }

  /// Sends the state if it changed, the user changed or a day has passed, and
  /// any opens that were waiting for config.
  func refresh() {
    enqueue { manager in
      await manager.report(after: nil)
      await manager.sendHeldOpens()
    }
  }

  /// Tracks `notification_open` if Superwall sent the notification and the
  /// `user_notifications` feature flag is on.
  func trackOpen(
    userInfo: [AnyHashable: Any],
    openedAt: Date = Date()
  ) {
    guard let open = NotificationTokenLogic.notificationOpen(
      fromUserInfo: userInfo,
      openedAt: openedAt
    ) else {
      return
    }
    trackOpen(open)
  }

  /// Tracks an open of a notification Superwall sent, if the
  /// `user_notifications` feature flag is on.
  ///
  /// A tap that launches the app usually arrives before config, which holds
  /// the flag. Such an open is saved and sent once config arrives, on a later
  /// launch if need be.
  func trackOpen(_ open: PrivateSuperwallEvents.NotificationOpen) {
    enqueue { manager in
      manager.loadIfNeeded()
      manager.dispatch(.holdOpen(open))
      await manager.sendHeldOpens()
    }
  }

  /// Waits for everything asked of the manager so far to finish.
  func waitUntilIdle() async {
    await coordinator.run {}
  }

  // MARK: - NotificationTokenContext

  var currentDate: Date {
    return now()
  }

  func save(_ registration: NotificationTokenState) {
    storage.save(registration, forType: NotificationTokenStateStorage.self)
  }

  func save(lastSent: NotificationTokenLastSent?) {
    guard let lastSent = lastSent else {
      storage.delete(NotificationTokenLastSentStorage.self)
      return
    }
    storage.save(lastSent, forType: NotificationTokenLastSentStorage.self)
  }

  func save(heldOpens: [PrivateSuperwallEvents.NotificationOpen]) {
    if heldOpens.isEmpty {
      storage.delete(NotificationHeldOpensStorage.self)
      return
    }
    storage.save(heldOpens, forType: NotificationHeldOpensStorage.self)
  }

  // MARK: - Sending

  @discardableResult
  private func dispatch(_ action: NotificationTokenAction) -> NotificationTokenAction.Outcome {
    return store.dispatch(action, in: self)
  }

  private func enqueue(_ operation: @escaping (NotificationTokenManager) async -> Void) {
    coordinator.enqueue { [weak self] in
      guard let self = self else {
        return
      }
      await operation(self)
    }
  }

  /// Reads what earlier launches saved, the first time anything is asked of
  /// the manager. Only called on `coordinator`, so it's read once, off the
  /// caller's thread and with the store unlocked.
  private func loadIfNeeded() {
    if store.read({ $0.isLoaded }) {
      return
    }
    dispatch(
      .load(
        registration: storage.get(NotificationTokenStateStorage.self),
        lastSent: storage.get(NotificationTokenLastSentStorage.self),
        heldOpens: storage.get(NotificationHeldOpensStorage.self) ?? []
      )
    )
  }

  /// Applies `change`, then sends the state if Superwall doesn't have it.
  private func report(after change: NotificationTokenAction?) async {
    loadIfNeeded()
    if let change = change {
      dispatch(change)
    }

    // Without a token there's nothing to send, so don't ask the system for
    // the notification settings yet.
    let registration = store.read { $0.registration }
    guard let address = registration.address else {
      return
    }

    let settings = await notificationSettings()
    let payload = NotificationTokenPayload(
      address: address,
      apnsEnvironment: apnsEnvironment(),
      apnsTopic: apnsTopic,
      authorizationOptions: NotificationTokenLogic.authorizationOptions(from: settings),
      permissionStatus: NotificationTokenLogic.permissionStatus(from: settings.authorizationStatus),
      enabled: registration.enabled,
      appVersion: appVersion,
      sdkVersion: sdkVersion
    )
    dispatch(.recordSettings(payload))

    // Kept until the feature flag is on, which `listen` re-checks for.
    if !isFeatureEnabled() {
      return
    }

    let outcome = dispatch(
      .queueEvent(
        payload: payload,
        fingerprint: Self.fingerprint(of: payload, for: identity()),
        isTrackingAllowed: isTrackingAllowed()
      )
    )
    guard case .sendEvent(let number) = outcome else {
      return
    }

    // Only marked as sent once Superwall has it. If the upload fails, the
    // queue is emptied first or the app quits before it's sent, the next
    // refresh sends it again.
    let enabled = payload.enabled
    let event = PrivateSuperwallEvents.NotificationToken(payload: payload)
    let isQueued = await track(event) { [weak self] isDelivered in
      self?.dispatch(.finishEvent(number: number, enabled: enabled, isDelivered: isDelivered))
    }
    if !isQueued {
      dispatch(.finishEvent(number: number, enabled: enabled, isDelivered: false))
    }
  }

  /// Sends the opens that were waiting for config, once it has arrived. They're
  /// dropped if it says notifications are off for the app.
  private func sendHeldOpens() async {
    loadIfNeeded()
    if !hasConfig() {
      return
    }
    guard case .opens(let opens) = dispatch(.takeHeldOpens) else {
      return
    }
    if !isFeatureEnabled() {
      return
    }
    for open in opens {
      _ = await track(open) { _ in }
    }
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
