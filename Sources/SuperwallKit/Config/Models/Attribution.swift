//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 20/11/2024.
//

import Foundation

struct Attribution: Codable, Equatable {
  let appleSearchAds: AppleSearchAds?
}

struct AppleSearchAds: Codable, Equatable {
  let enabled: Bool
}
