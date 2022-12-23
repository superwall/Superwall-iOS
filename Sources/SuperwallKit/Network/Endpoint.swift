//
//  Endpoint.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

struct Endpoint<Response: Decodable> {
  enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
  }
  struct Components {
    var scheme: String? = Api.scheme
    let host: String?
    let path: String
    var queryItems: [URLQueryItem]?
    var bodyData: Data?
  }

  var components: Components?
  var url: URL?
  var method: HttpMethod = .get
  var requestId: String = UUID().uuidString
  let factory: ApiFactory

  func makeRequest(forDebugging isForDebugging: Bool) -> URLRequest? {
    let url: URL

    if let components = components {
      var component = URLComponents()
      component.scheme = components.scheme
      component.host = components.host
      component.queryItems = components.queryItems
      component.path = components.path

      // If either the path or the query items passed contained
      // invalid characters, we'll get a nil URL back:
      guard let componentUrl = component.url else {
        return nil
      }
      url = componentUrl
    } else if let selfUrl = self.url {
      url = selfUrl
    } else {
      return nil
    }

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue

    if let bodyData = components?.bodyData {
      request.httpBody = bodyData
    }

    let headers = factory.makeHeaders(
      fromRequest: request,
      requestId: requestId,
      forDebugging: isForDebugging
    )

    for header in headers {
      request.setValue(
        header.value,
        forHTTPHeaderField: header.key
      )
    }

    return request
  }
}

// MARK: - EventsResponse
extension Endpoint where Response == EventsResponse {
  static func events(eventsRequest: EventsRequest, factory: ApiFactory) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(eventsRequest)
    let collectorHost = factory.api.collector.host

    return Endpoint(
      components: Components(
        host: collectorHost,
        path: Api.version1 + "events",
        bodyData: bodyData
      ),
      method: .post,
      factory: factory
    )
  }

  static func sessionEvents(_ session: SessionEventsRequest, factory: ApiFactory) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(session)
    let collectorHost = factory.api.collector.host

    return Endpoint(
      components: Components(
        host: collectorHost,
        path: Api.version1 + "session_events",
        bodyData: bodyData
      ),
      method: .post,
      factory: factory
    )
  }
}

// MARK: - Paywall
extension Endpoint where Response == Paywall {
  static func paywall(
    withIdentifier identifier: String? = nil,
    fromEvent event: EventData? = nil,
    factory: ApiFactory
  ) -> Self {
    let bodyData: Data?

    if let identifier = identifier {
      return paywall(byIdentifier: identifier, factory: factory)
    } else if let event = event {
      let bodyDict = ["event": event.jsonData]
      bodyData = try? JSONEncoder.toSnakeCase.encode(bodyDict)
    } else {
      let body = PaywallRequestBody(appUserId: factory.identityManager.userId)
      bodyData = try? JSONEncoder.toSnakeCase.encode(body)
    }
    let baseHost = factory.api.base.host

    return Endpoint(
      components: Components(
        host: baseHost,
        path: Api.version1 + "paywall",
        bodyData: bodyData
      ),
      method: .post,
      factory: factory
    )
  }

  static private func paywall(
    byIdentifier identifier: String,
    factory: ApiFactory
  ) -> Self {
    // WARNING: Do not modify anything about this request without considering our cache eviction code
    // we must know all the exact urls we need to invalidate so changing the order, inclusion, etc of any query
    // parameters will cause issues
    var queryItems = [URLQueryItem(name: "pk", value: factory.storage.apiKey)]

    // In the config endpoint we return all the locales, this code will check if:
    // 1. The device locale (ex: en_US) exists in the locales list
    // 2. The shortend device locale (ex: en) exists in the locale list
    // If either exist (preferring the most specific) include the locale in the
    // the url as a query param.
    if let config = factory.configManager.config {
      if config.locales.contains(factory.deviceHelper.locale) {
        let localeQuery = URLQueryItem(
          name: "locale",
          value: factory.deviceHelper.locale
        )
        queryItems.append(localeQuery)
      } else {
        let shortLocale = factory.deviceHelper.locale.split(separator: "_")[0]
        if config.locales.contains(String(shortLocale)) {
          let localeQuery = URLQueryItem(
            name: "locale",
            value: String(shortLocale)
          )
          queryItems.append(localeQuery)
        }
      }
    }
    let baseHost = factory.api.base.host

    return Endpoint(
      components: Components(
        host: baseHost,
        path: Api.version1 + "paywall/\(identifier)",
        queryItems: queryItems
      ),
      method: .get,
      factory: factory
    )
  }
}

// MARK: - PaywallsResponse
extension Endpoint where Response == Paywalls {
  static func paywalls(factory: ApiFactory) -> Self {
    let baseHost = factory.api.base.host
    return Endpoint(
      components: Components(
        host: baseHost,
        path: Api.version1 + "paywalls"
      ),
      method: .get,
      factory: factory
    )
  }
}

// MARK: - ConfigResponse
extension Endpoint where Response == Config {
  static func config(
    requestId: String,
    factory: ApiFactory
  ) -> Self {
    let queryItems = [URLQueryItem(name: "pk", value: factory.storage.apiKey)]
    let baseHost = factory.api.base.host

    return Endpoint(
      components: Components(
        host: baseHost,
        path: Api.version1 + "static_config",
        queryItems: queryItems
      ),
      method: .get,
      requestId: requestId,
      factory: factory
    )
  }
}

// MARK: - ConfirmedAssignmentResponse
extension Endpoint where Response == ConfirmedAssignmentResponse {
  static func assignments(factory: ApiFactory) -> Self {
    let baseHost = factory.api.base.host

    return Endpoint(
      components: Components(
        host: baseHost,
        path: Api.version1 + "assignments"
      ),
      method: .get,
      factory: factory
    )
  }

  static func confirmAssignments(
    _ confirmableAssignments: AssignmentPostback,
    factory: ApiFactory
  ) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(confirmableAssignments)
    let baseHost = factory.api.base.host

    return Endpoint(
      components: Components(
        host: baseHost,
        path: Api.version1 + "confirm_assignments",
        bodyData: bodyData
      ),
      method: .post,
      factory: factory
    )
  }
}

// MARK: - PostbackResponse
extension Endpoint where Response == PostBackResponse {
  static func postback(
    _ postback: Postback,
    factory: ApiFactory
  ) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(postback)
    let collectorHost = factory.api.collector.host

    return Endpoint(
      components: Components(
        host: collectorHost,
        path: Api.version1 + "postback",
        bodyData: bodyData
      ),
      method: .post,
      factory: factory
    )
  }
}
