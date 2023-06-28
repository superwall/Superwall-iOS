//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/06/2023.
//

import Foundation

struct Throwable<T: Decodable>: Decodable {
  let result: Result<T, Error>

  init(from decoder: Decoder) throws {
    result = Result { try T(from: decoder) }
  }
}
