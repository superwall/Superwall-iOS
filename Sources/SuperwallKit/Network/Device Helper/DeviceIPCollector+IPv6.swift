//
//  DeviceIPCollector+IPv6.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/10/2026.
//

import Foundation
#if canImport(Network)
import Network
#endif

// MARK: - IPv6 lookup
#if canImport(Network)
@available(iOS 12.0, macOS 10.14, tvOS 12.0, watchOS 6.0, *)
extension DeviceIPCollector {
  private static let maxResponseSize = 16_384

  /// `URLSession` can't be told which IP version to use, so this makes the
  /// request over a connection that may only use IPv6. On a network without
  /// IPv6 it fails rather than falling back to IPv4.
  static func fetchOverIPv6(
    from url: URL,
    timeout: TimeInterval = 3
  ) async throws -> [String: String] {
    guard
      url.scheme == "https",
      let host = url.host
    else {
      throw URLError(.badURL)
    }
    let parameters = NWParameters(tls: NWProtocolTLS.Options(), tcp: NWProtocolTCP.Options())
    if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
      ipOptions.version = .v6
    }
    let connection = NWConnection(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(integerLiteral: UInt16(url.port ?? 443)),
      using: parameters
    )
    // HTTP/1.0 so the server closes the connection when it's done and never
    // splits the body into chunks.
    let request = "GET \(url.path.isEmpty ? "/" : url.path) HTTP/1.0\r\n"
      + "Host: \(host)\r\n"
      // Cloudflare's Browser Integrity Check challenges requests without one.
      + "User-Agent: SuperwallKit/\(sdkVersion)\r\n"
      + "Accept: application/json\r\n"
      + "\r\n"
    let response = try await exchange(
      Data(request.utf8),
      over: connection,
      timeout: timeout
    )
    return try parseDevice(from: body(ofHTTPResponse: response))
  }

  /// Returns the body of an HTTP response, or throws unless its status is 200.
  static func body(ofHTTPResponse response: Data) throws -> Data {
    let separator = Data("\r\n\r\n".utf8)
    guard
      let headerEnd = response.range(of: separator),
      let statusLine = String(data: response[..<headerEnd.lowerBound], encoding: .utf8)?
        .components(separatedBy: "\r\n")
        .first
    else {
      throw URLError(.cannotParseResponse)
    }
    let parts = statusLine.split(separator: " ")
    guard
      parts.count >= 2,
      parts[0].hasPrefix("HTTP/"),
      parts[1] == "200"
    else {
      throw URLError(.badServerResponse)
    }
    return Data(response[headerEnd.upperBound...])
  }

  /// Whether `response` holds the headers and the full body its
  /// `Content-Length` promises. Without that header, only the server closing
  /// the connection marks the end.
  static func isCompleteHTTPResponse(_ response: Data) -> Bool {
    let separator = Data("\r\n\r\n".utf8)
    guard
      let headerEnd = response.range(of: separator),
      let headers = String(data: response[..<headerEnd.lowerBound], encoding: .utf8)
    else {
      return false
    }
    let contentLength = headers
      .components(separatedBy: "\r\n")
      .dropFirst()
      .compactMap { line -> Int? in
        let parts = line.split(separator: ":", maxSplits: 1)
        guard
          parts.count == 2,
          parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length"
        else {
          return nil
        }
        return Int(parts[1].trimmingCharacters(in: .whitespaces))
      }
      .first
    guard let contentLength = contentLength else {
      return false
    }
    return response.count - headerEnd.upperBound >= contentLength
  }

  private static func exchange(
    _ request: Data,
    over connection: NWConnection,
    timeout: TimeInterval
  ) async throws -> Data {
    let queue = DispatchQueue(label: "com.superwall.ipv6-lookup")
    return try await withCheckedThrowingContinuation { continuation in
      let state = ExchangeState(continuation: continuation)
      let finish: (Result<Data, Error>) -> Void = { result in
        if state.resume(with: result) {
          connection.cancel()
        }
      }

      func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxResponseSize) { data, _, isComplete, error in
          if let data = data {
            state.received.append(data)
          }
          if state.received.count > maxResponseSize {
            finish(.failure(URLError(.dataLengthExceedsMaximum)))
          } else if let error = error {
            finish(.failure(error))
          } else if isComplete || isCompleteHTTPResponse(state.received) {
            // Don't wait for the server to close if the whole body is here.
            finish(.success(state.received))
          } else {
            receive()
          }
        }
      }

      connection.stateUpdateHandler = { connectionState in
        switch connectionState {
        case .ready:
          connection.send(content: request, completion: .contentProcessed { error in
            if let error = error {
              finish(.failure(error))
            } else {
              receive()
            }
          })
        case .waiting(let error),
          .failed(let error):
          // Waiting means there's no IPv6 route right now.
          finish(.failure(error))
        case .cancelled:
          finish(.failure(CancellationError()))
        default:
          break
        }
      }
      connection.start(queue: queue)
      queue.asyncAfter(deadline: .now() + timeout) {
        finish(.failure(URLError(.timedOut)))
      }
    }
  }
}

/// Resumes the continuation once, whichever of the response, an error or the
/// timeout comes first. Only touched on the lookup's serial queue, apart from
/// the lock-guarded resume.
private final class ExchangeState: @unchecked Sendable {
  var received = Data()
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Data, Error>?

  init(continuation: CheckedContinuation<Data, Error>) {
    self.continuation = continuation
  }

  func resume(with result: Result<Data, Error>) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard let continuation = continuation else {
      return false
    }
    self.continuation = nil
    continuation.resume(with: result)
    return true
  }
}
#endif
