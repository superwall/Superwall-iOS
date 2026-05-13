//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/11/2024.
//

import Foundation

struct AdServicesResponse: Decodable {
  // Backend (`paywall-next:/apple-search-ads/token`) returns
  // `{ status: "ok", attribution: {...} }` on success. Error states come
  // back as non-2xx with `{ status: "error", error: "..." }`, but those are
  // thrown by `CustomURLSession`'s Task.retrying before we ever decode the
  // body, so we only model the success shape here.
  let attribution: [String: JSON]
}
