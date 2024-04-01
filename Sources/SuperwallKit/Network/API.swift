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
}

protocol ApiHostConfig {
    var port: Int? { get }
    var scheme: String { get }
    var host: String { get }
}

struct Api {
  let base: Base
  let collector: Collector
  static let version1 = "/api/v1/"

  init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
    self.base = Base(networkEnvironment: networkEnvironment)
    self.collector = Collector(networkEnvironment: networkEnvironment)
  }

    func getConfig(host: EndpointHost) -> ApiHostConfig {
        switch host {
        case .base:
            return base
        case .collector:
            return collector
        }
    }

    struct Base: ApiHostConfig {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }

      var port: Int? {
          return networkEnvironment.port
      }

      var scheme: String {
          return networkEnvironment.scheme
      }

    var host: String {
      return networkEnvironment.baseHost
    }
  }

    struct Collector: ApiHostConfig {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }

      var port: Int? {
          return networkEnvironment.port
      }

      var scheme: String {
          return networkEnvironment.scheme
      }

    var host: String {
      return networkEnvironment.collectorHost
    }
  }
}
