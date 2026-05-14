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

enum IsTestModeActiveSubscription: Storable {
  static var key: String {
    "store.isTestModeActiveSubscription"
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

/// Apple Search Ads attribution is install-scoped — the campaign that drove
/// the install doesn't change when a user logs out and another user logs in
/// on the same device. So all the AdServices state lives in
/// `.appSpecificDocuments`, surviving `reset(duringIdentify:)`. The cached
/// attribution dict (``AdServicesAttributionDataStorage``) is re-applied to
/// the new user's attributes after a reset so they pick up the same
/// `apple_search_ads_*` / `acquisition_*` keys without re-fetching.
enum AdServicesTokenStorage: Storable {
  static var key: String {
    "store.adServicesToken"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = String
}

/// Retry bookkeeping for the Apple Search Ads token post.
///
/// The presence of an entry under ``AdServicesTokenStorage`` is treated as a
/// "successfully posted to backend" sentinel. While we're still trying, this
/// secondary record tracks how many attempts we've made and when, so we can
/// bound retries (Apple's attribution endpoint only yields useful data within
/// ~24h of install).
enum AdServicesAttributionAttemptsStorage: Storable {
  static var key: String {
    "store.adServicesAttributionAttempts"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = AdServicesAttributionAttempts
}

/// Set when `AAAttribution.attributionToken()` returns a permanent error
/// (e.g. `platformNotSupported` / `attributionUnsupported`). Without this,
/// such devices would re-attempt the SDK call on every launch indefinitely
/// — the attempt budget doesn't cover them because we intentionally don't
/// bump it for non-transient errors.
enum AdServicesAttributionUnsupportedStorage: Storable {
  static var key: String {
    "store.adServicesAttributionUnsupported"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Bool
}

/// The decoded attribution payload from the backend, cached so we can
/// re-apply it to a new user's attributes after `reset(duringIdentify:)`.
/// Install-scoped: the same campaign keys apply to whichever user is logged
/// in on this install.
enum AdServicesAttributionDataStorage: Storable {
  static var key: String {
    "store.adServicesAttributionData"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = [String: JSON]
}

/// Read-side shim for the pre-install-scoped location of the token sentinel.
/// Older SDK versions wrote ``AdServicesTokenStorage`` to user-specific
/// documents. On first launch after upgrade we migrate that value over to the
/// new app-specific location so existing users aren't re-attempted.
enum LegacyUserScopedAdServicesTokenStorage: Storable {
  static var key: String {
    // Same key string as AdServicesTokenStorage so we hit the same on-disk
    // filename, just in the legacy directory.
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
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = Date
}

enum PendingStripeCheckoutPollStorage: Storable {
  static var key: String {
    "store.PendingStripeCheckoutPollStorage"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = PendingStripeCheckoutPollState
}

enum LatestCustomerInfo: Storable {
  static var key: String {
    "store.CustomerInfo"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = CustomerInfo
}

enum IntegrationAttributes: Storable {
  static var key: String {
    "store.IntegrationAttributes"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = [String: String]
}

enum LatestDeviceCustomerInfo: Storable {
  static var key: String {
    "store.DeviceCustomerInfo"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = CustomerInfo
}

enum AppTransactionIdSent: Storable {
  static var key: String {
    "store.appTransactionIdSent"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = Bool
}

enum LastApiKey: Storable {
  static var key: String {
    "store.lastApiKey"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = String
}
