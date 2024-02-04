//
//  Validation.swift
//  TPInAppReceipt
//
//  Created by Pavel Tikhonenko on 19/01/17.
//  Copyright © 2017-2021 Pavel Tikhonenko. All rights reserved.
//
// swiftlint:disable cyclomatic_complexity function_body_length

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(watchOS)
import UIKit
import WatchKit
#elseif os(macOS)
import IOKit
import Cocoa
#else
import VisionKit
#endif

import CommonCrypto

/// A InAppReceipt extension helps to validate the receipt
extension InAppReceipt {
  /// Determine whether receipt is valid or not
  ///
  /// - Returns:`true` if the receipt is valid, otherwise `false`
  var isValid: Bool {
    do {
      try validate()
      return true
    } catch {
      return false
    }
  }

  /// Computed SHA-1 hash, used to validate the receipt.
  private var computedHash: Data {
    let uuidData = guid()
    let opaqueData = opaqueValue
    let bundleIdData = bundleIdentifierData

    var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    var ctx = CC_SHA1_CTX()
    CC_SHA1_Init(&ctx)
    CC_SHA1_Update(&ctx, [UInt8](uuidData), CC_LONG(uuidData.count))
    CC_SHA1_Update(&ctx, [UInt8](opaqueData), CC_LONG(opaqueData.count))
    CC_SHA1_Update(&ctx, [UInt8](bundleIdData), CC_LONG(bundleIdData.count))
    CC_SHA1_Final(&hash, &ctx)

    return Data(hash)
  }

  /// Validate In App Receipt
  ///
  /// - throws: An error in the InAppReceipt domain, if verification fails
  private func validate() throws {
    try verifyHash()
    try verifyBundleIdentifierAndVersion()
    try verifySignature()
  }

  /// Verify only hash
  /// Should be equal to `receiptHash` value
  ///
  /// - throws: An error in the InAppReceipt domain, if verification fails
  private func verifyHash() throws {
    if computedHash != receiptHash {
      throw IARError.validationFailed(reason: .hashValidation)
    }
  }

  /// Verify that the bundle identifier in the receipt matches a hard-coded constant containing the CFBundleIdentifier value you expect in the Info.plist file. If they do not match, validation fails.
  /// Verify that the version identifier string in the receipt matches a hard-coded constant containing the CFBundleShortVersionString value (for macOS) or the CFBundleVersion value (for iOS) that you expect in the Info.plist file.
  ///
  ///
  /// - throws: An error in the InAppReceipt domain, if verification fails
  private func verifyBundleIdentifierAndVersion() throws {
    try verifyBundleIdentifier()
    try verifyBundleVersion()
  }

  /// Verify that the bundle identifier in the receipt matches a hard-coded constant containing the CFBundleIdentifier value you expect in the Info.plist file. If they do not match, validation fails.
  ///
  ///
  /// - throws: An error in the InAppReceipt domain, if verification fails
  private func verifyBundleIdentifier() throws {
    guard
      let bid = Bundle.main.bundleIdentifier,
      bid == bundleIdentifier
    else {
      throw IARError.validationFailed(reason: .bundleIdentifierVerification)
    }
  }

  /// Verify that the version identifier string in the receipt matches a hard-coded constant containing the CFBundleShortVersionString value (for macOS) or the CFBundleVersion value (for iOS) that you expect in the Info.plist file.
  ///
  ///
  /// - throws: An error in the InAppReceipt domain, if verification fails
  private func verifyBundleVersion() throws {
    guard
      let version = Bundle.main.receiptSpecificAppVersion,
      version == appVersion
    else {
      throw IARError.validationFailed(reason: .bundleVersionVerification)
    }
  }

  /// Verify signature inside pkcs7 container
  ///
  /// - throws: An error in the InAppReceipt domain, if verification can't be completed
  private func verifySignature() throws {
    try checkAppleRootCertExistence()

    // only check certificate chain of trust and signature validity after these version
    #if DEBUG
    try checkSignatureValidity()
    #else
    try checkChainOfTrust()
    try checkSignatureValidity()
    #endif
  }

