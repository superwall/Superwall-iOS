//
//  File.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation



class Store {
    
    let cache = Cache(name: "Store")
    
    public static let shared = Store();
    
    
    public var apiKey: String?
    public var debugKey: String?
    public var appUserId: String?
    public var aliasId: String?
	public var didTrackFirstSeen = false
	public var userAttributes = [String: Any]()
    
    public var userId: String? {
        return appUserId ?? aliasId ?? nil
    }
	
	public var triggers: Set<String> = Set<String>()
    
    init() {
        self.appUserId = cache.readString(forKey: "store.appUserId")
        self.aliasId = cache.readString(forKey: "store.aliasId")
		self.didTrackFirstSeen = cache.hasData(forKey: "store.didTrackFirstSeen")
		self.userAttributes = (cache.readDictionary(forKey: "store.userAttributes") as? [String: Any]) ?? [String: Any]()
		self.setCachedTriggers()
    }
    
    // call this when you log out
    func clear() {
        appUserId = nil
        aliasId = nil
		didTrackFirstSeen = false
		userAttributes = [String: Any]()
		triggers.removeAll()
        cache.cleanAll()
    }
    
    func save() {
        
        if let appUserId = appUserId {
            cache.write(string: appUserId, forKey: "store.appUserId")
        }
        
        if let aliasId = aliasId {
            cache.write(string: aliasId, forKey: "store.aliasId")
        }
		
		var standardUserAttributes = [String: Any]()
		
		if let a = aliasId {
			standardUserAttributes["aliasId"] = a
		}
		
		if let a = appUserId {
			standardUserAttributes["appUserId"] = a
		}
		
		add(userAttributes: standardUserAttributes)
		
    }
    
	func add(config: ConfigResponse) {
		var data = [String: Bool]()
		config.triggers.forEach { data[$0.eventName] = true }
		cache.write(dictionary: data, forKey: "store.config")
		triggers = Set(data.keys)
	}
	
	func add(userAttributes newAttributes: [String: Any]) {

		var merged = self.userAttributes
		
		for key in newAttributes.keys {
			if key != "$is_standard_event" && key != "$application_installed_at" { // ignore these
				var k = key
				
				if key.starts(with: "$") { // replace dollar signs
					k = key.replacingOccurrences(of: "$", with: "")
				}
				
				if let val = newAttributes[key] {
					merged[k] = val
				} else {
					merged[k] = nil
				}
			}
		}
		
		merged["applicationInstalledAt"] = DeviceHelper.shared.appInstallDate // we want camel case
		
		cache.write(dictionary: merged, forKey: "store.userAttributes")
		self.userAttributes = merged
	}
	
	
	
	func recordFirstSeenTracked() {
		cache.write(string: "true", forKey: "store.didTrackFirstSeen")
		didTrackFirstSeen = true
	}
	
	private func setCachedTriggers() {
		let triggerDict: [String: Bool] = (cache.readDictionary(forKey: "store.config") as? [String: Bool]) ?? [:]
		triggers = Set<String>()
		for k in Array(triggerDict.keys) {
			triggers.insert(k)
		}
	}
    
}


