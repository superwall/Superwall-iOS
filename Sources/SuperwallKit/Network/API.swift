//
//  SuperwallAPI.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

struct Api {
  let hostDomain: String
  let base: Base
  let collector: Collector

  static let version1 = "/api/v1/"
  static let scheme = "https"

  init(configManager: ConfigManager) {
    let networkEnvironment = configManager.options.networkEnvironment
    self.base = Base(networkEnvironment: networkEnvironment)
    self.collector = Collector(networkEnvironment: networkEnvironment)
    self.hostDomain = networkEnvironment.hostDomain
  }

  struct Base {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }

    var host: String {
      return networkEnvironment.baseHost
    }
  }

  struct Collector {
    private let networkEnvironment: SuperwallOptions.NetworkEnvironment

    init(networkEnvironment: SuperwallOptions.NetworkEnvironment) {
      self.networkEnvironment = networkEnvironment
    }

    var host: String {
      return networkEnvironment.collectorHost
    }
  }
}
