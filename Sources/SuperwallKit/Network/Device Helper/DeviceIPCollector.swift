import Foundation
import Darwin

/// Best-effort, session-local observations. Never waits on the network when reading attributes.
actor DeviceIPCollector {
  typealias Fetch = () async throws -> [String: String]
  private let fetch: Fetch
  private let now: () -> Date
  private var lastAttempt: Date?
  private var observations: [String: String] = [:]
  private let lifetime: TimeInterval = 15 * 60

  init(fetch: @escaping Fetch = DeviceIPCollector.fetchIPv4, now: @escaping () -> Date = Date.init) {
    self.fetch = fetch
    self.now = now
  }

  func refreshIfNeeded() {
    let date = now()
    if let lastAttempt = lastAttempt, date.timeIntervalSince(lastAttempt) < lifetime { return }
    lastAttempt = date
    Task {
      guard let device = try? await fetch() else { return }
      record(device)
    }
  }

  func record(_ device: [String: String]) {
    for family in [4, 6] {
      let key = "ipV\(family)"
      let address = device[key] ?? device["ipAddress"]
      let timestamp = device["\(key)ObservedAt"] ?? device["ipAddressObservedAt"]
      guard let address = address, let timestamp = timestamp,
        Self.isValid(address, family: family), isFresh(timestamp) else { continue }
      if let previous = observations["\(key)ObservedAt"],
        let oldDate = ISO8601DateFormatter.ipObservation.date(from: previous),
        let newDate = ISO8601DateFormatter.ipObservation.date(from: timestamp), oldDate > newDate { continue }
      observations[key] = address
      observations["\(key)ObservedAt"] = timestamp
    }
  }

  func attributes() -> [String: String] {
    var result: [String: String] = [:]
    for key in ["ipV4", "ipV6"] {
      if let timestamp = observations["\(key)ObservedAt"], isFresh(timestamp) {
        result[key] = observations[key]
        result["\(key)ObservedAt"] = timestamp
      }
    }
    return result
  }

  private func isFresh(_ timestamp: String) -> Bool {
    guard let date = ISO8601DateFormatter.ipObservation.date(from: timestamp) else { return false }
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

  static func fetchIPv4() async throws -> [String: String] {
    guard let url = URL(string: "https://v4.superwall-enrichment.com/api/v1/enrich") else { return [:] }
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 3
    config.timeoutIntervalForResource = 3
    let session = URLSession(configuration: config)
    defer { session.finishTasksAndInvalidate() }
    let data: Data = try await withCheckedThrowingContinuation { continuation in
      let task = session.dataTask(with: url) { data, response, error in
        if let error = error { continuation.resume(throwing: error); return }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
          let data = data, data.count < 16_384 else {
          continuation.resume(throwing: URLError(.badServerResponse)); return
        }
        continuation.resume(returning: data)
      }
      task.resume()
    }
    struct Response: Decodable { let device: [String: String] }
    return try JSONDecoder().decode(Response.self, from: data).device
  }
}

private extension ISO8601DateFormatter {
  static var ipObservation: ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }
}
