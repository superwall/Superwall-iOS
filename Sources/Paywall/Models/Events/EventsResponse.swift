//
//  EventsResponse.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//
// swiftlint:disable identifier_name

import Foundation

struct EventsResponse: Codable {
  enum Status: String, Codable {
    case ok
    case partialSuccess
  }
  var status: Status
  var invalidIndexes: [Int]?
}
