//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

import Foundation

extension JSONEncoder {
  static let superwall: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .formatted(Date.isoFormatter)
    return encoder
  }()
}

extension JSONDecoder {
  static let superwall: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(Date.isoFormatter)
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()
}
