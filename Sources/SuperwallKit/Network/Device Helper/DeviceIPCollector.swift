//
//  DeviceIPCollector.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 15/09/2026.
//

import Foundation
import Darwin

/// Best-effort, session-local observations. Never waits on the network when reading attributes.
actor DeviceIPCollector {
  typealias Fetch = () async throws -> [String: String]
  private let fetch: Fetch?
  private let now: () -> Date
  private var lastAttempt: Date?
  private var nextAttemptAt: Date?
  private var observations: [String: String] = [:]
  private let lifetime: TimeInterval = 15 * 60
  /// How long to wait after a failed fetch. Shorter than `lifetime` so a
  /// blip is retried soon, but long enough that an outage or offline device
  /// doesn't send a request on every read of the device attributes.
  private let retryDelay: TimeInterval = 60

  /// - Parameters:
  ///   - url: The IPv4-only endpoint to ask. When `nil`, nothing is fetched.
  ///   - fetch: Overrides the request, for tests.
  init(
    url: URL?,
    fetch: Fetch? = nil,
    now: @escaping () -> Date = Date.init
  ) {
    if let fetch = fetch {
      self.fetch = fetch
    } else if let url = url {
      self.fetch = { try await Self.fetchIPv4(from: url) }
    } else {
      self.fetch = nil
    }
    self.now = now
  }

  /// Starts a fetch in the background unless one was tried recently. The
  /// returned task is only there so tests can wait for it.
  @discardableResult
  func refreshIfNeeded() -> Task<Void, Never>? {
    guard let fetch = fetch else {
      return nil
    }
    let date = now()
    if let nextAttemptAt = nextAttemptAt,
      date < nextAttemptAt {
      return nil
    }
    lastAttempt = date
    nextAttemptAt = date.addingTimeInterval(lifetime)
    return Task {
      do {
        record(try await fetch())
      } catch {
        // Try again sooner than a success would, unless a newer attempt started.
        if lastAttempt == date {
          nextAttemptAt = date.addingTimeInterval(retryDelay)
        }
        Logger.debug(
          logLevel: .debug,
          scope: .network,
          message: "Couldn't fetch the device's IPv4 address",
          error: error
        )
      }
    }
  }

  func record(_ device: [String: String]) {
    for family in [4, 6] {
      let key = "ipV\(family)"
      let address = device[key] ?? device["ipAddress"]
      let timestamp = device["\(key)ObservedAt"] ?? device["ipAddressObservedAt"]
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
