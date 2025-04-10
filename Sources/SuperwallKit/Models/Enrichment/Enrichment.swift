//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 10/04/2025.
//

import Foundation

struct Enrichment: Codable {
  let user: JSON
  let device: JSON
}

typealias EnrichmentRequest = Enrichment
