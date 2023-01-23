//
//  Encodable+Dictionary.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

extension Encodable {
  func dictionary(withSnakeCase: Bool = false) -> [String: Any]? {
    let encoder: JSONEncoder
    if withSnakeCase {
      encoder = JSONEncoder.toSnakeCase
    } else {
      encoder = JSONEncoder()
    }
    guard let data = try? encoder.encode(self) else {
      return nil
    }
    let jsonObject = try? JSONSerialization.jsonObject(
      with: data,
      options: .allowFragments
    )

    return jsonObject.flatMap { $0 as? [String: Any] }
  }
}
