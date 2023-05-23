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
  /// The id of the paywall in the database.
  var databaseId: String

  /// The identifier of the paywall
  var identifier: String

  /// The name of the paywall
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

  /// Indicates whether the caching of the paywall is enabled or not.
  let onDeviceCache: OnDeviceCaching

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

  /// The reason for closing the paywall.
  var closeReason: PaywallCloseReason?

  /// Determines whether a paywall executes the
  /// ``Superwall/register(event:params:handler:feature:)`` feature block if the
  /// user does not purchase.
  var featureGating: FeatureGatingBehavior

  enum CodingKeys: String, CodingKey {
    case id
    case identifier
    case name
    case url
    case htmlSubstitutions = "paywalljsEvent"
    case presentationStyle = "presentationStyleV2"
    case presentationCondition
    case backgroundColorHex
    case products
    case featureGating
    case onDeviceCache

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

    featureGating = try values.decodeIfPresent(FeatureGatingBehavior.self, forKey: .featureGating) ?? .nonGated
    onDeviceCache = try values.decodeIfPresent(OnDeviceCaching.self, forKey: .onDeviceCache) ?? .disabled
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
    productVariables: [ProductVariable]? = [],
    swTemplateProductVariables: [ProductVariable]? = [],
    isFreeTrialAvailable: Bool = false,
    featureGating: FeatureGatingBehavior = .nonGated,
    onDeviceCache: OnDeviceCaching = .disabled
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
    self.productVariables = productVariables
    self.swProductVariablesTemplate = swTemplateProductVariables
    self.isFreeTrialAvailable = isFreeTrialAvailable
    self.featureGating = featureGating
    self.onDeviceCache = onDeviceCache
  }

  func getInfo(
    fromEvent: EventData?,
    factory: TriggerSessionManagerFactory
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
      responseLoadFailTime: responseLoadingInfo.failAt,
      webViewLoadStartTime: webviewLoadingInfo.startAt,
      webViewLoadCompleteTime: webviewLoadingInfo.endAt,
      webViewLoadFailTime: webviewLoadingInfo.failAt,
      productsLoadStartTime: productsLoadingInfo.startAt,
      productsLoadFailTime: productsLoadingInfo.failAt,
      productsLoadCompleteTime: productsLoadingInfo.endAt,
      experiment: experiment,
      paywalljsVersion: paywalljsVersion,
      isFreeTrialAvailable: isFreeTrialAvailable,
      factory: factory,
      featureGatingBehavior: featureGating,
      closeReason: closeReason
    )
  }

  mutating func overrideProductsIfNeeded(from paywall: Paywall) {
    products = paywall.products
    productIds = paywall.productIds
    swProducts = paywall.swProducts
    productVariables = paywall.productVariables
    swProductVariablesTemplate = paywall.swProductVariablesTemplate
    isFreeTrialAvailable = paywall.isFreeTrialAvailable
    productsLoadingInfo = paywall.productsLoadingInfo
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
