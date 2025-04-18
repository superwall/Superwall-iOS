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

enum Seed: Storable {
  static var key: String {
    "store.seed"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = Int
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

enum DidCacheLegacyTransactions: Storable {
  static var key: String {
    "store.didCacheLegacyTransactions"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Bool
}

enum DidTrackFirstSession: Storable {
  static var key: String {
    "store.didTrackFirstSession"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Bool
}

enum DidCleanUserAttributes: Storable {
  static var key: String {
    "store.didCleanUserAttributes"
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

enum Transactions: Storable {
  static var key: String {
    "store.transactions.v2"
  }
  static var directory: SearchPathDirectory = .cache
  typealias Value = [StoreTransaction]
}

enum PurchasingProductIds: Storable {
  static var key: String {
    "store.purchasingProductIds"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Set<String>
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

enum Assignments: Storable {
  static var key: String {
    "store.confirmedAssignments.v2"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = Set<Assignment>
}

enum SdkVersion: Storable {
  static var key: String {
    "store.sdkVersion"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = String
}

enum EntitlementsByProductId: Storable {
  static var key: String {
    "store.entitlementsByProductId"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = [String: Set<Entitlement>]
}

enum SubscriptionStatusKey: Storable {
  static var key: String {
    "store.subscriptionStatus"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = SubscriptionStatus
}

enum SurveyAssignmentKey: Storable {
  static var key: String {
    "store.surveyAssignmentKey"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = String
}

enum DisableVerbosePlacements: Storable {
  static var key: String {
    "store.disableVerboseEvents"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Bool
}

enum LatestConfig: Storable {
  static var key: String {
    "store.config"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Config
}

enum LatestEnrichment: Storable {
  static var key: String {
    "store.enrichment"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Enrichment
}

enum AdServicesTokenStorage: Storable {
  static var key: String {
    "store.adServicesToken"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = String
}

enum SK2TransactionIds: Storable {
  static var key: String {
    "store.syncedSK2TransactionIds"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Set<UInt64>
}

enum LatestRedeemResponse: Storable {
  static var key: String {
    "store.latestRedeemResponse"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = RedeemResponse
}

enum LastWebEntitlementsFetchDate: Storable {
  static var key: String {
    "store.LastWebEntitlementsFetchDate"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Date
}
