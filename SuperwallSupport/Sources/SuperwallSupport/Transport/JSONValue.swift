import Foundation

/// Any JSON value, kept exactly as it arrived so unknown kinds and unknown keys
/// survive a decode (the wire's lenient rule).
public enum JSONValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  public var objectValue: [String: JSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  public var arrayValue: [JSONValue]? {
    if case .array(let value) = self { return value }
    return nil
  }

  public var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  public var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  public var numberValue: Double? {
    if case .number(let value) = self { return value }
    return nil
  }

  /// An integer, only when the number is integral and exactly representable.
  public var intValue: Int? {
    guard case .number(let value) = self,
      value.rounded() == value,
      abs(value) <= 9_007_199_254_740_991
    else { return nil }
    return Int(value)
  }

  public subscript(key: String) -> JSONValue? {
    objectValue?[key]
  }

  /// Parses JSON text. Returns nil for anything that isn't JSON.
  public static func parse(_ text: String) -> JSONValue? {
    guard let data = text.data(using: .utf8) else { return nil }
    return parse(data)
  }

  public static func parse(_ data: Data) -> JSONValue? {
    guard
      let object = try? JSONSerialization.jsonObject(
        with: data,
        options: [.fragmentsAllowed]
      )
    else { return nil }
    return JSONValue(foundation: object)
  }

  init?(foundation object: Any) {
    switch object {
    case is NSNull:
      self = .null
    case let number as NSNumber:
      // JSONSerialization hands booleans back as NSNumber; tell them apart by type.
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        self = .bool(number.boolValue)
      } else {
        self = .number(number.doubleValue)
      }
    case let string as String:
      self = .string(string)
    case let array as [Any]:
      var values: [JSONValue] = []
      values.reserveCapacity(array.count)
      for element in array {
        guard let value = JSONValue(foundation: element) else { return nil }
        values.append(value)
      }
      self = .array(values)
    case let dictionary as [String: Any]:
      var values: [String: JSONValue] = [:]
      for (key, element) in dictionary {
        guard let value = JSONValue(foundation: element) else { return nil }
        values[key] = value
      }
      self = .object(values)
    default:
      return nil
    }
  }

  /// The Foundation object `JSONSerialization` writes.
  var foundationObject: Any {
    switch self {
    case .null: return NSNull()
    case .bool(let value): return value
    case .number(let value):
      if let int = intValue { return int }
      return value
    case .string(let value): return value
    case .array(let values): return values.map(\.foundationObject)
    case .object(let values): return values.mapValues(\.foundationObject)
    }
  }

  /// Compact JSON text, keys sorted so the output is stable.
  public func serialized() -> String {
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: foundationObject,
        options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]
      )
    else { return "null" }
    return String(decoding: data, as: UTF8.self)
  }
}

extension JSONValue: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not JSON")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .number(let value):
      if let int = intValue { try container.encode(int) } else { try container.encode(value) }
    case .string(let value): try container.encode(value)
    case .array(let values): try container.encode(values)
    case .object(let values): try container.encode(values)
    }
  }
}
