//
//  Variant.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum Variant: Decodable, Hashable {
  struct VariantTreatment: Decodable, Hashable {
    var variantId: String
    var paywallIdentifier: String
  }

  struct VariantHoldout: Decodable, Hashable {
    var variantId: String
  }

  case treatment(VariantTreatment)
  case holdout(VariantHoldout)

  enum Keys: String, CodingKey {
    case variantType
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: Variant.Keys.self)
    let variantType = try values.decode(String.self, forKey: .variantType)
    switch variantType {
    case "HOLDOUT":
      let holdout = try VariantHoldout(from: decoder)
      self = .holdout(holdout)
    case "TREATMENT":
      let treatment = try VariantTreatment(from: decoder)
      self = .treatment(treatment)
    default:
      // TODO: Handle unknowns better
      let holdout = try VariantHoldout(from: decoder)
      self = .holdout(holdout)
    }
  }
}
