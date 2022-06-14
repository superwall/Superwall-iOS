//
//  CacheKey.swift
//  Paywall
//
//  Created by Yusuf Tör on 08/03/2022.
//

import Foundation

enum SearchPathDirectory {
  case cache
  case documents
}
protocol Storable {
  static var key: String { get }
  static var directory: SearchPathDirectory { get }
  associatedtype Value
}

enum AppUserId: Storable {
  static var key: String {
    "store.appUserId"
  }
  static var directory: SearchPathDirectory = .documents
  typealias Value = String
}

enum AliasId: Storable {
  static var key: String {
    "store.aliasId"
  }
  static var directory: SearchPathDirectory = .documents
  typealias Value = String
}

enum DidTrackAppInstall: Storable {
  static var key: String {
    "store.didTrackAppInstall"
  }
  static var directory: SearchPathDirectory = .documents
  typealias Value = Bool
}

enum DidTrackFirstSeen: Storable {
  static var key: String {
    "store.didTrackFirstSeen"
  }
  static var directory: SearchPathDirectory = .documents
  // This really should be a Bool, but for some reason it's a String.
  typealias Value = String
}

enum UserAttributes: Storable {
  static var key: String {
    "store.userAttributes"
  }
  static var directory: SearchPathDirectory = .documents
  typealias Value = [String: Any]
}

enum TriggerSessions: Storable {
  static var key: String {
    "store.triggerSessions"
  }
  static var directory: SearchPathDirectory = .cache
  typealias Value = [TriggerSession]
}

enum Transactions: Storable {
  static var key: String {
    "store.transactions"
  }
  static var directory: SearchPathDirectory = .cache
  typealias Value = [TransactionModel]
}

enum TriggeredEvents: Storable {
  static var key: String {
    "store.triggeredEvents"
  }
  static var directory: SearchPathDirectory = .documents
  typealias Value = [String: [EventData]]
}
