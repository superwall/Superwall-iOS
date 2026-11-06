import Foundation

// Entries: the append-only conversation log as a person-side client sees it.
// Mirrors `@superwall/inbox-contracts/wire/entry.ts` and `lenient.ts`.

public enum SupportWire {
  /// The protocol this build speaks, sent at session start and in the socket's `hello`.
  public static let protocolName = "superwall-support/1"
  /// Exactly this text, so a hibernating Durable Object answers without waking.
  public static let pingFrame = #"{"type":"ping"}"#
  /// What an erased or redacted entry's `text` says.
  public static let redactedText = "This message was removed."
  /// Every entry kind this protocol version knows. Others decode as `.unknown`.
  public static let knownEntryKinds: [String] = [
    "person_message", "agent_message", "human_message", "note", "agent_feedback", "card",
    "card_response", "tool_call", "tool_result", "handoff", "status_change", "resolution",
    "system_notice"
  ]
  public static let maxMessageLength = 10_000
  public static let defaultWindow = 60
  public static let maxWindow = 200
  public static let maxAttachmentBytes = 25 * 1024 * 1024

  static let authorTypes: Set<String> = ["person", "agent", "human", "system", "external"]
  static let visibilities: Set<String> = ["public", "internal"]
  static let automationLevels: Set<String> = ["manual", "assisted", "autonomous", "external"]
}

public struct EntryAuthor: Equatable, Sendable {
  /// `person`, `agent`, `human`, `system` or `external`.
  public let type: String
  public let name: String?
  public let avatarUrl: String?
  /// Founder-side only.
  public let userId: Double?

  static func decode(_ value: JSONValue, path: String) throws -> EntryAuthor {
    let fields = try WireFields(value, path: path)
    return EntryAuthor(
      type: try fields.literal("type", SupportWire.authorTypes),
      name: try fields.optionalString("name"),
      avatarUrl: try fields.optionalString("avatarUrl"),
      userId: fields.has("userId") ? try fields.number("userId") : nil
    )
  }
}

/// Server-parsed rich text. Clients never parse markdown.
public enum EntrySpan: Equatable, Sendable {
  case text(String, marks: [String])
  case link(String, href: String)

  static let marks: Set<String> = ["bold", "italic", "code", "strike"]

  static func decode(_ value: JSONValue, path: String) throws -> EntrySpan {
    let fields = try WireFields(value, path: path)
    switch try fields.literal("t", ["text", "link"]) {
    case "text":
      let marks = try fields.optionalEach("marks") { mark, path in
        guard let mark = mark.stringValue, EntrySpan.marks.contains(mark) else {
          throw WireDecodeIssue(path: path, message: "Unknown mark")
        }
        return mark
      }
      return .text(try fields.string("text"), marks: marks ?? [])
    default:
      return .link(try fields.string("text"), href: try fields.string("href"))
    }
  }
}

public enum EntryBlock: Equatable, Sendable {
  case paragraph([EntrySpan])
  case list(ordered: Bool, items: [[EntrySpan]])
  case quote([EntrySpan])
  case code(String)

  static func decode(_ value: JSONValue, path: String) throws -> EntryBlock {
    let fields = try WireFields(value, path: path)
    switch try fields.literal("t", ["paragraph", "list", "quote", "code"]) {
    case "paragraph":
      return .paragraph(try fields.each("spans", EntrySpan.decode))
    case "list":
      let items = try fields.each("items") { item, path in
        guard let spans = item.arrayValue else {
          throw WireDecodeIssue(path: path, message: "Expected an array")
        }
        return try spans.enumerated().map { try EntrySpan.decode($1, path: "\(path)[\($0)]") }
      }
      return .list(ordered: try fields.bool("ordered"), items: items)
    case "quote":
      return .quote(try fields.each("spans", EntrySpan.decode))
    default:
      return .code(try fields.string("text"))
    }
  }
}

