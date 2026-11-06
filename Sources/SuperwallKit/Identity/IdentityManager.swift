//
//  File.swift
//
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation
import Combine

/// What the identity needs from the rest of the SDK when it replaces the user
/// with a new anonymous one, on `reset()` or on identifying a different user.
protocol IdentityResetHandling: AnyObject {
  /// The attributes a new user keeps, such as install-scoped attribution and
  /// the device identifiers. Called with the identity unlocked, and doesn't
  /// change the identity. Usually called before the identity changes. When another
  /// thread changed the user at the same moment, it's called afterwards
  /// instead, and what it returns is merged into the new user then.
  func attributesKeptAcrossReset() -> [String: Any?]

  /// Resets the rest of the SDK for the new user. Called once the identity
  /// has changed, with it unlocked. The identity isn't ready until this
  /// returns. Must not change the identity: it already holds what the new
  /// user keeps.
  func identityDidReset()
}

/// Holds the user's identity and serializes every change to it.
///
/// The identity lives in an ``IdentityState`` on a ``StateStore``. Changes
/// are ``IdentityAction``s, which run one at a time with the store locked and
/// have run when the call returns, so a read straight after a change sees it
/// and a merge called after `identify(userId:)` lands on the identified user.
/// Waiting on the config or on assignments happens in side effects, tracked
/// as pending work in the state, so it never holds up later changes.
///
/// Replacing the user with a new anonymous one works as on Android: the
/// identity owns it. The rest of the SDK hands over what the new user keeps
/// beforehand, and resets itself afterwards, through ``resetHandler``. So
/// nothing calls back into the identity while it changes.
class IdentityManager: IdentityContext {
  /// The appUserId or the aliasId, depending on whether the user is logged in
  /// or not.
  var userId: String {
    store.state.userId
  }

  /// The identified userId or Superwall-assigned UUID used for purchasing:
  /// the `appUserId` if it's a UUID, otherwise the UUID in the alias.
  var appAccountToken: UUID? {
    let state = store.state
    if let appUserId = state.appUserId,
      let uuid = UUID(uuidString: appUserId) {
      return uuid
    }
    return UUID(
      uuidString: state.aliasId.replacingOccurrences(
        of: IdentityLogic.superwallPrefix,
        with: ""
      )
    )
  }

  /// The userId passed to the SDK.
  var appUserId: String? {
    store.state.appUserId
  }

  /// User attributes that belong to the user.
  var userAttributes: [String: Any] {
    store.state.userAttributes
  }

  /// The randomly generated aliasId used to identify an anonymous user.
  var aliasId: String {
    store.state.aliasId
  }

  /// The randomly generated seed used to put users into cohorts.
  var seed: Int {
    store.state.seed
  }

  /// Indicates whether the user has logged in or not.
  var isLoggedIn: Bool {
    store.state.isLoggedIn
  }

  /// A Publisher that only emits when `identitySubject` is `true`. When `true`,
  /// it means the SDK is ready to fire triggers.
  var hasIdentity: AnyPublisher<Bool, Error> {
    identitySubject
      // Readiness reaches the subject once the store is unlocked, so while a
      // change is being applied the subject can still say ready. A `true` only
      // counts if the identity is still ready. If it isn't, the subject hears
      // `false` and then `true` again once it is.
      .filter { [weak self] isReady in
        isReady && self?.store.state.isReady == true
      }
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }

  /// Indicates whether the identity (i.e. anonymous or logged in with
  /// assignments) has been retrieved.
  ///
  /// When `false`, the SDK is unable to present paywalls. Mirrors
  /// ``IdentityState/isReady``.
  let identitySubject = CurrentValueSubject<Bool, Never>(false)

  let store: IdentityStore
  let userChangeLock = NSRecursiveLock()

  /// Resets the rest of the SDK when the identity replaces the user.
  weak var resetHandler: IdentityResetHandling?

  // Weak rather than unowned: side effects and queued actions can outlive
  // these, and then they should do nothing rather than crash.
  private weak var storage: Storage?
  private weak var configManager: ConfigManager?
  private weak var webEntitlementRedeemer: WebEntitlementRedeemer?
  private let notifyUserChangeHandler: (([String: Any]) -> Void)?
  private let trackHandler: (Trackable) async -> Void

  init(
    deviceHelper: DeviceHelper,
    storage: Storage,
    configManager: ConfigManager,
    webEntitlementRedeemer: WebEntitlementRedeemer,
    notifyUserChange: (([String: Any]) -> Void)? = nil,
    track: @escaping (Trackable) async -> Void = {
      _ = await Superwall.shared.track($0)
    }
  ) {
    self.storage = storage
    self.configManager = configManager
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self.notifyUserChangeHandler = notifyUserChange
    self.trackHandler = track

    let initialState = IdentityState.load(
      from: storage,
      appInstalledAtString: deviceHelper.appInstalledAtString
    )
    store = IdentityStore(initial: initialState)
    identitySubject.send(initialState.isReady)

    IdentityObservers.install(
      on: store,
      persist: { [weak self] before, after in
        self?.persistChanges(from: before, to: after)
      },
      readinessChanged: { [weak self] isReady in
        self?.identitySubject.send(isReady)
      }
    )
  }

