//
//  ProductVariable.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct ProductVariable: Codable, Equatable {
  let name: String
  let attributes: JSON

  /// Encodes in the format `"name": [attributes]`
  func encode(to encoder: Encoder) throws {
    // Create a container for the custom key (the product name)
    var container = encoder.container(keyedBy: DynamicCodingKey.self)

    // Use the product name as the key for the nested container
    let nameKey = DynamicCodingKey(stringValue: name)

    // Nested container for the attributes under the product name
    var productsContainer = container.nestedContainer(
      keyedBy: DynamicCodingKey.self,
      forKey: nameKey
    )

    for (key, value) in attributes {
      try value.encode(
        to: productsContainer.superEncoder(forKey: DynamicCodingKey(stringValue: key))
      )
    }
  }
}

private struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }

  init(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue: Int) {
    return nil
  }
}
