//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct LoadingInfo: Encodable {
    /// The loading start time.
    let startAt: Date
    /// The loading end time.
    let endAt: Date
    /// The time it took to load.
    let duration: TimeInterval
  }
}
