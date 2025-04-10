//
//  SuperwallAPI.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

enum EndpointHost {
  case base
  case collector
  case enrichment
  case adServices
}

protocol ApiHostConfig {
  var port: Int? { get }
  var scheme: String { get }
  var host: String { get }
}

struct Api {
  let base: Base
  let collector: Collector
  let enrichment: Enrichment
  let adServices: AdServices
  static let version1 = "/api/v1/"

  init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
    base = Base(networkEnvironment: networkEnvironment)
    collector = Collector(networkEnvironment: networkEnvironment)
    enrichment = Enrichment(networkEnvironment: networkEnvironment)
    adServices = AdServices(networkEnvironment: networkEnvironment)
  }

  func getConfig(host: EndpointHost) -> ApiHostConfig {
    switch host {
    case .base:
      return base
    case .collector:
      return collector
    case .enrichment:
      return enrichment
    case .adServices:
      return adServices
    }
  }

  struct Base: ApiHostConfig {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var port: Int? { return networkEnvironment.port }
    var scheme: String { return networkEnvironment.scheme }
    var host: String { return networkEnvironment.baseHost }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  struct Collector: ApiHostConfig {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var port: Int? { return networkEnvironment.port }
    var scheme: String { return networkEnvironment.scheme }
    var host: String { return networkEnvironment.collectorHost }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  struct Enrichment: ApiHostConfig {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var port: Int? { return networkEnvironment.port }
    var scheme: String { return networkEnvironment.scheme }
    var host: String { return networkEnvironment.enrichmentHost }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  struct AdServices: ApiHostConfig {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var port: Int? { return networkEnvironment.port }
    var scheme: String { return networkEnvironment.scheme }
    var host: String { return networkEnvironment.adServicesHost }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }
}
