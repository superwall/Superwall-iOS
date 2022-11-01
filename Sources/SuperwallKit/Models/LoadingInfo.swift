//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

struct LoadingInfo: Codable {
  /// The loading start time.
  var startAt: Date?
  /// The loading end time.
  var endAt: Date?
  /// When it failed.
  var failAt: Date?
}
