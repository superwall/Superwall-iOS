//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/04/2022.
//

import Foundation

struct TrackingParameters {
  let delegateParams: [String: Any]
  let eventParams: [String: Any]
}

extension TrackingParameters: Stubbable {
  static func stub() -> TrackingParameters {
    return TrackingParameters(
      delegateParams: [:],
      eventParams: [:]
    )
  }
}
