//
//  SWProduct.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import StoreKit

struct SWProduct: Codable {
  var localizedDescription: String
  var localizedTitle: String
  var price: Double
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

  init(product: SKProduct) {
    localizedDescription = product.localizedDescription
    localizedTitle = product.localizedTitle
    price = product.price.doubleValue
    priceLocale = product.priceLocale.identifier
    productIdentifier = product.productIdentifier
    isDownloadable = product.isDownloadable
    downloadContentLengths = product.downloadContentLengths.map { $0.doubleValue }
    contentVersion = product.contentVersion
    downloadContentVersion = product.downloadContentVersion

    if #available(iOS 14.0, *) {
      isFamilyShareable = product.isFamilyShareable
    }

    if #available(iOS 12.2, *) {
      discounts = product.discounts.map(SWProductDiscount.init)
    }

    if #available(iOS 12.0, *) {
      subscriptionGroupIdentifier = product.subscriptionGroupIdentifier
    }

    if #available(iOS 12.2, *) {
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
  }
}
