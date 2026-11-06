import Foundation
import XCTest

@testable import SuperwallSupport

/// The transport against a scripted socket and stubbed HTTP, for the cases a
/// real server won't produce on demand: stalls, close codes, resync and gaps.
final class TransportUnitTests: XCTestCase {
  static let conversation = "conv_01M6R13Q95YDTN13DKKN7BFQD2"
  static func entryId(_ seq: Int) -> String {
    "ent_" + String(repeating: "0", count: 26 - String(seq).count) + String(seq)
  }

  var sockets: FakeSocketFactory!
  var http: StubHTTP!

  override func setUp() {
    sockets = FakeSocketFactory()
    http = StubHTTP()
    StubURLProtocol.handler = { [http] request in http!.handle(request) }
  }

  func makeTransport(
    configure: (inout SupportTransport.Configuration) -> Void = { _ in }
  ) -> SupportTransport {
    var configuration = SupportTransport.Configuration(
      baseURL: URL(string: "https://inbox.test")!, apiKey: "pk_unit",
      sdk: SupportSdk(platform: "test", version: "0"), locale: "en",
      proofs: [SupportProof(kind: "install_secret", value: "i")])
    configuration.persistSendQueue = false
    configuration.backoffInitial = 0.02
    configuration.backoffMax = 0.05
    configuration.pingInterval = 0.2
    configuration.pingDeadline = 0.1
    configure(&configuration)
    let session = URLSessionConfiguration.ephemeral
    session.protocolClasses = [StubURLProtocol.self]
    return SupportTransport(
      configuration: configuration,
      http: SupportHTTPClient(baseURL: configuration.baseURL, urlSession: URLSession(configuration: session)),
      socketFactory: sockets, logger: { _ in })
  }

  func waitUntil(_ what: String, timeout: TimeInterval = 5, _ condition: () async -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await condition() { return }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for \(what)")
  }

  static func entryFrame(_ seq: Int, prev: Int) -> String {
    JSONValue.object([
      "type": .string("entry"), "seq": .number(Double(seq)), "prev": .number(Double(prev)),
      "entry": FixtureTests.entry(seq: seq, id: entryId(seq))
    ]).serialized()
  }

  static func ready(after: Int, head: Int) -> String {
    #"{"type":"ready","protocol":"superwall-support/1","conversationId":"\#(conversation)","after":\#(after),"head":\#(head)}"#
  }

  // MARK: -

  func testHelloCarriesTheCursor() async throws {
    http.windowEntries = [1, 2, 3]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    let hello = try await sockets.latest.firstSent()
    guard case .hello(_, let conversationId, let after, let afterId) = ClientFrame.decode(hello) else {
      return XCTFail("first frame wasn't hello: \(hello)")
    }
    XCTAssertEqual(conversationId, Self.conversation)
    XCTAssertEqual(after, 3)
    XCTAssertEqual(afterId, Self.entryId(3))
    await transport.stop()
  }

  /// The backlog stalls after `ready` with zero bytes (the EDGE case from the
  /// spike): the ping deadline still runs, so the socket is dropped and retried.
  func testPingDeadlineRunsDuringCatchUp() async throws {
    http.windowEntries = [1]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    let first = sockets.latest
    first.deliver(Self.ready(after: 1, head: 5))
    first.deliver(Self.entryFrame(2, prev: 1))
    first.answersPings = false
    try await waitUntil("catching up") { await transport.state == .catchingUp }
    try await waitUntil("ping timeout and a new socket") { self.sockets.count == 2 }
    let stats = await transport.stats
    XCTAssertEqual(stats.pingTimeouts, 1)
    // The new socket resumes from 2.
    let hello = try await sockets.latest.firstSent()
    guard case .hello(_, _, let after, _) = ClientFrame.decode(hello) else { return XCTFail() }
    XCTAssertEqual(after, 2)
    await transport.stop()
  }

  func testGapReconnectsWithTheCursor() async throws {
    http.windowEntries = [1]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    let socket = sockets.latest
    socket.deliver(Self.ready(after: 1, head: 4))
    socket.deliver(Self.entryFrame(3, prev: 2))  // 2 is missing
    try await waitUntil("reconnect") { self.sockets.count == 2 }
    let stats = await transport.stats
    XCTAssertEqual(stats.gaps, 1)
    let cursor = await transport.log.cursor
    XCTAssertEqual(cursor, 1)
    await transport.stop()
  }

