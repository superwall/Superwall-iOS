import Foundation

// Socket frames on `GET /v1/conversations/:id/live`, mirroring
// `@superwall/inbox-contracts/wire/frames.ts`. One JSON object per text frame,
// discriminated by `type`. A frame type this build doesn't know is ignored.

public struct PresenceParticipant: Equatable, Sendable {
  public let type: String
  public let name: String?
  public let avatarUrl: String?
  /// `viewing` or `typing` today. Open.
  public let state: String
}

public enum ServerFrame: Equatable, Sendable {
  case ready(conversationId: String, after: Int, head: Int)
  /// `entry` stays raw: decode it with `WireEntry.decode`. The seq is outside it,
  /// so the cursor moves even when the entry doesn't decode.
  case entry(seq: Int, prev: Int, entry: JSONValue)
  case tail(messageId: String, offset: Int, text: String)
  case tailCancel(messageId: String, reason: String?)
  case status(state: String, etaSeconds: Int?)
  case presence([PresenceParticipant])
  case resync(reason: String, head: Int)
  case error(code: String, message: String, retryable: Bool)
  case pong

  public static let knownTypes: Set<String> = [
    "ready", "entry", "tail", "tail_cancel", "status", "presence", "resync", "error", "pong"
  ]
}

public enum DecodedFrame: Equatable, Sendable {
  case frame(ServerFrame)
  /// Not JSON, not an object, an unknown `type`, or a known type that didn't decode.
  case ignored(reason: String)
}

public enum WireFrameDecoder {
  /// Decodes one socket text frame. Never throws: what it can't read is ignored.
  public static func decode(_ text: String) -> DecodedFrame {
    guard let json = JSONValue.parse(text) else { return .ignored(reason: "malformed_json") }
    return decode(json)
  }

  public static func decode(_ json: JSONValue) -> DecodedFrame {
    guard let type = json["type"]?.stringValue else { return .ignored(reason: "missing_type") }
    guard ServerFrame.knownTypes.contains(type) else {
      return .ignored(reason: "unknown_type:\(type)")
    }
    do {
      return .frame(try decodeKnown(type, json))
    } catch {
      return .ignored(reason: String(describing: error))
    }
  }

  private static func decodeKnown(_ type: String, _ json: JSONValue) throws -> ServerFrame {
    let fields = try WireFields(json)
    switch type {
    case "ready":
      _ = try fields.literal("protocol", [SupportWire.protocolName])
      return .ready(
        conversationId: try fields.id("conversationId", prefix: "conv"),
        after: try fields.seq("after"),
        head: try fields.seq("head")
      )
    case "entry":
      return .entry(
        seq: try fields.seq("seq"),
        prev: try fields.seq("prev"),
        entry: try fields.value("entry")
      )
    case "tail":
      let offset = try fields.int("offset")
      guard offset >= 0 else { throw WireDecodeIssue(path: "offset", message: "Negative offset") }
      return .tail(
        messageId: try fields.id("messageId", prefix: "ent"),
        offset: offset,
        text: try fields.string("text")
      )
    case "tail_cancel":
      return .tailCancel(
        messageId: try fields.id("messageId", prefix: "ent"),
        reason: try fields.optionalString("reason")
      )
    case "status":
      return .status(state: try fields.string("state"), etaSeconds: try fields.optionalInt("etaSeconds"))
    case "presence":
      return .presence(
        try fields.each("participants") { value, path in
          let participant = try WireFields(value, path: path)
          return PresenceParticipant(
            type: try participant.literal("type", SupportWire.authorTypes),
            name: try participant.optionalString("name"),
            avatarUrl: try participant.optionalString("avatarUrl"),
            state: try participant.string("state")
          )
        })
    case "resync":
      return .resync(reason: try fields.string("reason"), head: try fields.seq("head"))
    case "error":
      return .error(
        code: try fields.string("code"),
        message: try fields.string("message"),
        retryable: try fields.bool("retryable")
      )
    default:
      return .pong
    }
  }
}

/// Client → server frames.
public enum ClientFrame: Equatable, Sendable {
  case hello(sessionToken: String, conversationId: String, after: Int, afterId: String?)
  case typing(active: Bool)
  case ping

  public func encoded() -> String {
    switch self {
    case .ping:
      return SupportWire.pingFrame
    case .typing(let active):
      return JSONValue.object(["type": .string("typing"), "active": .bool(active)]).serialized()
    case .hello(let token, let conversationId, let after, let afterId):
      var object: [String: JSONValue] = [
        "type": .string("hello"),
        "protocol": .string(SupportWire.protocolName),
        "sessionToken": .string(token),
        "conversationId": .string(conversationId),
        "after": .number(Double(after))
      ]
      // Omitted at 0: there is no entry to check.
      if after > 0, let afterId { object["afterId"] = .string(afterId) }
      return JSONValue.object(object).serialized()
    }
  }

  /// Server-side shape check, used by tests on the client fixtures.
  public static func decode(_ text: String) -> ClientFrame? {
    guard let json = JSONValue.parse(text), let fields = try? WireFields(json) else { return nil }
    switch try? fields.string("type") {
    case "ping":
      return .ping
    case "typing":
      guard let active = try? fields.bool("active") else { return nil }
      return .typing(active: active)
    case "hello":
      guard
        (try? fields.string("protocol")) != nil,
        let token = try? fields.string("sessionToken"),
        let conversationId = try? fields.id("conversationId", prefix: "conv"),
        let after = try? fields.seq("after")
      else { return nil }
      let afterId: String?
      do { afterId = try fields.optionalId("afterId", prefix: "ent") } catch { return nil }
      return .hello(sessionToken: token, conversationId: conversationId, after: after, afterId: afterId)
    default:
      return nil
    }
  }
}

/// WebSocket close codes and what each tells the client to do.
public enum SupportCloseCode {
  public static let normal = 1000
  /// Server going away: reconnect with the cursor.
  public static let goingAway = 1001
  /// Start a new session; don't retry this token.
  public static let sessionInvalid = 4001
  /// This build's protocol is not served.
  public static let protocolUnsupported = 4002
  public static let badHello = 4003
  /// The conversation is gone. Don't retry.
  public static let notFound = 4004
  /// After a `resync` frame: reload over HTTP, then reconnect.
  public static let resync = 4009
  /// Overloaded or rate limited: reconnect with backoff.
  public static let tryLater = 4029
  public static let internalError = 1011
}
