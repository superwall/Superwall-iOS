// Drives SupportTransport against the fixture server (or a Core preview) and
// logs every transport event, so resume, background/foreground and network
// behaviour can be checked from outside the app.
//
// Launch arguments (UserDefaults):
//   -baseURL http://localhost:8791     inbox API origin
//   -apiKey pk_fixture_billing-question
//   -install <id>                       install proof; default per launch
//   -dropEverySeq 1                     cut the socket after each new seq
//   -sendBurst 20                       send N messages through the queue on start
//   -verifyEvery 3                      compare with the server's window every N s
// Log lines: NSLog "SWSUPPORT …" and Documents/support-transport.log.
import SuperwallSupport
import SwiftUI

@main
struct TransportTestApp: App {
  @StateObject private var model = TransportModel()
  var body: some Scene {
    WindowGroup { ContentView(model: model) }
  }
}

struct ContentView: View {
  @ObservedObject var model: TransportModel
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(model.state).font(.headline).accessibilityIdentifier("state")
      Text("cursor \(model.cursor) · entries \(model.entries) · pending \(model.pending)")
        .font(.caption).accessibilityIdentifier("counters")
      Text("connects \(model.connects) · drops \(model.drops) · gaps \(model.gaps) · dups \(model.dups) · ping timeouts \(model.pingTimeouts)")
        .font(.caption).accessibilityIdentifier("stats")
      Text("exact: \(model.exact)").font(.caption).accessibilityIdentifier("exact")
      HStack {
        Button("Send") { model.sendOne() }
        Button("Drop") { model.drop() }
        Button("Verify") { model.verify() }
      }
      ScrollView {
        Text(model.lines).font(.system(size: 9, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
  }
}

final class DropOnce: @unchecked Sendable {
  private let lock = NSLock()
  private var seen = Set<Int>()
  func first(_ seq: Int) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return seen.insert(seq).inserted
  }
}

@MainActor
final class TransportModel: ObservableObject {
  @Published var state = "starting"
  @Published var cursor = 0
  @Published var entries = 0
  @Published var pending = 0
  @Published var connects = 0
  @Published var drops = 0
  @Published var gaps = 0
  @Published var dups = 0
  @Published var pingTimeouts = 0
  @Published var exact = "not checked"
  @Published var lines = ""

  private let transport: SupportTransport
  private let monitor: SupportLifecycleMonitor
  private let baseURL: URL
  private let logURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("support-transport.log")
  private let t0 = Date()
  private var sent = 0

  init() {
    let defaults = UserDefaults.standard
    baseURL = URL(string: defaults.string(forKey: "baseURL") ?? "http://localhost:8791")!
    let apiKey = defaults.string(forKey: "apiKey") ?? "pk_fixture_billing-question"
    let install = defaults.string(forKey: "install") ?? UUID().uuidString
    var configuration = SupportTransport.Configuration(
      baseURL: baseURL, apiKey: apiKey,
      sdk: SupportSdk(platform: "ios", version: "test", addonVersion: "transport-m1"),
      locale: Locale.current.identifier, proofs: [SupportProof(kind: "install_secret", value: install)])
    if defaults.bool(forKey: "dropEverySeq") {
      let once = DropOnce()
      configuration.dropAfterAcceptingForTesting = { seq in once.first(seq) }
    }
    transport = SupportTransport(configuration: configuration)
    monitor = SupportLifecycleMonitor(transport: transport)
    try? "".write(to: logURL, atomically: true, encoding: .utf8)
    log("launch apiKey=\(apiKey) dropEverySeq=\(defaults.bool(forKey: "dropEverySeq"))")
    let burst = defaults.integer(forKey: "sendBurst")
    Task { await self.begin(burst: burst) }
  }

  private func begin(burst: Int) async {
    await transport.setEventHandler { [weak self] event in
      Task { @MainActor in await self?.refresh(event) }
    }
    monitor.start()
    do {
      try await transport.start()
      let session = await transport.session
      // Test app only: the host script posts into this conversation with it.
      log("started conversation \(session?.conversationId ?? "?") token \(session?.sessionToken ?? "?")")
    } catch {
      log("start failed: \(error)")
    }
    for _ in 0..<burst { sendOne() }
    let every = UserDefaults.standard.double(forKey: "verifyEvery")
    if every > 0 {
      while true {
        try? await Task.sleep(nanoseconds: UInt64(every * 1_000_000_000))
        verify()
      }
    }
  }

  func sendOne() {
    sent += 1
    let index = sent
    Task {
      do {
        let pending = try await transport.send(text: "Test message \(index)")
        log("queued \(pending.clientMessageId)")
      } catch {
        log("send refused: \(error)")
      }
    }
  }

  func drop() {
    Task { await transport.dropConnectionForTesting() }
  }

  /// Compares what the client holds with the server's newest window.
  func verify() {
    Task {
      guard let session = await transport.session else { return }
      var components = URLComponents(
        url: baseURL.appendingPathComponent("v1/conversations/\(session.conversationId)/entries"),
        resolvingAgainstBaseURL: false)!
      components.queryItems = [URLQueryItem(name: "limit", value: "200")]
      var request = URLRequest(url: components.url!)
      request.setValue("Bearer \(session.sessionToken)", forHTTPHeaderField: "Authorization")
      guard let (data, _) = try? await URLSession.shared.data(for: request),
        let window = try? JSONDecoder().decode(EntryWindow.self, from: data)
      else {
        exact = "verify failed"
        return
      }
      let held = await transport.log.entries
      let server = window.decodedEntries
      let same = held == server
      exact = same ? "yes (\(held.count) entries)" : "NO: held \(held.count), server \(server.count)"
      log("verify exact=\(same) held=\(held.compactMap(\.seq)) server=\(server.compactMap(\.seq))")
    }
  }

  private func refresh(_ event: SupportTransportEvent) async {
    let log = await transport.log
    let stats = await transport.stats
    cursor = log.cursor
    entries = log.entries.count
    pending = await transport.pendingMessages.count
    connects = stats.connects
    drops = stats.drops
    gaps = stats.gaps
    dups = stats.duplicates
    pingTimeouts = stats.pingTimeouts
    switch event {
    case .connectionChanged(let state):
      self.state = "\(state)"
      self.log("state \(state) cursor=\(log.cursor) connects=\(stats.connects) drops=\(stats.drops) gaps=\(stats.gaps) dups=\(stats.duplicates) httpCatchUps=\(stats.httpCatchUps) pingTimeouts=\(stats.pingTimeouts)")
    case .error(let code, let retryable):
      self.log("error \(code) retryable=\(retryable)")
    case .pendingChanged:
      self.log("pending \(pending)")
    case .logChanged:
      break
    }
  }

  func log(_ message: String) {
    let line = String(format: "%8.3f ", Date().timeIntervalSince(t0)) + message
    NSLog("SWSUPPORT %@", line)
    lines = String((line + "\n" + lines).prefix(8000))
    if let handle = try? FileHandle(forWritingTo: logURL) {
      handle.seekToEndOfFile()
      handle.write(Data((line + "\n").utf8))
      try? handle.close()
    }
  }
}
