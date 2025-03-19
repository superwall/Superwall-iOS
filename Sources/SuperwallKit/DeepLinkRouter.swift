//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/03/2025.
//

import Foundation

final class DeepLinkRouter {
  private unowned let webEntitlementRedeemer: WebEntitlementRedeemer
  private unowned let debugManager: DebugManager

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
      Task {
        await webEntitlementRedeemer.redeem(.code(code))
      }
      // TODO: Should be able to call depp link from cold app start
      return true
    } else {
      Task {
        await Superwall.shared.track(InternalSuperwallEvent.DeepLink(url: url))
      }
      return debugManager.handle(deepLinkUrl: url)
    }
  }
}
