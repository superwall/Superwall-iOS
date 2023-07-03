//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/07/2023.
//

import Foundation

struct ComputedProperty: Decodable {
  enum ComputedPropertyType: Decodable {
    case daysSince

    var prefix: String {
      switch self {
      case .daysSince:
        return "daysSince_"
      }
    }

    var calendarComponent: Calendar.Component {
      switch self {
      case .daysSince:
        return .day
      }
    }

    func dateComponent(from components: DateComponents) -> Int? {
      switch self {
      case .daysSince:
        return components.day
      }
    }

    enum CodingKeys: String, CodingKey {
      case daysSince = "DAYS_SINCE"
    }
  }
  let type: ComputedPropertyType
  let eventName: String
}
