//
//  CacheManager.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation

class Storage {
  static let shared = Storage()
  let coreDataManager: CoreDataManager

  var apiKey = ""
  var debugKey: String?
  var appUserId: String? {
    didSet {
      save()
    }
  }
  var aliasId: String? {
    didSet {
      save()
    }
  }
	var didTrackFirstSeen = false
  var userAttributes: [String: Any] = [:]
  var isUpdatingToStaticConfig = false
  var didCheckForStaticConfigUpdate = false

  var userId: String? {
    return appUserId ?? aliasId
  }
  private var confirmedAssignments: [Experiment.ID: Experiment.Variant]?
  private let cache: Cache

  init(
    cache: Cache = Cache(),
    coreDataManager: CoreDataManager = CoreDataManager()
  ) {
    self.cache = cache
    self.coreDataManager = coreDataManager
    self.appUserId = cache.read(AppUserId.self)
    self.aliasId = cache.read(AliasId.self)
    self.didTrackFirstSeen = cache.read(DidTrackFirstSeen.self) == true
    self.userAttributes = cache.read(UserAttributes.self) ?? [:]
  }

  func configure(
    appUserId: String?,
    apiKey: String
  ) {
    migrateData()
    updateSdkVersion()


    identify(with: appUserId)

    self.apiKey = apiKey

    if aliasId == nil {
      aliasId = StorageLogic.generateAlias()
    }
  }

  func identify(with userId: String?) {
    let outcome = StorageLogic.identify(
      withUserId: userId,
      oldUserId: appUserId,
      hasTriggerDelay: TriggerDelayManager.shared.hasDelay
    )

    if let userId = userId {
      appUserId = userId
    }

    switch outcome {
    case .reset:
      TriggerDelayManager.shared.appUserIdAfterReset = appUserId
      Paywall.reset()
    case .checkForStaticConfigUpgrade:
      checkForStaticConfigUpgrade()
    case .loadAssignments:
      ConfigManager.shared.loadAssignments()
    case .nonBlockingAssignmentDelay:
      let nonBlockingAssignmentCall = PreConfigAssignmentCall(isBlocking: false)
      TriggerDelayManager.shared.cachePreConfigAssignmentCall(nonBlockingAssignmentCall)
    }
  }

  private func migrateData() {
    let version = cache.read(Version.self) ?? .v1
    FileManagerMigrator.migrate(
      fromVersion: version,
      cache: cache
    )
  }

  /// Checks to see whether a user has upgraded from normal to static config.
  /// This blocks triggers until assignments is returned.
  private func updateSdkVersion() {
    if didCheckForStaticConfigUpdate {
      return
    }

    let actualSdkVersion = sdkVersion
    let previousSdkVersion = cache.read(SdkVersion.self)
    if actualSdkVersion != previousSdkVersion {
      cache.write(actualSdkVersion, forType: SdkVersion.self)
    }
    if previousSdkVersion == nil {
      isUpdatingToStaticConfig = true
    }

    didCheckForStaticConfigUpdate = true
  }

  /// Called by `identify(with:)` if the user ID set is the same as before.
  ///
  /// This gets, or queues the retrieval of, the user's assignments.
  /// This only happens if the user hasn't previously stored an SDK version in the cache and it's been over an hour since install.
  func checkForStaticConfigUpgrade(
    deviceHelper: DeviceHelper = DeviceHelper.shared,
    triggerDelayManager: TriggerDelayManager = .shared,
    configManager: ConfigManager = .shared,
    completion: (() -> Void)? = nil
  ) {
    if isUpdatingToStaticConfig {
      if triggerDelayManager.hasDelay {
        let blockingAssignmentCall = PreConfigAssignmentCall(isBlocking: true)
        triggerDelayManager.cachePreConfigAssignmentCall(blockingAssignmentCall)
      } else {
        configManager.loadAssignments()
      }
      isUpdatingToStaticConfig = false
    }
  }

  /// Call this when you log out
  func clear() {
    coreDataManager.deleteAllEntities()
    cache.cleanUserFiles()
    confirmedAssignments = nil
    appUserId = nil
    aliasId = StorageLogic.generateAlias()
    userAttributes = [:]
    ConfigManager.shared.clear()
    didTrackFirstSeen = false
    recordFirstSeenTracked()
  }

	func mergeUserAttributes(_ newAttributes: [String: Any]) {
    let mergedAttributes = StorageLogic.mergeAttributes(
      newAttributes,
      with: userAttributes
    )
    cache.write(mergedAttributes, forType: UserAttributes.self)
    userAttributes = mergedAttributes
	}

	func recordFirstSeenTracked() {
    if didTrackFirstSeen {
      return
    }

    Paywall.track(SuperwallEvent.FirstSeen())
    cache.write(true, forType: DidTrackFirstSeen.self)
		didTrackFirstSeen = true
	}

  func recordAppInstall(
    trackEvent: (Trackable) -> TrackingResult = Paywall.track
  ) {
    let didTrackAppInstall = cache.read(DidTrackAppInstall.self) ?? false
    if didTrackAppInstall {
      return
    }

    _ = trackEvent(SuperwallEvent.AppInstall())
    cache.write(true, forType: DidTrackAppInstall.self)
  }

  private func save() {
    if let appUserId = appUserId {
      cache.write(appUserId, forType: AppUserId.self)
    }

    if let aliasId = aliasId {
      cache.write(aliasId, forType: AliasId.self)
    }

    var standardUserAttributes: [String: Any] = [:]

    if let aliasId = aliasId {
      standardUserAttributes["aliasId"] = aliasId
    }

    if let appUserId = appUserId {
      standardUserAttributes["appUserId"] = appUserId
    }

    mergeUserAttributes(standardUserAttributes)
  }

  func clearCachedSessionEvents() {
    cache.delete(TriggerSessions.self)
    cache.delete(Transactions.self)
  }

  func getCachedTriggerSessions() -> TriggerSessions.Value {
    return cache.read(TriggerSessions.self) ?? []
  }

  func saveTriggerSessions(_ sessions: [TriggerSession]) {
    cache.write(
      sessions,
      forType: TriggerSessions.self
    )
  }

  func getCachedTransactions() -> Transactions.Value {
    return cache.read(Transactions.self) ?? []
  }

  func saveTransactions(_ transactions: [TransactionModel]) {
    cache.write(
      transactions,
      forType: Transactions.self
    )
  }

  func saveLastPaywallView() {
    cache.write(
      Date(),
      forType: LastPaywallView.self
    )
  }

  func getLastPaywallView() -> LastPaywallView.Value? {
    return cache.read(LastPaywallView.self)
  }

  func incrementTotalPaywallViews() {
    cache.write(
      (getTotalPaywallViews() ?? 0) + 1,
      forType: TotalPaywallViews.self
    )
  }

  func getTotalPaywallViews() -> TotalPaywallViews.Value? {
    return cache.read(TotalPaywallViews.self)
  }

  func saveConfirmedAssignments(_ assignments: [Experiment.ID: Experiment.Variant]) {
    cache.write(
      assignments,
      forType: ConfirmedAssignments.self
    )
    confirmedAssignments = assignments
  }

  func getConfirmedAssignments() -> [Experiment.ID: Experiment.Variant] {
    if let confirmedAssignments = confirmedAssignments {
      return confirmedAssignments
    } else {
      let assignments = cache.read(ConfirmedAssignments.self) ?? [:]
      confirmedAssignments = assignments
      return assignments
    }
  }
}
