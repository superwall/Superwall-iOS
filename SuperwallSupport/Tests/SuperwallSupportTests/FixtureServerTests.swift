import Foundation
import XCTest

@testable import SuperwallSupport

/// End to end against paywall-next's fixture server:
///
///   PORT=8791 pnpm --filter @superwall/inbox-test-client fixture-server
///   SUPPORT_FIXTURE_URL=http://localhost:8791 swift test
///
/// Skipped when `SUPPORT_FIXTURE_URL` isn't set.
final class FixtureServerTests: XCTestCase {
  var baseURL: URL!

  override func setUpWithError() throws {
    guard let value = ProcessInfo.processInfo.environment["SUPPORT_FIXTURE_URL"],
      let url = URL(string: value)
    else {
      throw XCTSkip("Set SUPPORT_FIXTURE_URL to run against the fixture server")
    }
    baseURL = url
  }

  func makeTransport(
    apiKey: String, install: String = UUID().uuidString, queueFile: URL? = nil,
    configure: (inout SupportTransport.Configuration) -> Void = { _ in }
  ) -> SupportTransport {
    var configuration = SupportTransport.Configuration(
      baseURL: baseURL, apiKey: apiKey, sdk: SupportSdk(platform: "test", version: "0.0.0"),
      locale: "en", proofs: [SupportProof(kind: "install_secret", value: install)])
    configuration.backoffInitial = 0.05
    configuration.backoffMax = 0.4
    configuration.sendQueueFileURL = queueFile
    configuration.persistSendQueue = queueFile != nil
    configure(&configuration)
    return SupportTransport(configuration: configuration)
  }

  /// The newest window over HTTP: what the server holds, to compare a client against.
  func serverEntries(_ transport: SupportTransport) async throws -> [WireEntry] {
    let current = await transport.session
    let session = try XCTUnwrap(current)
    let http = SupportHTTPClient(baseURL: baseURL, urlSession: .shared)
    let window = try await http.entries(
      token: session.sessionToken, conversationId: session.conversationId, limit: 200)
    return window.decodedEntries
  }

