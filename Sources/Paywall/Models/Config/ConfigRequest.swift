//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/06/2022.
//

import Foundation

struct ConfigRequest: Equatable {
  let id: String
  let completion: ((Result<Config, Error>) -> Void)

  static func == (lhs: ConfigRequest, rhs: ConfigRequest) -> Bool {
    return lhs.id == rhs.id
  }
}
