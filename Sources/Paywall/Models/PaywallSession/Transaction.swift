//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Transaction: Encodable {
    let startAt: Date
    let endAt: Date
    let failAt: Date
    let abandonAt: Date
    enum Outcome: String, Encodable {
      case completed
      case failed
      case abandoned
      case restored
      case restoreFailed = "restore_failed"
      case noTransaction = "no_transaction"
    }
    let outcome: Outcome

    struct TransactionProduct: Encodable {
      let id: String
      
      struct Period: Encodable {
        /// The period, e.g. "year"
        let value: String
        /// The alternative period of the product, e.g. "1 yr"
        let alternative: String
        /// The period of the product ending in ly, e.g. "yearly"
        let ly: String
        /// The localized period, e.g. "1 yr"
        let localized: String
        /// The weekly duration of the product, e.g. "52"
        let weeks: String
        /// The monthly duration of the product, e.g. "12"
        let months: String
        /// The years duration of the product, e.g. "1"
        let years: String
      }
      /// Info about the period of the
      let period: Period

      struct TrialPeriod: Encodable {
        /// The days in the trial period, e.g. "2"
        let days: String
        /// The weeks in the trial period, e.g. "2"
        let weeks: String
        /// The months in the trial period, e.g. "12"
        let months: String
        /// The years in the trial period, e.g. "0"
        let years: String
        /// The text version of the trial period, e.g. "7-day"
        let text: String
      }
      /// The trial period associated with the product, if any.
      let trialPeriod: TrialPeriod?

      struct Price: Encodable {
        struct LocalizedPrice: Encodable {
          /// The localized price, e.g.  "$89.99"
          let value: String
          /// The amount the product costs per day, e.g. "$0.25"
          let dailyPrice: String
          /// The amount the product costs per week, e.g. "$0.25"
          let weeklyPrice: String
          /// The amount the product costs per month, e.g.  "$0.25"
          let monthlyPrice: String
          /// The amount the product costs per year, e.g.  "$0.25"
          let yearlyPrice: String
        }
        let localized: LocalizedPrice

        struct RawPrice: Encodable {
          /// The raw localized price, e.g.  "89.99"
          let value: String
          /// The raw localized price per day, e.g. "0.25"
          let dailyPrice: String
          /// The raw localized price per week, e.g. "0.25"
          let weeklyPrice: String
          /// The raw localized price per month, e.g.  "0.25"
          let monthlyPrice: String
          /// The amount the product costs per year, e.g.  "$0.25"
          let yearlyPrice: String
        }
        let raw: RawPrice
      }
      /// The price of the transacted product
      let price: Price

      /// The locale of the transacted product
      let locale: String

      struct Currency: Encodable {
        /// The currency code of the transacted product, e.g.  "USD"
        let code: String
        /// The currency symbol of the transacted product, e.g.  "$"
        let symbol: String
      }
      /// Info about the currency of the transacted product
      let currency: Currency

      /// The language code of the transacted product, e.g. en
      let languageCode: String
    }
    /// The product from the transaction
    let product: TransactionProduct
  }
}
