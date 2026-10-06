//
//  DeviceIPCollector.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 15/09/2026.
//

import Foundation
import Darwin
#if canImport(Network)
import Network
#endif

/// Best-effort, session-local observations. Never waits on the network when reading attributes.
actor DeviceIPCollector {
  typealias Fetch = () async throws -> [String: String]

  /// One address lookup with its own schedule, so a failing IPv6 lookup
  /// doesn't hold up or speed up the IPv4 one.
  private struct Lookup {
    let name: String
    let fetch: Fetch
    var lastAttempt: Date?
    var nextAttemptAt: Date?

    init(name: String, fetch: @escaping Fetch) {
      self.name = name
      self.fetch = fetch
    }
  }

  private var lookups: [Lookup]
  private let now: () -> Date
  private var observations: [String: String] = [:]
  private let lifetime: TimeInterval = 15 * 60
  /// How long to wait after a failed fetch. Shorter than `lifetime` so a
  /// blip is retried soon, but long enough that an outage or offline device
  /// doesn't send a request on every read of the device attributes.
  private let retryDelay: TimeInterval = 60

  /// - Parameters:
  ///   - ipV4Url: An IPv4-only endpoint to ask. When `nil`, IPv4 isn't looked up.
  ///   - ipV6Url: An endpoint to ask over IPv6 only. When `nil`, on watchOS, or
  ///     on systems that can't require IPv6, IPv6 isn't looked up.
  init(
    ipV4Url: URL?,
    ipV6Url: URL?,
    now: @escaping () -> Date = Date.init
  ) {
    var lookups: [Lookup] = []
    if let ipV4Url = ipV4Url {
      lookups.append(Lookup(name: "IPv4") { try await Self.fetchIPv4(from: ipV4Url) })
    }
    // watchOS doesn't let apps open their own connections like this.
    #if canImport(Network) && !os(watchOS)
    if let ipV6Url = ipV6Url,
      #available(iOS 12.0, macOS 10.14, tvOS 12.0, watchOS 6.0, *) {
      lookups.append(Lookup(name: "IPv6") { try await Self.fetchOverIPv6(from: ipV6Url) })
    }
    #endif
    self.lookups = lookups
    self.now = now
  }

  /// One lookup per closure, each with its own schedule. For tests.
  init(
    fetches: [Fetch],
    now: @escaping () -> Date = Date.init
  ) {
    self.lookups = fetches.enumerated().map { Lookup(name: "test \($0.offset)", fetch: $0.element) }
    self.now = now
  }

  /// Starts any lookups that are due, in the background. The returned task
  /// finishes when they do and is only there so tests can wait for it.
  @discardableResult
  func refreshIfNeeded() -> Task<Void, Never>? {
    let date = now()
    var started: [Task<Void, Never>] = []
    for index in lookups.indices {
      if let nextAttemptAt = lookups[index].nextAttemptAt,
        date < nextAttemptAt {
        continue
      }
      lookups[index].lastAttempt = date
      lookups[index].nextAttemptAt = date.addingTimeInterval(lifetime)
      started.append(start(lookupAt: index, attemptedAt: date))
    }
    if started.isEmpty {
      return nil
    }
    return Task {
      for task in started {
        await task.value
      }
    }
  }

  private func start(lookupAt index: Int, attemptedAt date: Date) -> Task<Void, Never> {
    let lookup = lookups[index]
    return Task {
      do {
        record(try await lookup.fetch())
      } catch {
        // Try again sooner than a success would, unless a newer attempt started.
        if lookups[index].lastAttempt == date {
          lookups[index].nextAttemptAt = date.addingTimeInterval(retryDelay)
        }
        Logger.debug(
          logLevel: .debug,
          scope: .network,
          message: "Couldn't fetch the device's \(lookup.name) address",
          error: error
        )
      }
    }
  }

  func record(_ device: [String: String]) {
    for family in [4, 6] {
      let key = "ipV\(family)"
      // Each address only counts with its own timestamp, so an `ipV6` with no
      // time can't borrow the time of an IPv4 `ipAddress`.
      let address: String?
      let timestamp: String?
      if let familyAddress = device[key] {
        address = familyAddress
        timestamp = device["\(key)ObservedAt"]
      } else {
        address = device["ipAddress"]
        timestamp = device["ipAddressObservedAt"]
      }
      guard
        let address = address,
        let timestamp = timestamp,
        let date = Self.date(from: timestamp),
        Self.isValid(address, family: family),
        isFresh(date)
      else {
        continue
      }
      if let previous = observations["\(key)ObservedAt"],
        let previousDate = Self.date(from: previous),
        previousDate > date {
        continue
      }
      observations[key] = address
      observations["\(key)ObservedAt"] = timestamp
    }
  }

  func attributes() -> [String: String] {
    var result: [String: String] = [:]
    for key in ["ipV4", "ipV6"] {
      if let timestamp = observations["\(key)ObservedAt"],
        let date = Self.date(from: timestamp),
        isFresh(date) {
        result[key] = observations[key]
        result["\(key)ObservedAt"] = timestamp
      }
    }
    return result
  }

  private func isFresh(_ date: Date) -> Bool {
    let age = now().timeIntervalSince(date)
    return age >= -60 && age < lifetime
  }

  static func isValid(_ address: String, family: Int) -> Bool {
    if family == 4 {
      var bytes = in_addr()
      return inet_pton(AF_INET, address, &bytes) == 1
    }
    var bytes = in6_addr()
    return inet_pton(AF_INET6, address, &bytes) == 1 && !address.lowercased().hasPrefix("::ffff:")
  }

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let wholeSecondFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// Parses ISO 8601 timestamps with or without milliseconds.
  static func date(from timestamp: String) -> Date? {
    return fractionalFormatter.date(from: timestamp)
      ?? wholeSecondFormatter.date(from: timestamp)
  }

  static func fetchIPv4(from url: URL) async throws -> [String: String] {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 3
    config.timeoutIntervalForResource = 3
    let session = URLSession(configuration: config)
    defer { session.finishTasksAndInvalidate() }
    let data: Data = try await withCheckedThrowingContinuation { continuation in
      let task = session.dataTask(with: url) { data, response, error in
        if let error = error {
          continuation.resume(throwing: error)
          return
        }
        guard
          let response = response as? HTTPURLResponse,
          response.statusCode == 200,
          let data = data,
          data.count < 16_384
        else {
          continuation.resume(throwing: URLError(.badServerResponse))
          return
        }
        continuation.resume(returning: data)
      }
      task.resume()
    }
    return try parseDevice(from: data)
  }

  /// Reads the string values of the response's `device` object, skipping any
  /// that aren't strings.
  static func parseDevice(from data: Data) throws -> [String: String] {
    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let device = json["device"] as? [String: Any]
    else {
      throw URLError(.cannotParseResponse)
    }
    return device.compactMapValues { $0 as? String }
  }
}

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
          } else if isComplete {
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
