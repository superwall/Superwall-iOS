//
//  Store.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation

final class Store {
  static let shared = Store()

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
    self.appUserId = cache.readString(forKey: "store.appUserId")
    self.aliasId = cache.readString(forKey: "store.aliasId")
    self.didTrackFirstSeen = cache.hasData(forKey: "store.didTrackFirstSeen")
    self.userAttributes = (cache.readDictionary(forKey: "store.userAttributes") as? [String: Any]) ?? [String: Any]()
    self.setCachedTriggers()
  }

  func configure(
    appUserId: String?,
    apiKey: String
  ) {
    self.appUserId = appUserId
    self.apiKey = apiKey

    if aliasId == nil {
      aliasId = StoreLogic.generateAlias()
    }
  }

  /// Call this when you log out
  func clear() {
    appUserId = nil
    aliasId = StoreLogic.generateAlias()
    didTrackFirstSeen = false
    userAttributes = [:]
    triggers.removeAll()
    v2Triggers.removeAll()
    cache.cleanAll()
    recordFirstSeenTracked()
  }

  func save() {
    if let appUserId = appUserId {
      cache.write(appUserId, forKey: "store.appUserId")
    }

    if let aliasId = aliasId {
      cache.write(aliasId, forKey: "store.aliasId")
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
    let v1TriggerDictionary = StoreLogic.getV1TriggerDictionary(from: config.triggers)
    cache.write(v1TriggerDictionary, forKey: "store.config")
    triggers = Set(v1TriggerDictionary.keys)

    v2Triggers = StoreLogic.getV2TriggerDictionary(from: config.triggers)
	}

	func addUserAttributes(_ newAttributes: [String: Any]) {
    let mergedAttributes = StoreLogic.mergeAttributes(
      newAttributes,
      with: userAttributes
    )
		cache.write(mergedAttributes, forKey: "store.userAttributes")
    userAttributes = mergedAttributes
	}

	func recordFirstSeenTracked() {
    if didTrackFirstSeen {
      return
    }

    Paywall.track(.firstSeen)
		cache.write("true", forKey: "store.didTrackFirstSeen")
		didTrackFirstSeen = true
	}

	private func setCachedTriggers() {
    let cachedTriggers = cache.readDictionary(forKey: "store.config") as? [String: Bool]
		let triggerDict = cachedTriggers ?? [:]

    triggers = []
		for key in triggerDict.keys {
			triggers.insert(key)
		}
	}
}
