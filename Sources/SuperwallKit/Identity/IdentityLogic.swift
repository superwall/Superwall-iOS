//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation

enum IdentityLogic {
  enum IdentityConfigurationAction {
    case reset
    case loadAssignments
  }

  static func generateAlias() -> String {
    return "$SuperwallAlias:\(UUID().uuidString)"
  }

  static func mergeAttributes(
    _ newAttributes: [String: Any?],
    with oldAttributes: [String: Any],
    appInstalledAtString: String
  ) -> [String: Any] {
    var mergedAttributes = oldAttributes

    for key in newAttributes.keys {
      if key == "$is_standard_event" {
        continue
      }
      if key == "$application_installed_at" {
        continue
      }

      var key = key

      if key.starts(with: "$") { // replace dollar signs
        key = key.replacingOccurrences(of: "$", with: "")
      }

      if let value = newAttributes[key] {
        mergedAttributes[key] = value
      } else {
        mergedAttributes[key] = nil
      }
    }

    // we want camel case
    mergedAttributes["applicationInstalledAt"] = appInstalledAtString

    return mergedAttributes
  }

  /// Logic to figure out whether to get assignments before firing triggers.
  ///
  /// The logic is:
  /// - If is logged in to account that existed PRE static config, get assignments.
  /// - If anonymous, is NOT first app open since install, and existed PRE static config, get assignments.
  /// - If logged in POST static config, don't get assignments.
  /// - If anonymous, is NOT first app open since install, and existed POST static config, don't get assignments.
  /// - If anonymous, IS first app open since install, existed PRE static, don't get assignments.
  /// - If anonymous, IS first app open since install, existed POST static, don't get assignments.
  static func shouldGetAssignments(
    isLoggedIn: Bool,
    neverCalledStaticConfig: Bool,
    isFirstAppOpen: Bool
  ) -> Bool {
    if neverCalledStaticConfig {
      if isLoggedIn || !isFirstAppOpen {
        return true
      }
    }

    return false
  }

  /// Removes white spaces and new lines
  ///
  /// - Returns: An optional `String` of the trimmed `userId`. This is `nil`
  /// if the `userId` is empty.
  static func sanitize(userId: String) -> String? {
    let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    if userId.isEmpty {
      return nil
    }
    return userId
  }
}
