//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/09/2024.
//
// swiftlint:disable function_body_length

import Foundation
internal import Superscript

final class EvaluationContext: HostContext {
  let storage: Storage

  init(storage: Storage) {
    self.storage = storage
  }

  func computedProperty(name: String, args: String, callback: ResultCallback) {
    callback.onResult(result: value(ofProperty: name, args: args))
  }

  func deviceProperty(name: String, args: String, callback: ResultCallback) {
    callback.onResult(result: value(ofProperty: name, args: args))
  }

  /// The property's value as JSON, or an empty string if it has none.
  ///
  /// The evaluator holds the thread it was called on until it has the answer, so
  /// this answers on that thread and never from a `Task`. Evaluations run on Swift
  /// concurrency's threads, and there are only as many of those as the device has
  /// cores. With each one held by an evaluation, a task would have none left to
  /// run on, and every evaluation would wait forever along with all the app's
  /// other async work.
  func value(ofProperty name: String, args: String) -> String {
    guard
      let type = ComputedPropertyRequestType.allCases.first(where: { $0.description == name }),
      let argsData = args.data(using: .utf8),
      let passableValues = try? JSONDecoder().decode([PassableValue].self, from: argsData),
      case let .string(placementName)? = passableValues.first
    else {
      return ""
    }

    let number: Int?
    if let window = Self.placementCountWindow(for: type) {
      // We don't add one here because the placement data is saved before
      // we do the count.
      number = storage.coreDataManager.countPlacementAndWait(
        placementName,
        since: window.startDate
      )
    } else {
      number = storage.coreDataManager.getComputedPropertySincePlacementAndWait(
        PlacementData(
          name: placementName,
          parameters: [:],
          createdAt: Date()
        ),
        request: ComputedPropertyRequest(
          type: type,
          placementName: placementName
        )
      )
    }

    guard
      let number = number,
      let jsonData = try? JSONEncoder().encode(toPassableValue(from: number)),
      let jsonString = String(data: jsonData, encoding: .utf8)
    else {
      return ""
    }
    return jsonString
  }

  /// How far back a placement count goes.
  enum PlacementCountWindow: Equatable {
    /// Counts the placements from this date onwards.
    case since(Date)

    /// Counts every placement.
    case allTime

    var startDate: Date? {
      switch self {
      case .since(let date):
        return date
      case .allTime:
        return nil
      }
    }
  }

  /// The window a placement count covers, ending at `now`, or `nil` if `type`
  /// isn't a placement count.
  ///
  /// A month is one calendar month back from `now`, so it's 28 to 31 days long.
  /// It's counted on the Gregorian calendar whichever calendar the device uses,
  /// so that a month is the same length for everyone.
  static func placementCountWindow(
    for type: ComputedPropertyRequestType,
    now: Date = Date(),
    calendar: Calendar = Calendar(identifier: .gregorian)
  ) -> PlacementCountWindow? {
    let hour: TimeInterval = 60 * 60
    let day = 24 * hour

    switch type {
    case .placementsInHour:
      return .since(now.addingTimeInterval(-hour))
    case .placementsInDay:
      return .since(now.addingTimeInterval(-day))
    case .placementsInWeek:
      return .since(now.addingTimeInterval(-7 * day))
    case .placementsInMonth:
      let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)
      return .since(monthAgo ?? now.addingTimeInterval(-30 * day))
    case .placementsSinceInstall:
      return .allTime
    case .minutesSince,
      .hoursSince,
      .daysSince,
      .monthsSince,
      .yearsSince:
      return nil
    }
  }
}

extension Dictionary where Key == String, Value == Any {
  func toPassableValue() -> PassableValue {
    let passableMap = self.mapValues { SuperwallKit.toPassableValue(from: $0) }
    return PassableValue.map(passableMap)
  }
}

func toPassableValue(from anyValue: Any) -> PassableValue {
  if let number = anyValue as? NSNumber {
    // Check if it is a boolean
    if CFGetTypeID(number) == CFBooleanGetTypeID() {
      return .bool(number.boolValue)
    }
    // If not a boolean, let the switch handle the rest
  }

  switch anyValue {
  case is NSNull:
    // A field the SDK explicitly reported as unknown. Without this it would fall
    // through to the `default` case and come out as an empty map, which can't be
    // compared to anything.
    return .null
  case let value as Int:
    return .int(value)
  case let value as UInt64:
    return .uint(value)
  case let value as Double:
    return .float(value)
  case let value as String:
    return .string(value)
  case let value as Bool:
    return .bool(value)
  case let value as Data:
    return .bytes(value)
  case let value as [Any]:
    return .list(value.map { toPassableValue(from: $0) })
  case let value as JSON:
    if let int = value.int {
      return .int(int)
    } else if let uint = value.uInt64 {
      return .uint(uint)
    } else if let float = value.double {
      return .float(float)
    } else if let bool = value.bool {
      return .bool(bool)
    } else if let string = value.string {
      return .string(string)
    } else if let array = value.array {
      return .list(array.map { toPassableValue(from: $0) })
    } else if let object = value.dictionaryObject {
      let passableMap = object.reduce(into: [:]) { result, pair in
        result[pair.0] = toPassableValue(from: pair.1)
      }
      return .map(passableMap)
    }
    let passableMap = value.reduce(into: [:]) { result, pair in
      result[pair.0] = toPassableValue(from: pair.1)
    }
    return .map(passableMap)
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
    return toPassableValue(from: JSON(anyValue))
  }
}
