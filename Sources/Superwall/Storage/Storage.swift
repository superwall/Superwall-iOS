//
//  CacheManager.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation

class Storage {
  /// The shared `Storage` instance.
  static let shared = Storage()

  /// The interface that manages core data.
  let coreDataManager: CoreDataManager

  /// The API key set on configure.
  var apiKey = ""

  /// Indicates whether first seen has been tracked.
	var didTrackFirstSeen = false

  /// Indicates whether static config hasn't been called before.
  ///
  /// Users upgrading from older SDK versions will not have called static config.
  /// This means that we'll need to wait for assignments before firing triggers.
  var neverCalledStaticConfig = false

  /// The confirmed assignments for the user loaded from the cache.
  private var confirmedAssignments: [Experiment.ID: Experiment.Variant]?

  /// The disk cache.
  private let cache: Cache

  // MARK: - Configuration
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
    let previousSdkVersion = cache.read(SdkVersion.self)

    if actualSdkVersion != previousSdkVersion {
      save(actualSdkVersion, forType: SdkVersion.self)
    }

    if previousSdkVersion == nil {
      neverCalledStaticConfig = true
    }
  }

  /// Clears data that is user specific.
  func clear() {
    coreDataManager.deleteAllEntities()
    cache.cleanUserFiles()
    confirmedAssignments = nil
    didTrackFirstSeen = false
    recordFirstSeenTracked()
  }

  // MARK: - Custom
  /// Tracks and stores first seen for the user.
	func recordFirstSeenTracked() {
    if didTrackFirstSeen {
      return
    }

    Superwall.track(InternalSuperwallEvent.FirstSeen())
    save(true, forType: DidTrackFirstSeen.self)
		didTrackFirstSeen = true
	}

  /// Records the app install
  func recordAppInstall(
    trackEvent: (Trackable) -> TrackingResult = Superwall.track
  ) {
    let didTrackAppInstall = get(DidTrackAppInstall.self) ?? false
    if didTrackAppInstall {
      return
    }

    _ = trackEvent(InternalSuperwallEvent.AppInstall())
    save(true, forType: DidTrackAppInstall.self)
  }

  func clearCachedSessionEvents() {
    cache.delete(TriggerSessions.self)
    cache.delete(Transactions.self)
  }

  func trackPaywallOpen() {
    let totalPaywallViews = get(TotalPaywallViews.self) ?? 0
    save(totalPaywallViews + 1, forType: TotalPaywallViews.self)
    save(Date(), forType: LastPaywallView.self)
  }


  func saveConfirmedAssignments(_ assignments: [Experiment.ID: Experiment.Variant]) {
    save(assignments, forType: ConfirmedAssignments.self)
    confirmedAssignments = assignments
  }

  func getConfirmedAssignments() -> [Experiment.ID: Experiment.Variant] {
    if let confirmedAssignments = confirmedAssignments {
      return confirmedAssignments
    } else {
      let assignments = get(ConfirmedAssignments.self) ?? [:]
      confirmedAssignments = assignments
      return assignments
    }
  }

// MARK: - Cache Reading & Writing
  func get<Key: Storable>(_ keyType: Key.Type) -> Key.Value? {
    return cache.read(keyType)
  }

  func get<Key: Storable>(_ keyType: Key.Type) -> Key.Value? where Key.Value: Decodable {
    return cache.read(keyType)
  }

  func save<Key: Storable>(_ value: Key.Value, forType keyType: Key.Type) {
    return cache.write(value, forType: keyType)
  }

  func save<Key: Storable>(_ value: Key.Value, forType keyType: Key.Type) where Key.Value: Encodable {
    return cache.write(value, forType: keyType)
  }
}