public struct EntryAttachment: Equatable, Sendable {
  public let id: String
  /// `file` or `diagnostics`.
  public let kind: String
  public let filename: String?
  public let mime: String
  public let bytes: Int
  /// `quarantine`, `clean` or `rejected`.
  public let status: String

  static func decode(_ value: JSONValue, path: String) throws -> EntryAttachment {
    let fields = try WireFields(value, path: path)
    return EntryAttachment(
      id: try fields.id("id", prefix: "att"),
      kind: try fields.literal("kind", ["file", "diagnostics"]),
      filename: try fields.optionalString("filename"),
      mime: try fields.string("mime"),
      bytes: try fields.int("bytes"),
      status: try fields.literal("status", ["quarantine", "clean", "rejected"])
    )
  }
}

/// The card envelope. Its element set (`nodes`) is owned by the card-markup
/// contract (M4), so nodes stay opaque JSON here.
public struct CardEnvelope: Equatable, Sendable {
  public let id: String
  public let card: String
  public let tpl: String
  public let ui: Int
  /// Complete on its own, including how to proceed.
  public let text: String
  public let expiresAt: Date?
  /// `live`, `resolved` or `expired`.
  public let state: String?
  public let nodes: [JSONValue]
  public let bind: [String: JSONValue]?
  /// Each action's JSON. `kind` is open; a client that doesn't know it sends `reply`.
  public let actions: [String: [String: JSONValue]]
  public let resolvedText: String?

  static func decode(_ value: JSONValue, path: String) throws -> CardEnvelope {
    let fields = try WireFields(value, path: path)
    guard try fields.int("v") == 1 else {
      throw WireDecodeIssue(path: "\(path).v", message: "Expected card envelope v1")
    }
    var actions: [String: [String: JSONValue]] = [:]
    for (key, action) in try fields.objectFields("actions").object {
      let actionFields = try WireFields(action, path: "\(path).actions.\(key)")
      _ = try actionFields.string("kind")
      _ = try actionFields.optionalString("reply")
      actions[key] = actionFields.object
    }
    var resolvedText: String?
    if fields.has("resolved") {
      resolvedText = try fields.objectFields("resolved").string("text")
    }
    return CardEnvelope(
      id: try fields.id("id", prefix: "card"),
      card: try fields.string("card"),
      tpl: try fields.string("tpl"),
      ui: try fields.int("ui"),
      text: try fields.string("text"),
      expiresAt: try fields.optionalTimestamp("expiresAt"),
      state: try fields.optionalLiteral("state", ["live", "resolved", "expired"]),
      nodes: try fields.array("nodes"),
      bind: try fields.optionalObject("bind"),
      actions: actions,
      resolvedText: resolvedText
    )
  }
}

/// An entry of a kind this version knows, decoded strictly.
public struct KnownEntry: Equatable, Sendable {
  public let seq: Int
  public let id: String
  public let conversationId: String
  public let kind: String
  /// `public` or `internal`. Person-side clients only receive public entries.
  public let visibility: String
  public let author: EntryAuthor
  public let createdAt: Date
  public let automationLevel: String?
  /// Erased: draw `text` (`SupportWire.redactedText`) and nothing else.
  public let redacted: Bool
  /// The plain-text fallback. Required on most kinds, optional on tool entries.
  public let text: String?
  public let body: Body

  public enum Body: Equatable, Sendable {
    /// `person_message`, `agent_message`, `human_message`, `note`, `agent_feedback`.
    case message(
      blocks: [EntryBlock]?,
      attachments: [EntryAttachment]?,
      clientMessageId: String?,
      turnId: String?,
      mentions: [Double]?
    )
    case card(CardEnvelope)
    case cardResponse(cardId: String, actionId: String)
    case toolCall(callId: String, tool: String, target: String, args: JSONValue?, state: String)
    case toolResult(callId: String, status: String)
    case handoff(to: String, reason: String?, etaSeconds: Int?)
    case statusChange(from: String?, to: String)
    case resolution(outcome: String, actionId: String?)
    case systemNotice(code: String)
  }

