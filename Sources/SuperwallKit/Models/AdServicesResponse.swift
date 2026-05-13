//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/11/2024.
//

import Foundation

struct AdServicesResponse: Decodable {
  let attribution: [String: JSON]

  // Apple's attribution endpoint can confirm a user is ineligible (e.g. they
  // didn't come from a Search Ads campaign). When the backend forwards that
  // signal we can stop retrying — distinct from a transient failure where the
  // payload simply hasn't arrived yet.
  let eligible: Bool?
  let error: String?
}
