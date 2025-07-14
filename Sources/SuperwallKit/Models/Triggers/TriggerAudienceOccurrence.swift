//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation

struct TriggerAudienceOccurrence: Codable, Hashable {
  struct RawInterval: Codable {
    enum IntervalType: String, Codable {
      case minutes = "MINUTES"
      case infinity = "INFINITY"

      init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        self = IntervalType(rawValue: rawValue) ?? .infinity
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
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
  enum CountType: Hashable {
    case min(Int)
    case max(Int)
  }
  var count: CountType
  let interval: Interval

  enum CodingKeys: String, CodingKey {
    case key
    case maxCount
    case minCount
    case interval
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    key = try values.decode(String.self, forKey: .key)

    if let maxCount = try values.decodeIfPresent(Int.self, forKey: .maxCount) {
      count = .max(maxCount)
    } else if let minCount = try values.decodeIfPresent(Int.self, forKey: .minCount) {
      count = .min(minCount)
    } else {
      // Will never get here
      count = .max(-1)
    }

    let interval = try values.decode(RawInterval.self, forKey: .interval)
    if interval.type == .minutes,
      let minutes = interval.minutes {
      self.interval = .minutes(minutes)
    } else {
      self.interval = .infinity
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(key, forKey: .key)
    switch count {
    case .min(let minCount):
      try container.encodeIfPresent(minCount, forKey: .minCount)
    case .max(let maxCount):
      try container.encodeIfPresent(maxCount, forKey: .maxCount)
    }

    switch interval {
    case .minutes(let minutes):
      let rawInterval = RawInterval(type: .minutes, minutes: minutes)
      try container.encode(rawInterval, forKey: .interval)
    case .infinity:
      let rawInterval = RawInterval(type: .infinity, minutes: nil)
      try container.encode(rawInterval, forKey: .interval)
    }
  }

  init(
    key: String,
    count: CountType,
    interval: Interval
  ) {
    self.key = key
    self.count = count
    self.interval = interval
  }
}

extension TriggerAudienceOccurrence: Stubbable {
  static func stub() -> TriggerAudienceOccurrence {
    return TriggerAudienceOccurrence(
      key: "abc",
      count: .max(10),
      interval: .infinity
    )
  }
}
