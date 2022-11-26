//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/11/2022.
//

import Foundation

 struct PreloadingDisabled: Codable {
   let all: Bool
   let triggers: Set<String>
 }

 // MARK: - Stubbable

 extension PreloadingDisabled: Stubbable {
   static func stub() -> PreloadingDisabled {
     return PreloadingDisabled(
       all: false,
       triggers: []
     )
   }
 }
