//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Trigger: Encodable {
    let id: String
    let eventId: String
    let name: String
    enum TriggerType: Encodable {
      case implicit
      case explicit
    }
    let type: TriggerType
    let isSuperwallEvent: Bool

    struct Experiment: Encodable {
      let expression: String
      let groupId: String
    }
    let experiment: Experiment
  }
}
