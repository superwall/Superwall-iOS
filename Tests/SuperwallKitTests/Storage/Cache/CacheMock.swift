//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/06/2022.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit

class CacheMock: Cache {
  /// Guards the dictionaries: the SDK reads storage on background queues.
  private let lock = NSRecursiveLock()
  var internalCache: [String: Data] = [:]
  var internalUserDocuments: [String: Data] = [:]
  var internalAppDocuments: [String: Data] = [:]

  init(
    cacheInternalValue: [String: Data] = [:],
    userDocumentsInternalValue: [String: Data] = [:],
    appDocumentsInternalValue: [String: Data] = [:]
  ) {
    self.internalCache = cacheInternalValue
    self.internalUserDocuments = userDocumentsInternalValue
    self.internalAppDocuments = appDocumentsInternalValue
  }

  override func read<Key>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) -> Key.Value? where Key: Storable, Key.Value: Decodable {
    lock.lock()
    defer { lock.unlock() }
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .userSpecificDocuments:
      internalValue = internalUserDocuments
    case .appSpecificDocuments:
      internalValue = internalAppDocuments
    }

    guard let data = internalValue[keyType.key] else {
      return nil
    }
    guard let value = try? JSONDecoder().decode(Key.Value.self, from: data) else {
      return nil
    }
    return value
  }

  override func read<Key>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) -> Key.Value? where Key : Storable {
    lock.lock()
    defer { lock.unlock() }
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .userSpecificDocuments:
      internalValue = internalUserDocuments
    case .appSpecificDocuments:
      internalValue = internalAppDocuments
    }

    guard let data = internalValue[keyType.key] else {
      return nil
    }
    guard let value = NSKeyedUnarchiver.unarchiveObject(with: data) as? Key.Value else {
      return nil
    }
    return value
  }

  override func write<Key: Storable>(
    _ value: Key.Value,
    forType keyType: Key.Type,
    inDirectory directory: SearchPathDirectory? = nil
  ) where Key.Value: Encodable {
    lock.lock()
    defer { lock.unlock() }
    guard let data = try? JSONEncoder().encode(value) else {
      return
    }
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .userSpecificDocuments:
      internalValue = internalUserDocuments
    case .appSpecificDocuments:
      internalValue = internalAppDocuments
    }

    internalValue[keyType.key] = data

    switch directory {
    case .cache:
      internalCache = internalValue
    case .userSpecificDocuments:
      internalUserDocuments = internalValue
    case .appSpecificDocuments:
      internalAppDocuments = internalValue
    }
  }

  override func write<Key>(
    _ value: Key.Value,
    forType keyType: Key.Type,
    inDirectory directory: SearchPathDirectory? = nil
  ) where Key : Storable {
    lock.lock()
    defer { lock.unlock() }
    guard let value = value as? NSCoding else {
      return
    }
    let data = NSKeyedArchiver.archivedData(withRootObject: value)

    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .userSpecificDocuments:
      internalValue = internalUserDocuments
    case .appSpecificDocuments:
      internalValue = internalAppDocuments
    }

    internalValue[keyType.key] = data

    switch directory {
    case .cache:
      internalCache = internalValue
    case .userSpecificDocuments:
      internalUserDocuments = internalValue
    case .appSpecificDocuments:
      internalAppDocuments = internalValue
    }
  }


  override func delete<Key>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) where Key : Storable {
    lock.lock()
    defer { lock.unlock() }
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .userSpecificDocuments:
      internalValue = internalUserDocuments
    case .appSpecificDocuments:
      internalValue = internalAppDocuments
    }

    internalValue[keyType.key] = nil

    switch directory {
    case .cache:
      internalCache = internalValue
    case .userSpecificDocuments:
      internalUserDocuments = internalValue
    case .appSpecificDocuments:
      internalAppDocuments = internalValue
    }
  }
}