  func waitUntil(
    _ timeout: TimeInterval = 15, _ what: String, _ condition: () async -> Bool
  ) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await condition() { return }
      try await Task.sleep(nanoseconds: 20_000_000)
    }
    XCTFail("Timed out waiting for \(what)")
  }

  /// Waits until a script has played out: its transcript's entry count, no tail,
  /// and its final status.
  func waitForScript(_ transport: SupportTransport, _ script: String) async throws {
    let transcript = try FixtureTests.load("wire/conversations/\(script).json")
    let count = transcript["window"]?["entries"]?.arrayValue?.count ?? -1
    let status = transcript["frames"]?.arrayValue?.last?["state"]?.stringValue
    try await waitUntil(20, "\(count) entries and status \(status ?? "none")") {
      let log = await transport.log
      return log.entries.count == count && log.tail == nil && log.status == status
    }
  }

  func testPacedConversationArrivesExact() async throws {
    let transport = makeTransport(apiKey: "pk_fixture_billing-question")
    try await transport.start()
    try await waitForScript(transport, "billing-question")
    let log = await transport.log
    let server = try await serverEntries(transport)
    XCTAssertEqual(log.entries, server)
    let stats = await transport.stats
    XCTAssertEqual(stats.gaps, 0)
    let state = await transport.state
    XCTAssertEqual(state, .live)
    await transport.stop()
  }

  /// The socket is cut after every new seq (no close frame, as a network cut would);
  /// each reconnect resumes from the cursor, and the log ends exact.
  func testDropAtEverySeq() async throws {
    for script in ["billing-question", "human-handoff", "future-kinds"] {
      let transport = makeTransport(apiKey: "pk_fixture_\(script)")
      let dropper = SeqDropper(transport: transport)
      await transport.setEventHandler { event in
        if event == .logChanged { Task { await dropper.check() } }
      }
      try await transport.start()
      try await waitForScript(transport, script)
      let log = await transport.log
      let server = try await serverEntries(transport)
      XCTAssertEqual(log.entries, server, script)
      let stats = await transport.stats
      let drops = await dropper.drops
      let droppedAt = await dropper.droppedAt
      XCTAssertEqual(stats.gaps, 0, script)
      XCTAssertGreaterThanOrEqual(drops, 1, script)
      print("\(script): \(drops) drops at seqs \(droppedAt), \(stats.connects) connects, gaps \(stats.gaps), dups \(stats.duplicates)")
      await transport.stop()
    }
  }

  /// Deterministic: the transport cuts its own socket right after accepting each
  /// new seq, so it resumes from every position, while 30 messages land.
  func testResumeFromEverySeq() async throws {
    let seen = SeenSeqs()
    let transport = makeTransport(apiKey: "pk_test_plain") { configuration in
      configuration.dropAfterAcceptingForTesting = { seq in seen.firstTime(seq) }
    }
    try await transport.start()
    try await waitUntil(5, "live") { await transport.state == .live }
    let current = await transport.session
    let session = try XCTUnwrap(current)
    let http = SupportHTTPClient(baseURL: baseURL, urlSession: .shared)
    for index in 0..<30 {
      _ = try await http.sendMessage(
        token: session.sessionToken, conversationId: session.conversationId,
        SendMessage(clientMessageId: "every-\(index)", text: "Message \(index)", attachments: nil))
    }
    try await waitUntil(20, "30 entries") { await transport.log.entries.count == 30 }
    try await waitUntil(5, "live") { await transport.state == .live }
    let held = await transport.log.entries
    let server = try await serverEntries(transport)
    XCTAssertEqual(held, server)
    XCTAssertEqual(held.compactMap(\.seq), Array(1...30))
    let stats = await transport.stats
    XCTAssertEqual(seen.count, 30, "dropped after every seq")
    XCTAssertEqual(stats.gaps, 0)
    print("resume from every seq: \(seen.count) drops, \(stats.connects) connects, gaps \(stats.gaps), dups \(stats.duplicates)")
    await transport.stop()
  }

  func testBackgroundThenForegroundResumes() async throws {
    let transport = makeTransport(apiKey: "pk_fixture_human-handoff")
    try await transport.start()
    try await waitUntil(10, "first entry") { await transport.log.entries.count >= 1 }
    await transport.setForeground(false)
    let backgroundState = await transport.state
    XCTAssertEqual(backgroundState, .idle)
    // The script keeps going while we hold no socket.
    try await Task.sleep(nanoseconds: 1_500_000_000)
    let heldInBackground = await transport.log.entries.count
    await transport.setForeground(true)
    try await waitForScript(transport, "human-handoff")
    let held = await transport.log.entries
    let server = try await serverEntries(transport)
    XCTAssertEqual(held, server)
    print("background: held \(heldInBackground) entries, caught up to 5 on foreground")
    await transport.stop()
  }

  func testNetworkLossThenReturn() async throws {
    let transport = makeTransport(apiKey: "pk_fixture_future-kinds")
    try await transport.start()
    try await waitUntil(10, "first entry") { await transport.log.entries.count >= 1 }
    await transport.setNetworkAvailable(false)
    let offlineState = await transport.state
    XCTAssertEqual(offlineState, .offline)
    try await Task.sleep(nanoseconds: 1_000_000_000)
    let started = Date()
    await transport.setNetworkAvailable(true)
    try await waitUntil(5, "live again") { await transport.state == .live }
    print(String(format: "network back -> live in %.0f ms", Date().timeIntervalSince(started) * 1000))
    try await waitForScript(transport, "future-kinds")
    let held = await transport.log.entries
    let server = try await serverEntries(transport)
    XCTAssertEqual(held, server)
    await transport.stop()
  }

  /// A send made offline is persisted, survives the transport going away, and
  /// lands exactly once when a new transport (a relaunch) drains the queue.
  func testSendQueueSurvivesRelaunchAndLandsOnce() async throws {
    let install = UUID().uuidString
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("send-queue-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }

    let first = makeTransport(apiKey: "pk_test_plain", install: install, queueFile: file)
    try await first.start()
    let firstSession = await first.session
    let conversationId = try XCTUnwrap(firstSession?.conversationId)
    await first.setNetworkAvailable(false)
    let pending = try await first.send(text: "Where is my receipt?")
    let queued = await first.pendingMessages
    XCTAssertEqual(queued.count, 1)
    await first.stop()

    // The queue is on disk.
    let saved = try JSONDecoder.iso.decode([PendingMessage].self, from: Data(contentsOf: file))
    XCTAssertEqual(saved.map(\.clientMessageId), [pending.clientMessageId])

    let second = makeTransport(apiKey: "pk_test_plain", install: install, queueFile: file)
    try await second.start(conversationId: conversationId)
    try await waitUntil(10, "queue drained") { await second.pendingMessages.isEmpty }
    try await waitUntil(10, "entry over the socket") {
      await second.log.entries.contains { $0.clientMessageId == pending.clientMessageId }
    }

    // A retry with the same id (the response was lost) gets the first entry back.
    let secondSession = await second.session
    let session = try XCTUnwrap(secondSession)
    let http = SupportHTTPClient(baseURL: baseURL, urlSession: .shared)
    let again = try await http.sendMessage(
      token: session.sessionToken, conversationId: conversationId,
      SendMessage(clientMessageId: pending.clientMessageId, text: "ignored", attachments: nil))
    XCTAssertTrue(again.duplicate)
    let server = try await serverEntries(second)
    XCTAssertEqual(server.filter { $0.clientMessageId == pending.clientMessageId }.count, 1)
    let secondEntries = await second.log.entries
    XCTAssertEqual(secondEntries, server)
    await second.stop()
  }

  /// Far behind at `ready` (more than the socket replay cap): the client reads
  /// windows over HTTP, then the socket only carries what's new.
  func testFarBehindCatchesUpOverHTTP() async throws {
    let transport = makeTransport(apiKey: "pk_test_plain") { $0.socketReplayCap = 10 }
    try await transport.start()
    try await waitUntil(5, "live") { await transport.state == .live }
    let current = await transport.session
    let session = try XCTUnwrap(current)
    let http = SupportHTTPClient(baseURL: baseURL, urlSession: .shared)
    // The client holds two entries…
    for index in 0..<2 {
      _ = try await http.sendMessage(
        token: session.sessionToken, conversationId: session.conversationId,
        SendMessage(clientMessageId: "held-\(index)", text: "Held \(index)", attachments: nil))
    }
    try await waitUntil(5, "2 held") { await transport.log.cursor == 2 }
    await transport.setForeground(false)

    // …then 25 more land while it holds no socket.
    for index in 0..<25 {
      _ = try await http.sendMessage(
        token: session.sessionToken, conversationId: session.conversationId,
        SendMessage(clientMessageId: "bulk-\(index)", text: "Message \(index)", attachments: nil))
    }
    await transport.setForeground(true)
    try await waitUntil(10, "caught up") { await transport.log.entries.count == 27 }
    try await waitUntil(5, "live") { await transport.state == .live }
    let stats = await transport.stats
    XCTAssertEqual(stats.httpCatchUps, 1)
    XCTAssertEqual(stats.gaps, 0)
    let held = await transport.log.entries
    let server = try await serverEntries(transport)
    XCTAssertEqual(held, server)
    await transport.stop()
  }

  func testOverlongMessageIsRefusedBeforeQueueing() async throws {
    let transport = makeTransport(apiKey: "pk_test_plain")
    try await transport.start()
    do {
      _ = try await transport.send(text: String(repeating: "a", count: SupportWire.maxMessageLength + 1))
      XCTFail("Expected messageTooLong")
    } catch SupportTransportError.messageTooLong {}
    let pendingAfter = await transport.pendingMessages
    XCTAssertTrue(pendingAfter.isEmpty)
    await transport.stop()
  }
}

final class SeenSeqs: @unchecked Sendable {
  private let lock = NSLock()
  private var seqs = Set<Int>()
  func firstTime(_ seq: Int) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return seqs.insert(seq).inserted
  }
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return seqs.count
  }
}

/// Cuts the socket the first time each new seq is held.
actor SeqDropper {
  let transport: SupportTransport
  var lastSeen = 0
  var drops = 0
  var droppedAt: [Int] = []

  init(transport: SupportTransport) {
    self.transport = transport
  }

  func check() async {
    let cursor = await transport.log.cursor
    guard cursor > lastSeen else { return }
    lastSeen = cursor
    drops += 1
    droppedAt.append(cursor)
    await transport.dropConnectionForTesting()
  }
}

extension JSONDecoder {
  static let iso: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}
