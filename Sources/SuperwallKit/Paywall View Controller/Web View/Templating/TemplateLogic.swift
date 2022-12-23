//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/10/2022.
//

import Foundation

enum TemplateLogic {
  /// Turns input variables into a base64 encoded template to be passed to the
  /// webview.
  static func getBase64EncodedTemplates(
    from paywall: Paywall,
    withParams params: JSON?,
    identityManager: IdentityManager,
    deviceHelper: DeviceHelper
  ) -> String {
    let productsTemplate = ProductTemplate(
      eventName: "products",
      products: paywall.products
    )

    let variablesTemplate = Variables(
      productVariables: paywall.productVariables,
      params: params,
      userAttributes: identityManager.userAttributes,
      templateDeviceDictionary: deviceHelper.templateDevice.dictionary()
    ).templated()

    let freeTrialTemplate = FreeTrialTemplate(
      eventName: "template_substitutions_prefix",
      prefix: paywall.isFreeTrialAvailable ? "freeTrial" : nil
    )

    let swProductTemplate = swProductTemplate(
      from: paywall.swProductVariablesTemplate ?? []
    )

    let encodedTemplates = [
      utf8Encoded(productsTemplate),
      utf8Encoded(variablesTemplate),
      utf8Encoded(freeTrialTemplate),
      utf8Encoded(swProductTemplate)
    ]

    let templatesString = "[" + encodedTemplates.joined(separator: ",") + "]"
    let templatesData = templatesString.data(using: .utf8)

    return templatesData?.base64EncodedString() ?? ""
  }

  private static func utf8Encoded<T: Codable>(_ input: T) -> String {
    if let data = try? JSONEncoder().encode(input) {
      return String(data: data, encoding: .utf8) ?? "{}"
    } else {
      return "{}"
    }
  }

  private static func swProductTemplate(
    from swProductTemplateVariables: [ProductVariable]
  ) -> JSON {
    var variables: [String: Any] = [:]

    for variable in swProductTemplateVariables {
      variables[variable.type.rawValue] = JSON(variable.attributes)
    }

    // swiftlint:disable:next array_constructor
    let values: [String: Any] = [
      "event_name": "template_product_variables",
      "variables": variables
    ]

    return JSON(values)
  }
}
