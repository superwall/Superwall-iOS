//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 20/11/2024.
//

import Foundation

struct Attribution: Codable, Equatable {
  let appleSearchAds: AppleSearchAds?
  /// Superwall's install attribution (MMP). Off unless the backend enables it.
  let mmp: MMPAttribution?

  init(
    appleSearchAds: AppleSearchAds?,
    mmp: MMPAttribution? = nil
  ) {
    self.appleSearchAds = appleSearchAds
    self.mmp = mmp
  }
}

struct AppleSearchAds: Codable, Equatable {
  let enabled: Bool
}

struct MMPAttribution: Codable, Equatable {
  let enabled: Bool
}
