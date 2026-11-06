import Foundation

// Client half of the resume rules in `@superwall/inbox-contracts/wire/resume.ts`:
// keep a cursor and a tail exact across reconnects, with no gap and no duplicate.

public enum EntryFrameOutcome: Equatable, Sendable {
  /// New, and directly after the cursor: draw it and move the cursor.
  case accept
  /// Already held: drop it.
  case duplicate
  /// Something is missing between the cursor and this entry: reconnect with the cursor.
  case gap(expected: Int, prev: Int)
}

/// A reply being streamed, keyed by the id its sealed entry will have.
public struct TailState: Equatable, Sendable {
  public let messageId: String
  public let text: String
}

public enum WireResume {
  /// What to do with an `entry` frame, given the last seq held.
  public static func applyEntryFrame(cursor: Int, seq: Int, prev: Int) -> EntryFrameOutcome {
    if seq <= cursor { return .duplicate }
    if prev != cursor { return .gap(expected: cursor, prev: prev) }
    return .accept
  }

  /// Applies a `tail` frame: truncate to `offset` (UTF-16 code units) and append,
  /// so a replay is harmless. An offset past the held text can only follow a lost
  /// frame: keep what's held and wait for the next socket, which restarts at 0.
  public static func applyTail(
    _ current: TailState?, messageId: String, offset: Int, text: String
  ) -> TailState? {
    let held = current?.messageId == messageId ? current : nil
    let base = Array((held?.text ?? "").utf16)
    if offset > base.count { return held }
    let kept = String(decoding: base[0..<offset], as: UTF16.self)
    return TailState(messageId: messageId, text: kept + text)
  }
}
