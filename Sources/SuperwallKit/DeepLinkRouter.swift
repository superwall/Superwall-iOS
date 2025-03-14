//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/03/2025.
//

import Foundation

final class DeepLinkRouter {
  private let webEntitlementRedeemer: WebEntitlementRedeemer
  private let debugManager: DebugManager

  init(
    webEntitlementRedeemer: WebEntitlementRedeemer,
    debugManager: DebugManager
  ) {
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self.debugManager = debugManager
  }

  func route(url: URL) -> Bool {
    let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)

    // Check if the URL matches the expected web2app format
    if url.host == "superwall",
      url.path == "/redeem",
      let code = urlComponents?.queryItems?.first(where: { $0.name == "code" })?.value {
      // It's a web2app redemption link
      // TODO: Is this firstRedemption? What if they're trying to redeem a code that's already been redeemed?
      // TODO: Should we put in the existing codes here or somewhere else?
      let redeemable = Redeemable(code: code, firstRedemption: true)
      Task {
        await webEntitlementRedeemer.redeem(codes: [redeemable])
      }
      return true
    } else {
      return debugManager.handle(deepLinkUrl: url)
    }
  }
}
// TODO: when saving code, firstRedemptoin as false
