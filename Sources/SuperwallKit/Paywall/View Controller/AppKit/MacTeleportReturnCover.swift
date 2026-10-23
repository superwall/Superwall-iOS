#if os(macOS)
import AppKit
import WebKit

/// Mac apps keep rendering when the browser opens. The page owns its waiting screen and
/// status checks; the native side forwards return links without iOS app-switcher snapshots.
@MainActor
final class TeleportReturnCover: NSObject {
  private weak var webView: WKWebView?
  private var pendingOpen: (id: UUID, open: () -> Void)?

  init(view: NSView, webView: WKWebView) {
    self.webView = webView
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(returnLinkOpened),
      name: .superwallReturnLinkOpened,
      object: nil
    )
  }

  func leave(drawingWaitingScreen: Bool, open: @escaping () -> Void) {
    guard drawingWaitingScreen, let webView else {
      open()
      return
    }
    let id = UUID()
    pendingOpen = (id, open)
    webView.callAsyncJavaScript(
      Self.showWaitingScreenScript, arguments: [:], in: nil, in: .page
    ) { [weak self] _ in
      self?.finishOpening(id)
    }
    // A page that never resolves must not prevent opening the browser.
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 500_000_000)
      self?.finishOpening(id)
    }
  }

  private func finishOpening(_ id: UUID) {
    guard let pendingOpen, pendingOpen.id == id else { return }
    self.pendingOpen = nil
    pendingOpen.open()
  }

  // Native status polling is only needed while iOS suspends the page.
  func startWatching(_ watch: Watch) {}
  func stopWatching() {}

  func reset() {
    pendingOpen = nil
  }

  @objc private func returnLinkOpened(_ notification: Notification) {
    webView?.callAsyncJavaScript(
      Self.returnScript,
      arguments: ["reason": notification.userInfo?["reason"] as? String ?? ""],
      in: nil,
      in: .page,
      completionHandler: nil
    )
  }
}
#endif
