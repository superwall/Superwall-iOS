//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

struct PaywallSession: Encodable {
  /// Paywall session ID
  let id = UUID().uuidString
  /// The start time of the paywall session
  let startAt: Date
  let endAt: Date?
  let hasTransaction: Bool
  let closedFromPaywall: Bool
//  let eventId: String

  // Installation
  /// If user installed the application today
  var didInstallToday: Bool = {
    guard let appInstallDate = DeviceHelper.shared.appInstallDate else {
      return false
    }
    return Calendar.current.isDateInToday(appInstallDate)
  }()
  /// When the user installed the app
  let installAt: String = DeviceHelper.shared.appInstalledAtString

  /// The experiment the paywall is associated with
  let experiment: Experiment

  /// Info about the trigger for the paywall session
  let trigger: Trigger

  /// The app session
  let appSession: AppSession

  /// Info about restoring
  let restore: RestoreInfo?

  /// Paywall nth impressions
  let paywallStats: PaywallStats

  /// Paywall info
  let paywall: Paywall

  /// Available products
  let products: Products

  /// The transaction
  let transaction: Transaction?

  /// The most on device user attributes
  let userAttributes: JSON
}
