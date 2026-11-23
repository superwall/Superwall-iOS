//
//  CertificateFields.swift
//  SuperwallKit
//
//  Created by Superwall on 19/11/2026.
//

import Foundation

/// The validity and CA flag of a certificate. `Security` has no API for these on every platform,
/// so the few fields are read from the DER directly.
struct CertificateFields {
  let notBefore: Int64
  let notAfter: Int64
  let isCA: Bool

  init?(der: Data) {
    var outer = DERReader(Array(der))
    guard
      let certificateBytes = outer.read(tag: 0x30),
      outer.isAtEnd
    else {
      return nil
    }
    var certificate = DERReader(certificateBytes)
    guard let tbsBytes = certificate.read(tag: 0x30) else {
      return nil
    }
    var tbs = DERReader(tbsBytes)
    guard
      tbs.read(tag: 0xa0) != nil, // version
      tbs.read(tag: 0x02) != nil, // serial
      tbs.read(tag: 0x30) != nil, // signature algorithm
      tbs.read(tag: 0x30) != nil, // issuer
      let validityBytes = tbs.read(tag: 0x30)
    else {
      return nil
    }
    var validity = DERReader(validityBytes)
    guard
      let notBefore = validity.readTime(),
      let notAfter = validity.readTime(),
      tbs.read(tag: 0x30) != nil, // subject
      tbs.read(tag: 0x30) != nil, // subject public key info
      let extensionsWrapper = tbs.read(tag: 0xa3)
    else {
      return nil
    }
    self.notBefore = notBefore
    self.notAfter = notAfter

    var wrapper = DERReader(extensionsWrapper)
    guard
      let extensions = wrapper.read(tag: 0x30),
      let isCA = Self.isCertificateAuthority(extensions: extensions)
    else {
      return nil
    }
    self.isCA = isCA
  }

  /// The `cA` flag of the basic constraints extension, `false` when it's absent.
  private static func isCertificateAuthority(extensions: [UInt8]) -> Bool? {
    var reader = DERReader(extensions)
    let basicConstraints: [UInt8] = [0x55, 0x1d, 0x13]
    while let extensionBytes = reader.read(tag: 0x30) {
      var item = DERReader(extensionBytes)
      guard let oid = item.read(tag: 0x06) else {
        return nil
      }
      guard oid == basicConstraints else {
        continue
      }
      _ = item.read(tag: 0x01) // critical, optional
      guard let value = item.read(tag: 0x04) else {
        return nil
      }
      var valueReader = DERReader(value)
      guard let constraints = valueReader.read(tag: 0x30) else {
        return nil
      }
      var constraintsReader = DERReader(constraints)
      return constraintsReader.read(tag: 0x01).map { $0.first.map { $0 != 0 } ?? false } ?? false
    }
    return false
  }
}

/// Reads definite-length DER TLVs with single-byte tags. A read that doesn't match leaves the
/// position where it was.
struct DERReader {
  private let bytes: [UInt8]
  private var offset = 0

  init(_ bytes: [UInt8]) {
    self.bytes = bytes
  }

  var isAtEnd: Bool {
    offset == bytes.count
  }

  mutating func read(tag: UInt8) -> [UInt8]? {
    var position = offset
    guard
      position + 2 <= bytes.count,
      bytes[position] == tag
    else {
      return nil
    }
    position += 1
    var length = Int(bytes[position])
    position += 1
    if length & 0x80 != 0 {
      let lengthBytes = length & 0x7f
      guard
        (1...4).contains(lengthBytes),
        lengthBytes <= bytes.count - position
      else {
        return nil
      }
      // Accumulated in 64 bits: `Int` is 32 bits on arm64_32 watches, where four length bytes
      // could wrap to a negative length.
      var wide: UInt64 = 0
      for _ in 0..<lengthBytes {
        wide = wide << 8 | UInt64(bytes[position])
        position += 1
      }
      guard wide <= UInt64(bytes.count - position) else {
        return nil
      }
      length = Int(wide)
    }
    guard length <= bytes.count - position else {
      return nil
    }
    offset = position + length
    return Array(bytes[position..<(position + length)])
  }

  /// UTCTime (years 1950–2049) or GeneralizedTime, as Unix seconds.
  mutating func readTime() -> Int64? {
    let text: String
    if let utc = read(tag: 0x17) {
      guard let value = String(bytes: utc, encoding: .ascii), value.count == 13 else {
        return nil
      }
      let year = Int(value.prefix(2)) ?? 0
      text = (year >= 50 ? "19" : "20") + value
    } else if let generalized = read(tag: 0x18) {
      guard let value = String(bytes: generalized, encoding: .ascii) else {
        return nil
      }
      text = value
    } else {
      return nil
    }
    let digits = Array(text.dropLast())
    guard
      text.count == 15,
      text.hasSuffix("Z"),
      digits.allSatisfy({ $0.isASCII && $0.isNumber })
    else {
      return nil
    }
    func field(_ start: Int, _ length: Int) -> Int {
      Int(String(digits[start..<(start + length)])) ?? 0
    }
    var components = DateComponents()
    components.year = field(0, 4)
    components.month = field(4, 2)
    components.day = field(6, 2)
    components.hour = field(8, 2)
    components.minute = field(10, 2)
    components.second = field(12, 2)
    var calendar = Calendar(identifier: .gregorian)
    guard let utc = TimeZone(identifier: "UTC") else {
      return nil
    }
    calendar.timeZone = utc
    guard let date = calendar.date(from: components) else {
      return nil
    }
    return Int64(date.timeIntervalSince1970)
  }
}
