import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized, .timeLimit(.minutes(1)))
struct ConfigRequestStartedTests {
  @Test func requestResumesBeforeWarmupAndResponseDoesNotWaitForWarmup() async throws {
    ConfigWarmupURLProtocol.state.reset()
    let factory = DependencyContainer()
    let session = RecordingSession(configuration: configuration())
    defer { session.invalidateAndCancel() }
    let client = CustomURLSession(factory: factory, urlSession: session)
    let queue = DispatchQueue(label: "held-config-warmup")
    let decoded = Counter()
    queue.suspend()
    defer { queue.resume(); queue.sync {} }
    let prewarmer = ConfigDecodingPrewarmer(
      schedule: { queue.async(execute: $0) },
      decode: { decoded.increment() }
    )
    let callbacks = Counter()

    let config: Config = try await client.request(
      .config(maxRetry: 0, apiKey: "prewarm-test", timeout: nil),
      data: SuperwallRequestData(factory: factory),
      onRequestStarted: {
        callbacks.increment()
        #expect(session.createdTask?.state != .suspended)
        #expect(session.createdTask != nil)
        prewarmer.start()
      }
    )

    #expect(config.buildId == "superwall-config-prewarm")
    #expect(callbacks.value == 1)
    #expect(decoded.value == 0, "Response decoding must finish while warmup is still queued")
  }

  @Test func retryResumesAnotherRequestWithoutRepeatingWarmup() async throws {
    ConfigWarmupURLProtocol.state.reset(failFirst: true)
    let factory = DependencyContainer()
    let session = URLSession(configuration: configuration())
    defer { session.invalidateAndCancel() }
    let client = CustomURLSession(factory: factory, urlSession: session)
    let decoded = Counter()
    let callbacks = Counter()
    let prewarmer = ConfigDecodingPrewarmer(
      schedule: { $0() },
      decode: { decoded.increment() }
    )
    var endpoint = Endpoint<EndpointKinds.Superwall, Config>.config(
      maxRetry: 1,
      apiKey: "prewarm-test",
      timeout: nil
    )
    endpoint.retryInterval = 0

    _ = try await client.request(
      endpoint,
      data: SuperwallRequestData(factory: factory),
      onRequestStarted: {
        callbacks.increment()
        prewarmer.start()
      }
    )

    #expect(ConfigWarmupURLProtocol.state.requestCount == 2)
    #expect(callbacks.value == 2)
    #expect(decoded.value == 1)
  }

  @Test func timeoutCancelsTheResumedURLSessionTask() async {
    ConfigWarmupURLProtocol.state.reset(holdResponse: true)
    let factory = DependencyContainer()
    let session = URLSession(configuration: configuration())
    defer { session.invalidateAndCancel() }
    let client = CustomURLSession(factory: factory, urlSession: session)
    let callbacks = Counter()

    do {
      let _: Config = try await client.request(
        .config(maxRetry: 0, apiKey: "prewarm-test", timeout: 0.5),
        data: SuperwallRequestData(factory: factory),
        onRequestStarted: { callbacks.increment() }
      )
      Issue.record("The held request should time out")
    } catch {
      #expect(error is CancellationError)
    }

    #expect(callbacks.value == 1)
    #expect(await ConfigWarmupURLProtocol.state.waitUntilStopped())
    #expect(ConfigWarmupURLProtocol.state.requestCount == 1)
  }

