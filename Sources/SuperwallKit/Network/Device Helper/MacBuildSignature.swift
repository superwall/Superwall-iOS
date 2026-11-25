//
//  MacBuildSignature.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/11/2026.
//

import Foundation

/// Tells a TestFlight or development build of a Mac app from a released one by
/// how it's signed.
///
/// A Mac app's receipt has the same path in every kind of build, so the path
/// can't tell them apart as it does on iOS.
enum MacBuildSignature {
  /// What a signature satisfies when the build isn't a released one.
  enum SandboxRequirement: String, CaseIterable {
    /// Apple's TestFlight Beta Distribution certificate, which it signs
    /// TestFlight builds with.
    case testFlight = "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.25.1]"

    /// A developer's own Apple Development certificate.
    case development = "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.12]"
  }

  /// The entitlement Xcode adds to a build it runs, whatever it's signed with,
  /// so that the debugger can attach. Neither the App Store nor notarization
  /// accepts an app that has it.
  static let debuggerEntitlement = "com.apple.security.get-task-allow"

  /// Whether a signature belongs to a TestFlight or development build.
  ///
  /// Anything else counts as released, including an app sold outside the Mac
  /// App Store.
  ///
  /// - Parameters:
  ///   - allowsDebugger: Whether the app has the ``debuggerEntitlement``.
  ///   - satisfies: Whether the signature satisfies a requirement.
  static func isSandbox(
    allowsDebugger: Bool,
    satisfies: (SandboxRequirement) -> Bool
  ) -> Bool {
    if allowsDebugger {
      return true
    }
    return SandboxRequirement.allCases.contains(where: satisfies)
  }
}

#if os(macOS) || targetEnvironment(macCatalyst)
import Security

extension MacBuildSignature {
  /// Whether the running app is a TestFlight or development build.
  ///
  /// Read from disk once, because the signature is the same for as long as
  /// the app runs.
  static let isSandbox: Bool = {
    var runningCode: SecCode?
    guard
      SecCodeCopySelf([], &runningCode) == errSecSuccess,
      let runningCode = runningCode
    else {
      return false
    }
    var staticCode: SecStaticCode?
    guard
      SecCodeCopyStaticCode(runningCode, [], &staticCode) == errSecSuccess,
      let staticCode = staticCode
    else {
      return false
    }
    return isSandbox(staticCode)
  }()

  /// Starts reading ``isSandbox`` off the calling thread, so that whoever asks
  /// first waits only for what's left of the read.
  static func readInBackground() {
    DispatchQueue.global(qos: .userInitiated).async {
      _ = isSandbox
    }
  }

  /// Whether the app or executable at `url` is a TestFlight or development
  /// build. `false` when its signature can't be read.
  static func isSandbox(codeAt url: URL) -> Bool {
    var staticCode: SecStaticCode?
    guard
      SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
      let staticCode = staticCode
    else {
      return false
    }
    return isSandbox(staticCode)
  }

  private static func isSandbox(_ code: SecStaticCode) -> Bool {
    var signingInformation: CFDictionary?
    guard
      SecCodeCopySigningInformation(
        code,
        SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation),
        &signingInformation
      ) == errSecSuccess,
      let information = signingInformation as? [String: Any]
    else {
      return false
    }
    let entitlements = information[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
    let allowsDebugger = entitlements?[debuggerEntitlement] as? Bool ?? false

    return isSandbox(allowsDebugger: allowsDebugger) { sandboxRequirement in
      var requirement: SecRequirement?
      guard
        SecRequirementCreateWithString(
          sandboxRequirement.rawValue as CFString,
          [],
          &requirement
        ) == errSecSuccess,
        let requirement = requirement
      else {
        return false
      }
      // Checks the signature and its certificates without reading every file
      // in the app, which takes seconds for a large one.
      return SecStaticCodeCheckValidity(
        code,
        SecCSFlags(rawValue: kSecCSBasicValidateOnly),
        requirement
      ) == errSecSuccess
    }
  }
}
#endif