  /// Checks for static config upgrade before setting identity.
  func configure() async {
    store.update(IdentityUpdate.begin(.configuration))
    let neverCalledStaticConfig = storage?.neverCalledStaticConfig ?? false
    let isFirstAppOpen = !(storage?.get(DidTrackFirstSeen.self) ?? false)

    if IdentityLogic.shouldGetAssignments(
      isLoggedIn: isLoggedIn,
      neverCalledStaticConfig: neverCalledStaticConfig,
      isFirstAppOpen: isFirstAppOpen
    ) {
      try? await configManager?.getAssignments()
    }

    store.update(IdentityUpdate.end(.configuration))
  }

  /// Creates an account and may or may not wait for assignments before
  /// the identity is ready.
  func identify(
    userId: String,
    options: IdentityOptions?
  ) {
    guard let userId = IdentityLogic.sanitize(userId: userId) else {
      Logger.debug(
        logLevel: .error,
        scope: .identityManager,
        message: "The provided userId was empty."
      )
      return
    }

    // Gathered before the identity is locked, since the rest of the SDK reads
    // them under its own locks. If another thread changes the user in the
    // meantime, the action sorts it out.
    let currentUserId = store.state.appUserId
    let switchesUser = currentUserId != nil && currentUserId != userId
    let keptAttributes = switchesUser ? attributesKeptAcrossReset() : nil

    dispatch(
      .identify(
        userId: userId,
        restoreAssignments: options?.restorePaywallAssignments ?? false,
        keptAttributes: keptAttributes
      )
    )
  }
}

// MARK: - Reset
extension IdentityManager {
  /// Replaces the user with a new anonymous one, then resets the rest of the
  /// SDK through ``resetHandler``, before returning. The identity isn't ready
  /// until both are done.
  func reset() {
    dispatch(.reset(keptAttributes: attributesKeptAcrossReset()))
  }
}

// MARK: - User Attributes
extension IdentityManager {
  /// Merges the attributes. From inside another identity change, such as the
  /// reset an identify does, it lands once that change has finished.
  func mergeUserAttributes(
    _ newUserAttributes: [String: Any?],
    shouldTrackMerge: Bool = true
  ) {
    dispatch(
      .mergeAttributes(
        newUserAttributes,
        shouldTrack: shouldTrackMerge,
        shouldNotify: false
      )
    )
  }

  /// Merges the attributes and notifies the delegate.
  /// This is used when attributes are updated from the paywall.
  func mergeUserAttributesAndNotify(
    _ newUserAttributes: [String: Any?],
    shouldTrackMerge: Bool = true
  ) {
    dispatch(
      .mergeAttributes(
        newUserAttributes,
        shouldTrack: shouldTrackMerge,
        shouldNotify: true
      )
    )
  }
}

// MARK: - IdentityContext
extension IdentityManager {
  func userIdSeed(for userId: String) async -> Int? {
    guard let configManager = configManager else {
      return nil
    }
    let config = try? await configManager.configState
      .compactMap { $0.getConfig() }
      .throwableAsync()
    guard config?.featureFlags.enableUserIdSeed == true else {
      return nil
    }
    return userId.sha256MappedToRange()
  }

  func fetchAssignments() async {
    try? await configManager?.getAssignments()
  }

  func redeemExistingWebEntitlements() async {
    await webEntitlementRedeemer?.redeem(.existingCodes)
  }

  func attributesKeptAcrossReset() -> [String: Any?] {
    resetHandler?.attributesKeptAcrossReset() ?? [:]
  }

  func resetRestOfSDK() {
    resetHandler?.identityDidReset()
  }

  func trackIdentityAlias() {
    sideEffect { [trackHandler] in
      await trackHandler(InternalSuperwallEvent.IdentityAlias())
    }
  }

  func trackUserAttributes(_ attributes: [String: Any]) {
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: store.state.appInstalledAtString,
      audienceFilterParams: attributes
    )
    sideEffect { [trackHandler] in
      await trackHandler(event)
    }
  }

  func notifyUserChange(_ attributes: [String: Any]) {
    notifyUserChangeHandler?(attributes)
  }

  func persistIdentity(_ state: IdentityState) {
    guard let storage = storage else {
      return
    }
    if let appUserId = state.appUserId {
      storage.save(appUserId, forType: AppUserId.self)
    } else {
      storage.delete(AppUserId.self)
    }
    storage.save(state.aliasId, forType: AliasId.self)
    storage.save(state.seed, forType: Seed.self)
    storage.save(state.userAttributes, forType: UserAttributes.self)
  }

  func sideEffect(_ work: @escaping () async -> Void) {
    Task {
      await work()
    }
  }

  /// Saves only the fields an update changed. Updates that only touch
  /// pending work save nothing.
  private func persistChanges(from before: IdentityState, to after: IdentityState) {
    guard let storage = storage else {
      return
    }
    if after.appUserId != before.appUserId {
      if let appUserId = after.appUserId {
        storage.save(appUserId, forType: AppUserId.self)
      } else {
        storage.delete(AppUserId.self)
      }
    }
    if after.aliasId != before.aliasId {
      storage.save(after.aliasId, forType: AliasId.self)
    }
    if after.seed != before.seed {
      storage.save(after.seed, forType: Seed.self)
    }
    if !NSDictionary(dictionary: after.userAttributes).isEqual(to: before.userAttributes) {
      storage.save(after.userAttributes, forType: UserAttributes.self)
    }
  }
}
