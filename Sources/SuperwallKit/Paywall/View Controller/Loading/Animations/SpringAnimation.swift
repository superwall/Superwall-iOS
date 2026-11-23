//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

#if canImport(WebKit)
import SwiftUI

extension Animation {
  static var spring: Animation {
    .interpolatingSpring(stiffness: 300, damping: 23)
  }
}
#endif
