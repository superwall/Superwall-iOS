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

    addHeaders(
      to: &request,
      forDebugging: isForDebugging
    )

    return request
  }

  private func addHeaders(
    to request: inout URLRequest,
    forDebugging isForDebugging: Bool
  ) {
    let requestId = UUID().uuidString

    let apiKey = isForDebugging ? (Store.shared.debugKey ?? "") : Store.shared.apiKey
    let auth = "Bearer \(apiKey)"
    let headers = [
      "Authorization": auth,
      "X-Platform": "iOS",
      "X-Platform-Environment": "SDK",
      "X-App-User-ID": Store.shared.appUserId ?? "",
      "X-Alias-ID": Store.shared.aliasId ?? "",
      "X-Vendor-ID": DeviceHelper.shared.vendorId,
      "X-App-Version": DeviceHelper.shared.appVersion,
      "X-OS-Version": DeviceHelper.shared.osVersion,
      "X-Device-Model": DeviceHelper.shared.model,
      "X-Device-Locale": DeviceHelper.shared.locale,
      "X-Device-Language-Code": DeviceHelper.shared.languageCode,
      "X-Device-Currency-Code": DeviceHelper.shared.currencyCode,
      "X-Device-Currency-Symbol": DeviceHelper.shared.currencySymbol,
      "X-Device-Timezone-Offset": DeviceHelper.shared.secondsFromGMT,
      "X-App-Install-Date": DeviceHelper.shared.appInstallDate,
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
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let bodyData = try? encoder.encode(eventsRequest)

    return Endpoint(
      components: Components(
        host: Api.Analytics.host,
        path: Api.version1 + "events",
        bodyData: bodyData
      ),
      method: .post
    )
  }
}

// MARK: - PaywallResponse
extension Endpoint where Response == PaywallResponse {
  static func paywall(
    withIdentifier: String? = nil,
    fromEvent event: EventData? = nil
  ) -> Self {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let bodyData: Data?

    if let id = withIdentifier {
      let bodyDict = ["identifier": id]
      bodyData = try? encoder.encode(bodyDict)
    } else if let event = event {
      let bodyDict = ["event": event.jsonData]
      bodyData = try? encoder.encode(bodyDict)
    } else {
      let bodyDict = PaywallRequest(appUserId: Store.shared.userId ?? "")
      bodyData = try? encoder.encode(bodyDict)
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
extension Endpoint where Response == ConfigResponse {
  static func config() -> Self {
    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "config"
      ),
      method: .get
    )
  }
}

// MARK: - ConfirmedAssignmentResponse
extension Endpoint where Response == ConfirmedAssignmentResponse {
  static func confirmedAssignment(_ confirmedAssignment: ConfirmedAssignments) -> Self {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let bodyData = try? encoder.encode(confirmedAssignment)

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
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let bodyData = try? encoder.encode(postback)

    return Endpoint(
      components: Components(
        host: Api.Base.host,
        path: Api.version1 + "postback",
        bodyData: bodyData
      ),
      method: .post
    )
  }
}
