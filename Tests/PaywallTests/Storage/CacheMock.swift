//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/06/2022.
//
// swiftlint:disable all

import Foundation
@testable import Paywall

final class CacheMock: Cache {
  var internalCache: [String: Data] = [:]
  var internalDocuments: [String: Data] = [:]

  init(
    cacheInternalValue: [String: Data] = [:],
    documentsInternalValue: [String: Data] = [:]
  ) {
    self.internalCache = cacheInternalValue
    self.internalDocuments = documentsInternalValue
  }

  override func read<Key>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) -> Key.Value? where Key: Storable, Key.Value: Decodable {
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .documents:
      internalValue = internalDocuments
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
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .documents:
      internalValue = internalDocuments
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
    guard let data = try? JSONEncoder().encode(value) else {
      return
    }
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .documents:
      internalValue = internalDocuments
    }

    internalValue[keyType.key] = data

    switch directory {
    case .cache:
      internalCache = internalValue
    case .documents:
      internalDocuments = internalValue
    }
  }

  override func write<Key>(
    _ value: Key.Value,
    forType keyType: Key.Type,
    inDirectory directory: SearchPathDirectory? = nil
  ) where Key : Storable {
    guard let value = value as? NSCoding else {
      return
    }
    let data = NSKeyedArchiver.archivedData(withRootObject: value)

    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .documents:
      internalValue = internalDocuments
    }

    internalValue[keyType.key] = data

    switch directory {
    case .cache:
      internalCache = internalValue
    case .documents:
      internalDocuments = internalValue
    }
  }


  override func delete<Key>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) where Key : Storable {
    var internalValue: [String: Data]
    let directory = directory ?? keyType.directory
    switch directory {
    case .cache:
      internalValue = internalCache
    case .documents:
      internalValue = internalDocuments
    }

    internalValue[keyType.key] = nil

    switch directory {
    case .cache:
      internalCache = internalValue
    case .documents:
      internalDocuments = internalValue
    }
  }
}
