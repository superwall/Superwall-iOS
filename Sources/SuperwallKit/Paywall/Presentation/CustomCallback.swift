//
//  CustomCallback.swift
//  SuperwallKit
//
//  Created by Ian Rumac on 2025.
//

import Foundation

/// The behavior of a custom callback request.
public enum CustomCallbackBehavior: String, Decodable {
  /// The paywall waits for the callback to complete before continuing.
  case blocking
  /// The paywall continues immediately; callback triggers onSuccess/onFailure.
  case nonBlocking = "non-blocking"
}

/// A custom callback request from the paywall.
public struct CustomCallback {
  /// The name of the callback.
  public let name: String

  /// Optional variables passed with the callback.
  public let variables: [String: Any]?

  public init(name: String, variables: [String: Any]? = nil) {
    self.name = name
    self.variables = variables
  }
}

/// The status of a custom callback result.
public enum CustomCallbackResultStatus: String {
  case success
  case failure
}

/// The result of handling a custom callback.
public struct CustomCallbackResult {
  /// The status of the callback result.
  public let status: CustomCallbackResultStatus

  /// Optional data to send back to the paywall.
  public let data: [String: Any]?

  public init(status: CustomCallbackResultStatus, data: [String: Any]? = nil) {
    self.status = status
    self.data = data
  }

  /// Creates a success result with optional data.
  public static func success(data: [String: Any]? = nil) -> CustomCallbackResult {
    return CustomCallbackResult(status: .success, data: data)
  }

  /// Creates a failure result with optional data.
  public static func failure(data: [String: Any]? = nil) -> CustomCallbackResult {
    return CustomCallbackResult(status: .failure, data: data)
  }
}
