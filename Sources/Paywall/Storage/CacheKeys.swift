//
//  CacheKey.swift
//  Paywall
//
//  Created by Yusuf Tör on 08/03/2022.
//

import Foundation

protocol CachingType {
  static var key: String { get }
  associatedtype Value
}

enum AppUserId: CachingType {
  static var key: String {
    "store.appUserId"
  }
  typealias Value = String
}

enum AliasId: CachingType {
  static var key: String {
    "store.aliasId"
  }
  typealias Value = String
}

enum DidTrackFirstSeen: CachingType {
  static var key: String {
    "store.didTrackFirstSeen"
  }
  // This really should be a Bool, but for some reason it's a String.
  typealias Value = String
}

enum UserAttributes: CachingType {
  static var key: String {
    "store.userAttributes"
  }
  typealias Value = [String: Any]
}

enum Config: CachingType {
  static var key: String {
    "store.config"
  }
  typealias Value = [String: Bool]
}