  /// Verifies existence of Apple Root Certificate in bundle
  ///
  /// - throws: An error in the InAppReceipt domain, if Apple Root Certificate does not exist
  private func checkAppleRootCertExistence() throws {
    guard
      let certPath = rootCertificatePath,
      FileManager.default.fileExists(atPath: certPath)
    else {
      throw IARError.validationFailed(reason: .signatureValidation(.appleIncRootCertificateNotFound))
    }
  }

  private func checkChainOfTrust() throws {
    // Validate chain of trust of certificate
    // Ensure the iTunes certificate included in the receipt is indeed signed by Apple root cert
    // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/trust/creating_a_trust_object

    // root cert data is loaded from the bundled Apple Root Certificate
    guard
      let path = rootCertificatePath,
      let rootCertData = try? Data(contentsOf: URL(fileURLWithPath: path))
    else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadAppleIncRootCertificate))
    }

    guard let iTunesCertData = iTunesCertificateData else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadiTunesCertificate))
    }

    guard let worldwideDeveloperCertData = worldwideDeveloperCertificateData else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadWorldwideDeveloperCertificate))
    }

    guard let rootCertSec = SecCertificateCreateWithData(nil, rootCertData as CFData) else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadAppleIncRootCertificate))
    }

    guard let iTunesCertSec = SecCertificateCreateWithData(nil, iTunesCertData as CFData) else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadiTunesCertificate))
    }

    guard let worldwideDevCertSec = SecCertificateCreateWithData(nil, worldwideDeveloperCertData as CFData) else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadWorldwideDeveloperCertificate))
    }

    let policy = SecPolicyCreateBasicX509()

    var wwdcTrust: SecTrust?
    var iTunesTrust: SecTrust?

    // verify worldwide developer cert in the receipt is signed by Apple Root Cert
    let worldwideDevCertVerifyStatus = SecTrustCreateWithCertificates(
      [worldwideDevCertSec, rootCertSec] as AnyObject,
      policy,
      &wwdcTrust
    )

    guard worldwideDevCertVerifyStatus == errSecSuccess && wwdcTrust != nil else {
      throw IARError.validationFailed(reason: .signatureValidation(.invalidCertificateChainOfTrust))
    }

    // verify iTunes cert in the receipt is signed by worldwide developer cert, which is signed by Apple Root Cert
    let iTunesCertVerifystatus = SecTrustCreateWithCertificates(
      [iTunesCertSec, worldwideDevCertSec, rootCertSec] as AnyObject,
      policy,
      &iTunesTrust
    )

    guard iTunesCertVerifystatus == errSecSuccess && iTunesTrust != nil else {
      throw IARError.validationFailed(reason: .signatureValidation(.invalidCertificateChainOfTrust))
    }

    var secTrustResult = SecTrustResultType.unspecified

    if #available(OSX 10.14, tvOS 12.0, *) {
      var error: CFError?
      guard
        let wwdcTrust = wwdcTrust,
        SecTrustEvaluateWithError(wwdcTrust, &error)
      else {
        throw IARError.validationFailed(reason: .signatureValidation(.invalidCertificateChainOfTrust))
      }
    } else {
      guard
        let wwdcTrust = wwdcTrust,
        SecTrustEvaluate(wwdcTrust, &secTrustResult) == errSecSuccess
      else {
        throw IARError.validationFailed(reason: .signatureValidation(.invalidCertificateChainOfTrust))
      }
    }

    if #available(OSX 10.14, tvOS 12.0, *) {
      var error: CFError?
      guard
        let iTunesTrust = iTunesTrust,
        SecTrustEvaluateWithError(iTunesTrust, &error)
      else {
        throw IARError.validationFailed(reason: .signatureValidation(.invalidCertificateChainOfTrust))
      }
    } else {
      guard
        let iTunesTrust = iTunesTrust,
        SecTrustEvaluate(iTunesTrust, &secTrustResult) == errSecSuccess
      else {
        throw IARError.validationFailed(reason: .signatureValidation(.invalidCertificateChainOfTrust))
      }
    }
  }

  private func checkSignatureValidity() throws {
    guard let signature = signature else {
      throw IARError.validationFailed(reason: .signatureValidation(.signatureNotFound))
    }

    guard let iTunesPublicKeyContainer = receipt.iTunesPublicKeyData else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadiTunesPublicKey))
    }

    let keyDict: [String: Any] = [
      kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits as String: 2048
    ]

    guard let iTunesPublicKeySec = SecKeyCreateWithData(
      iTunesPublicKeyContainer as CFData,
      keyDict as CFDictionary,
      nil
    ) else {
      throw IARError.validationFailed(reason: .signatureValidation(.unableToLoadAppleIncPublicSecKey))
    }

    var umErrorCF: Unmanaged<CFError>?

    guard let alg = receipt.digestAlgorithm,
    SecKeyVerifySignature(iTunesPublicKeySec, alg, payloadRawData as CFData, signature as CFData, &umErrorCF) else {
      // let error = umErrorCF?.takeRetainedValue() as Error? as NSError?
      throw IARError.validationFailed(reason: .signatureValidation(.invalidSignature))
    }
  }
}

