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

  var userId: String? {
    return appUserId ?? aliasId
  }
  private(set) var triggersFiredPreConfig: [PreConfigTrigger] = []
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

    if let newAppUserId = appUserId {
      self.appUserId = newAppUserId
    }

    self.apiKey = apiKey

    if aliasId == nil {
      aliasId = StorageLogic.generateAlias()
    }

    updateSdkVersion()
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
    let actualSdkVersion = sdkVersion
    cache.write(actualSdkVersion, forType: SdkVersion.self)
  }

  func checkForStaticConfigUpgrade() {
    let storedSdkVersion = cache.read(SdkVersion.self)

    if storedSdkVersion == nil && DeviceHelper.shared.minutesSinceInstall > 60 {
      TriggerDelayManager.shared.enterAssignmentDispatchQueue()

      // After config, we get the assignments.
      // Only when the config and assignments are fetched do we fire triggers.
      TriggerDelayManager.shared.configDispatchGroup.notify(queue: .main) {
        ConfigManager.shared.getAssignments {
          TriggerDelayManager.shared.leaveAssignmentDispatchQueue()
        }
      }
    }
  }

  /// Call this when you log out
  func clear() {
    coreDataManager.deleteAllEntities()
    cache.cleanUserFiles()
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

  func cachePreConfigTrigger(_ trigger: PreConfigTrigger) {
    triggersFiredPreConfig.append(trigger)
  }

  func clearPreConfigTriggers() {
    triggersFiredPreConfig.removeAll()
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

  func saveConfirmedAssignments(_ assignments: [String: Experiment.Variant]) {
    cache.write(
      assignments,
      forType: ConfirmedAssignments.self
    )
  }

  func getConfirmedAssignments() -> [Experiment.ID: Experiment.Variant] {
    return cache.read(ConfirmedAssignments.self) ?? [:]
  }
}
