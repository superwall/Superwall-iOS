import Foundation

// Session start and HTTP command payloads, mirroring
// `@superwall/inbox-contracts/wire/session.ts` and `commands.ts`. Requests are
// Encodable; responses decode with `JSONDecoder` and keep unknown keys out of
// the way (they're ignored, as the schemas do).

public struct SupportSdk: Codable, Equatable, Sendable {
  /// `ios`, `android`, `expo`, `flutter` …
  public var platform: String
  public var version: String
  /// The add-on build, when it ships separately from core.
  public var addonVersion: String?

  public init(platform: String, version: String, addonVersion: String? = nil) {
    self.platform = platform
    self.version = version
    self.addonVersion = addonVersion
  }
}

public struct SupportCapabilities: Codable, Equatable, Sendable {
  public struct UI: Codable, Equatable, Sendable {
    public var v: Int
    public var elements: [String: Int]
    public init(v: Int, elements: [String: Int]) {
      self.v = v
      self.elements = elements
    }
  }
  public var ui: UI
  public var cards: [String]
  /// Open bridge verbs: `purchase`, `restore`, `manage`, `refund`, `open_url`, `tool` …
  public var actions: [String]
  /// Entry kinds this build renders natively. Others draw from `text`.
  public var entryKinds: [String]?
  public var attachments: Bool?

  public init(
    ui: UI, cards: [String], actions: [String], entryKinds: [String]? = nil, attachments: Bool? = nil
  ) {
    self.ui = ui
    self.cards = cards
    self.actions = actions
    self.entryKinds = entryKinds
    self.attachments = attachments
  }

  /// What the transport-only build can draw: text for everything (M2 adds renderers).
  public static let textOnly = SupportCapabilities(
    ui: UI(v: 1, elements: [:]), cards: [], actions: [], entryKinds: nil, attachments: true)
}

public struct SupportAppTool: Codable, Equatable, Sendable {
  public var name: String
  public var version: String
  public var schemaHash: String
}

/// One proof the session presents. `value` is a secret: never logged.
public struct SupportProof: Codable, Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  public var description: String { "SupportProof(kind: \(kind), value: <redacted>)" }
  public var debugDescription: String { description }
  public var kind: String
  public var value: String
  public init(kind: String, value: String) {
    self.kind = kind
    self.value = value
  }
}

public struct SessionStart: Codable, Equatable, Sendable {
  public var `protocol`: String = SupportWire.protocolName
  public var apiKey: String
  public var sdk: SupportSdk
  public var locale: String
  public var storefront: String?
  public var capabilities: SupportCapabilities
  public var appTools: [SupportAppTool]?
  public var proofs: [SupportProof]
  /// Reopen this conversation if the proofs allow, instead of the latest open one.
  public var conversationId: String?

  public init(
    apiKey: String, sdk: SupportSdk, locale: String, storefront: String? = nil,
    capabilities: SupportCapabilities, appTools: [SupportAppTool]? = nil,
    proofs: [SupportProof], conversationId: String? = nil
  ) {
    self.apiKey = apiKey
    self.sdk = sdk
    self.locale = locale
    self.storefront = storefront
    self.capabilities = capabilities
    self.appTools = appTools
    self.proofs = proofs
    self.conversationId = conversationId
  }
}

public struct SessionStarted: Decodable, Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  /// Never prints the token.
  public var description: String {
    "SessionStarted(sessionId: \(sessionId), conversationId: \(conversationId), sessionToken: <redacted>)"
  }
  public var debugDescription: String { description }
  public struct AcceptedProof: Decodable, Equatable, Sendable {
    public let kind: String
    /// `anonymous` or `identified`.
    public let level: String
    public let expiresAt: String?
  }
  public struct Human: Decodable, Equatable, Sendable {
    public let available: Bool
    public let etaSeconds: Int?
  }
  public struct Redirect: Decodable, Equatable, Sendable {
    public let reason: String
    public let url: String
  }

  public let `protocol`: String
  public let sessionId: String
  public let sessionToken: String
  public let expiresAt: String
  public let applicationId: Int
  public let conversationId: String
  public let proofs: [AcceptedProof]
  public let caps: SupportCapabilities
  public let disclosure: String?
  public let consentRequired: Bool
  /// The computed palette (theme contract, M2). Opaque here.
  public let theme: [String: JSONValue]
  public let human: Human
  /// Present when this build must not open chat.
  public let redirect: Redirect?
  /// Seconds between client pings on the socket.
  public let heartbeatSeconds: Int
}

/// `GET /v1/conversations/:id/entries`: entries are raw JSON, decoded one by one.
public struct EntryWindow: Decodable, Equatable, Sendable {
  public let conversationId: String
  public let entries: [JSONValue]
  public let head: Int
  public let hasMore: Bool

