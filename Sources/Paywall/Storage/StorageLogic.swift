//
//  StoreLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum StorageLogic {
  static func generateAlias() -> String {
    return "$SuperwallAlias:\(UUID().uuidString)"
  }

  static func getV1TriggerDictionary(from triggers: Set<Trigger>) -> [String: Bool] {
    // swiftlint:disable:next array_constructor
    var output: [String: Bool] = [:]
    let triggers = triggers.filter { $0.triggerVersion == .v1 }

    for trigger in triggers {
      output[trigger.eventName] = true
    }

    return output
  }

  static func getV2TriggerDictionary(from triggers: Set<Trigger>) -> [String: TriggerV2] {
    let v2TriggersDictionary = triggers
      .compactMap { trigger in
        switch trigger.triggerVersion {
        case .v1:
          return nil
        case .v2(let triggerV2):
          return triggerV2
        }
      }
      .reduce([String: TriggerV2]()) { (result, trigger: TriggerV2) in
        var result = result
        result[trigger.eventName] = trigger
        return result
      }

    return v2TriggersDictionary
  }

  static func mergeAttributes(
    _ newAttributes: [String: Any],
    with oldAttributes: [String: Any]
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
    mergedAttributes["applicationInstalledAt"] = DeviceHelper.shared.appInstalledAtString

    return mergedAttributes
  }
}
