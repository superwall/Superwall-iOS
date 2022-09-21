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

	var didTrackFirstSeen = false

  var neverCalledStaticConfig = false
  var didCheckForStaticConfigUpdate = false


  private var confirmedAssignments: [Experiment.ID: Experiment.Variant]?
  private let cache: Cache

  init(
    cache: Cache = Cache(),
    coreDataManager: CoreDataManager = CoreDataManager()
  ) {
    self.cache = cache
    self.coreDataManager = coreDataManager
    self.didTrackFirstSeen = cache.read(DidTrackFirstSeen.self) == true
  }

  func configure(apiKey: String) {
    migrateData()
    updateSdkVersion()
    self.apiKey = apiKey
  }

/*
  func identify(with userId: String) {
    guard let outcome = StorageLogic.identify(
      newUserId: userId,
      oldUserId: appUserId
    ) else {
      loadAssignmentsIfNeeded()
      return
    }

    appUserId = userId

    switch outcome {
    case .reset:
      TriggerDelayManager.shared.appUserIdAfterReset = appUserId
      Paywall.reset()
    case .loadAssignments:
      if TriggerDelayManager.shared.appUserIdAfterReset == nil {
        loadAssignments()
      } else {
        loadAssignmentsAfterConfig(isBlocking: true)
        TriggerDelayManager.shared.appUserIdAfterReset = nil
      }
    }
  }*/

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
      neverCalledStaticConfig = true
    }

    didCheckForStaticConfigUpdate = true
  }

  /// Call this when you log out
  func clear() {
    coreDataManager.deleteAllEntities()
    cache.cleanUserFiles()
    confirmedAssignments = nil
    didTrackFirstSeen = false
    recordFirstSeenTracked()
  }

	func recordFirstSeenTracked() {
    if didTrackFirstSeen {
      return
    }

    Paywall.track(InternalSuperwallEvent.FirstSeen())
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

    _ = trackEvent(InternalSuperwallEvent.AppInstall())
    cache.write(true, forType: DidTrackAppInstall.self)
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

  func get<Key: Storable>(_ keyType: Key.Type) -> Key.Value? {
    return cache.read(keyType)
  }

  func save<Key: Storable>(_ value: Key.Value, forType keyType: Key.Type) {
    return cache.write(value, forType: keyType)
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
