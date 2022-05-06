//
//  PaywallResponse.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

struct PaywallsResponse: Decodable {
  var paywalls: [PaywallResponse]
}

struct PaywallResponse: Decodable {
  var id: String?
  var name: String?
  var slug: String?

  /// The ID of the paywall variant
  var variantId: String?

  /// The ID of the paywall experiment
  var experimentId: String?

  /// The identifier of the paywall
  var identifier: String?

  /// The URL of the paywall webpage
  var url: String
  var paywalljsEvent: String

  var presentationStyle: PaywallPresentationStyle = .sheet
  var backgroundColorHex: String?

  /// The products associated with the paywall.
  var products: [Product]

  /// The variables associated with the paywall
  var variables: [Variable]? = []

  var productVariables: [ProductVariable]? = []

  var idNonOptional: String {
    return id ?? ""
  }

  var responseLoadStartTime: Date?
  var responseLoadCompleteTime: Date?
  var responseLoadFailTime: Date?

  var webViewLoadStartTime: Date?
  var webViewLoadCompleteTime: Date?
  var webViewLoadFailTime: Date?

  var productsLoadStartTime: Date?
  var productsLoadCompleteTime: Date?
  var productsLoadFailTime: Date?

  var paywallBackgroundColor: UIColor {
    if let hexString = backgroundColorHex {
      return UIColor(hexString: hexString)
    }

    return UIColor.darkGray
  }

  var productIds: [String] {
    return products.map { $0.id }
  }

  var templateVariables: JSON {
    var variables: [String: Any] = [
      "user": Storage.shared.userAttributes,
      "device": DeviceHelper.shared.templateDevice.dictionary ?? [:]
    ]

    for variable in self.variables ?? [] {
      variables[variable.key] = variable.value
    }

    let values: [String: Any] = [
      "event_name": "template_variables",
      "variables": variables
    ]

    return JSON(values)
  }

  var templateProductVariables: JSON {
    var variables: [String: Any] = [:]

    for variable in productVariables ?? [] {
      variables[variable.key] = variable.value
    }

    // swiftlint:disable:next array_constructor
    let values: [String: Any] = [
      "event_name": "template_product_variables",
      "variables": variables
    ]

    return JSON(values)
  }

  var isFreeTrialAvailable: Bool? = false

  var templateSubstitutionsPrefix: TemplateSubstitutionsPrefix {
    let isFreeTrialAvailable = isFreeTrialAvailable ?? false
    // TODO: Jake decide if we should send `freeTrial` or `null`
    return TemplateSubstitutionsPrefix(
      eventName: "template_substitutions_prefix",
      prefix: isFreeTrialAvailable ? "freeTrial" : nil
    )
  }

  var templateProducts: TemplateProducts {
    return TemplateProducts(
      eventName: "products",
      products: products
    )
  }

  func getPaywallInfo(
    fromEvent: EventData?,
    calledByIdentifier: Bool = false
  ) -> PaywallInfo {
    return PaywallInfo(
      id: id ?? "unknown",
      identifier: identifier ?? "unknown",
      name: name ?? "unknown",
      slug: slug ?? "unknown",
      url: URL(string: url),
      productIds: productIds,
      fromEventData: fromEvent,
      calledByIdentifier: calledByIdentifier,
      responseLoadStartTime: responseLoadStartTime,
      responseLoadCompleteTime: responseLoadCompleteTime,
      webViewLoadStartTime: webViewLoadStartTime,
      webViewLoadCompleteTime: webViewLoadCompleteTime,
      productsLoadStartTime: productsLoadStartTime,
      productsLoadCompleteTime: productsLoadCompleteTime,
      variantId: variantId,
      experimentId: experimentId
    )
  }

  func getBase64EventsString(params: JSON? = nil) -> String {
    var templateVariables = self.templateVariables

    if let params = params {
      templateVariables["variables"]["params"] = params
    } else {
      templateVariables["variables"]["params"] = JSON([String: Any]())
    }

    let encodedStrings = [
      encodedEventString(DeviceHelper.shared.templateDevice),
      encodedEventString(templateProducts),
      encodedEventString(templateSubstitutionsPrefix),
      encodedEventString(templateVariables),
      encodedEventString(templateProductVariables)
    ]

    let string = "[" + encodedStrings.joined(separator: ",") + "]"

    let utf8str = string.data(using: .utf8)
    return utf8str?.base64EncodedString() ?? ""
  }

  private func encodedEventString<T: Codable>(_ input: T) -> String {
    if let data = try? JSONEncoder().encode(input) {
      return String(data: data, encoding: .utf8) ?? "{}"
    } else {
      return "{}"
    }
  }
}

extension PaywallResponse: Stubbable {
  static func stub() -> PaywallResponse {
    return PaywallResponse(
      url: "url",
      paywalljsEvent: "event",
      products: []
    )
  }
}
