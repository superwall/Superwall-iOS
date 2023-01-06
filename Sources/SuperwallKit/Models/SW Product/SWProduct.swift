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
    contentVersion = product.contentVersion
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
}
