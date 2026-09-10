//
//  DevServerLocation.swift
//  SuperwallKit
//
//  A found `superwall dev` server: the base it answered on and the
//  manifest it served from there.
//

import Foundation

struct DevServerLocation: Equatable {
  let base: URL
  let manifest: DevServerManifest
}
