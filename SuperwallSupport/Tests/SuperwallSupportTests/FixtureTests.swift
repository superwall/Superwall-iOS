import Foundation
import XCTest

@testable import SuperwallSupport

/// Decodes every person-side wire fixture from paywall-next
/// (`packages/inbox-contracts/fixtures`, synced by `scripts/sync-fixtures.sh`)
/// the way its manifest says a client must.
final class FixtureTests: XCTestCase {
  struct Manifest: Decodable {
    struct Fixture: Decodable {
      let path: String
      let module: String
      let expect: [String: JSONValue]
    }
    let `protocol`: String
    let fixtures: [Fixture]
  }

  static var fixturesURL: URL {
    Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
  }

  static func load(_ path: String) throws -> JSONValue {
    let data = try Data(contentsOf: fixturesURL.appendingPathComponent(path))
    return try XCTUnwrap(JSONValue.parse(data), "\(path) isn't JSON")
  }

  static func loadText(_ path: String) throws -> String {
    try String(contentsOf: fixturesURL.appendingPathComponent(path), encoding: .utf8)
  }

  func manifest() throws -> Manifest {
    let data = try Data(contentsOf: Self.fixturesURL.appendingPathComponent("manifest.json"))
    return try JSONDecoder().decode(Manifest.self, from: data)
  }

  func testSourceIsRecorded() throws {
    let source = try Self.load("SOURCE.json")
    let commit = try XCTUnwrap(source["commit"]?.stringValue)
    XCTAssertEqual(commit.count, 40, "SOURCE.json must name the exact paywall-next commit")
  }

  func testProtocolMatches() throws {
    XCTAssertEqual(try manifest().protocol, SupportWire.protocolName)
  }

  /// Every wire fixture is checked; founder-side modules (change stream, outbox,
  /// ingress) aren't something a person-side SDK decodes.
  func testEveryWireFixture() throws {
    let manifest = try manifest()
    var checked = 0
    var skipped: [String: Int] = [:]
    for fixture in manifest.fixtures {
      guard fixture.module == "wire" else {
        skipped[fixture.module, default: 0] += 1
        continue
      }
      try check(fixture)
      checked += 1
    }
    let wireCount = manifest.fixtures.filter { $0.module == "wire" }.count
    XCTAssertEqual(checked, wireCount)
    XCTAssertGreaterThanOrEqual(checked, 68)
    print("Checked \(checked) wire fixtures; skipped founder-side \(skipped)")
  }

  private func check(_ fixture: Manifest.Fixture) throws {
    let expect = fixture.expect
    if let lenient = expect["lenient"]?.stringValue {
      let outcome = try XCTUnwrap(expect["outcome"]?.stringValue)
      switch lenient {
      case "entry":
        let decoded = WireEntry.decode(try Self.load(fixture.path))
        XCTAssertEqual(Self.outcome(of: decoded), outcome, "\(fixture.path): \(decoded)")
      case "frame":
        let decoded = WireFrameDecoder.decode(try Self.loadText(fixture.path))
        switch decoded {
        case .frame: XCTAssertEqual("Frame", outcome, fixture.path)
        case .ignored(let reason): XCTAssertEqual("Ignored", outcome, "\(fixture.path): \(reason)")
        }
      default:
        XCTFail("Unknown lenient mode \(lenient) in \(fixture.path)")
      }
    } else if let schema = expect["decode"]?.stringValue {
      let valid = try XCTUnwrap(expect["valid"]?.boolValue)
      XCTAssertEqual(try decodes(schema, path: fixture.path), valid, "\(fixture.path) as \(schema)")
    } else if expect["resume"] != nil {
      try checkResume(fixture.path)
    } else if expect["transcript"] != nil {
      try checkTranscript(fixture.path)
    } else {
      XCTFail("No expectation for \(fixture.path)")
    }
  }

  static func outcome(of entry: WireEntry) -> String {
    switch entry {
    case .known: return "Known"
    case .unknown: return "Unknown"
    case .failed: return "Failed"
    }
  }

