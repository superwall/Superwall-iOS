//
//  DevServerSurface.swift
//  SuperwallKit
//
//  One entry in the surface list a running `superwall dev` server exposes:
//  a locally served paywall or funnel, and the dashboard paywall it is
//  bound to via `superwall.lock`, if any.
//

import Foundation

struct DevServerSurface: Decodable, Equatable {
  let kind: String
  let id: String
  let url: String
  let paywallId: String?
  let identifier: String?
  let products: [String: String]?
}
