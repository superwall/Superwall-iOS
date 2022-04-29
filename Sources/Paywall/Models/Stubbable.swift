//
//  Stubbable.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

import Foundation

protocol Stubbable: KeyPathWritable {
  static func stub() -> Self
}