  func testDuplicateIsDropped() async throws {
    http.windowEntries = [1, 2]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    let socket = sockets.latest
    socket.deliver(Self.ready(after: 2, head: 2))
    socket.deliver(Self.entryFrame(2, prev: 1))
    try await waitUntil("duplicate counted") { await transport.stats.duplicates == 1 }
    let count = await transport.log.entries.count
    XCTAssertEqual(count, 2)
    XCTAssertEqual(sockets.count, 1)
    await transport.stop()
  }

  func testResyncReloadsNewestWindowAndReconnects() async throws {
    http.windowEntries = [1, 2]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    // The server's log was restored: it now holds 10…12.
    http.windowEntries = [10, 11, 12]
    sockets.latest.deliver(#"{"type":"resync","reason":"boundary_mismatch","head":12}"#)
    try await waitUntil("reconnect") { self.sockets.count == 2 }
    let seqs = await transport.log.entries.compactMap(\.seq)
    XCTAssertEqual(seqs, [10, 11, 12])
    let hello = try await sockets.latest.firstSent()
    guard case .hello(_, _, let after, _) = ClientFrame.decode(hello) else { return XCTFail() }
    XCTAssertEqual(after, 12)
    await transport.stop()
  }

  func testNotFoundStops() async throws {
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    sockets.latest.closeFromServer(code: SupportCloseCode.notFound)
    try await waitUntil("stopped") { await transport.state == .stopped(reason: "not_found") }
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(sockets.count, 1, "never retries a gone conversation")
  }

  func testProtocolUnsupportedStops() async throws {
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    sockets.latest.closeFromServer(code: SupportCloseCode.protocolUnsupported)
    try await waitUntil("stopped") { await transport.state == .stopped(reason: "protocol_unsupported") }
  }

  func testSessionInvalidStartsANewSession() async throws {
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    XCTAssertEqual(http.sessionsStarted, 1)
    sockets.latest.closeFromServer(code: SupportCloseCode.sessionInvalid)
    try await waitUntil("new socket") { self.sockets.count == 2 }
    XCTAssertEqual(http.sessionsStarted, 2)
    let hello = try await sockets.latest.firstSent()
    guard case .hello(let token, _, _, _) = ClientFrame.decode(hello) else { return XCTFail() }
    XCTAssertEqual(token, "tok_2")
    await transport.stop()
  }

  func testServerGoingAwayRetriesWithBackoff() async throws {
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    sockets.latest.closeFromServer(code: SupportCloseCode.goingAway)
    try await waitUntil("retry") { self.sockets.count == 2 }
    await transport.stop()
  }

  func testTailIsTruncateThenAppendAndSealedByItsEntry() async throws {
    http.windowEntries = [1]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    let socket = sockets.latest
    let id = Self.entryId(2)
    socket.deliver(Self.ready(after: 1, head: 1))
    socket.deliver(#"{"type":"tail","messageId":"\#(id)","offset":0,"text":"You renewed "}"#)
    socket.deliver(#"{"type":"tail","messageId":"\#(id)","offset":12,"text":"the Year"}"#)
    // A replayed chunk is harmless.
    socket.deliver(#"{"type":"tail","messageId":"\#(id)","offset":12,"text":"the Year"}"#)
    // A chunk past what's held (one was lost) is ignored.
    socket.deliver(#"{"type":"tail","messageId":"\#(id)","offset":99,"text":"zzz"}"#)
    try await waitUntil("tail") { await transport.log.tail?.text == "You renewed the Year" }
    socket.deliver(Self.entryFrame(2, prev: 1))
    try await waitUntil("sealed") { await transport.log.tail == nil }
    let count = await transport.log.entries.count
    XCTAssertEqual(count, 2)
    await transport.stop()
  }

  func testTailOffsetsAreUTF16() {
    let start = WireResume.applyTail(nil, messageId: "m", offset: 0, text: "Hi 👋🏽 there")
    // "Hi " is 3 code units, the emoji with its modifier 4.
    let truncated = WireResume.applyTail(start, messageId: "m", offset: 7, text: "!")
    XCTAssertEqual(truncated?.text, "Hi 👋🏽!")
  }

  func testUnknownFrameTypeAndMalformedJSONAreIgnored() async throws {
    http.windowEntries = [1]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    let socket = sockets.latest
    socket.deliver(Self.ready(after: 1, head: 2))
    socket.deliver(#"{"type":"reaction","emoji":"👍"}"#)
    socket.deliver("not json")
    socket.deliver(#"{"type":"entry","seq":2,"prev":1,"entry":{"kind":"card","text":"Reply 'yes'.","card":"broken"}}"#)
    try await waitUntil("live") { await transport.state == .live }
    let log = await transport.log
    XCTAssertEqual(log.cursor, 2, "an undecodable entry still moves the cursor")
    XCTAssertEqual(log.entries.last?.fallbackText, "Reply 'yes'.")
    let ignored = await transport.stats.ignoredFrames
    XCTAssertEqual(ignored, 2)
    await transport.stop()
  }

  func testUploadAsksPutsThenCompletes() async throws {
    let transport = makeTransport()
    try await transport.start()
    let bytes = Data("diagnostic log".utf8)
    let completed = try await transport.uploadAttachment(data: bytes, filename: "log.txt", mime: "text/plain")
    XCTAssertEqual(completed.status, "quarantine")
    XCTAssertEqual(http.calls.filter { !$0.hasPrefix("POST /v1/sessions") && !$0.hasPrefix("GET") }, [
      "POST /v1/conversations/\(Self.conversation)/attachments",
      "PUT https://uploads.test/put/att_1",
      "POST /v1/attachments/att_01M6R13Q95YDTN13DKKN7BFQD2/complete"
    ])
    XCTAssertEqual(http.uploaded, bytes)
    XCTAssertEqual(http.uploadRequest?["sha256"]?.stringValue, SupportHTTPClient.sha256Hex(bytes))
    XCTAssertEqual(http.uploadRequest?["bytes"]?.intValue, bytes.count)
    XCTAssertEqual(http.putContentType, "text/plain")
    await transport.stop()
  }

  func testSendRetriesTheSameClientMessageIdUntilAccepted() async throws {
    http.failSends = 2
    let transport = makeTransport()
    try await transport.start()
    let pending = try await transport.send(text: "Hello")
    try await waitUntil("accepted") { await transport.pendingMessages.isEmpty }
    XCTAssertEqual(http.sendIds, Array(repeating: pending.clientMessageId, count: 3))
    await transport.stop()
  }

  func testNonRetryableSendFailsAndStaysForTheUser() async throws {
    http.rejectSends = true
    let transport = makeTransport()
    try await transport.start()
    let pending = try await transport.send(text: "Hello")
    try await waitUntil("failed") { await transport.pendingMessages.first?.state == .failed }
    let failure = await transport.pendingMessages.first?.failure
    XCTAssertEqual(failure, "NotPermitted")
    http.rejectSends = false
    await transport.retry(clientMessageId: pending.clientMessageId)
    try await waitUntil("accepted on retry") { await transport.pendingMessages.isEmpty }
    await transport.stop()
  }

  /// The network dies between session start and the first window: start still
  /// connects, and a far-ahead `ready` loads the newest window, not all history.
  func testFirstWindowFailureStillConnects() async throws {
    http.failEntries = 1
    http.windowEntries = Array(1...100)
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    sockets.latest.deliver(Self.ready(after: 0, head: 100))
    try await waitUntil("newest window") { await transport.log.cursor == 100 }
    let hasOlder = await transport.log.hasOlder
    XCTAssertFalse(hasOlder)
    XCTAssertTrue(http.calls.contains { $0.hasPrefix("GET") }, "reloaded over HTTP")
    XCTAssertFalse(http.calls.contains { $0.contains("after=") }, "no catch-up from 0")
    await transport.stop()
  }

  /// URLSession can report the close code after `receive` throws: the `error`
  /// frame before the close decides instead.
  func testErrorFrameDecidesWhenTheCloseCodeIsMissing() async throws {
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    sockets.latest.deliver(#"{"type":"error","code":"conversation_not_found","message":"Gone","retryable":false}"#)
    try await Task.sleep(nanoseconds: 50_000_000)
    sockets.latest.closeFromServer(code: nil)
    try await waitUntil("stopped") { await transport.state == .stopped(reason: "not_found") }
  }

  /// While an HTTP catch-up replaces the socket, foreground and network events
  /// must not open a second socket from the half-caught-up cursor.
  func testNoSecondSocketDuringHTTPCatchUp() async throws {
    http.windowEntries = [1]
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    http.windowEntries = Array(1...100)
    http.entriesDelay = 0.3
    sockets.latest.deliver(Self.ready(after: 1, head: 100))
    try await waitUntil("catching up") { await transport.state == .catchingUp }
    await transport.setForeground(true)
    await transport.setNetworkAvailable(false)
    await transport.setNetworkAvailable(true)
    XCTAssertEqual(sockets.count, 1)
    try await waitUntil("caught up and reconnected") { self.sockets.count == 2 }
    let cursor = await transport.log.cursor
    XCTAssertEqual(cursor, 100)
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(sockets.count, 2)
    await transport.stop()
  }

  /// A scroll-back in flight when a resync replaces the log is dropped.
  func testStaleScrollBackIsDropped() async throws {
    http.windowEntries = Array(50...59)
    http.hasMore = true
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    http.beforeDelay = 0.4
    let older = Task { try await transport.loadOlder() }
    try await Task.sleep(nanoseconds: 50_000_000)
    http.windowEntries = [100, 101, 102]
    sockets.latest.deliver(#"{"type":"resync","reason":"boundary_mismatch","head":102}"#)
    try await older.value
    try await waitUntil("reconnected") { self.sockets.count == 2 }
    let seqs = await transport.log.entries.compactMap(\.seq)
    XCTAssertEqual(seqs, [100, 101, 102])
    await transport.stop()
  }

  /// A redirect at session start stops the transport and fails nothing silently;
  /// a heartbeat of 0 from the server can't spin the ping loop.
  func testRedirectStops() async throws {
    http.redirectSessions = true
    let transport = makeTransport()
    do {
      try await transport.start()
      XCTFail("expected a redirect")
    } catch SupportTransportError.redirected(let url) {
      XCTAssertEqual(url, "https://help.test")
    }
    let state = await transport.state
    XCTAssertEqual(state, .stopped(reason: "redirect"))
    XCTAssertEqual(sockets.count, 0)
  }

  /// Opened while the server is down: start throws, then keeps trying on its own.
  func testFailedStartRetriesByItself() async throws {
    http.failSessions = 2
    let transport = makeTransport()
    do {
      try await transport.start()
      XCTFail("expected the first start to fail")
    } catch {}
    try await waitUntil("connected on its own") { self.sockets.count == 1 }
    XCTAssertEqual(http.sessionsStarted, 1)
    await transport.stop()
  }

  func testBackgroundClosesAndForegroundReconnectsAtOnce() async throws {
    let transport = makeTransport()
    try await transport.start()
    try await waitUntil("socket") { self.sockets.count == 1 }
    await transport.setForeground(false)
    XCTAssertTrue(sockets.latest.closedByClient)
    let state = await transport.state
    XCTAssertEqual(state, .idle)
    await transport.setForeground(true)
    XCTAssertEqual(sockets.count, 2, "reconnects synchronously on foreground, no backoff wait")
    await transport.stop()
  }
}

// MARK: - Fakes

final class FakeSocket: SupportSocket, @unchecked Sendable {
  private let lock = NSLock()
  private var inbox: [String] = []
  private var waiters: [CheckedContinuation<String, Error>] = []
  private var sent: [String] = []
  private var sentWaiters: [CheckedContinuation<String, Never>] = []
  private var closed = false
  private var serverCloseCode: Int?
  var closedByClient = false
  var answersPings = true

  struct Closed: Error {}

  func send(_ text: String) async throws {
    try record(text)
  }

  private func record(_ text: String) throws {
    lock.lock()
    if closed {
      lock.unlock()
      throw Closed()
    }
    sent.append(text)
    let waiters = sentWaiters
    sentWaiters = []
    let answer = text == SupportWire.pingFrame && answersPings
    lock.unlock()
    waiters.forEach { $0.resume(returning: text) }
    if answer { deliver(#"{"type":"pong"}"#) }
  }

  func firstSent() async throws -> String {
    await withCheckedContinuation { continuation in register(continuation) }
  }

  private func register(_ continuation: CheckedContinuation<String, Never>) {
    lock.lock()
    if let first = sent.first {
      lock.unlock()
      continuation.resume(returning: first)
    } else {
      sentWaiters.append(continuation)
      lock.unlock()
    }
  }

  func receive() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      lock.lock()
      if !inbox.isEmpty {
        let next = inbox.removeFirst()
        lock.unlock()
        continuation.resume(returning: next)
      } else if closed {
        lock.unlock()
        continuation.resume(throwing: Closed())
      } else {
        waiters.append(continuation)
        lock.unlock()
      }
    }
  }

  func deliver(_ text: String) {
    lock.lock()
    if closed {
      lock.unlock()
      return
    }
    if waiters.isEmpty {
      inbox.append(text)
      lock.unlock()
    } else {
      let waiter = waiters.removeFirst()
      lock.unlock()
      waiter.resume(returning: text)
    }
  }

  func closeFromServer(code: Int?) {
    lock.lock()
    serverCloseCode = code
    closed = true
    let waiters = self.waiters
    self.waiters = []
    lock.unlock()
    waiters.forEach { $0.resume(throwing: Closed()) }
  }

  func close(code: Int, reason: String) {
    lock.lock()
    closedByClient = true
    closed = true
    let waiters = self.waiters
    self.waiters = []
    lock.unlock()
    waiters.forEach { $0.resume(throwing: Closed()) }
  }

  var closeCode: Int? {
    lock.lock()
    defer { lock.unlock() }
    return serverCloseCode
  }
}

final class FakeSocketFactory: SupportSocketFactory, @unchecked Sendable {
  private let lock = NSLock()
  private var made: [FakeSocket] = []
  func make(url: URL) -> SupportSocket {
    let socket = FakeSocket()
    lock.lock()
    made.append(socket)
    lock.unlock()
    return socket
  }
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return made.count
  }
  var latest: FakeSocket {
    lock.lock()
    defer { lock.unlock() }
    return made.last!
  }
}

/// Answers the inbox API's HTTP calls from memory.
final class StubHTTP: @unchecked Sendable {
  private let lock = NSLock()
  var windowEntries: [Int] = []
  var sessionsStarted = 0
  var calls: [String] = []
  var failSends = 0
  var failEntries = 0
  var hasMore = false
  var entriesDelay: TimeInterval = 0
  var beforeDelay: TimeInterval = 0
  var redirectSessions = false
  var failSessions = 0
  var rejectSends = false
  var sendIds: [String] = []
  var uploadRequest: [String: JSONValue]?
  var uploaded: Data?
  var putContentType: String?

  func handle(_ request: URLRequest) -> (Int, Data) {
    lock.lock()
    defer { lock.unlock() }
    let url = request.url!
    let method = request.httpMethod ?? "GET"
    let body = request.bodyData()
    calls.append(
      url.host == "uploads.test"
        ? "\(method) \(url.absoluteString)" : "\(method) \(url.path)\(url.query.map { "?" + $0 } ?? "")")
    switch (method, url.path) {
    case ("POST", "/v1/sessions") where failSessions > 0:
      failSessions -= 1
      return (503, Data(#"{"_tag":"WireUnavailable","message":"Down"}"#.utf8))
    case ("POST", "/v1/sessions") where redirectSessions:
      sessionsStarted += 1
      return (200, Data(#"""
        {"protocol":"superwall-support/1","sessionId":"sess_01M6R13Q96S0JV0S92F7TEJ3CH","sessionToken":"tok_r","expiresAt":"2026-11-06T09:55:23.174Z","applicationId":1,"conversationId":"\#(TransportUnitTests.conversation)","proofs":[],"caps":{"ui":{"v":1,"elements":{}},"cards":[],"actions":[]},"consentRequired":false,"theme":{},"human":{"available":false},"heartbeatSeconds":0,"redirect":{"reason":"sdk_blocked","url":"https://help.test"}}
        """#.utf8))
    case ("POST", "/v1/sessions"):
      sessionsStarted += 1
      return (200, Data(#"""
        {"protocol":"superwall-support/1","sessionId":"sess_01M6R13Q96S0JV0S92F7TEJ3CH","sessionToken":"tok_\#(sessionsStarted)","expiresAt":"2026-11-06T09:55:23.174Z","applicationId":1,"conversationId":"\#(TransportUnitTests.conversation)","proofs":[],"caps":{"ui":{"v":1,"elements":{}},"cards":[],"actions":[]},"consentRequired":false,"theme":{},"human":{"available":false},"heartbeatSeconds":25}
        """#.utf8))
    case ("GET", _) where url.path.hasSuffix("/entries") && failEntries > 0:
      failEntries -= 1
      return (503, Data(#"{"_tag":"WireUnavailable","message":"Down"}"#.utf8))
    case ("GET", _) where url.path.hasSuffix("/entries"):
      let delay = (url.query ?? "").contains("before=") ? beforeDelay : entriesDelay
      if delay > 0 {
        lock.unlock()
        Thread.sleep(forTimeInterval: delay)
        lock.lock()
      }
      let entries = windowEntries.map { FixtureTests.entry(seq: $0, id: TransportUnitTests.entryId($0)) }
      let json = JSONValue.object([
        "conversationId": .string(TransportUnitTests.conversation), "entries": .array(entries),
        "head": .number(Double(windowEntries.last ?? 0)), "hasMore": .bool(hasMore)
      ])
      return (200, Data(json.serialized().utf8))
    case ("POST", _) where url.path.hasSuffix("/messages"):
      let message = JSONValue.parse(body)!
      let id = message["clientMessageId"]!.stringValue!
      sendIds.append(id)
      if rejectSends {
        return (403, Data(#"{"_tag":"NotPermitted","message":"No","retryable":false}"#.utf8))
      }
      if failSends > 0 {
        failSends -= 1
        return (503, Data(#"{"_tag":"WireUnavailable","message":"Try again"}"#.utf8))
      }
      var entry = FixtureTests.entry(seq: 99, id: TransportUnitTests.entryId(99), kind: "person_message")
        .objectValue!
      entry["clientMessageId"] = .string(id)
      entry["author"] = .object(["type": .string("person")])
      return (200, Data(JSONValue.object(["entry": .object(entry), "duplicate": .bool(false)]).serialized().utf8))
    case ("POST", _) where url.path.hasSuffix("/attachments"):
      uploadRequest = JSONValue.parse(body)?.objectValue
      return (200, Data(#"""
        {"attachmentId":"att_01M6R13Q95YDTN13DKKN7BFQD2","upload":{"method":"PUT","url":"https://uploads.test/put/att_1","headers":{"content-type":"text/plain"},"expiresAt":"2026-11-06T10:10:00.000Z"}}
        """#.utf8))
    case ("PUT", _):
      uploaded = body
      putContentType = request.value(forHTTPHeaderField: "content-type")
      return (200, Data())
    case ("POST", _) where url.path.hasSuffix("/complete"):
      return (200, Data(#"{"attachmentId":"att_01M6R13Q95YDTN13DKKN7BFQD2","status":"quarantine"}"#.utf8))
    default:
      return (404, Data(#"{"_tag":"ConversationNotFound","message":"No"}"#.utf8))
    }
  }
}

final class StubURLProtocol: URLProtocol {
  nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let (status, data) = Self.handler?(request) ?? (500, Data())
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

extension URLRequest {
  /// The body, whether it was set directly or arrives as a stream (as URLProtocol sees uploads).
  func bodyData() -> Data {
    if let httpBody { return httpBody }
    guard let stream = httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let read = stream.read(&buffer, maxLength: buffer.count)
      if read <= 0 { break }
      data.append(buffer, count: read)
    }
    return data
  }
}
