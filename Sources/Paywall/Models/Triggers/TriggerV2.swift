//
//  TriggerV2.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct TriggerV2: Decodable, Hashable {
  // Just for convience, should be captured in the "Trigger" struct
  var eventName: String
  var rules: [TriggerRule]
}

extension TriggerV2: Stubbable {
  static func stub() -> TriggerV2 {
    return TriggerV2(
      eventName: "opened_application",
      rules: [.stub()]
    )
  }
}
