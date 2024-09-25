//
//  EndpointKind.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/09/2024.
//

import Foundation

protocol EndpointKind {
  associatedtype RequestData
  static var jsonDecoder: JSONDecoder { get }
  static func prepare(
    _ request: inout URLRequest,
    with data: RequestData
  ) async

  static func makeDefaultComponents(
    factory: ApiFactory,
    host: EndpointHost
  ) -> ApiHostConfig
}

extension EndpointKind {
  static func makeDefaultComponents(
    factory: ApiFactory,
    host: EndpointHost
  ) -> ApiHostConfig {
    factory.makeDefaultComponents(host: host)
  }
}

struct SuperwallRequestData {
  let factory: ApiFactory
  var requestId = UUID().uuidString
  var isForDebugging = false
}

enum EndpointKinds {
  enum Superwall: EndpointKind {
    static var jsonDecoder = JSONDecoder.fromSnakeCase

    static func prepare(
      _ request: inout URLRequest,
      with data: SuperwallRequestData
    ) async {
      let headers = await data.factory.makeHeaders(
        fromRequest: request,
        isForDebugging: data.isForDebugging,
        requestId: data.requestId
      )

      for header in headers {
        request.setValue(
          header.value,
          forHTTPHeaderField: header.key
        )
      }
    }
  }

  enum AdServices: EndpointKind {
    static var jsonDecoder = JSONDecoder()

    static func prepare(
      _ request: inout URLRequest,
      with _: Void
    ) async {
      request.setValue(
        "Content-Type",
        forHTTPHeaderField: "text/plain"
      )
    }
  }
}
