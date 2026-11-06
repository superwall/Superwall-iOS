import Foundation

/// Why a value didn't decode, with the path to it.
public struct WireDecodeIssue: Error, Equatable, CustomStringConvertible, Sendable {
  public let path: String
  public let message: String
  public var description: String { path.isEmpty ? message : "\(path): \(message)" }
}

/// Wire id rules, the same patterns as `@superwall/inbox-contracts/ids`.
enum WireIds {
  /// Crockford base32 ULID, 26 characters.
  private static let ulid = "[0-9A-HJKMNP-TV-Z]{26}"
  private static var cache: [String: NSRegularExpression] = [:]
  private static let lock = NSLock()

  static func matches(_ value: String, prefix: String) -> Bool {
    matches(value, pattern: "^\(prefix)_\(ulid)$")
  }

  static func isClientMessageId(_ value: String) -> Bool {
    matches(value, pattern: "^[A-Za-z0-9_-]{1,36}$")
  }

  static func matches(_ value: String, pattern: String) -> Bool {
    lock.lock()
    let regex: NSRegularExpression
    if let cached = cache[pattern] {
      regex = cached
    } else {
      // The patterns are constants in this file.
      // swiftlint:disable:next force_try
      regex = try! NSRegularExpression(pattern: pattern)
      cache[pattern] = regex
    }
    lock.unlock()
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regex.firstMatch(in: value, range: range) != nil
  }
}

/// ISO 8601 UTC timestamps, as `Schema.DateTimeUtcFromString` writes them.
enum WireTimestamp {
  private static let withFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
  private static let withoutFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
  private static let lock = NSLock()

  static func parse(_ value: String) -> Date? {
    lock.lock()
    defer { lock.unlock() }
    return withFraction.date(from: value) ?? withoutFraction.date(from: value)
  }

  static func format(_ date: Date) -> String {
    lock.lock()
    defer { lock.unlock() }
    return withFraction.string(from: date)
  }
}

/// Reads fields of one JSON object strictly, the way the TypeScript schemas do:
/// a required key must be present with the right type, an optional key may be
/// absent but not present with the wrong type (`null` included). Unknown keys
/// are ignored, and kept by the caller.
struct WireFields {
  let object: [String: JSONValue]
  let path: String

  init(_ value: JSONValue, path: String = "") throws {
    guard let object = value.objectValue else {
      throw WireDecodeIssue(path: path, message: "Expected an object")
    }
    self.object = object
    self.path = path
  }

  private func at(_ key: String) -> String { path.isEmpty ? key : "\(path).\(key)" }

  private func fail(_ key: String, _ message: String) -> WireDecodeIssue {
    WireDecodeIssue(path: at(key), message: message)
  }

  func has(_ key: String) -> Bool { object[key] != nil }

  func value(_ key: String) throws -> JSONValue {
    guard let value = object[key] else { throw fail(key, "Missing key") }
    return value
  }

  func string(_ key: String) throws -> String {
    guard let value = try value(key).stringValue else { throw fail(key, "Expected a string") }
    return value
  }

  func optionalString(_ key: String) throws -> String? {
    guard has(key) else { return nil }
    return try string(key)
  }

  func bool(_ key: String) throws -> Bool {
    guard let value = try value(key).boolValue else { throw fail(key, "Expected a boolean") }
    return value
  }

  func optionalBool(_ key: String) throws -> Bool? {
    guard has(key) else { return nil }
    return try bool(key)
  }

  func int(_ key: String) throws -> Int {
    guard let value = try value(key).intValue else { throw fail(key, "Expected an integer") }
    return value
  }

  func optionalInt(_ key: String) throws -> Int? {
    guard has(key) else { return nil }
    return try int(key)
  }

  func number(_ key: String) throws -> Double {
    guard let value = try value(key).numberValue else { throw fail(key, "Expected a number") }
    return value
  }

  /// A `Seq`: an integer at least 0.
  func seq(_ key: String) throws -> Int {
    let value = try int(key)
    guard value >= 0 else { throw fail(key, "Expected a seq at least 0") }
    return value
  }

  func id(_ key: String, prefix: String) throws -> String {
    let value = try string(key)
    guard WireIds.matches(value, prefix: prefix) else {
      throw fail(key, "Expected a \(prefix)_ id")
    }
    return value
  }

  func optionalId(_ key: String, prefix: String) throws -> String? {
    guard has(key) else { return nil }
    return try id(key, prefix: prefix)
  }

  func literal(_ key: String, _ allowed: Set<String>) throws -> String {
    let value = try string(key)
    guard allowed.contains(value) else {
      throw fail(key, "Expected one of \(allowed.sorted().joined(separator: ", "))")
    }
    return value
  }

  func optionalLiteral(_ key: String, _ allowed: Set<String>) throws -> String? {
    guard has(key) else { return nil }
    return try literal(key, allowed)
  }

  func timestamp(_ key: String) throws -> Date {
    let value = try string(key)
    guard let date = WireTimestamp.parse(value) else { throw fail(key, "Expected an ISO 8601 time") }
    return date
  }

  func optionalTimestamp(_ key: String) throws -> Date? {
    guard has(key) else { return nil }
    return try timestamp(key)
  }

  func array(_ key: String) throws -> [JSONValue] {
    guard let value = try value(key).arrayValue else { throw fail(key, "Expected an array") }
    return value
  }

  func optionalArray(_ key: String) throws -> [JSONValue]? {
    guard has(key) else { return nil }
    return try array(key)
  }

  func objectFields(_ key: String) throws -> WireFields {
    try WireFields(try value(key), path: at(key))
  }

  func optionalObject(_ key: String) throws -> [String: JSONValue]? {
    guard has(key) else { return nil }
    guard let value = try value(key).objectValue else { throw fail(key, "Expected an object") }
    return value
  }

  /// Decodes each element of an array with `decode`, failing on the first bad one.
  func each<T>(_ key: String, _ decode: (JSONValue, String) throws -> T) throws -> [T] {
    try array(key).enumerated().map { index, element in try decode(element, "\(at(key))[\(index)]") }
  }

  func optionalEach<T>(_ key: String, _ decode: (JSONValue, String) throws -> T) throws -> [T]? {
    guard has(key) else { return nil }
    return try each(key, decode)
  }
}
