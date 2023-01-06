//
//  CacheKey.swift
//  Superwall
//
//  Created by Yusuf Tör on 08/03/2022.
//

import Foundation

enum SearchPathDirectory {
  /// Saves to the caches directory, which can be cleared by
  /// the system at any time.
  case cache

  /// Specific to the user.
  case userSpecificDocuments

  /// Specific to the app as a whole.
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
    "store.transactions.v2"
  }
  static var directory: SearchPathDirectory = .cache
  typealias Value = [StoreTransaction]
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

enum SdkVersion: Storable {
  static var key: String {
    "store.sdkVersion"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = String
}

enum SubscriptionStatus: Storable {
  static var key: String {
    "store.subscriptionStatus"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Bool
}