  /// The `clientMessageId` a `person_message` carries, for matching a send.
  public var clientMessageId: String? {
    if case .message(_, _, let id, _, _) = body { return id }
    return nil
  }

  static func decode(_ value: JSONValue) throws -> KnownEntry {
    let fields = try WireFields(value)
    let kind = try fields.string("kind")
    let messageKinds: Set<String> = [
      "person_message", "agent_message", "human_message", "note", "agent_feedback"
    ]
    let textRequired = !["tool_call", "tool_result"].contains(kind)
    let text = textRequired ? try fields.string("text") : try fields.optionalString("text")

    let body: Body
    if messageKinds.contains(kind) {
      let allowsAttachments = kind == "person_message" || kind == "human_message"
      let allowsTurn = kind == "agent_message" || kind == "agent_feedback"
      body = .message(
        blocks: try fields.optionalEach("blocks", EntryBlock.decode),
        attachments: allowsAttachments
          ? try fields.optionalEach("attachments", EntryAttachment.decode) : nil,
        clientMessageId: kind == "person_message"
          ? try clientMessageId(fields) : nil,
        turnId: allowsTurn ? try fields.optionalId("turnId", prefix: "turn") : nil,
        mentions: kind == "note"
          ? try fields.optionalEach("mentions") { mention, path in
            guard let number = mention.numberValue else {
              throw WireDecodeIssue(path: path, message: "Expected a number")
            }
            return number
          } : nil
      )
    } else {
      switch kind {
      case "card":
        body = .card(try CardEnvelope.decode(try fields.value("card"), path: "card"))
      case "card_response":
        body = .cardResponse(
          cardId: try fields.id("cardId", prefix: "card"),
          actionId: try fields.string("actionId")
        )
      case "tool_call":
        body = .toolCall(
          callId: try fields.id("callId", prefix: "call"),
          tool: try fields.string("tool"),
          target: try fields.literal("target", ["app", "server"]),
          args: fields.object["args"],
          state: try fields.string("state")
        )
      case "tool_result":
        body = .toolResult(
          callId: try fields.id("callId", prefix: "call"),
          status: try fields.literal("status", ["ok", "error", "declined"])
        )
      case "handoff":
        body = .handoff(
          to: try fields.literal("to", ["human", "agent"]),
          reason: try fields.optionalString("reason"),
          etaSeconds: try fields.optionalInt("etaSeconds")
        )
      case "status_change":
        body = .statusChange(from: try fields.optionalString("from"), to: try fields.string("to"))
      case "resolution":
        body = .resolution(
          outcome: try fields.string("outcome"),
          actionId: try fields.optionalId("actionId", prefix: "act")
        )
      case "system_notice":
        body = .systemNotice(code: try fields.string("code"))
      default:
        throw WireDecodeIssue(path: "kind", message: "Not a known kind")
      }
    }

    return KnownEntry(
      seq: try fields.seq("seq"),
      id: try fields.id("id", prefix: "ent"),
      conversationId: try fields.id("conversationId", prefix: "conv"),
      kind: kind,
      visibility: try fields.literal("visibility", SupportWire.visibilities),
      author: try EntryAuthor.decode(try fields.value("author"), path: "author"),
      createdAt: try fields.timestamp("createdAt"),
      automationLevel: try fields.optionalLiteral("automationLevel", SupportWire.automationLevels),
      redacted: try fields.optionalBool("redacted") ?? false,
      text: text,
      body: body
    )
  }

  private static func clientMessageId(_ fields: WireFields) throws -> String? {
    guard let value = try fields.optionalString("clientMessageId") else { return nil }
    guard WireIds.isClientMessageId(value) else {
      throw WireDecodeIssue(path: "clientMessageId", message: "Expected a client message id")
    }
    return value
  }
}

/// A known kind that didn't decode, or JSON with no usable envelope.
public struct FailedEntry: Equatable, Sendable {
  public let seq: Int?
  public let id: String?
  public let kind: String?
  /// Drawn instead of the entry.
  public let text: String?
  /// Erased: expected to fail; draw `text` (`SupportWire.redactedText`) and nothing else.
  public let redacted: Bool
  public let issue: String
  public let raw: JSONValue
}

