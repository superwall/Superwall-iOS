import Foundation
import Network

#if canImport(UIKit)
  import UIKit
#endif

/// Feeds a transport the app's foreground state and the network path, the two
/// signals that decide when the socket is held and when it reconnects at once.
///
/// Signals go through one stream drained by one task, so a quick background then
/// foreground reaches the transport in that order. Both are seeded at `start()`.
public final class SupportLifecycleMonitor: @unchecked Sendable {
  private enum Signal {
    case foreground(Bool)
    case network(Bool)
  }

  private let transport: SupportTransport
  private let pathMonitor = NWPathMonitor()
  private var observers: [NSObjectProtocol] = []
  private let signals: AsyncStream<Signal>
  private let emit: AsyncStream<Signal>.Continuation
  private var drain: Task<Void, Never>?

  public init(transport: SupportTransport) {
    self.transport = transport
    (signals, emit) = AsyncStream.makeStream(of: Signal.self)
  }

  /// Starts observing. Call on the main thread.
  @MainActor
  public func start() {
    let transport = transport
    let signals = signals
    drain = Task {
      for await signal in signals {
        switch signal {
        case .foreground(let value): await transport.setForeground(value)
        case .network(let value): await transport.setNetworkAvailable(value)
        }
      }
    }

    #if canImport(UIKit) && !os(watchOS)
      emit.yield(.foreground(UIApplication.shared.applicationState != .background))
      let center = NotificationCenter.default
      observers.append(
        center.addObserver(
          forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [emit] _ in emit.yield(.foreground(false)) })
      observers.append(
        center.addObserver(
          forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [emit] _ in emit.yield(.foreground(true)) })
    #endif

    // The first update reports the current path, which seeds the network state.
    pathMonitor.pathUpdateHandler = { [emit] path in
      emit.yield(.network(path.status == .satisfied))
    }
    pathMonitor.start(queue: DispatchQueue(label: "com.superwall.support.path"))
  }

  public func stop() {
    pathMonitor.cancel()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    emit.finish()
    drain?.cancel()
  }

  deinit {
    stop()
  }
}
