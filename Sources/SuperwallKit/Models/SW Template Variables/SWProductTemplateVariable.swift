//
//  TemplateVariable.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation
import StoreKit

struct SWProductTemplateVariable: Encodable {
  var raw: SWProduct?
  var subscription: SWSubscriptionTemplateVariable?
  var trial: SWSubscriptionTemplateVariable?
  var discount: SWSubscriptionTemplateVariable?
  var lifetime: SWSubscriptionTemplateVariable?
  var identifier: String

  var locale: String?
  var languageCode: String?
  var currencyCode: String?
  var currencySymbol: String?

  init(product: SKProduct) {
    self.locale = product.priceLocale.identifier
    self.languageCode = product.priceLocale.languageCode
    self.currencyCode = product.priceLocale.currencyCode
    self.currencySymbol = product.priceLocale.currencySymbol
    self.identifier = product.productIdentifier

    let subscription = SWSubscriptionTemplateVariable(type: .subscription, product: product)
    let trial = SWSubscriptionTemplateVariable(type: .trial, product: product)
    // let discount = SWSubscriptionTemplateVariable(type: .discount, product: product)
    let lifetime = SWSubscriptionTemplateVariable(type: .lifetime, product: product)

    self.subscription = subscription.exists ? subscription : nil
    self.trial = trial.exists ? trial : nil
    // self.discount = discount.exists ? discount : nil
    self.lifetime = lifetime.exists ? lifetime : nil
  }
}
