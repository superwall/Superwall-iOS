//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/07/2023.
//

import Foundation

/// A request to compute a device property associated with an event at runtime.
@objc(SWKComputedPropertyRequest)
@objcMembers
public final class ComputedPropertyRequest: NSObject, Decodable {
  /// The type of device property to compute.
  @objc(SWKComputedPropertyRequestType)
  public enum ComputedPropertyRequestType: Int, Decodable {
    /// The number of minutes since the event occurred.
    case minutesSince

    /// The number of hours since the event occurred.
    case hoursSince

    /// The number of days since the event occurred.
    case daysSince

    /// The number of months since the event occurred.
    case monthsSince

    /// The number of years since the event occurred.
    case yearsSince

    var prefix: String {
      switch self {
      case .minutesSince:
        return "minutesSince_"
      case .hoursSince:
        return "hoursSince_"
      case .daysSince:
        return "daysSince_"
      case .monthsSince:
        return "monthsSince_"
      case .yearsSince:
        return "yearsSince_"
      }
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
      }
    }

    enum CodingKeys: String, CodingKey {
      case minutesSince = "MINUTES_SINCE"
      case hoursSince = "HOURS_SINCE"
      case daysSince = "DAYS_SINCE"
      case monthsSince = "MONTHS_SINCE"
      case yearsSince = "YEARS_SINCE"
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let rawValue = try container.decode(String.self)
      let gatingType = CodingKeys(rawValue: rawValue)
      switch gatingType {
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
  }

  /// The type of device property to compute.
  public let type: ComputedPropertyRequestType

  /// The name of the event used to compute the device property.
  public let eventName: String
}
