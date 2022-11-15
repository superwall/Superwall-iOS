//
//  Paywall.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

struct Paywalls: Decodable {
  var paywalls: [Paywall]
}

struct Paywall: Decodable {
  var databaseId: String

  /// The identifier of the paywall
  var identifier: String

  let name: String

  /// The URL of the paywall webpage
  let url: URL

  /// Contains the website modifications that are made on the paywall editor to be accepted
  /// by the webview.
  let htmlSubstitutions: String

  struct Presentation {
    var style: PaywallPresentationStyle = .modal
    let condition: PresentationCondition

    init(
      style: PaywallPresentationStyle,
      condition: PresentationCondition
    ) {
      self.style = style
      self.condition = condition
    }
  }
  let presentation: Presentation

  let backgroundColorHex: String
  let backgroundColor: UIColor

  /// The products associated with the paywall.
  var products: [Product] {
    didSet {
      productIds = products.map { $0.id }
    }
  }

  var responseLoadingInfo: LoadingInfo
  var webviewLoadingInfo: LoadingInfo
  var productsLoadingInfo: LoadingInfo

  // MARK: - Added by client
  /// An array of the ids of paywall products.
  ///
  /// This is set on init and whenever products are updated.
  var productIds: [String]

  /// The experiment associated with the paywall.
  var experiment: Experiment?

  /// An ordered list of SWProducts that this paywall uses. This is accessed by the trigger session.
  var swProducts: [SWProduct]? = []

  /// The product variables associated with the paywall.
  ///
  /// Each contains a product type and their attributes.
  var productVariables: [ProductVariable]? = []

  /// As of yet unused product variables in a different format.
  ///
  /// Each consists of a type and a dictionary of SWTemplateVariable properties.
  var swProductVariablesTemplate: [ProductVariable]? = []

  /// The paywall.js version being used. Added when the website fires `onReady`.
  var paywalljsVersion: String?

  /// Determines whether a free trial is available or not.
  var isFreeTrialAvailable = false

  enum CodingKeys: String, CodingKey {
    case id
    case identifier
    case name
    case slug
    case url
    case htmlSubstitutions = "paywalljsEvent"
    case presentationStyle = "presentationStyleV2"
    case presentationCondition
    case backgroundColorHex
    case products

    case responseLoadStartTime
    case responseLoadCompleteTime
    case responseLoadFailTime

    case webViewLoadStartTime
    case webViewLoadCompleteTime
    case webViewLoadFailTime

    case productsLoadStartTime
    case productsLoadCompleteTime
    case productsLoadFailTime
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    databaseId = try values.decode(String.self, forKey: .id)
    identifier = try values.decode(String.self, forKey: .identifier)
    name = try values.decode(String.self, forKey: .name)
    url = try values.decode(URL.self, forKey: .url)
    htmlSubstitutions = try values.decode(String.self, forKey: .htmlSubstitutions)

    let presentationStyle = try values.decode(PaywallPresentationStyle.self, forKey: .presentationStyle)
    let presentationCondition = try values.decode(PresentationCondition.self, forKey: .presentationCondition)

    presentation = Presentation(
      style: presentationStyle,
      condition: presentationCondition
    )

    backgroundColorHex = try values.decode(String.self, forKey: .backgroundColorHex)
    let backgroundColor = UIColor(hexString: backgroundColorHex)
    self.backgroundColor = backgroundColor

    products = try values.decode([Product].self, forKey: .products)
    productIds = products.map { $0.id }

    let responseLoadStartTime = try values.decodeIfPresent(Date.self, forKey: .responseLoadStartTime)
    let responseLoadCompleteTime = try values.decodeIfPresent(Date.self, forKey: .responseLoadCompleteTime)
    let responseLoadFailTime = try values.decodeIfPresent(Date.self, forKey: .responseLoadFailTime)
    responseLoadingInfo = LoadingInfo(
      startAt: responseLoadStartTime,
      endAt: responseLoadCompleteTime,
      failAt: responseLoadFailTime
    )

