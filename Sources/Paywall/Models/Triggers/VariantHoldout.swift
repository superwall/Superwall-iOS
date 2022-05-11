//
//  VariantHoldout.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import Foundation

public struct VariantHoldout: Decodable, Hashable {
  var variantId: String
}

extension VariantHoldout: Stubbable {
  static func stub() -> VariantHoldout {
    return VariantHoldout(variantId: "id")
  }
}
