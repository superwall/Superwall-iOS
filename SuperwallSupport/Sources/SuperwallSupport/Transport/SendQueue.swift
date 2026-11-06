import Foundation

/// A message the person sent that hasn't been confirmed yet. Persisted, so a
/// send survives the app being killed: the same `clientMessageId` is retried
/// until the server confirms it, and the server lands it once.
public struct PendingMessage: Codable, Equatable, Sendable {
  public enum State: String, Codable, Sendable {
    /// Waiting to send, or between retries.
    case pending
    /// The server refused it for good (`retryable: false`). Shown with `failure`.
    case failed
  }

  public let clientMessageId: String
  public let conversationId: String
  public let text: String
  public let attachmentIds: [String]
  public let createdAt: Date
  public var attempts: Int
  public var state: State
  /// The wire error tag for a failed send. Never message text.
  public var failure: String?
}

/// Pending sends, in the order they were made, saved to one JSON file.
/// Writes are atomic, so a crash mid-write leaves the previous file.
final class SendQueueStore: @unchecked Sendable {
  private let fileURL: URL?
  private let lock = NSLock()
  private var items: [PendingMessage]

  /// `fileURL` nil keeps the queue in memory only (tests).
  init(fileURL: URL?) {
    self.fileURL = fileURL
    if let fileURL,
      let data = try? Data(contentsOf: fileURL),
      let items = try? Self.decoder.decode([PendingMessage].self, from: data)
    {
      self.items = items
    } else {
      self.items = []
    }
  }

  static func defaultFileURL(namespace: String) -> URL? {
    guard
      let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first
    else { return nil }
    let directory = base.appendingPathComponent("SuperwallSupport", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // The namespace is the API key's hash, so two apps' queues never mix.
    return directory.appendingPathComponent("send-queue-\(namespace).json")
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  var all: [PendingMessage] {
    lock.lock()
    defer { lock.unlock() }
    return items
  }

  func append(_ item: PendingMessage) {
    mutate { $0.append(item) }
  }

  /// Removes a confirmed send. Returns whether it was queued.
  @discardableResult
  func remove(clientMessageId: String) -> Bool {
    var removed = false
    mutate { items in
      let before = items.count
      items.removeAll { $0.clientMessageId == clientMessageId }
      removed = items.count != before
    }
    return removed
  }

  func update(clientMessageId: String, _ change: (inout PendingMessage) -> Void) {
    mutate { items in
      guard let index = items.firstIndex(where: { $0.clientMessageId == clientMessageId }) else {
        return
      }
      change(&items[index])
    }
  }

  /// The next send to try for a conversation: the oldest pending one.
  func next(conversationId: String) -> PendingMessage? {
    all.first { $0.conversationId == conversationId && $0.state == .pending }
  }

  private func mutate(_ change: (inout [PendingMessage]) -> Void) {
    lock.lock()
    change(&items)
    let snapshot = items
    lock.unlock()
    guard let fileURL, let data = try? Self.encoder.encode(snapshot) else { return }
    try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
}
