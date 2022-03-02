//
//  PaywallRequest.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct PaywallRequest: Codable {
  var appUserId: String
}

struct PaywallFromEventRequest: Codable {
  var appUserId: String
  var event: EventData?
}
