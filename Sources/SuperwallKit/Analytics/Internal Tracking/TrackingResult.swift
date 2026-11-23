//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/04/2022.
//

import Foundation

struct TrackingResult {
  var data: PlacementData
  let parameters: TrackingParameters
  /// Whether the event went into the queue for sending, or straight to the server
  /// if it's sent in a request of its own, which the tracking behavior can prevent.
  /// It isn't confirmation that the upload succeeded.
  var isQueuedForSending = false
}
extension TrackingResult: Stubbable {
  static func stub() -> TrackingResult {
    return TrackingResult(
      data: .stub(),
      parameters: .stub()
    )
  }
}
