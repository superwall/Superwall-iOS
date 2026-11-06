import Foundation

/// What a client holds of one conversation: entries by seq, the cursor it
/// resumes from, the streaming tail and the status outside the log.
///
/// The cursor only moves through contiguous delivery (socket frames checked with
/// `prev`, or HTTP windows read in order). Entries that arrive any other way,
/// like the entry a send returns, are held but don't move it, so the socket
/// still delivers them in order and they are de-duplicated by seq.
public struct ConversationLog: Equatable, Sendable {
  public private(set) var conversationId: String?
  /// The last seq held through contiguous delivery; 0 for none.
  public private(set) var cursor: Int = 0
  /// The id of the entry at `cursor`, when it decoded far enough to have one.
  public private(set) var cursorId: String?
  public private(set) var entriesBySeq: [Int: WireEntry] = [:]
  private var heldIds = Set<String>()
  public private(set) var tail: TailState?
  public private(set) var status: String?
  public private(set) var statusEtaSeconds: Int?
  public private(set) var presence: [PresenceParticipant] = []
  /// The oldest seq held, for scrolling back with `before=`.
  public var oldestSeq: Int? { entriesBySeq.keys.min() }
  /// More entries exist before the oldest one held.
  public private(set) var hasOlder = false

  public init() {}

  /// Entries in seq order.
  public var entries: [WireEntry] {
    entriesBySeq.keys.sorted().compactMap { entriesBySeq[$0] }
  }

  mutating func reset(conversationId: String) {
    self = ConversationLog()
    self.conversationId = conversationId
  }

  /// Replaces everything with the newest window (open, or after `resync`).
  mutating func replace(with window: EntryWindow) {
    let conversationId = conversationId
    self = ConversationLog()
    self.conversationId = conversationId ?? window.conversationId
    for entry in window.decodedEntries { insertReadInOrder(entry) }
    hasOlder = window.hasMore
  }

  /// A window read with `after=cursor`: contiguous, so it moves the cursor.
  mutating func applyCatchUp(_ window: EntryWindow) {
    for entry in window.decodedEntries { insertReadInOrder(entry) }
  }

  /// A window read with `before=oldest`: older entries; the cursor stays.
  mutating func applyOlder(_ window: EntryWindow) {
    for entry in window.decodedEntries {
      guard let seq = entry.seq else { continue }
      hold(seq, entry)
    }
    hasOlder = window.hasMore
  }

  private mutating func insertReadInOrder(_ entry: WireEntry) {
    // An entry with no seq can't be placed: it is dropped (a later entry moves the
    // cursor past it). Over the socket the frame carries the seq, so it is kept there.
    guard let seq = entry.seq, seq > cursor else { return }
    hold(seq, entry)
    cursor = seq
    cursorId = entry.id
  }

  /// An `entry` frame. Returns what the resume rules decided.
  mutating func applyEntryFrame(seq: Int, prev: Int, raw: JSONValue) -> EntryFrameOutcome {
    let outcome = WireResume.applyEntryFrame(cursor: cursor, seq: seq, prev: prev)
    guard outcome == .accept else { return outcome }
    let entry = WireEntry.decode(raw)
    // The frame's seq is authoritative: the cursor moves even when the entry doesn't decode.
    hold(seq, entry)
    cursor = seq
    cursorId = entry.id
    return outcome
  }

  /// An entry that arrived outside the stream (a send's response). Held, cursor unchanged.
  mutating func holdOutOfBand(_ entry: WireEntry) {
    guard let seq = entry.seq, entriesBySeq[seq] == nil else { return }
    hold(seq, entry)
  }

  private mutating func hold(_ seq: Int, _ entry: WireEntry) {
    entriesBySeq[seq] = entry
    if let id = entry.id {
      heldIds.insert(id)
      if tail?.messageId == id { tail = nil }
    }
  }

  /// `ready`: tails are never persisted, so drop any held one; a live tail is re-sent.
  mutating func ready() {
    tail = nil
  }

  mutating func applyTail(messageId: String, offset: Int, text: String) {
    // A tail for an entry already held is stale (its seal came first).
    if heldIds.contains(messageId) { return }
    tail = WireResume.applyTail(tail, messageId: messageId, offset: offset, text: text)
  }

  mutating func cancelTail(messageId: String) {
    if tail?.messageId == messageId { tail = nil }
  }

  mutating func setStatus(_ state: String, etaSeconds: Int?) {
    status = state
    statusEtaSeconds = etaSeconds
  }

  mutating func setPresence(_ participants: [PresenceParticipant]) {
    presence = participants
  }
}
