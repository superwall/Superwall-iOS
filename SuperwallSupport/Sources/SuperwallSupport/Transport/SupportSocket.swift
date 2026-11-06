import Foundation

/// One WebSocket, as the transport needs it. The real one is
/// `URLSessionWebSocketTask`; tests use a scripted fake.
protocol SupportSocket: AnyObject, Sendable {
  func send(_ text: String) async throws
  /// The next frame as text (a binary frame is read as UTF-8). Throws when the socket closes.
  func receive() async throws -> String
  func close(code: Int, reason: String)
  /// The close code the server sent, once closed.
  var closeCode: Int? { get }
}

protocol SupportSocketFactory: Sendable {
  func make(url: URL) -> SupportSocket
}

final class URLSessionSupportSocket: NSObject, SupportSocket, URLSessionWebSocketDelegate,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var task: URLSessionWebSocketTask!
  private var session: URLSession!
  private var receivedCloseCode: Int?

  init(url: URL, configuration: URLSessionConfiguration) {
    super.init()
    // A session per socket so its delegate sees this socket's close code.
    session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    task = session.webSocketTask(with: url)
    // The default 1 MB cap would turn one oversized frame into a reconnect loop.
    task.maximumMessageSize = 16 * 1024 * 1024
    // URLSessionWebSocketTask offers permessage-deflate on its own (M0 spike).
    task.resume()
  }

  func send(_ text: String) async throws {
    try await task.send(.string(text))
  }

  func receive() async throws -> String {
    while true {
      switch try await task.receive() {
      case .string(let text): return text
      case .data(let data):
        if let text = String(data: data, encoding: .utf8) { return text }
      @unknown default:
        continue
      }
    }
  }

  func close(code: Int, reason: String) {
    let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .normalClosure
    task.cancel(with: closeCode, reason: reason.data(using: .utf8))
    session.finishTasksAndInvalidate()
  }

  var closeCode: Int? {
    lock.lock()
    defer { lock.unlock() }
    if let receivedCloseCode { return receivedCloseCode }
    let raw = task.closeCode.rawValue
    return raw == URLSessionWebSocketTask.CloseCode.invalid.rawValue ? nil : raw
  }

  func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
  ) {
    lock.lock()
    receivedCloseCode = closeCode.rawValue
    lock.unlock()
  }
}

struct URLSessionSupportSocketFactory: SupportSocketFactory {
  let configuration: URLSessionConfiguration
  func make(url: URL) -> SupportSocket {
    URLSessionSupportSocket(url: url, configuration: configuration)
  }
}
