//
//  CustomerCenterViewModel+Support.swift
//
//
//  Created by Jordan Morgan on 25/08/2026.
//

import Foundation

// MARK: - Support email

@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  var supportMailtoURL: URL? {
    SupportEmailComposer.mailtoURL(
      email: configuration.support.email,
      subject: strings.string("customer_center_support_subject"),
      body: strings.string("customer_center_support_body"),
      diagnostics: diagnostics
    )
  }

  private var diagnostics: SupportEmailDiagnostics {
    let env = dependencies.environment
    return .init(
      userId: env.userId,
      appVersion: env.appVersion,
      osVersion: env.osVersion,
      deviceModel: env.deviceModel,
      sdkVersion: env.sdkVersion,
      activeEntitlementIds: activeEntitlementIds,
      isSandbox: env.isSandbox
    )
  }

  /// Whether to show the contact-support path.
  ///
  /// Gated only on a support email being configured. `canOpenURL("mailto:…")` returns false on
  /// device unless the host app declares `mailto` in `LSApplicationQueriesSchemes`, so
  /// pre-gating on it would hide the path entirely for most apps. The tap handler falls back to
  /// a sheet showing the address instead.
  var supportEmailAvailable: Bool { supportMailtoURL != nil }
}
