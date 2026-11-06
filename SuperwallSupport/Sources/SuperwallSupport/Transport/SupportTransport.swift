import Foundation

/// What the transport tells its owner (the chat UI, M2).
public enum SupportTransportEvent: Equatable, Sendable {
  case connectionChanged(SupportConnectionState)
  /// Entries, the tail, status or presence changed. Read `log`.
  case logChanged
  /// A pending send was added, retried, confirmed or failed. Read `pendingMessages`.
  case pendingChanged
  /// An `error` frame or a failed command the owner may want to show.
  case error(code: String, retryable: Bool)
}

public enum SupportConnectionState: Equatable, Sendable {
  /// Not started, or backgrounded: no socket (background delivery is push).
  case idle
  case connecting
  /// `ready` received, replaying the backlog.
  case catchingUp
  case live
  case waitingToRetry(seconds: Double)
  /// Waiting for the network to come back.
  case offline
  /// Won't reconnect: the conversation is gone, or this build isn't served.
  case stopped(reason: String)
}

/// The Support transport for one conversation: session start, the live socket,
/// resume from seq, HTTP windows, the send queue and attachment upload.
///
/// Rules from the M0 transport spike:
/// - hold the socket only while foregrounded;
/// - on foreground or network-available, reconnect at once with backoff reset;
/// - ping every 10 s with a 5 s deadline, during catch-up as well as live;
/// - on foreground, probe a socket that survived before trusting it;
/// - replay at most about 60 entries over the socket, anything older over HTTP windows.
public actor SupportTransport {
  public struct Configuration: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Never prints the API key or proof values.
    public var description: String { "Configuration(baseURL: \(baseURL), sdk: \(sdk))" }
    public var debugDescription: String { description }

    /// The inbox API origin, e.g. `https://inbox-api.superwall.com`.
    public var baseURL: URL
    public var apiKey: String
    public var sdk: SupportSdk
    public var locale: String
    public var storefront: String?
    public var capabilities: SupportCapabilities
    public var proofs: [SupportProof]
    public var pingInterval: TimeInterval = 10
    public var pingDeadline: TimeInterval = 5
    /// Behind by more than this at `ready`: catch up over HTTP windows instead.
    public var socketReplayCap: Int = 60
    public var windowSize: Int = SupportWire.defaultWindow
    public var backoffInitial: TimeInterval = 0.5
    public var backoffMax: TimeInterval = 8
    public var sendBackoffMax: TimeInterval = 30
    /// Where the send queue is saved. Nil: Application Support, keyed by API key.
    public var sendQueueFileURL: URL?
    /// Keep the send queue in memory only.
    public var persistSendQueue = true
    /// Testing only: called after each new seq is accepted from the socket; return
    /// true to cut the socket right there, as a network drop would.
    public var dropAfterAcceptingForTesting: (@Sendable (Int) -> Bool)?

    public init(
      baseURL: URL, apiKey: String, sdk: SupportSdk, locale: String,
      storefront: String? = nil, capabilities: SupportCapabilities = .textOnly,
      proofs: [SupportProof]
    ) {
      self.baseURL = baseURL
      self.apiKey = apiKey
      self.sdk = sdk
      self.locale = locale
      self.storefront = storefront
      self.capabilities = capabilities
      self.proofs = proofs
    }
  }

  /// Counters for tests and diagnostics. Never message content.
  public struct Stats: Equatable, Sendable {
    public var connects = 0
    public var drops = 0
    public var gaps = 0
    public var duplicates = 0
    public var pingTimeouts = 0
    public var httpCatchUps = 0
    public var resyncs = 0
    public var ignoredFrames = 0
  }

  public let configuration: Configuration
  private let http: SupportHTTPClient
  private let socketFactory: SupportSocketFactory
  private let queue: SendQueueStore
  private let logger: @Sendable (String) -> Void

  public private(set) var session: SessionStarted?
  public private(set) var log = ConversationLog()
  public private(set) var state: SupportConnectionState = .idle {
    didSet { if state != oldValue { emit(.connectionChanged(state)) } }
  }
  public private(set) var stats = Stats()

  private var eventHandler: (@Sendable (SupportTransportEvent) -> Void)?
  private var foreground = true
  private var networkAvailable = true
  private var started = false
  private var starting = false
  private var stopped = false
  /// A start that failed retryably: retried on backoff, and at once on network or foreground.
  private var startWanted = false
  private var startConversationId: String?
  private var startRetryTask: Task<Void, Never>?
  /// An HTTP read that replaces the socket (catch-up, resync, the first window) is
  /// running: no socket may open until it ends, or two would race over the cursor.
  private var httpBusy = false
  /// Bumped whenever the log is replaced, so a scroll-back that was in flight is dropped.
  private var logEpoch = 0
  /// Session renewals since the last progress, so a server that keeps answering 4001 backs off.
  private var sessionRenewals = 0
  /// The last `error` frame on this socket: its code says what a close means when the
  /// close code itself hasn't been reported yet.
  private var lastErrorCode: String?

  // The socket and everything tied to it. `generation` invalidates old loops.
  private var socket: SupportSocket?
  private var generation = 0
  private var readyHead: Int?
  private var lastFrameAt = Date.distantPast
  private var backoff: TimeInterval
  private var retryTask: Task<Void, Never>?
  private var pingTask: Task<Void, Never>?
  private var consecutiveGaps = 0

  private var sendTask: Task<Void, Never>?
  private var sendGeneration = 0
  private var sendBackoff: TimeInterval

  public init(configuration: Configuration, urlSession: URLSession = .shared) {
    self.init(
      configuration: configuration,
      http: SupportHTTPClient(baseURL: configuration.baseURL, urlSession: urlSession),
      socketFactory: URLSessionSupportSocketFactory(configuration: urlSession.configuration),
      logger: { message in
        #if DEBUG
          NSLog("[SuperwallSupport] %@", message)
        #endif
      }
    )
  }

  init(
    configuration: Configuration, http: SupportHTTPClient, socketFactory: SupportSocketFactory,
    logger: @escaping @Sendable (String) -> Void
  ) {
    self.configuration = configuration
    self.http = http
    self.socketFactory = socketFactory
    self.logger = logger
    backoff = configuration.backoffInitial
    sendBackoff = configuration.backoffInitial
    let fileURL: URL?
    if !configuration.persistSendQueue {
      fileURL = nil
    } else if let explicit = configuration.sendQueueFileURL {
      fileURL = explicit
    } else {
      fileURL = SendQueueStore.defaultFileURL(
        namespace: String(SupportHTTPClient.sha256Hex(Data(configuration.apiKey.utf8)).prefix(16)))
    }
    queue = SendQueueStore(fileURL: fileURL)
  }

  public func setEventHandler(_ handler: (@Sendable (SupportTransportEvent) -> Void)?) {
    eventHandler = handler
  }

  public var pendingMessages: [PendingMessage] {
    guard let conversationId = session?.conversationId else { return [] }
    return queue.all.filter { $0.conversationId == conversationId }
  }

  // MARK: - Lifecycle

  /// Starts a session, loads the newest window and connects. Throws only when the
  /// session can't start (call again to retry). A window that fails to load doesn't
  /// stop it: the socket's catch-up reads it over HTTP instead.
  public func start(conversationId: String? = nil) async throws {
    guard !started, !starting else { return }
    starting = true
    defer { starting = false }
    startRetryTask?.cancel()
    // A previous start that ended in a redirect may be retried.
    stopped = false
    do {
      try await startSession(conversationId: conversationId)
    } catch let error as SupportTransportError where error.isRetryable {
      // Opened offline, or the server is down: keep trying without the caller.
      startWanted = true
      startConversationId = conversationId
      state = networkAvailable ? .waitingToRetry(seconds: backoff) : .offline
      scheduleStartRetry()
      throw error
    }
    startWanted = false
    httpBusy = true
    do {
      try await reloadNewestWindow()
    } catch {
      logger("first window failed (\(error)); the socket catches up")
    }
    httpBusy = false
    started = true
    connect()
    flushSends()
  }

  private func scheduleStartRetry() {
    startRetryTask?.cancel()
    guard networkAvailable, foreground else { return }
    let wait = backoff
    backoff = min(backoff * 2, configuration.backoffMax)
    startRetryTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
      guard !Task.isCancelled else { return }
      await self?.retryStartFromTimer()
    }
  }

  private func retryStartFromTimer() async {
    // Not cancelled by the start it runs.
    startRetryTask = nil
    await retryStart()
  }

  private func retryStart() async {
    guard startWanted, !started, !stopped else { return }
    // Scheduled again inside when it is still retryable.
    try? await start(conversationId: startConversationId)
  }

  /// Closes the socket and stops reconnecting, for good: build a new transport to
  /// start again. Pending sends stay queued on disk. The transport's tasks hold it
  /// until this is called, so always call it when chat closes.
  public func stop() {
    stopped = true
    startWanted = false
    startRetryTask?.cancel()
    closeSocket(reason: "stopped")
    retryTask?.cancel()
    sendTask?.cancel()
    state = .stopped(reason: "stopped")
  }

  /// The app moved to the foreground or the background.
  public func setForeground(_ isForeground: Bool) {
    guard isForeground != foreground else {
      if isForeground { probeOrConnect() }
      return
    }
    foreground = isForeground
    if isForeground {
      if startWanted {
        backoff = configuration.backoffInitial
        Task { await self.retryStart() }
      }
      probeOrConnect()
      flushSends(resetBackoff: true)
    } else {
      // The socket is held only while foregrounded; Android loses it ~5 s into
      // background anyway, and background delivery is push.
      retryTask?.cancel()
      closeSocket(reason: "background")
      if !isStoppedState { state = .idle }
    }
  }

  /// The OS reported the network path changed.
  public func setNetworkAvailable(_ available: Bool) {
    guard available != networkAvailable else { return }
    networkAvailable = available
    if available {
      backoff = configuration.backoffInitial
      if startWanted { Task { await self.retryStart() } }
      if socket == nil { connect() }
      flushSends(resetBackoff: true)
    } else {
      retryTask?.cancel()
      closeSocket(reason: "offline")
      if !isStoppedState { state = .offline }
    }
  }

  private var isStoppedState: Bool {
    if case .stopped = state { return true }
    return false
  }

  private func probeOrConnect() {
    backoff = configuration.backoffInitial
    if let socket {
      // A socket that survived suspension may be dead without knowing it: ping now
      // and drop it if nothing comes back within the deadline.
      sendPing(on: socket, generation: generation)
    } else {
      connect()
    }
  }

  // MARK: - Session

  private func startSession(conversationId: String?) async throws {
    var request = SessionStart(
      apiKey: configuration.apiKey, sdk: configuration.sdk, locale: configuration.locale,
      storefront: configuration.storefront, capabilities: configuration.capabilities,
      proofs: configuration.proofs, conversationId: conversationId ?? session?.conversationId)
    request.protocol = SupportWire.protocolName
    let started = try await http.startSession(request)
    if let redirect = started.redirect {
      session = started
      stopForGood(reason: "redirect")
      throw SupportTransportError.redirected(url: redirect.url)
    }
    if session?.conversationId != started.conversationId {
      // A new conversation: the old socket and the old log belong to the old one.
      if session != nil { closeSocket(reason: "new conversation") }
      log.reset(conversationId: started.conversationId)
      logEpoch += 1
    }
    session = started
    logger("session started, conversation \(started.conversationId)")
  }

  /// Runs an authenticated command, starting a new session once if the token is refused.
  private func authenticated<T>(_ call: (String, String) async throws -> T) async throws -> T {
    guard let session else { throw SupportTransportError.notStarted }
    do {
      return try await call(session.sessionToken, session.conversationId)
    } catch SupportTransportError.wire(let body) where body.tag == "SessionInvalid" || body.tag == "HTTP401" {
      try await startSession(conversationId: session.conversationId)
      guard let renewed = self.session else { throw SupportTransportError.notStarted }
      return try await call(renewed.sessionToken, renewed.conversationId)
    }
  }

  // MARK: - Windows

  private func reloadNewestWindow() async throws {
    let window = try await authenticated { token, conversationId in
      try await self.http.entries(
        token: token, conversationId: conversationId, limit: self.configuration.windowSize)
    }
    log.replace(with: window)
    logEpoch += 1
    reconcileQueue(with: window)
    emit(.logChanged)
  }

  /// Reads `after=cursor` windows until caught up. Past `maxCatchUpWindows` it gives
  /// up on the gap and loads the newest window instead; scrolling back fills the rest.
  private func catchUpOverHTTP() async throws {
    stats.httpCatchUps += 1
    for _ in 0..<Self.maxCatchUpWindows {
      guard foreground, !stopped else { return }
      let cursor = log.cursor
      let window = try await authenticated { token, conversationId in
        try await self.http.entries(
          token: token, conversationId: conversationId, after: cursor,
          limit: self.configuration.windowSize)
      }
      log.applyCatchUp(window)
      reconcileQueue(with: window)
      emit(.logChanged)
      // Stop when the server has nothing more, or a window didn't move the cursor.
      if !window.hasMore || log.cursor == cursor { return }
    }
    try await reloadNewestWindow()
  }

  static let maxCatchUpWindows = 5

  /// Sends confirmed by an entry that arrived over HTTP leave the queue, failed ones included.
  private func reconcileQueue(with window: EntryWindow) {
    var changed = false
    for entry in window.decodedEntries {
      if let id = entry.clientMessageId, queue.remove(clientMessageId: id) { changed = true }
    }
    if changed { emit(.pendingChanged) }
  }

  /// Scrolls back: the window before the oldest entry held.
  public func loadOlder() async throws {
    guard let oldest = log.oldestSeq, log.hasOlder else { return }
    let epoch = logEpoch
    let window = try await authenticated { token, conversationId in
      try await self.http.entries(
        token: token, conversationId: conversationId, before: oldest,
        limit: self.configuration.windowSize)
    }
    // The log was replaced meanwhile: this window belongs to the old one.
    guard epoch == logEpoch, log.oldestSeq == oldest else { return }
    log.applyOlder(window)
    emit(.logChanged)
  }

  // MARK: - Socket

  private func liveURL(conversationId: String) -> URL? {
    guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)
    else { return nil }
    components.scheme = components.scheme == "http" ? "ws" : "wss"
    components.path = components.path.trimmingSuffix("/") + "/v1/conversations/\(conversationId)/live"
    return components.url
  }

  private func connect() {
    guard started, !stopped, !httpBusy, foreground, networkAvailable, socket == nil,
      let session, let url = liveURL(conversationId: session.conversationId)
    else {
      if !networkAvailable, !stopped { state = .offline }
      return
    }
    retryTask?.cancel()
    generation += 1
    let generation = generation
    let socket = socketFactory.make(url: url)
    self.socket = socket
    readyHead = nil
    lastErrorCode = nil
    lastFrameAt = Date()
    stats.connects += 1
    state = .connecting
    let hello = ClientFrame.hello(
      sessionToken: session.sessionToken, conversationId: session.conversationId,
      after: log.cursor, afterId: log.cursorId)
    Task { await self.run(socket: socket, generation: generation, hello: hello.encoded()) }
    startPings(on: socket, generation: generation)
  }

  private func run(socket: SupportSocket, generation: Int, hello: String) async {
    do {
      try await socket.send(hello)
      while true {
        let text = try await socket.receive()
        guard generation == self.generation else { return }
        await handle(text: text, socket: socket, generation: generation)
        guard generation == self.generation else { return }
      }
    } catch {
      guard generation == self.generation else { return }
      // URLSession can report the close code after `receive` throws; the `error`
      // frame sent before the close says the same thing.
      let code = socket.closeCode ?? Self.closeCode(forErrorFrame: lastErrorCode)
      dropped(closeCode: code, reason: SupportHTTPClient.describe(error))
    }
  }

  static func closeCode(forErrorFrame code: String?) -> Int? {
    switch code {
    case "session_invalid": return SupportCloseCode.sessionInvalid
    case "conversation_not_found", "not_found": return SupportCloseCode.notFound
    case "protocol_unsupported": return SupportCloseCode.protocolUnsupported
    default: return nil
    }
  }

  private func handle(text: String, socket: SupportSocket, generation: Int) async {
    lastFrameAt = Date()
    switch WireFrameDecoder.decode(text) {
    case .ignored(let reason):
      stats.ignoredFrames += 1
      logger("ignored frame: \(reason)")
    case .frame(let frame):
      await handle(frame: frame, socket: socket, generation: generation)
    }
  }

  private func handle(frame: ServerFrame, socket: SupportSocket, generation: Int) async {
    switch frame {
    case .ready(_, _, let head):
      log.ready()
      readyHead = head
      emit(.logChanged)
      if head - log.cursor > configuration.socketReplayCap {
        // Too far behind for the socket: read windows over HTTP, then reconnect from there.
        // Holding nothing (the first window failed): load the newest window, not all history.
        let holdsNothing = log.cursor == 0
        await replaceSocket(reason: "catch up over HTTP") {
          if holdsNothing { try await self.reloadNewestWindow() } else { try await self.catchUpOverHTTP() }
        }
        return
      }
      state = .catchingUp
      checkCaughtUp()

    case .entry(let seq, let prev, let raw):
      switch log.applyEntryFrame(seq: seq, prev: prev, raw: raw) {
      case .accept:
        consecutiveGaps = 0
        // Progress: the path works, so a drop after this retries from the first step.
        backoff = configuration.backoffInitial
        let entry = log.entriesBySeq[seq]
        if let clientMessageId = entry?.clientMessageId, queue.remove(clientMessageId: clientMessageId) {
          emit(.pendingChanged)
        }
        emit(.logChanged)
        checkCaughtUp()
        if configuration.dropAfterAcceptingForTesting?(seq) == true {
          socket.close(code: SupportCloseCode.goingAway, reason: "test drop")
          dropped(closeCode: nil, reason: "test drop after seq \(seq)")
        }
      case .duplicate:
        stats.duplicates += 1
        checkCaughtUp()
      case .gap(let expected, let prev):
        stats.gaps += 1
        consecutiveGaps += 1
        logger("gap: holding \(expected), frame prev \(prev); reconnecting")
        // Reconnect with the cursor at once, unless gaps keep repeating.
        await replaceSocket(reason: "gap", backoff: consecutiveGaps > 3) {}
      }

    case .tail(let messageId, let offset, let text):
      log.applyTail(messageId: messageId, offset: offset, text: text)
      emit(.logChanged)

    case .tailCancel(let messageId, _):
      log.cancelTail(messageId: messageId)
      emit(.logChanged)

    case .status(let state, let eta):
      log.setStatus(state, etaSeconds: eta)
      emit(.logChanged)

    case .presence(let participants):
      log.setPresence(participants)
      emit(.logChanged)

    case .resync(let reason, _):
      stats.resyncs += 1
      logger("resync: \(reason)")
      await replaceSocket(reason: "resync") {
        try await self.reloadNewestWindow()
      }

    case .error(let code, _, let retryable):
      lastErrorCode = code
      emit(.error(code: code, retryable: retryable))
      // The close that follows carries what to do (session invalid, not found …).

    case .pong:
      break
    }
  }

  /// Live once the cursor reaches the head `ready` announced.
  private func checkCaughtUp() {
    guard state == .catchingUp, let readyHead, log.cursor >= readyHead else { return }
    state = .live
    backoff = configuration.backoffInitial
    sessionRenewals = 0
  }

  /// Drops this socket, runs `work` (an HTTP read), then reconnects.
  private func replaceSocket(
    reason: String, backoff useBackoff: Bool = false, work: () async throws -> Void
  ) async {
    closeSocket(reason: reason)
    httpBusy = true
    state = .catchingUp
    defer { httpBusy = false }
    do {
      try await work()
    } catch {
      httpBusy = false
      logger("\(reason) failed: \(error)")
      scheduleRetry()
      return
    }
    httpBusy = false
    if useBackoff { scheduleRetry() } else { connect() }
  }

  private func closeSocket(reason: String) {
    generation += 1
    pingTask?.cancel()
    pingTask = nil
    socket?.close(code: SupportCloseCode.normal, reason: reason)
    socket = nil
    readyHead = nil
  }

  /// The socket closed or failed under us.
  private func dropped(closeCode: Int?, reason: String) {
    stats.drops += 1
    logger("socket dropped: code \(closeCode.map(String.init) ?? "none"), \(reason)")
    closeSocket(reason: "dropped")
    switch closeCode {
    case SupportCloseCode.sessionInvalid:
      state = .connecting
      Task { await self.renewSessionThenConnect() }
    case SupportCloseCode.protocolUnsupported:
      stopForGood(reason: "protocol_unsupported")
    case SupportCloseCode.notFound:
      stopForGood(reason: "not_found")
    default:
      // 1001 (going away), 1011, 4029, 4003, or a network failure: back off and retry.
      scheduleRetry()
    }
  }

  private func renewSessionThenConnect() async {
    sessionRenewals += 1
    do {
      try await startSession(conversationId: session?.conversationId)
      // A server that keeps refusing new tokens gets backoff, not a tight loop.
      if sessionRenewals > 1 { scheduleRetry() } else { connect() }
    } catch {
      scheduleRetry()
    }
  }

  /// Won't reconnect: closes the socket, and fails pending sends so they don't sit forever.
  private func stopForGood(reason: String) {
    stopped = true
    retryTask?.cancel()
    closeSocket(reason: reason)
    sendTask?.cancel()
    var changed = false
    for item in queue.all where item.state == .pending {
      queue.update(clientMessageId: item.clientMessageId) {
        $0.state = .failed
        $0.failure = reason
      }
      changed = true
    }
    if changed { emit(.pendingChanged) }
    state = .stopped(reason: reason)
  }

  private func scheduleRetry() {
    guard !stopped else { return }
    guard foreground else {
      state = .idle
      return
    }
    guard networkAvailable else {
      state = .offline
      return
    }
    retryTask?.cancel()
    // Full jitter on the current step, so many clients don't reconnect in lockstep.
    let delay = Double.random(in: (backoff / 2)...backoff)
    backoff = min(backoff * 2, configuration.backoffMax)
    state = .waitingToRetry(seconds: delay)
    retryTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }
      await self?.retryNow()
    }
  }

  private func retryNow() {
    if socket == nil { connect() }
  }

  // MARK: - Liveness

  private func startPings(on socket: SupportSocket, generation: Int) {
    pingTask?.cancel()
    // The server's heartbeat is an upper bound; never below a second, whatever it says.
    let interval = max(1, min(configuration.pingInterval, Double(session?.heartbeatSeconds ?? 10)))
    pingTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        guard !Task.isCancelled else { return }
        await self?.sendPing(on: socket, generation: generation)
      }
    }
  }

  /// Sends a ping and drops the socket if no frame at all arrives within the
  /// deadline. Runs during catch-up too: a stalled backlog is a dead socket.
  private func sendPing(on socket: SupportSocket, generation: Int) {
    guard generation == self.generation else { return }
    let sentAt = Date()
    let deadline = max(0.5, configuration.pingDeadline)
    // The deadline runs from the send, not from its completion: a send stuck on a
    // dead path must still trip it.
    Task { try? await socket.send(SupportWire.pingFrame) }
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
      await self?.checkLiveness(generation: generation, since: sentAt)
    }
  }

  private func checkLiveness(generation: Int, since sentAt: Date) {
    guard generation == self.generation, socket != nil else { return }
    if lastFrameAt < sentAt {
      stats.pingTimeouts += 1
      dropped(closeCode: nil, reason: "no frame within \(configuration.pingDeadline)s of a ping")
    }
  }

  // MARK: - Sending

  /// Queues a message and sends it. Returns at once; the queue retries with the
  /// same `clientMessageId` until the server confirms it.
  @discardableResult
  public func send(text: String, attachmentIds: [String] = []) throws -> PendingMessage {
    guard let session else { throw SupportTransportError.notStarted }
    let clientMessageId = UUID().uuidString.lowercased()
    let message = SendMessage(
      clientMessageId: clientMessageId, text: text,
      attachments: attachmentIds.isEmpty ? nil : attachmentIds.map(AttachmentRef.init),
      seenSeq: nil)
    try message.validate()
    let pending = PendingMessage(
      clientMessageId: clientMessageId, conversationId: session.conversationId, text: text,
      attachmentIds: attachmentIds, createdAt: Date(), attempts: 0, state: .pending, failure: nil)
    queue.append(pending)
    emit(.pendingChanged)
    flushSends()
    return pending
  }

  /// Retries a failed send by hand, with the same `clientMessageId`.
  public func retry(clientMessageId: String) {
    queue.update(clientMessageId: clientMessageId) {
      $0.state = .pending
      $0.failure = nil
    }
    emit(.pendingChanged)
    flushSends(resetBackoff: true)
  }

  /// Drops a failed send the person gave up on.
  public func discard(clientMessageId: String) {
    if queue.remove(clientMessageId: clientMessageId) { emit(.pendingChanged) }
  }

  /// Starts draining the queue. With `resetBackoff` (foreground, network back, a
  /// manual retry) a drain asleep in backoff is woken: retrying the same id is safe.
  private func flushSends(resetBackoff: Bool = false) {
    if resetBackoff {
      sendBackoff = configuration.backoffInitial
      sendTask?.cancel()
      sendTask = nil
    }
    guard sendTask == nil, session != nil, !stopped else { return }
    sendGeneration += 1
    let generation = sendGeneration
    sendTask = Task {
      await self.drainSendQueue()
      self.sendDrainFinished(generation)
    }
  }

  private func sendDrainFinished(_ generation: Int) {
    if generation == sendGeneration { sendTask = nil }
  }

  private func drainSendQueue() async {
    while !Task.isCancelled, networkAvailable,
      let conversationId = session?.conversationId,
      let next = queue.next(conversationId: conversationId)
    {
      queue.update(clientMessageId: next.clientMessageId) { $0.attempts += 1 }
      let message = SendMessage(
        clientMessageId: next.clientMessageId, text: next.text,
        attachments: next.attachmentIds.isEmpty ? nil : next.attachmentIds.map(AttachmentRef.init),
        seenSeq: log.cursor > 0 ? log.cursor : nil)
      do {
        let accepted = try await authenticated { token, conversationId in
          try await self.http.sendMessage(token: token, conversationId: conversationId, message)
        }
        sendBackoff = configuration.backoffInitial
        queue.remove(clientMessageId: next.clientMessageId)
        log.holdOutOfBand(WireEntry.decode(accepted.entry))
        emit(.pendingChanged)
        emit(.logChanged)
      } catch let error as SupportTransportError where error.isRetryable {
        logger("send retry after \(error)")
        let delay = max(sendBackoff, error.retryAfter ?? 0)
        sendBackoff = min(sendBackoff * 2, configuration.sendBackoffMax)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      } catch {
        let tag: String
        if case SupportTransportError.wire(let body) = error { tag = body.tag } else { tag = "\(error)" }
        queue.update(clientMessageId: next.clientMessageId) {
          $0.state = .failed
          $0.failure = tag
        }
        emit(.pendingChanged)
        emit(.error(code: tag, retryable: false))
      }
    }
  }

  // MARK: - Attachments

  /// Uploads bytes for an attachment and returns its id, for `send(text:attachmentIds:)`.
  /// Asks for an upload, PUTs the bytes to the presigned URL, then completes it.
  public func uploadAttachment(
    data: Data, filename: String, mime: String, kind: String = "file"
  ) async throws -> UploadCompleted {
    guard data.count <= SupportWire.maxAttachmentBytes, !data.isEmpty else {
      throw SupportTransportError.attachmentTooLarge(max: SupportWire.maxAttachmentBytes)
    }
    let request = UploadRequest(
      kind: kind, filename: String(filename.prefix(255)), mime: mime, bytes: data.count,
      sha256: SupportHTTPClient.sha256Hex(data))
    return try await withRetries {
      let intent = try await self.authenticated { token, conversationId in
        try await self.http.createUpload(token: token, conversationId: conversationId, request)
      }
      try await self.http.put(intent.upload, data: data)
      return try await self.authenticated { token, _ in
        try await self.http.completeUpload(token: token, attachmentId: intent.attachmentId)
      }
    }
  }

  /// A short-lived link to an attachment's bytes.
  public func attachmentURL(attachmentId: String) async throws -> URL {
    let link = try await authenticated { token, _ in
      try await self.http.attachmentURL(token: token, attachmentId: attachmentId)
    }
    guard let url = URL(string: link.url) else { throw SupportTransportError.invalidRequest("Bad URL") }
    return url
  }

  // MARK: - Other commands

  public func markRead(seq: Int) async throws {
    try await withRetries {
      try await self.authenticated { token, conversationId in
        try await self.http.markRead(token: token, conversationId: conversationId, seq: seq)
      }
    }
  }

  public func cardAction(cardId: String, _ request: CardActionRequest) async throws {
    let accepted = try await withRetries {
      try await self.authenticated { token, _ in
        try await self.http.cardAction(token: token, cardId: cardId, request)
      }
    }
    for raw in accepted.entries { log.holdOutOfBand(WireEntry.decode(raw)) }
    emit(.logChanged)
  }

  public func toolCallResult(callId: String, _ request: ToolCallResultRequest) async throws {
    try await withRetries {
      try await self.authenticated { token, _ in
        try await self.http.toolCallResult(token: token, callId: callId, request)
      }
    }
  }

  public func setTyping(_ active: Bool) {
    guard let socket else { return }
    let frame = ClientFrame.typing(active: active).encoded()
    Task { try? await socket.send(frame) }
  }

  /// Retries an idempotent command a few times on retryable failures.
  private func withRetries<T>(attempts: Int = 3, _ call: () async throws -> T) async throws -> T {
    var delay = configuration.backoffInitial
    var attempt = 1
    while true {
      do {
        return try await call()
      } catch let error as SupportTransportError where error.isRetryable && attempt < attempts {
        attempt += 1
        try? await Task.sleep(nanoseconds: UInt64(max(delay, error.retryAfter ?? 0) * 1_000_000_000))
        delay = min(delay * 2, configuration.backoffMax)
      }
    }
  }

  // MARK: - Events

  private func emit(_ event: SupportTransportEvent) {
    eventHandler?(event)
  }

  // MARK: - Test hooks

  /// Drops the socket as if the network had cut it. For test apps and debugging only.
  public func dropConnectionForTesting() {
    guard let socket else { return }
    let generation = generation
    socket.close(code: SupportCloseCode.goingAway, reason: "simulated")
    if generation == self.generation { dropped(closeCode: nil, reason: "simulated") }
  }
}
