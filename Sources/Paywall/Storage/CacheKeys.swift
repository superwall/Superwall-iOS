//
//  CacheKey.swift
//  Paywall
//
//  Created by Yusuf Tör on 08/03/2022.
//

import Foundation

enum SearchPathDirectory {
  case cache
  case userSpecificDocuments
  case appSpecificDocuments
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
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = String
}

enum AliasId: Storable {
  static var key: String {
    "store.aliasId"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = String
}

enum DidTrackAppInstall: Storable {
  static var key: String {
    "store.didTrackAppInstall"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Bool
}

enum DidTrackFirstSeen: Storable {
  static var key: String {
    "store.didTrackFirstSeen.v2"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = Bool
}

enum UserAttributes: Storable {
  static var key: String {
    "store.userAttributes"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
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

enum Version: Storable {
  static var key: String {
    "store.version"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = DataStoreVersion
}

enum LastPaywallView: Storable {
  static var key: String {
    "store.lastPaywallView"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = Date
}

enum TotalPaywallViews: Storable {
  static var key: String {
    "store.totalPaywallViews"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = Int
}

enum ConfirmedAssignments: Storable {
  static var key: String {
    "store.confirmedAssignments"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = [Experiment.ID: Experiment.Variant]
}
