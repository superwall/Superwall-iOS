//
//  ProductVariable.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct ProductVariable: Codable, Equatable {
  let type: ProductType
  let attributes: JSON
}