    let webviewLoadStartTime = try values.decodeIfPresent(Date.self, forKey: .webViewLoadStartTime)
    let webviewLoadCompleteTime = try values.decodeIfPresent(Date.self, forKey: .webViewLoadCompleteTime)
    let webviewLoadFailTime = try values.decodeIfPresent(Date.self, forKey: .webViewLoadFailTime)
    webviewLoadingInfo = LoadingInfo(
      startAt: webviewLoadStartTime,
      endAt: webviewLoadCompleteTime,
      failAt: webviewLoadFailTime
    )

    let productsLoadStartTime = try values.decodeIfPresent(Date.self, forKey: .productsLoadStartTime)
    let productsLoadCompleteTime = try values.decodeIfPresent(Date.self, forKey: .productsLoadCompleteTime)
    let productsLoadFailTime = try values.decodeIfPresent(Date.self, forKey: .productsLoadFailTime)
    productsLoadingInfo = LoadingInfo(
      startAt: productsLoadStartTime,
      endAt: productsLoadCompleteTime,
      failAt: productsLoadFailTime
    )
  }

  init(
    databaseId: String,
    identifier: String,
    name: String,
    experiment: Experiment? = nil,
    url: URL,
    htmlSubstitutions: String,
    presentation: Paywall.Presentation,
    backgroundColorHex: String,
    backgroundColor: UIColor,
    products: [Product],
    productIds: [String],
    responseLoadingInfo: LoadingInfo,
    webviewLoadingInfo: LoadingInfo,
    productsLoadingInfo: LoadingInfo,
    paywalljsVersion: String,
    swProducts: [SWProduct]? = [],
    variables: [ProductVariable]? = [],
    swTemplateProductVariables: [ProductVariable]? = [],
    isFreeTrialAvailable: Bool = false
  ) {
    self.databaseId = databaseId
    self.identifier = identifier
    self.name = name
    self.experiment = experiment
    self.url = url
    self.htmlSubstitutions = htmlSubstitutions
    self.presentation = presentation
    self.backgroundColor = backgroundColor
    self.backgroundColorHex = backgroundColorHex
    self.products = products
    self.productIds = productIds
    self.responseLoadingInfo = responseLoadingInfo
    self.webviewLoadingInfo = webviewLoadingInfo
    self.productsLoadingInfo = productsLoadingInfo
    self.paywalljsVersion = paywalljsVersion
    self.swProducts = swProducts
    self.productVariables = variables
    self.swProductVariablesTemplate = swTemplateProductVariables
    self.isFreeTrialAvailable = isFreeTrialAvailable
  }

  func getInfo(
    fromEvent: EventData?
  ) -> PaywallInfo {
    return PaywallInfo(
      databaseId: databaseId,
      identifier: identifier,
      name: name,
      url: url,
      products: products,
      fromEventData: fromEvent,
      responseLoadStartTime: responseLoadingInfo.startAt,
      responseLoadCompleteTime: responseLoadingInfo.endAt,
      webViewLoadStartTime: webviewLoadingInfo.startAt,
      webViewLoadCompleteTime: webviewLoadingInfo.endAt,
      productsLoadStartTime: productsLoadingInfo.startAt,
      productsLoadFailTime: productsLoadingInfo.failAt,
      productsLoadCompleteTime: productsLoadingInfo.endAt,
      experiment: experiment,
      paywalljsVersion: paywalljsVersion
    )
  }
}

// MARK: - Equatable
extension Paywall: Equatable {
  static func == (lhs: Paywall, rhs: Paywall) -> Bool {
    return lhs.databaseId == rhs.databaseId
  }
}

// swiftlint:disable force_unwrapping

// MARK: - Stubbable
extension Paywall: Stubbable {
  static func stub() -> Paywall {
    return Paywall(
      databaseId: "id",
      identifier: "identifier",
      name: "abc",
      url: URL(string: "https://google.com")!,
      htmlSubstitutions: "",
      presentation: Presentation(
        style: .modal,
        condition: .checkUserSubscription
      ),
      backgroundColorHex: "",
      backgroundColor: .black,
      products: [],
      productIds: [],
      responseLoadingInfo: .init(),
      webviewLoadingInfo: .init(),
      productsLoadingInfo: .init(),
      paywalljsVersion: ""
    )
  }
}