/// One entry, decoded on its own so a bad one never blanks a conversation.
public enum WireEntry: Equatable, Sendable {
  /// A kind this version knows, and it decoded. `raw` keeps unknown keys.
  case known(KnownEntry, raw: [String: JSONValue])
  /// A kind this version doesn't know. Drawn from `text` if present, else skipped.
  case unknown(seq: Int, id: String, kind: String, text: String?, raw: [String: JSONValue])
  /// A known kind that didn't decode, or JSON with no usable envelope. Drawn from `text`.
  case failed(FailedEntry)

  public var seq: Int? {
    switch self {
    case .known(let entry, _): return entry.seq
    case .unknown(let seq, _, _, _, _): return seq
    case .failed(let failed): return failed.seq
    }
  }

  public var id: String? {
    switch self {
    case .known(let entry, _): return entry.id
    case .unknown(_, let id, _, _, _): return id
    case .failed(let failed): return failed.id
    }
  }

  public var kind: String? {
    switch self {
    case .known(let entry, _): return entry.kind
    case .unknown(_, _, let kind, _, _): return kind
    case .failed(let failed): return failed.kind
    }
  }

  /// What a client draws when it can't fully render the entry.
  public var fallbackText: String? {
    switch self {
    case .known(let entry, _): return entry.text
    case .unknown(_, _, _, let text, _): return text
    case .failed(let failed): return failed.text
    }
  }

  public var clientMessageId: String? {
    if case .known(let entry, _) = self { return entry.clientMessageId }
    return nil
  }

  /// Decodes one entry from JSON. Never throws.
  public static func decode(_ raw: JSONValue) -> WireEntry {
    let object = raw.objectValue
    // The envelope every entry carries: seq, id, kind, and an optional string text.
    let envelope: Envelope? = {
      guard let object,
        let seq = object["seq"]?.intValue, seq >= 0,
        let id = object["id"]?.stringValue, WireIds.matches(id, prefix: "ent"),
        let kind = object["kind"]?.stringValue
      else { return nil }
      let text = object["text"]
      if let text, text.stringValue == nil { return nil }
      return Envelope(seq: seq, id: id, kind: kind, text: text?.stringValue)
    }()

    guard let envelope, let object else {
      // Keep every identity field that validates on its own: with the id, a client
      // can still match this entry to the tail it seals.
      let seq = object?["seq"]?.intValue.flatMap { $0 >= 0 ? $0 : nil }
      let id = object?["id"]?.stringValue.flatMap { WireIds.matches($0, prefix: "ent") ? $0 : nil }
      return .failed(
        FailedEntry(
          seq: seq,
          id: id,
          kind: object?["kind"]?.stringValue,
          text: object?["text"]?.stringValue,
          redacted: object?["redacted"]?.boolValue == true,
          issue: "No usable envelope",
          raw: raw
        ))
    }
    guard SupportWire.knownEntryKinds.contains(envelope.kind) else {
      return .unknown(
        seq: envelope.seq, id: envelope.id, kind: envelope.kind, text: envelope.text, raw: object)
    }
    do {
      return .known(try KnownEntry.decode(raw), raw: object)
    } catch {
      return .failed(
        FailedEntry(
          seq: envelope.seq,
          id: envelope.id,
          kind: envelope.kind,
          text: envelope.text,
          redacted: object["redacted"]?.boolValue == true,
          issue: String(describing: error),
          raw: raw
        ))
    }
  }

  /// The fields every entry carries, read on their own.
  private struct Envelope {
    let seq: Int
    let id: String
    let kind: String
    let text: String?
  }

  /// Decodes a window's entries one by one. A non-array decodes to no entries.
  public static func decodeAll(_ raw: JSONValue) -> [WireEntry] {
    (raw.arrayValue ?? []).map(decode)
  }
}