  /// Strict decode with the named schema, as the manifest says.
  private func decodes(_ schema: String, path: String) throws -> Bool {
    let data = try Data(contentsOf: Self.fixturesURL.appendingPathComponent(path))
    let decoder = JSONDecoder()
    do {
      switch schema {
      case "ClientFrame":
        return ClientFrame.decode(try Self.loadText(path)) != nil
      case "SessionStart": _ = try decoder.decode(SessionStart.self, from: data)
      case "SessionStarted": _ = try decoder.decode(SessionStarted.self, from: data)
      case "EntryWindow": _ = try decoder.decode(EntryWindow.self, from: data)
      case "SendMessage": try decoder.decode(SendMessage.self, from: data).validate()
      case "SendAccepted": _ = try decoder.decode(SendAccepted.self, from: data)
      case "MarkRead": _ = try decoder.decode(MarkRead.self, from: data)
      case "UploadRequest": _ = try decoder.decode(UploadRequest.self, from: data)
      case "UploadIntent": _ = try decoder.decode(UploadIntent.self, from: data)
      case "UploadCompleted": _ = try decoder.decode(UploadCompleted.self, from: data)
      case "AttachmentUrl": _ = try decoder.decode(AttachmentUrl.self, from: data)
      case "CardActionRequest": _ = try decoder.decode(CardActionRequest.self, from: data)
      case "CardActionAccepted": _ = try decoder.decode(CardActionAccepted.self, from: data)
      case "ToolCallResultRequest": _ = try decoder.decode(ToolCallResultRequest.self, from: data)
      case "WireError": _ = try decoder.decode(WireErrorBody.self, from: data)
      default:
        XCTFail("No decoder for \(schema) (\(path))")
        return false
      }
      return true
    } catch {
      return false
    }
  }

  // MARK: Resume

  /// The client half of each resume case: holding the cursor (and maybe a tail),
  /// the frames the server sends apply with no gap and no duplicate, `ready`
  /// drops a held tail, and a replayed entry seals the tail it names. The server
  /// half (`planResume`) is re-derived here too, so the fixture's meaning is
  /// pinned on this side of the wire.
  private func checkResume(_ path: String) throws {
    let fixture = try Self.load(path)
    let visible = try XCTUnwrap(fixture["visible"]?.arrayValue).map {
      (seq: $0["seq"]!.intValue!, id: $0["id"]!.stringValue!)
    }
    let after = try XCTUnwrap(fixture["cursor"]?["after"]?.intValue)
    let afterId = fixture["cursor"]?["afterId"]?.stringValue
    let lastSeq = try XCTUnwrap(fixture["lastSeq"]?.intValue)
    let maxBacklog = try XCTUnwrap(fixture["maxBacklog"]?.intValue)
    let expected = try XCTUnwrap(fixture["expected"]?.objectValue)
    let head = visible.last?.seq ?? 0

    // Server side, as resume.ts plans it.
    let boundary = visible.first { $0.seq == after }
    let following = visible.filter { $0.seq > after }
    let plan: (tag: String, reason: String?) = {
      if after > lastSeq { return ("Resync", "beyond_head") }
      if after > 0, boundary == nil || (afterId != nil && boundary?.id != afterId) {
        return ("Resync", "boundary_mismatch")
      }
      if following.count > maxBacklog { return ("Resync", "too_far_behind") }
      return ("Replay", nil)
    }()
    XCTAssertEqual(plan.tag, expected["_tag"]?.stringValue, path)
    XCTAssertEqual(head, expected["head"]?.intValue, path)
    guard plan.tag == "Replay" else {
      XCTAssertEqual(plan.reason, expected["reason"]?.stringValue, path)
      return
    }
    let seqs = try XCTUnwrap(expected["seqs"]?.arrayValue).compactMap(\.intValue)
    let prevs = try XCTUnwrap(expected["prevs"]?.arrayValue).compactMap(\.intValue)
    XCTAssertEqual(following.map(\.seq), seqs, path)

    // Client side: hold up to the cursor (and the tail), then apply ready + entries.
    var log = ConversationLog()
    var window: [JSONValue] = []
    for item in visible where item.seq <= after { window.append(Self.entry(seq: item.seq, id: item.id)) }
    log.replace(with: Self.window(window))
    XCTAssertEqual(log.cursor, after, path)
    if let held = fixture["heldTail"]?.objectValue {
      log.applyTail(
        messageId: held["messageId"]!.stringValue!, offset: 0, text: held["text"]!.stringValue!)
      XCTAssertNotNil(log.tail, path)
    }
    log.ready()
    for (index, seq) in seqs.enumerated() {
      let id = visible.first { $0.seq == seq }!.id
      XCTAssertEqual(
        log.applyEntryFrame(seq: seq, prev: prevs[index], raw: Self.entry(seq: seq, id: id)), .accept,
        "\(path) seq \(seq)")
      // A replay of the same frame is a duplicate, never a second entry.
      XCTAssertEqual(
        log.applyEntryFrame(seq: seq, prev: prevs[index], raw: Self.entry(seq: seq, id: id)),
        .duplicate, path)
    }
    XCTAssertEqual(log.cursor, seqs.last ?? after, path)
    if expected["tailAfter"]?.stringValue == "dropped" { XCTAssertNil(log.tail, path) }
  }

