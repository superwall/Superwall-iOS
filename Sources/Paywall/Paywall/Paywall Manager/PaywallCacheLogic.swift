//
//  PaywallCacheLogic.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

import Foundation

enum PaywallCacheLogic {
  static func key(
    forIdentifier identifier: String?,
    event: EventData?,
    locale: String = DeviceHelper.shared.locale
  ) -> String {
    let id = identifier ?? "$no_id"
    let name = event?.name ?? "$no_event"
    return "\(id)_\(name)_\(locale)"
  }
}
