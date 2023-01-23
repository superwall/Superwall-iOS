//
//  Stubbable.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

import Foundation

/// Creates a stub of a class to be used in tests only.
protocol Stubbable: KeyPathWritable {
  static func stub() -> Self
}
