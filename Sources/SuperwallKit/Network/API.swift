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
  case subscriptionsApi
  case paywallsV2
}

protocol ApiHostConfig {
  var networkEnvironment: SuperwallOptions.NetworkEnvironment { get }
  var port: Int? { get }
  var scheme: String { get }
  var host: String { get }
  var path: String { get }
}

extension ApiHostConfig {
  var port: Int? { return networkEnvironment.port }
  var scheme: String { return networkEnvironment.scheme }
}

struct Api {
  let base: Base
  let collector: Collector
  let enrichment: Enrichment
  let adServices: AdServices
  let subscriptionsApi: SubscriptionsAPI
  let paywallsV2: PaywallsV2

  init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
    base = Base(networkEnvironment: networkEnvironment)
    collector = Collector(networkEnvironment: networkEnvironment)
    enrichment = Enrichment(networkEnvironment: networkEnvironment)
    adServices = AdServices(networkEnvironment: networkEnvironment)
    subscriptionsApi = SubscriptionsAPI(networkEnvironment: networkEnvironment)
    paywallsV2 = PaywallsV2(networkEnvironment: networkEnvironment)
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
    case .subscriptionsApi:
      return subscriptionsApi
    case .paywallsV2:
      return paywallsV2
    }
  }

  struct Base: ApiHostConfig {
    let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var host: String { return networkEnvironment.baseHost }
    var path: String { return "/api/v1/" }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  struct Collector: ApiHostConfig {
    let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var host: String { return networkEnvironment.collectorHost }
    var path: String { return "/api/v1/" }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  struct Enrichment: ApiHostConfig {
    internal let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var port: Int? { return networkEnvironment.port }
    var scheme: String { return networkEnvironment.scheme }
    var host: String { return networkEnvironment.enrichmentHost }
    var path: String { return "/api/v1/" }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  struct AdServices: ApiHostConfig {
    let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var host: String { return networkEnvironment.adServicesHost }
    var path: String { return "/api/v1/" }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  struct SubscriptionsAPI: ApiHostConfig {
    let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var host: String { return networkEnvironment.web2AppHost }
    var path: String { return "/subscriptions-api/public/v1/" }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }

  /// The V2 API served under the `/v2/` prefix on the base host
  /// (e.g. `superwall.com/v2/*`, which is routed to the V2 Worker).
  struct PaywallsV2: ApiHostConfig {
    let networkEnvironment: SuperwallOptions.NetworkEnvironment
    var host: String { return networkEnvironment.baseHost }
    var path: String { return "/v2/" }

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }
  }
}