  // MARK: Transcripts

  /// A cold client fed a transcript's frames ends with exactly the window's entries.
  /// Then the same frames again after a drop at every seq: still exact.
  private func checkTranscript(_ path: String) throws {
    let fixture = try Self.load(path)
    let frames = try XCTUnwrap(fixture["frames"]?.arrayValue)
    let window = try JSONDecoder().decode(
      EntryWindow.self, from: try Data(contentsOf: Self.fixturesURL.appendingPathComponent(path))
        .windowField())

    var log = ConversationLog()
    for frame in frames { apply(frame, to: &log, path: path) }
    XCTAssertEqual(log.entries, window.decodedEntries, path)
    XCTAssertEqual(log.cursor, window.head, path)
    XCTAssertNil(log.tail, path)

    // Drop after every seq: reconnect with the cursor and get the rest, as the
    // server replays from `after`.
    let entryFrames = frames.filter { $0["type"]?.stringValue == "entry" }
    for dropAt in 0...entryFrames.count {
      var resumed = ConversationLog()
      for frame in entryFrames.prefix(dropAt) { apply(frame, to: &resumed, path: path) }
      let cursor = resumed.cursor
      resumed.ready()
      for frame in entryFrames where frame["seq"]!.intValue! > cursor {
        apply(frame, to: &resumed, path: path)
      }
      XCTAssertEqual(resumed.entries, window.decodedEntries, "\(path) dropped at \(dropAt)")
    }
  }

  private func apply(_ frame: JSONValue, to log: inout ConversationLog, path: String) {
    guard case .frame(let decoded) = WireFrameDecoder.decode(frame) else {
      return XCTFail("\(path): frame didn't decode: \(frame.serialized())")
    }
    switch decoded {
    case .ready: log.ready()
    case .entry(let seq, let prev, let raw):
      XCTAssertEqual(log.applyEntryFrame(seq: seq, prev: prev, raw: raw), .accept, "\(path) seq \(seq)")
    case .tail(let id, let offset, let text): log.applyTail(messageId: id, offset: offset, text: text)
    case .tailCancel(let id, _): log.cancelTail(messageId: id)
    case .status(let state, let eta): log.setStatus(state, etaSeconds: eta)
    default: break
    }
  }

  // MARK: Helpers

  static func entry(seq: Int, id: String, kind: String = "agent_message") -> JSONValue {
    .object([
      "seq": .number(Double(seq)),
      "id": .string(id),
      "conversationId": .string("conv_00000000000000000000000001"),
      "kind": .string(kind),
      "visibility": .string("public"),
      "author": .object(["type": .string("agent")]),
      "createdAt": .string("2026-11-05T10:00:00.000Z"),
      "text": .string("Entry \(seq)")
    ])
  }

  static func window(_ entries: [JSONValue], hasMore: Bool = false) -> EntryWindow {
    let json = JSONValue.object([
      "conversationId": .string("conv_00000000000000000000000001"),
      "entries": .array(entries),
      "head": .number(Double(entries.last?["seq"]?.intValue ?? 0)),
      "hasMore": .bool(hasMore)
    ])
    // swiftlint:disable:next force_try
    return try! JSONDecoder().decode(EntryWindow.self, from: Data(json.serialized().utf8))
  }
}

extension Data {
  /// The `window` field of a transcript fixture, as its own JSON document.
  fileprivate func windowField() throws -> Data {
    guard let window = JSONValue.parse(self)?["window"] else {
      throw WireDecodeIssue(path: "window", message: "Missing")
    }
    return Data(window.serialized().utf8)
  }
}