  @Test func cancellationBeforeTaskRegistrationCompletesWithoutStartingWarmup() async {
    ConfigWarmupURLProtocol.state.reset(holdResponse: true)
    let factory = DependencyContainer()
    let session = RecordingSession(configuration: configuration())
    session.beforeCreatingTask = {
      // The operation is already inside its cancellation handler, but the
      // URLSessionDataTask has not yet been registered with that handler.
      withUnsafeCurrentTask { $0?.cancel() }
    }
    defer { session.invalidateAndCancel() }
    let client = CustomURLSession(factory: factory, urlSession: session)
    let callbacks = Counter()

    do {
      let _: Config = try await client.request(
        .config(maxRetry: 0, apiKey: "prewarm-test", timeout: nil),
        data: SuperwallRequestData(factory: factory),
        onRequestStarted: { callbacks.increment() }
      )
      Issue.record("The canceled operation should not return a config")
    } catch {
      #expect((error as? URLError)?.code == .cancelled || error is CancellationError)
    }

    #expect(session.createdTask != nil)
    #expect(callbacks.value == 0)
  }

  private func configuration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.protocolClasses = [ConfigWarmupURLProtocol.self]
    return configuration
  }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }
}

private final class RecordingSession: URLSession, @unchecked Sendable {
  private let backing: URLSession
  private let lock = NSLock()
  private var task: URLSessionDataTask?
  var beforeCreatingTask: (() -> Void)?
  var createdTask: URLSessionDataTask? {
    lock.lock()
    defer { lock.unlock() }
    return task
  }

  init(configuration: URLSessionConfiguration) {
    backing = URLSession(configuration: configuration)
    super.init()
  }

  override func invalidateAndCancel() {
    backing.invalidateAndCancel()
  }

  override func dataTask(
    with request: URLRequest,
    completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
  ) -> URLSessionDataTask {
    beforeCreatingTask?()
    let task = backing.dataTask(with: request, completionHandler: completionHandler)
    lock.lock()
    self.task = task
    lock.unlock()
    return task
  }
}

private final class ConfigWarmupURLProtocol: URLProtocol, @unchecked Sendable {
  static let state = ProtocolState()

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let behavior = Self.state.start()
    guard !behavior.hold else { return }
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: behavior.fail ? 500 : 200,
      httpVersion: nil,
      headerFields: nil
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(ConfigDecodingPrewarmer.fixture.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {
    Self.state.stop()
  }

  final class ProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var hold = false
    private var failFirst = false
    private var hasStopped = false
    private var stopWaiters: [StopWaiter] = []
    var requestCount: Int {
      lock.lock()
      defer { lock.unlock() }
      return count
    }

    func reset(holdResponse: Bool = false, failFirst: Bool = false) {
      lock.lock()
      defer { lock.unlock() }
      count = 0
      hold = holdResponse
      self.failFirst = failFirst
      hasStopped = false
      stopWaiters = []
    }

    func waitUntilStopped() async -> Bool {
      let waiter = StopWaiter()
      return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
          waiter.install(continuation)
          lock.lock()
          if hasStopped {
            lock.unlock()
            waiter.complete(true)
          } else {
            stopWaiters.append(waiter)
            lock.unlock()
          }
          DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            waiter.complete(false)
          }
        }
      } onCancel: {
        waiter.complete(false)
      }
    }

    func stop() {
      lock.lock()
      hasStopped = true
      let waiters = stopWaiters
      stopWaiters = []
      lock.unlock()
      for waiter in waiters {
        waiter.complete(true)
      }
    }

    /// Stop, timeout and cancellation may race, including cancellation before
    /// the continuation is installed. Exactly one result resumes the waiter.
    private final class StopWaiter: @unchecked Sendable {
      private let lock = NSLock()
      private var continuation: CheckedContinuation<Bool, Never>?
      private var result: Bool?

      func install(_ continuation: CheckedContinuation<Bool, Never>) {
        lock.lock()
        if let result = result {
          lock.unlock()
          continuation.resume(returning: result)
        } else {
          self.continuation = continuation
          lock.unlock()
        }
      }

      func complete(_ result: Bool) {
        lock.lock()
        guard self.result == nil else {
          lock.unlock()
          return
        }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: result)
      }
    }

    func start() -> (hold: Bool, fail: Bool) {
      lock.lock()
      defer { lock.unlock() }
      count += 1
      return (hold, failFirst && count == 1)
    }
  }
}
