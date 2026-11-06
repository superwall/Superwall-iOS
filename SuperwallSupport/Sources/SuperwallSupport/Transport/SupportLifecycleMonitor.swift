import Foundation
import Network

#if canImport(UIKit)
  import UIKit
#endif

/// Feeds a transport the app's foreground state and the network path, the two
/// signals that decide when the socket is held and when it reconnects at once.
public final class SupportLifecycleMonitor: @unchecked Sendable {
  private let transport: SupportTransport
  private let pathMonitor = NWPathMonitor()
  private var observers: [NSObjectProtocol] = []

  public init(transport: SupportTransport) {
    self.transport = transport
  }

  /// Starts observing. Call on the main thread.
  public func start() {
    pathMonitor.pathUpdateHandler = { [transport] path in
      let available = path.status == .satisfied
      Task { await transport.setNetworkAvailable(available) }
    }
    pathMonitor.start(queue: DispatchQueue(label: "com.superwall.support.path"))

    #if canImport(UIKit) && !os(watchOS)
      let center = NotificationCenter.default
      observers.append(
        center.addObserver(
          forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [transport] _ in
          Task { await transport.setForeground(false) }
        })
      observers.append(
        center.addObserver(
          forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [transport] _ in
          Task { await transport.setForeground(true) }
        })
    #endif
  }

  public func stop() {
    pathMonitor.cancel()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
  }

  deinit {
    stop()
  }
}
