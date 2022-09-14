//
//  Endpoint.swift
//  Paywall
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

  func makeRequest(forDebugging isForDebugging: Bool) -> URLRequest? {
    let url: URL

    if let components {
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

    addHeaders(
      to: &request,
      requestId: requestId,
      forDebugging: isForDebugging
    )

    return request
  }

  private func addHeaders(
    to request: inout URLRequest,
    requestId: String,
    forDebugging isForDebugging: Bool
  ) {
    let apiKey = isForDebugging ? (Storage.shared.debugKey ?? "") : Storage.shared.apiKey
    let auth = "Bearer \(apiKey)"
    let headers = [
      "Authorization": auth,
      "X-Platform": "iOS",
      "X-Platform-Environment": "SDK",
      "X-App-User-ID": Storage.shared.appUserId ?? "",
      "X-Alias-ID": Storage.shared.aliasId ?? "",
      "X-Vendor-ID": DeviceHelper.shared.vendorId,
      "X-App-Version": DeviceHelper.shared.appVersion,
      "X-OS-Version": DeviceHelper.shared.osVersion,
      "X-Device-Model": DeviceHelper.shared.model,
      "X-Device-Locale": DeviceHelper.shared.locale,
      "X-Device-Language-Code": DeviceHelper.shared.languageCode,
      "X-Device-Currency-Code": DeviceHelper.shared.currencyCode,
      "X-Device-Currency-Symbol": DeviceHelper.shared.currencySymbol,
      "X-Device-Timezone-Offset": DeviceHelper.shared.secondsFromGMT,
      "X-App-Install-Date": DeviceHelper.shared.appInstalledAtString,
      "X-Radio-Type": DeviceHelper.shared.radioType,
      "X-Device-Interface-Style": DeviceHelper.shared.interfaceStyle,
      "X-SDK-Version": sdkVersion,
      "X-Request-Id": requestId,
      "X-Bundle-ID": DeviceHelper.shared.bundleId,
      "X-Low-Power-Mode": DeviceHelper.shared.isLowPowerModeEnabled,
      "Content-Type": "application/json"
    ]

    for header in headers {
      request.setValue(
        header.value,
        forHTTPHeaderField: header.key
      )
    }
  }
}

// MARK: - EventsResponse
extension Endpoint where Response == EventsResponse {
  static func events(eventsRequest: EventsRequest) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(eventsRequest)

    return Endpoint(
      components: Components(
        host: Api.Collector.host,
        path: Api.version1 + "events",
        bodyData: bodyData
      ),
      method: .post
    )
  }

  static func sessionEvents(_ session: SessionEventsRequest) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(session)

    return Endpoint(
      components: Components(
        host: Api.Collector.host,
        path: Api.version1 + "session_events",
        bodyData: bodyData
      ),
      method: .post
    )
  }
}

// MARK: - PaywallResponse
extension Endpoint where Response == PaywallResponse {
  static func paywall(
    withIdentifier identifier: String? = nil,
    fromEvent event: EventData? = nil
  ) -> Self {
    let bodyData: Data?

    if let identifier {
      return paywall(byIdentifier: identifier)
    } else if let event {
      let bodyDict = ["event": event.jsonData]
      bodyData = try? JSONEncoder.toSnakeCase.encode(bodyDict)
    } else {
      let bodyDict = PaywallRequest(appUserId: Storage.shared.userId ?? "")
      bodyData = try? JSONEncoder.toSnakeCase.encode(bodyDict)
    }
    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "paywall",
        bodyData: bodyData
      ),
      method: .post
    )
  }

  static private func paywall(byIdentifier identifier: String) -> Self {
    // WARNING: Do not modify anything about this request without considering our cache eviction code
    // we must know all the exact urls we need to invalidate so changing the order, inclusion, etc of any query
    // parameters will cause issues
    var queryItems = [URLQueryItem(name: "pk", value: Storage.shared.apiKey)]

    // In the config endpoint we return all the locales, this code will check if:
    // 1. The device locale (ex: en_US) exists in the locales list
    // 2. The shortend device locale (ex: en) exists in the locale list
    // If either exist (preferring the most specific) include the locale in the
    // the url as a query param.
    if let config = ConfigManager.shared.config {
      if config.locales.contains(DeviceHelper.shared.locale) {
        let localeQuery = URLQueryItem(
          name: "locale",
          value: DeviceHelper.shared.locale
        )
        queryItems.append(localeQuery)
      } else {
        let shortLocale = DeviceHelper.shared.locale.split(separator: "_")[0]
        if config.locales.contains(String(shortLocale)) {
          let localeQuery = URLQueryItem(
            name: "locale",
            value: String(shortLocale)
          )
          queryItems.append(localeQuery)
        }
      }
    }

    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "paywall/\(identifier)",
        queryItems: queryItems
      ),
      method: .get
    )
  }
}

// MARK: - PaywallsResponse
extension Endpoint where Response == PaywallsResponse {
  static func paywalls() -> Self {
    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "paywalls"
      ),
      method: .get
    )
  }
}

// MARK: - ConfigResponse
extension Endpoint where Response == Config {
  static func config(requestId: String) -> Self {
    let queryItems = [URLQueryItem(name: "pk", value: Storage.shared.apiKey)]

    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "static_config",
        queryItems: queryItems
      ),
      method: .get,
      requestId: requestId
    )
  }
}

// MARK: - ConfirmedAssignmentResponse
extension Endpoint where Response == ConfirmedAssignmentResponse {
  static var assignments: Self {
    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "assignments"
      ),
      method: .get
    )
  }

  static func confirmAssignments(_ confirmableAssignments: ConfirmableAssignments) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(confirmableAssignments)

    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "confirm_assignments",
        bodyData: bodyData
      ),
      method: .post
    )
  }
}

// MARK: - PostbackResponse
extension Endpoint where Response == PostBackResponse {
  static func postback(_ postback: Postback) -> Self {
    let bodyData = try? JSONEncoder.toSnakeCase.encode(postback)

    return Endpoint(
      components: Components(
        host: Api.Collector.host,
        path: Api.version1 + "postback",
        bodyData: bodyData
      ),
      method: .post
    )
  }
}
