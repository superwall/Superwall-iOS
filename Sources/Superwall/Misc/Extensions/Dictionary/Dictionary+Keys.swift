//
//  Dictionary+Keys.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

extension Dictionary where Value: Equatable {
  func allKeys(forValue val: Value) -> [Key] {
    return self.filter { $1 == val }.map { $0.0 }
  }
}
