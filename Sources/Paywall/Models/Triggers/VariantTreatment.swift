//
//  VariantTreatment.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import Foundation

struct VariantTreatment: Decodable, Hashable {
  var variantId: String
  var paywallIdentifier: String
}

extension VariantTreatment: Stubbable {
  static func stub() -> VariantTreatment {
    return VariantTreatment(
      variantId: "1",
      paywallIdentifier: "2"
    )
  }
}
