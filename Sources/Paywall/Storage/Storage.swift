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
  var locales: Set<String> = []
  var configRequestId = ""

  var userId: String? {
    return appUserId ?? aliasId
  }
  /// Used to store the config request if it occurred in the background.
  var configRequest: ConfigRequest?
  // swiftlint:disable:next array_constructor
  var triggers: [String: Trigger] = [:]
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

  func migrateData() {
    let version = cache.read(Version.self) ?? .v1
    FileManagerMigrator.migrate(
      fromVersion: version,
      cache: cache
    )
  }

  func configure(
    appUserId: String?,
    apiKey: String
  ) {
    migrateData()
    self.appUserId = appUserId
    self.apiKey = apiKey

    if aliasId == nil {
      aliasId = StorageLogic.generateAlias()
    }
  }

  /// Call this when you log out
  func clear() {
    coreDataManager.deleteAllEntities()
    cache.cleanUserFiles()
    appUserId = nil
    aliasId = StorageLogic.generateAlias()
    userAttributes = [:]
    triggers.removeAll()
    didTrackFirstSeen = false
    recordFirstSeenTracked()
  }

	func addConfig(
    _ config: Config,
    withRequestId requestId: String
  ) {
    locales = Set(config.localization.locales.map { $0.locale })
    configRequestId = requestId
    AppSessionManager.shared.appSessionTimeout = config.appSessionTimeout
    triggers = StorageLogic.getTriggerDictionary(from: config.triggers)
	}

	func addUserAttributes(_ newAttributes: [String: Any]) {
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

    addUserAttributes(standardUserAttributes)
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
}
