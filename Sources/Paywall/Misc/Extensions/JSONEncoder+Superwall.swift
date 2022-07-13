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
}
