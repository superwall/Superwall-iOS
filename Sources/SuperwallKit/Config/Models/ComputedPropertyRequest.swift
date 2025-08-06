//
//  File.swift
//
//
//  Created by Yusuf Tör on 03/07/2023.
//

import Foundation

/// A request to compute a device property associated with a placement at runtime.
@objc(SWKComputedPropertyRequest)
@objcMembers
public final class ComputedPropertyRequest: NSObject, Codable {
  /// The type of device property to compute.
  public let type: ComputedPropertyRequestType

  /// The name of the event used to compute the device property.
  public let placementName: String

  enum CodingKeys: String, CodingKey {
    case type
    case placementName = "eventName"
  }

  init(type: ComputedPropertyRequestType, placementName: String) {
    self.type = type
    self.placementName = placementName
    super.init()
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encode(placementName, forKey: .placementName)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decode(ComputedPropertyRequestType.self, forKey: .type)
    placementName = try container.decode(String.self, forKey: .placementName)
    super.init()
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(type)
    hasher.combine(placementName)
    return hasher.finalize()
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? ComputedPropertyRequest else {
      return false
    }
    return type == other.type
    && placementName == other.placementName
  }
}

/// The type of device property to compute.
@objc(SWKComputedPropertyRequestType)
public enum ComputedPropertyRequestType: Int, Codable, CustomStringConvertible, CaseIterable, Equatable {
  /// The number of minutes since the placement occurred.
  case minutesSince

  /// The number of hours since the placement occurred.
  case hoursSince

  /// The number of days since the placement occurred.
  case daysSince

  /// The number of months since the placement occurred.
  case monthsSince

  /// The number of years since the placement occurred.
  case yearsSince

  /// The number of placements within the last hour.
  case placementsInHour

  /// The number of placements within the last day.
  case placementsInDay

  /// The number of placements within the last week.
  case placementsInWeek

  /// The number of placements within the last month.
  case placementsInMonth

  /// The number of placements since install.
  case placementsSinceInstall

  var prefix: String {
    return description + "_"
  }

  public var description: String {
    switch self {
    case .minutesSince:
      return "minutesSince"
    case .hoursSince:
      return "hoursSince"
    case .daysSince:
      return "daysSince"
    case .monthsSince:
      return "monthsSince"
    case .yearsSince:
      return "yearsSince"
    case .placementsInHour:
      return "placementsInHour"
    case .placementsInDay:
      return "placementsInDay"
    case .placementsInWeek:
      return "placementsInWeek"
    case .placementsInMonth:
      return "placementsInMonth"
    case .placementsSinceInstall:
      return "placementsSinceInstall"
    }
  }

  /// Indicates whether we should be counting placements
  var isPlacementCount: Bool {
    return [
      .placementsInHour,
      .placementsInDay,
      .placementsInWeek,
      .placementsInMonth,
      .placementsSinceInstall
    ].contains(self)
  }

  var calendarComponent: Calendar.Component {
    switch self {
    case .minutesSince:
      return .minute
    case .hoursSince:
      return .hour
    case .daysSince:
      return .day
    case .monthsSince:
      return .month
    case .yearsSince:
      return .year
    default:
      // This should never get called
      return .year
    }
  }

  func dateComponent(from components: DateComponents) -> Int? {
    switch self {
    case .minutesSince:
      return components.minute
    case .hoursSince:
      return components.hour
    case .daysSince:
      return components.day
    case .monthsSince:
      return components.month
    case .yearsSince:
      return components.year
    case .placementsInDay:
      return components.day
    default:
      // This should never get called
      return nil
    }
  }

  enum CodingKeys: String, CodingKey {
    case minutesSince = "MINUTES_SINCE"
    case hoursSince = "HOURS_SINCE"
    case daysSince = "DAYS_SINCE"
    case monthsSince = "MONTHS_SINCE"
    case yearsSince = "YEARS_SINCE"
    case placementsInDay = "PLACEMENTS_IN_DAY"
    case placementsInHour = "PLACEMENTS_IN_HOUR"
    case placementsInWeek = "PLACEMENTS_IN_WEEK"
    case placementsInMonth = "PLACEMENTS_IN_MONTH"
    case placementsSinceInstall = "PLACEMENTS_SINCE_INSTALL"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let type = CodingKeys(rawValue: rawValue)
    switch type {
    case .minutesSince:
      self = .minutesSince
    case .hoursSince:
      self = .hoursSince
    case .daysSince:
      self = .daysSince
    case .monthsSince:
      self = .monthsSince
    case .yearsSince:
      self = .yearsSince
    case .placementsInDay:
      self = .placementsInDay
    case .placementsInHour:
      self = .placementsInHour
    case .placementsInMonth:
      self = .placementsInMonth
    case .placementsInWeek:
      self = .placementsInWeek
    case .placementsSinceInstall:
      self = .placementsSinceInstall
    case .none:
      throw DecodingError.valueNotFound(
        String.self,
        .init(
          codingPath: [],
          debugDescription: "Unsupported computed property type."
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .minutesSince:
      try container.encode(CodingKeys.minutesSince.rawValue)
    case .hoursSince:
      try container.encode(CodingKeys.hoursSince.rawValue)
    case .daysSince:
      try container.encode(CodingKeys.daysSince.rawValue)
    case .monthsSince:
      try container.encode(CodingKeys.monthsSince.rawValue)
    case .yearsSince:
      try container.encode(CodingKeys.yearsSince.rawValue)
    case .placementsInDay:
      try container.encode(CodingKeys.placementsInDay.rawValue)
    case .placementsInHour:
      try container.encode(CodingKeys.placementsInHour.rawValue)
    case .placementsInMonth:
      try container.encode(CodingKeys.placementsInMonth.rawValue)
    case .placementsInWeek:
      try container.encode(CodingKeys.placementsInWeek.rawValue)
    case .placementsSinceInstall:
      try container.encode(CodingKeys.placementsSinceInstall.rawValue)
    }
  }
}
