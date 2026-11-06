import Foundation

#if canImport(CryptoKit)
  import CryptoKit
#endif

/// The HTTP half of `superwall-support/1`: sessions, windows, commands, uploads.
/// Every command is idempotent, so the caller may retry any retryable failure as-is.
final class SupportHTTPClient: @unchecked Sendable {
  let baseURL: URL
  private let urlSession: URLSession
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  var requestTimeout: TimeInterval = 15

  init(baseURL: URL, urlSession: URLSession) {
    self.baseURL = baseURL
    self.urlSession = urlSession
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  }

  func startSession(_ request: SessionStart) async throws -> SessionStarted {
    try await send("POST", "/v1/sessions", token: nil, body: request)
  }

  /// A window: `after` for catching up, `before` for scrolling back, neither for the newest.
  func entries(
    token: String, conversationId: String, after: Int? = nil, before: Int? = nil,
    limit: Int = SupportWire.defaultWindow
  ) async throws -> EntryWindow {
    var query = [URLQueryItem(name: "limit", value: String(min(max(limit, 1), SupportWire.maxWindow)))]
    if let after { query.append(URLQueryItem(name: "after", value: String(after))) }
    if let before { query.append(URLQueryItem(name: "before", value: String(before))) }
    return try await send(
      "GET", "/v1/conversations/\(conversationId)/entries", token: token, body: nil as Empty?,
      query: query)
  }

  func sendMessage(token: String, conversationId: String, _ message: SendMessage) async throws
    -> SendAccepted
  {
    try await send("POST", "/v1/conversations/\(conversationId)/messages", token: token, body: message)
  }

  func markRead(token: String, conversationId: String, seq: Int) async throws {
    let _: Empty = try await send(
      "POST", "/v1/conversations/\(conversationId)/read", token: token, body: MarkRead(seq: seq))
  }

  func createUpload(token: String, conversationId: String, _ request: UploadRequest) async throws
    -> UploadIntent
  {
    try await send("POST", "/v1/conversations/\(conversationId)/attachments", token: token, body: request)
  }

  func completeUpload(token: String, attachmentId: String) async throws -> UploadCompleted {
    try await send("POST", "/v1/attachments/\(attachmentId)/complete", token: token, body: nil as Empty?)
  }

  func attachmentURL(token: String, attachmentId: String) async throws -> AttachmentUrl {
    try await send("GET", "/v1/attachments/\(attachmentId)/url", token: token, body: nil as Empty?)
  }

  func cardAction(token: String, cardId: String, _ request: CardActionRequest) async throws
    -> CardActionAccepted
  {
    try await send("POST", "/v1/cards/\(cardId)/actions", token: token, body: request)
  }

  func toolCallResult(token: String, callId: String, _ request: ToolCallResultRequest) async throws {
    let _: Empty = try await send("POST", "/v1/tool-calls/\(callId)/result", token: token, body: request)
  }

  /// The presigned PUT of an upload intent: straight to storage, no bearer token.
  func put(_ upload: UploadIntent.Upload, data: Data) async throws {
    guard let url = URL(string: upload.url) else {
      throw SupportTransportError.invalidRequest("Bad upload URL")
    }
    var request = URLRequest(url: url)
    request.httpMethod = upload.method
    for (name, value) in upload.headers { request.setValue(value, forHTTPHeaderField: name) }
    request.httpBody = data
    let response: URLResponse
    do {
      (_, response) = try await urlSession.data(for: request)
    } catch {
      throw SupportTransportError.network(Self.describe(error))
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
      // Storage errors carry no wire body. 4xx (an expired link) needs a new intent, so it isn't retried here.
      throw SupportTransportError.wire(
        WireErrorBody(tag: "UploadFailed", message: "Upload answered \(status)", retryable: status >= 500))
    }
  }

  // MARK: - Plumbing

  private struct Empty: Codable {}

  private func send<Body: Encodable, Response: Decodable>(
    _ method: String, _ path: String, token: String?, body: Body?, query: [URLQueryItem] = []
  ) async throws -> Response {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw SupportTransportError.invalidRequest("Bad URL")
    }
    let basePath = components.path.trimmingSuffix("/")
    components.path = basePath + path
    if !query.isEmpty { components.queryItems = query }
    guard let url = components.url else { throw SupportTransportError.invalidRequest("Bad URL") }
    var request = URLRequest(url: url)
    request.httpMethod = method
    // Short, so a stalled window read fails over to a retry instead of hanging catch-up.
    request.timeoutInterval = requestTimeout
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try encoder.encode(body)
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await urlSession.data(for: request)
    } catch {
      throw SupportTransportError.network(Self.describe(error))
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
      if let body = try? decoder.decode(WireErrorBody.self, from: data) {
        throw SupportTransportError.wire(body)
      }
      // No wire body (a proxy, a crash): 5xx and 429 are worth retrying, 4xx isn't.
      throw SupportTransportError.wire(
        WireErrorBody(
          tag: "HTTP\(status)", message: "HTTP \(status)", retryable: status >= 500 || status == 429))
    }
    if Response.self == Empty.self, data.isEmpty {
      // `Empty` has no fields, so decoding `{}` always succeeds.
      return try decoder.decode(Response.self, from: Data("{}".utf8))
    }
    do {
      return try decoder.decode(Response.self, from: data)
    } catch {
      // A 2xx we can't read: retrying the same idempotent command is the safe answer.
      // Only the type: a decoding error can quote what it failed on.
      throw SupportTransportError.network("Undecodable response: \(type(of: error))")
    }
  }

  static func describe(_ error: Error) -> String {
    let nsError = error as NSError
    return "\(nsError.domain) \(nsError.code)"
  }

  static func sha256Hex(_ data: Data) -> String {
    #if canImport(CryptoKit)
      return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    #else
      fatalError("CryptoKit is required")
    #endif
  }
}

extension String {
  func trimmingSuffix(_ suffix: String) -> String {
    hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
  }
}
