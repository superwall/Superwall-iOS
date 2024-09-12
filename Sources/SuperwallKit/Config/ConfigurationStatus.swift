//
//  ConfigurationStatus.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/09/2024.
//

/// An enum representing the configuration status of the SDK.
@objc(SWKConfigurationStatus)
public enum ConfigurationStatus: Int {
  /// The configuration process is not yet completed.
  case pending

  /// The configuration process completed successfully.
  case configured

  /// The configuration process failed.
  case failed
}