private func guid() -> Data {
#if os(watchOS)
  if let identifierForVendor = WKInterfaceDevice.current().identifierForVendor {
    var rawUUID = identifierForVendor.uuid
    let count = MemoryLayout.size(ofValue: rawUUID)
    let data = withUnsafePointer(to: &rawUUID) {
      Data(bytes: $0, count: count)
    }
    return data
  }
  return Data()
#elseif !targetEnvironment(macCatalyst) && (os(iOS) || os(tvOS) || os(visionOS))
  if let identifierForVendor = UIDevice.current.identifierForVendor {
    var rawUUID = identifierForVendor.uuid
    let count = MemoryLayout.size(ofValue: rawUUID)
    let data = withUnsafePointer(to: &rawUUID) {
      Data(bytes: $0, count: count)
    }
    return data
  }
  return Data()
#elseif targetEnvironment(macCatalyst) || os(macOS)
  if let guid = getMacAddress() {
    return guid
  } else {
    assertionFailure("Failed to retrieve guid")
  }
  return Data()
#endif
}

#if targetEnvironment(macCatalyst) || os(macOS)
func getMacAddress() -> Data? {
  guard
    let service = ioService(named: "en0", wantBuiltIn: true)
    ?? ioService(named: "en1", wantBuiltIn: true)
    ?? ioService(named: "en0", wantBuiltIn: false)
  else {
    return nil
  }

  defer { IOObjectRelease(service) }

  if let cftype = IORegistryEntrySearchCFProperty(
    service,
    kIOServicePlane,
    "IOMACAddress" as CFString,
    kCFAllocatorDefault,
    IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
  ) {
    return (cftype as? Data)
  }

  return nil
}

func ioService(named name: String, wantBuiltIn: Bool) -> io_service_t? {
  let mainPort: mach_port_t
  if #available(macOS 12.0, macCatalyst 15.0, *) {
    mainPort = kIOMainPortDefault
  } else {
    mainPort = 0 // the kIOMasterPortDefault symbol is unavailable on xcode 14 and later.
  }
  var iterator = io_iterator_t()

  defer {
    if iterator != IO_OBJECT_NULL {
      IOObjectRelease(iterator)
    }
  }

  guard
    let matchingDict = IOBSDNameMatching(mainPort, 0, name),
    IOServiceGetMatchingServices(mainPort, matchingDict as CFDictionary, &iterator) == KERN_SUCCESS,
    iterator != IO_OBJECT_NULL
  else {
    return nil
  }

  var candidate = IOIteratorNext(iterator)
  while candidate != IO_OBJECT_NULL {
    if let cftype = IORegistryEntryCreateCFProperty(candidate, "IOBuiltin" as CFString, kCFAllocatorDefault, 0) {
      // Keeping the following as force case because optionally casting it is an error
      // when building for mac catalyst.
      // swiftlint:disable:next force_cast
      let isBuiltIn = cftype.takeRetainedValue() as! CFBoolean
      if wantBuiltIn == CFBooleanGetValue(isBuiltIn) {
        return candidate
      }
    }

    IOObjectRelease(candidate)
    candidate = IOIteratorNext(iterator)
  }

  return nil
}
#endif
