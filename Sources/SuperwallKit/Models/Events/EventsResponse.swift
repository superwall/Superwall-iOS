//
//  EventsResponse.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//
// swiftlint:disable identifier_name

import Foundation

struct EventsResponse: Codable {
  enum Status: String, Codable {
    case ok
    case partialSuccess

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let rawValue = try container.decode(RawValue.self)
      self = Status(rawValue: rawValue) ?? .partialSuccess
    }
  }
  var status: Status
  var invalidIndexes: [Int]?
}
