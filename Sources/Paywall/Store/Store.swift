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
    
    public var userId: String? {
        return appUserId ?? aliasId ?? nil
    }
	
	public var triggers: Set<String> = Set<String>()
    
    init() {
        self.appUserId = cache.readString(forKey: "store.appUserId")
        self.aliasId = cache.readString(forKey: "store.aliasId")
		self.didTrackFirstSeen = cache.hasData(forKey: "store.didTrackFirstSeen")
		self.setCachedTriggers()
    }
    
    // call this when you log out
    func clear() {
        appUserId = nil
        aliasId = nil
		didTrackFirstSeen = false
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
	
		
    }
    
	func add(config: ConfigResponse) {
		var data = [String: Bool]()
		config.triggers.forEach { data[$0.eventName] = true }
		cache.write(dictionary: data, forKey: "store.config")
		triggers = Set(data.keys)
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


