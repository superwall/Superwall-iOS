//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/09/2024.
//

import Foundation
import SuperCEL

final class EvaluationContext: HostContext {
  let storage: Storage

  init(storage: Storage) {
    self.storage = storage
  }

  func computedProperty(name: String, args: String) async -> String {
    guard
      let type = ComputedPropertyRequestType.allCases.first(where: { $0.description == name })
    else {
      return ""
    }
    let argsJson = JSON(args)
    let value = argsJson["value"]

    guard let name = value["name"].string else {
      return ""
    }
    let createdAt = value["createdAt"].string?.rfc3339date() ?? Date()

    let request = ComputedPropertyRequest(
      type: type,
      placementName: name
    )

    guard let number = await storage.coreDataManager.getComputedPropertySincePlacement(
      PlacementData(
        name: name,
        parameters: [:],
        createdAt: createdAt
      ),
      request: request
    ) else {
      return ""
    }

    return "\(number)"
  }
}

extension Dictionary where Key == String, Value == Any {
  func toPassableValue() -> PassableValue {
    let passableMap = self.mapValues { SuperwallKit.toPassableValue(from: $0) }
    return PassableValue.map(passableMap)
  }
}

func toPassableValue(from anyValue: Any) -> PassableValue {
  switch anyValue {
  case let value as Int:
    return .int(value)
  case let value as UInt64:
    return .uint(value)
  case let value as Double:
    return .float(value)
  case let value as String:
    return .string(value)
  case let value as Data:
    return .bytes(value)
  case let value as Bool:
    return .bool(value)
  case let value as [Any]:
    return .list(value.map { toPassableValue(from: $0) })
  case let value as [AnyHashable: Any]:
    let stringKeyMap = value.compactMap { key, value -> (String, Any)? in
      if let key = key as? String {
        return (key, value)
      }
      return nil
    }
    let passableMap = stringKeyMap.reduce(into: [:]) { result, pair in
      result[pair.0] = toPassableValue(from: pair.1)
    }

    return .map(passableMap)
  case let value as PassableValue:
    return value
  default:
    fatalError("Unsupported type: \(anyValue)")
  }
}
