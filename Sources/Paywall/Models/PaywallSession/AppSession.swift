//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct AppSession: Encodable {
    /// App session id
    let id: String
    /// App session start time
    let startAt: Date
  }
}
