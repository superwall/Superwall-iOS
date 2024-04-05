//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/06/2023.
//

import Foundation


/// A generic struct for error-tolerant decoding.
///
/// It allows each element in a collection to be decoded independently, enabling the
/// handling of decoding errors on a per-element basis. This is useful for decoding
/// arrays of objects where some objects might be malformed or incomplete.
///
/// Example:
///
/// ```
/// let appStoreProductItems = try values.decodeIfPresent(
///   [Throwable<ProductItem>].self,
///   forKey: .productItems
/// ) ?? []
/// productItems = appStoreProductItems.compactMap { try? $0.result.get() }
/// ```
/// This gets the product items whose decoding doesn't fail.
struct Throwable<T: Decodable>: Decodable {
  let result: Result<T, Error>

  init(from decoder: Decoder) throws {
    result = Result { try T(from: decoder) }
  }
}
