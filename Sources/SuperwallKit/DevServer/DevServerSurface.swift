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
  /// How the paywall asks to be presented, straight from its `config.ts`.
  struct Presentation: Decodable, Equatable {
    struct Drawer: Decodable, Equatable {
      let height: Double
      let cornerRadius: Double
    }
    struct Popup: Decodable, Equatable {
      let width: Double
      let height: Double
      let cornerRadius: Double
    }

    let style: String?
    let drawer: Drawer?
    let popup: Popup?
  }

  let kind: String
  let id: String
  let url: String
  let paywallId: String?
  let identifier: String?
  let products: [String: String]?
  let presentation: Presentation?
}
