//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

import Foundation

extension JSONEncoder {
  /// Converts to snake case and ISO formats dates
  static let toSnakeCase: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .formatted(Date.isoFormatter)
    return encoder
  }()
}

extension JSONDecoder {
  /// Converts from snake case and ISO formatted dates
  static let fromSnakeCase: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(Date.isoFormatter)
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()

  /// Decoder for Web2App endpoints that handles millisecond timestamps.
  ///
  /// This decoder supports dates in two formats:
  /// - Milliseconds since epoch (Int64): Common in Java/JavaScript APIs
  /// - ISO8601 strings: Standard date format
  ///
  /// Note: This is specifically for Web2App endpoints which return CustomerInfo
  /// with dates as milliseconds since epoch.
  static let web2App: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()

      // Try milliseconds first (divide by 1000 to convert to seconds)
      if let milliseconds = try? container.decode(Int64.self) {
        return Date(timeIntervalSince1970: Double(milliseconds) / 1000.0)
      }

      // Fall back to ISO8601 string
      if let dateString = try? container.decode(String.self) {
        if let date = Date.isoFormatter.date(from: dateString) {
          return date
        }
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Date string does not match ISO8601 format"
        )
      }

      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected Int64 (milliseconds) or ISO8601 String for date"
      )
    }
    return decoder
  }()
}
