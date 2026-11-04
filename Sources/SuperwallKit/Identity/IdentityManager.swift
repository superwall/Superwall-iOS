//
//  File.swift
//
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation
import Combine

/// Holds the user's identity and serializes every change to it.
///
/// The identity lives in an ``IdentityState`` on a ``SequentialStore``.
/// Reads are synchronous and never wait. Changes are ``IdentityAction``s,
/// run one at a time in call order, and a change returns once it has run, so
/// a read straight after it sees it and a merge called after
/// `identify(userId:)` lands on the identified user. The one exception: a
/// change made while an identify on another thread is resetting for a new
/// user runs after that reset, once the call has returned. Waiting on the
/// config or on assignments happens in side effects, tracked as pending work
/// in the state, so it never holds up later changes.
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
      .filter { $0 == true }
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

  // Weak rather than unowned: side effects and queued actions can outlive
  // these, and then they should do nothing rather than crash.
  private weak var storage: Storage?
  private weak var configManager: ConfigManager?
  private weak var webEntitlementRedeemer: WebEntitlementRedeemer?
  private let notifyUserChangeHandler: (([String: Any]) -> Void)?
  private let resetForNewUserHandler: () -> Void
  private let trackHandler: (Trackable) async -> Void

  init(
    deviceHelper: DeviceHelper,
    storage: Storage,
    configManager: ConfigManager,
    webEntitlementRedeemer: WebEntitlementRedeemer,
    notifyUserChange: (([String: Any]) -> Void)? = nil,
    resetForNewUser: @escaping () -> Void = {
      Superwall.shared.reset(duringIdentify: true)
    },
    track: @escaping (Trackable) async -> Void = {
      _ = await Superwall.shared.track($0)
    }
  ) {
    self.storage = storage
    self.configManager = configManager
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self.notifyUserChangeHandler = notifyUserChange
    self.resetForNewUserHandler = resetForNewUser
    self.trackHandler = track

    let initialState = IdentityState.load(
      from: storage,
      appInstalledAtString: deviceHelper.appInstalledAtString
    )
    store = IdentityStore(initial: initialState)
    identitySubject.send(initialState.isReady)

    IdentityInterceptors.installObservers(
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

    dispatch(
      .identify(
        userId: userId,
        restoreAssignments: options?.restorePaywallAssignments ?? false
      )
    )
  }

  /// Returns once identity changes dispatched so far, from any thread, have
  /// run. Doesn't wait for their side effects, such as the seed waiting for
  /// the config, or for changes handed over while a user switch was resetting.
  func flush() async {
    store.dispatch(IdentityBarrier(), in: self)
    await store.flush()
  }
}

// MARK: - Reset
extension IdentityManager {
  /// Clears all stored user-specific variables.
  ///
  /// - Parameters:
  ///   - duringIdentify: Whether the reset is part of `identify(userId:)`
  ///   switching user. Then it's running inside the identify action, so it
  ///   applies straight away instead of after that action.
  func reset(duringIdentify: Bool) {
    if duringIdentify {
      store.update(
        IdentityUpdate.reset(
          aliasId: IdentityLogic.generateAlias(),
          seed: IdentityLogic.generateSeed()
        )
      )
    } else {
      dispatch(.reset)
    }
  }

  /// Marks the identity as not ready while `Superwall.reset()` cleans up
  /// after the user it's replacing, so that no paywall is presented in the
  /// middle of that. Pass the result to ``endReset(_:)`` when it's done.
  func beginReset() -> UUID {
    let id = UUID()
    store.update(IdentityUpdate.begin(.reset(id)))
    return id
  }

  /// Ends the cleanup that ``beginReset()`` started.
  func endReset(_ id: UUID) {
    store.update(IdentityUpdate.end(.reset(id)))
  }

  /// Saves the identity again after the user's storage has been wiped. From
  /// inside an identify, it runs once the identify has finished.
  func didResetStorage() {
    dispatch(.persist)
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

  func resetForNewUser() {
    // Resets the rest of the SDK, which takes other objects' queues that may
    // be held by threads waiting to change the identity.
    store.callingOut(resetForNewUserHandler)
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

/// Does nothing. Dispatched to wait for the identity changes before it.
private struct IdentityBarrier: SyncStoreAction {
  func execute(in context: IdentityContext) {}
}
