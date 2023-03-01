//
//  InAppReceipt+ASN1Decodable.swift
//  TPInAppReceipt
//
//  Created by Pavel Tikhonenko on 04/08/20.
//  Copyright © 2017-2021 Pavel Tikhonenko. All rights reserved.
//
// swiftlint:disable type_name

import Foundation

final class _InAppReceipt {
  private var pkcs7container: PKCS7Container

  var payload: InAppReceiptPayload

  init(rawData: Data) throws {
    let asn1decoder = ASN1Decoder()
    self.pkcs7container = try asn1decoder.decode(PKCS7Container.self, from: rawData)

    do {
      self.payload = try asn1decoder.decode(
        PayloadContainer.self,
        from: pkcs7container.signedData.contentInfo.payload.rawData
      ).payload
    } catch {
      self.payload = try asn1decoder.decode(
        _PayloadContainer.self,
        from: pkcs7container.signedData.contentInfo.payload.rawData
      ).payload
    }
  }
}

extension _InAppReceipt {
  var digestAlgorithm: SecKeyAlgorithm? {
    guard let algName = pkcs7container.signedData.alg.items.first?.algorithm else {
      return nil
    }

    guard let alg = OID(rawValue: algName)?.encryptionAlgorithm() else {
      return nil
    }

    return alg
  }

  var worldwideDeveloperCertificateData: Data? {
    let arr = pkcs7container.signedData.certificates.certificates

    guard arr.count >= 2 else {
      return nil
    }

    return arr[1].rawData
  }

  var signatureData: Data {
    return pkcs7container.signedData.signerInfos.encryptedDigest
  }

  var iTunesCertificateContainer: PKCS7Container.Certificate? {
    return pkcs7container.signedData.certificates.certificates.first
  }

  var iTunesCertificateData: Data? {
    return iTunesCertificateContainer?.rawData
  }

  var iTunesPublicKeyData: Data? {
    return iTunesCertificateContainer?.cert.subjectPublicKeyInfo
  }
}

struct PayloadContainer: ASN1Decodable {
  var payload: InAppReceiptPayload

  static var template: ASN1Template {
    return ASN1Template.contextSpecific(0).constructed().explicit(tag: ASN1Identifier.Tag.octetString).constructed()
  }

  enum CodingKeys: ASN1CodingKey {
    case payload

    var template: ASN1Template {
      switch self {
      case .payload:
        return InAppReceiptPayload.template
      }
    }
  }
}

/// Legacy payload format
struct _PayloadContainer: ASN1Decodable {
  var payload: InAppReceiptPayload

  static var template: ASN1Template {
    return ASN1Template.contextSpecific(0).constructed()
  }

  enum CodingKeys: ASN1CodingKey {
    case payload

    var template: ASN1Template {
      switch self {
      case .payload:
        return InAppReceiptPayload.template
      }
    }
  }
}
