//
//  CacheManager.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation

final class CacheManager {
  static let shared = CacheManager()

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
	var userAttributes = [String: Any]()

  var userId: String? {
    return appUserId ?? aliasId
  }
	var triggers: Set<String> = Set<String>()
  // swiftlint:disable:next array_constructor
  var v2Triggers: [String: TriggerV2] = [:]
  private let cache = Cache(name: "Store")

  init() {
    self.appUserId = cache.readString(forKey: .appUserId)
    self.aliasId = cache.readString(forKey: .aliasId)
    self.didTrackFirstSeen = cache.hasData(forKey: .didTrackFirstSeen)
    self.userAttributes = (cache.readDictionary(forKey: .userAttributes) as? [String: Any]) ?? [String: Any]()
    self.setCachedTriggers()
  }

  func configure(
    appUserId: String?,
    apiKey: String
  ) {
    self.appUserId = appUserId
    self.apiKey = apiKey

    if aliasId == nil {
      aliasId = CacheManagerLogic.generateAlias()
    }
  }

  /// Call this when you log out
  func clear() {
    appUserId = nil
    aliasId = CacheManagerLogic.generateAlias()
    didTrackFirstSeen = false
    userAttributes = [:]
    triggers.removeAll()
    v2Triggers.removeAll()
    cache.cleanAll()
    recordFirstSeenTracked()
  }

  func save() {
    if let appUserId = appUserId {
      cache.write(appUserId, forKey: .appUserId)
    }

    if let aliasId = aliasId {
      cache.write(aliasId, forKey: .aliasId)
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

	func addConfig(_ config: ConfigResponse) {
    let v1TriggerDictionary = CacheManagerLogic.getV1TriggerDictionary(from: config.triggers)
    cache.write(v1TriggerDictionary, forKey: .config)
    triggers = Set(v1TriggerDictionary.keys)

    v2Triggers = CacheManagerLogic.getV2TriggerDictionary(from: config.triggers)
	}

	func addUserAttributes(_ newAttributes: [String: Any]) {
    let mergedAttributes = CacheManagerLogic.mergeAttributes(
      newAttributes,
      with: userAttributes
    )
    cache.write(mergedAttributes, forKey: .userAttributes)
    userAttributes = mergedAttributes
	}

	func recordFirstSeenTracked() {
    if didTrackFirstSeen {
      return
    }

    Paywall.track(.firstSeen)
    cache.write("true", forKey: .didTrackFirstSeen)
		didTrackFirstSeen = true
	}

	private func setCachedTriggers() {
    let cachedTriggers = cache.readDictionary(forKey: .config) as? [String: Bool]
		let triggerDict = cachedTriggers ?? [:]

    triggers = []
		for key in triggerDict.keys {
			triggers.insert(key)
		}
	}
}
