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
  /// Whether the event was put on the queue that sends it to Superwall. Disabled
  /// verbose placements and events tracked while tracking is off aren't.
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
