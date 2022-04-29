//
//  EventsRequest.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct EventsRequest: Encodable {
  var events: [JSON]
  //var sessions: [PaywallSession]
}
