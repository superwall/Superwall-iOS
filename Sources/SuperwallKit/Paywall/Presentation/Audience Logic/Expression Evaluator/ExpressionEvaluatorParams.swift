//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import Foundation

struct LiquidExpressionEvaluatorParams: Codable {
  var expression: String
  var values: JSON

  func toBase64Input() -> String? {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(self) {
      return data.base64EncodedString()
    }
    return nil
  }
}

struct JsExpressionEvaluatorParams: Codable {
  var expressionJs: String
  var values: JSON

  private enum CodingKeys: String, CodingKey {
    case expressionJs = "expressionJS"
    case values
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(expressionJs, forKey: .expressionJs)
    try container.encode(values, forKey: .values)
  }

  func toBase64Input() -> String? {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(self) {
      return data.base64EncodedString()
    }
    return nil
  }
}
