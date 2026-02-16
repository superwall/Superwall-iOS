//
//  SWProduct.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//
import StoreKit

struct SWProduct: Codable {
  var localizedDescription: String
  var localizedTitle: String
  var price: Decimal
  var priceLocale: String
  var productIdentifier: String
  var isDownloadable: Bool
  var downloadContentLengths: [Double]
  var contentVersion: String
  var downloadContentVersion: String
  var isFamilyShareable: Bool?
  var subscriptionGroupIdentifier: String?
  var discounts: [SWProductDiscount]?
  var subscriptionPeriod: SWProductSubscriptionPeriod?
  var introductoryPrice: SWProductDiscount?

  init(product: SK1Product) {
    localizedDescription = product.localizedDescription
    localizedTitle = product.localizedTitle
    price = product.price as Decimal
    priceLocale = product.priceLocale.identifier
    productIdentifier = product.productIdentifier
    isDownloadable = product.isDownloadable
    downloadContentLengths = product.downloadContentLengths.map { $0.doubleValue }
    #if os(visionOS)
    contentVersion = ""
    #else
    contentVersion = product.contentVersion
    #endif
    downloadContentVersion = product.downloadContentVersion

    if #available(iOS 14.0, *) {
      isFamilyShareable = product.isFamilyShareable
    }

    discounts = product.discounts.map(SWProductDiscount.init)

    subscriptionGroupIdentifier = product.subscriptionGroupIdentifier

    if let period = product.subscriptionPeriod {
      subscriptionPeriod = SWProductSubscriptionPeriod(
        period: period,
        numberOfPeriods: 1
      )
    }
    if let discount = product.introductoryPrice {
      introductoryPrice = SWProductDiscount(discount: discount)
    }
  }

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  init(product: SK2Product) {
    localizedDescription = product.description
    localizedTitle = product.displayName
    price = product.price
    priceLocale = product.priceFormatStyle.locale.identifier
    productIdentifier = product.id
    isDownloadable = false
    downloadContentLengths = []
    contentVersion = ""
    downloadContentVersion = ""

    isFamilyShareable = product.isFamilyShareable

    discounts = product.subscription?.promotionalOffers.map { offer in
      SWProductDiscount(offer: offer, fromProduct: product)
    }

    subscriptionGroupIdentifier = product.subscription?.subscriptionGroupID

    if let subscription = product.subscription {
      subscriptionPeriod = SWProductSubscriptionPeriod(
        period: subscription.subscriptionPeriod,
        numberOfPeriods: 1
      )
    }
    if let offer = product.subscription?.introductoryOffer {
      introductoryPrice = SWProductDiscount(offer: offer, fromProduct: product)
    }
  }

  init(product: StripeProductType) {
    localizedDescription = "" // product.description
    localizedTitle = "" // product.displayName
    price = product.price
    priceLocale = product.priceLocale.identifier
    productIdentifier = product.productIdentifier
    isDownloadable = false
    downloadContentLengths = []
    contentVersion = ""
    downloadContentVersion = ""

    isFamilyShareable = product.isFamilyShareable

    if let offer = product.subscriptionIntroOffer {
      discounts = [SWProductDiscount(offer: offer, fromProduct: product)]
    }

    subscriptionGroupIdentifier = product.subscriptionGroupIdentifier

    if let subscriptionPeriod = product.subscriptionPeriod {
      self.subscriptionPeriod = SWProductSubscriptionPeriod(
        period: subscriptionPeriod,
        numberOfPeriods: 1
      )
    }
    if let offer = product.subscriptionIntroOffer {
      introductoryPrice = SWProductDiscount(offer: offer, fromProduct: product)
    }
  }

  init(
    localizedDescription: String,
    localizedTitle: String,
    price: Decimal,
    priceLocale: String,
    productIdentifier: String,
    isDownloadable: Bool,
    downloadContentLengths: [Double],
    contentVersion: String,
    downloadContentVersion: String,
    isFamilyShareable: Bool?,
    subscriptionGroupIdentifier: String?,
    discounts: [SWProductDiscount]?,
    subscriptionPeriod: SWProductSubscriptionPeriod?,
    introductoryPrice: SWProductDiscount?
  ) {
    self.localizedDescription = localizedDescription
    self.localizedTitle = localizedTitle
    self.price = price
    self.priceLocale = priceLocale
    self.productIdentifier = productIdentifier
    self.isDownloadable = isDownloadable
    self.downloadContentLengths = downloadContentLengths
    self.contentVersion = contentVersion
    self.downloadContentVersion = downloadContentVersion
    self.isFamilyShareable = isFamilyShareable
    self.subscriptionGroupIdentifier = subscriptionGroupIdentifier
    self.discounts = discounts
    self.subscriptionPeriod = subscriptionPeriod
    self.introductoryPrice = introductoryPrice
  }

  /// Creates a blank SWProduct with empty/default values.
  static func blank() -> SWProduct {
    SWProduct(
      localizedDescription: "",
      localizedTitle: "",
      price: 0,
      priceLocale: "",
      productIdentifier: "",
      isDownloadable: false,
      downloadContentLengths: [],
      contentVersion: "",
      downloadContentVersion: "",
      isFamilyShareable: nil,
      subscriptionGroupIdentifier: nil,
      discounts: nil,
      subscriptionPeriod: nil,
      introductoryPrice: nil
    )
  }
}
