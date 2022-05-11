//
//  VariantTreatment.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import Foundation

public struct VariantTreatment: Decodable, Hashable {
  var paywallIdentifier: String
}

extension VariantTreatment: Stubbable {
  static func stub() -> VariantTreatment {
    return VariantTreatment(
      paywallIdentifier: "1"
    )
  }
}
