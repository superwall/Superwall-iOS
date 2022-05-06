//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension TriggerSession {
  struct LoadingInfo: Encodable {
    /// The loading start time.
    var startAt: Date?
    /// The loading end time.
    var endAt: Date?
    /// When it failed.
    var failAt: Date?
  }
}
