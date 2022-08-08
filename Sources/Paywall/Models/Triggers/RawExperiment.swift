//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/07/2022.
//

import Foundation

/// An experiment without a confirmed variant assignment.
struct RawExperiment: Decodable, Hashable {
  let id: String
  let groupId: String
  let variants: [VariantOption]
}
