//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation

struct TriggerRuleOccurrence: Decodable, Hashable {
  struct RawInterval: Decodable {
    enum IntervalType: String, Decodable {
      case minutes = "MINUTES"
      case infinity = "INFINITY"

      init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = IntervalType(rawValue: rawValue) ?? .infinity
      }
    }
    let type: IntervalType
    let minutes: Int?
  }

  enum Interval: Decodable, Hashable {
    case infinity
    case minutes(Int)
  }
  let key: String
  var maxCount: Int
  let interval: Interval

  enum CodingKeys: String, CodingKey {
    case key
    case maxCount
    case interval
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    key = try values.decode(String.self, forKey: .key)
    maxCount = try values.decode(Int.self, forKey: .maxCount)

    let interval = try values.decode(RawInterval.self, forKey: .interval)
    if interval.type == .minutes,
      let minutes = interval.minutes {
      self.interval = .minutes(minutes)
    } else {
      self.interval = .infinity
    }
  }

  init(
    key: String,
    maxCount: Int,
    interval: Interval
  ) {
    self.key = key
    self.maxCount = maxCount
    self.interval = interval
  }
}

extension TriggerRuleOccurrence: Stubbable {
  static func stub() -> TriggerRuleOccurrence {
    return TriggerRuleOccurrence(
      key: "abc",
      maxCount: 10,
      interval: .infinity
    )
  }
}
