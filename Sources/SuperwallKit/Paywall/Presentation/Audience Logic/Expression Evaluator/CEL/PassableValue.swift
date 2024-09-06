//
//  File.swift
//
//
//  Created by Yusuf Tör on 14/08/2024.
//
// swiftlint:disable cyclomatic_complexity

import Foundation

struct ExecutionContext: Codable {
  let variables: PassableMap
  let expression: String
  let platform: [String: String]
}

struct PassableMap: Codable {
  let map: [String: PassableValue]
}

indirect enum PassableValue: Codable {
  case list([PassableValue])
  case map([String: PassableValue])
  case function(value: String, args: PassableValue?)
  case int(Int)
  case uint(UInt64)
  case float(Double)
  case string(String)
  case bytes(Data)
  case bool(Bool)
  case timestamp(Int64)
  case null

  private enum CodingKeys: String, CodingKey {
    case list, map, function, int, uint, float, string, bytes, bool, timestamp, null
    case value, args
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let listValue = try? container.decode([PassableValue].self, forKey: .list) {
      self = .list(listValue)
    } else if let mapValue = try? container.decode([String: PassableValue].self, forKey: .map) {
      self = .map(mapValue)
    } else if let functionValue = try? container.decode(String.self, forKey: .value) {
      let args = try container.decodeIfPresent(PassableValue.self, forKey: .args)
      self = .function(value: functionValue, args: args)
    } else if let intValue = try? container.decode(Int.self, forKey: .int) {
      self = .int(intValue)
    } else if let uintValue = try? container.decode(UInt64.self, forKey: .uint) {
      self = .uint(uintValue)
    } else if let floatValue = try? container.decode(Double.self, forKey: .float) {
      self = .float(floatValue)
    } else if let stringValue = try? container.decode(String.self, forKey: .string) {
      self = .string(stringValue)
    } else if let bytesValue = try? container.decode(Data.self, forKey: .bytes) {
      self = .bytes(bytesValue)
    } else if let boolValue = try? container.decode(Bool.self, forKey: .bool) {
      self = .bool(boolValue)
    } else if let timestampValue = try? container.decode(Int64.self, forKey: .timestamp) {
      self = .timestamp(timestampValue)
    } else if container.contains(.null) {
      self = .null
    } else {
      // TODO: Review whether we should be throwing here or something softer
      throw DecodingError.typeMismatch(
        PassableValue.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Unknown type"
        )
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .list(let value):
      try container.encode(value, forKey: .list)
    case .map(let value):
      try container.encode(value, forKey: .map)
    case let .function(value, args):
      try container.encode(value, forKey: .value)
      try container.encode(args, forKey: .args)
    case .int(let value):
      try container.encode(value, forKey: .int)
    case .uint(let value):
      try container.encode(value, forKey: .uint)
    case .float(let value):
      try container.encode(value, forKey: .float)
    case .string(let value):
      try container.encode(value, forKey: .string)
    case .bytes(let value):
      try container.encode(value, forKey: .bytes)
    case .bool(let value):
      try container.encode(value, forKey: .bool)
    case .timestamp(let value):
      try container.encode(value, forKey: .timestamp)
    case .null:
      try container.encodeNil(forKey: .null)
    }
  }
}