  enum CodingKeys: String, CodingKey { case conversationId, entries, head, hasMore }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    conversationId = try container.decode(String.self, forKey: .conversationId)
    // Like decodeEntries in lenient.ts: anything but an array is no entries, never a failed window.
    entries = (try? container.decode([JSONValue].self, forKey: .entries)) ?? []
    head = try container.decode(Int.self, forKey: .head)
    hasMore = try container.decode(Bool.self, forKey: .hasMore)
  }

  public var decodedEntries: [WireEntry] { entries.map(WireEntry.decode) }
}

public struct AttachmentRef: Codable, Equatable, Sendable {
  public var attachmentId: String
}

public struct SendMessage: Codable, Equatable, Sendable {
  public var clientMessageId: String
  public var text: String
  public var attachments: [AttachmentRef]?
  public var seenSeq: Int?

  /// The rules the server enforces, checked before a send is queued.
  public func validate() throws {
    guard WireIds.isClientMessageId(clientMessageId) else {
      throw SupportTransportError.invalidMessage("clientMessageId")
    }
    // The schema's max length counts UTF-16 code units, like JavaScript.
    guard text.utf16.count <= SupportWire.maxMessageLength else {
      throw SupportTransportError.messageTooLong(max: SupportWire.maxMessageLength)
    }
  }
}

public struct SendAccepted: Decodable, Equatable, Sendable {
  /// The committed `person_message`, as raw JSON.
  public let entry: JSONValue
  public let duplicate: Bool
}

public struct MarkRead: Codable, Equatable, Sendable {
  public var seq: Int
}

public struct UploadRequest: Codable, Equatable, Sendable {
  /// `file` or `diagnostics`.
  public var kind: String
  public var filename: String
  public var mime: String
  public var bytes: Int
  /// Hex SHA-256 of the bytes.
  public var sha256: String
}

public struct UploadIntent: Decodable, Equatable, Sendable {
  public struct Upload: Decodable, Equatable, Sendable {
    public let method: String
    public let url: String
    public let headers: [String: String]
    public let expiresAt: String
  }
  public let attachmentId: String
  public let upload: Upload
}

public struct UploadCompleted: Decodable, Equatable, Sendable {
  public let attachmentId: String
  /// `quarantine`, `clean` or `rejected`.
  public let status: String
}

public struct AttachmentUrl: Decodable, Equatable, Sendable {
  public let url: String
  public let expiresAt: String
}

public struct CardActionRequest: Codable, Equatable, Sendable {
  public var actionId: String
  public var token: String
  public var values: [String: JSONValue]?
}

public struct CardActionAccepted: Decodable, Equatable, Sendable {
  public let entries: [JSONValue]
}

public struct ToolCallResultRequest: Codable, Equatable, Sendable {
  /// `ok`, `error` or `declined`.
  public var status: String
  public var data: JSONValue?
}

/// An HTTP error body: `_tag` is the stable code, and `retryable` tells an SDK
/// that doesn't know the tag whether to retry.
public struct WireErrorBody: Decodable, Equatable, Sendable, Error {
  public let tag: String
  public let message: String
  public let retryable: Bool
  public let redirect: String?
  public let reason: String?
  public let retryAfterMs: Int?

  enum CodingKeys: String, CodingKey {
    case tag = "_tag"
    case message, retryable, redirect, reason, retryAfterMs
  }

  /// Tags whose schema defaults `retryable` to true when a body omits it.
  static let retryableByDefault: Set<String> = ["RateLimited", "WireUnavailable"]

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    tag = try container.decode(String.self, forKey: .tag)
    message = try container.decode(String.self, forKey: .message)
    retryable =
      try container.decodeIfPresent(Bool.self, forKey: .retryable)
      ?? Self.retryableByDefault.contains(tag)
    redirect = try container.decodeIfPresent(String.self, forKey: .redirect)
    reason = try container.decodeIfPresent(String.self, forKey: .reason)
    retryAfterMs = try container.decodeIfPresent(Int.self, forKey: .retryAfterMs)
  }

  init(tag: String, message: String, retryable: Bool) {
    self.tag = tag
    self.message = message
    self.retryable = retryable
    redirect = nil
    reason = nil
    retryAfterMs = nil
  }
}

public enum SupportTransportError: Error, Equatable, Sendable {
  case messageTooLong(max: Int)
  case invalidMessage(String)
  case attachmentTooLarge(max: Int)
  /// The server answered with a wire error body.
  case wire(WireErrorBody)
  /// No response, or one we couldn't read. Always safe to retry: commands are idempotent.
  case network(String)
  /// A request this build can't even make (a bad URL). Retrying won't help.
  case invalidRequest(String)
  case notStarted
  /// The session told this build not to open chat.
  case redirected(url: String)

  public var isRetryable: Bool {
    switch self {
    case .wire(let body): return body.retryable
    case .network: return true
    default: return false
    }
  }

  /// How long the server asked us to wait (`RateLimited.retryAfterMs`), in seconds.
  var retryAfter: TimeInterval? {
    if case .wire(let body) = self, let ms = body.retryAfterMs { return Double(ms) / 1000 }
    return nil
  }
}
