// swiftlint:disable all
#if os(macOS)
import AppKit
import Testing
import WebKit
@testable import SuperwallKit

@MainActor
@Suite(.serialized)
struct MacTeleportReturnCoverTests {
  @Test(arguments: [true, false])
  func waitingScreenAndReturnLinkUsePageFunctions(legacy: Bool) async throws {
    let webView = WKWebView()
    let show = legacy ? "showCheckoutWaitingScreen" : "showTeleportWaitingScreen"
    let hide = legacy ? "hideCheckoutWaitingScreen" : "handleTeleportReturn"
    webView.loadHTMLString("""
      <html><body><script>
      window.shown = false; window.reason = null;
      window.app = {
        \(show): async function() { window.shown = true; return true; },
        \(hide): async function(args) { window.reason = args.reason; return true; }
      };
      </script></body></html>
      """, baseURL: nil)
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
      if (try? await webView.evaluateJavaScript("typeof window.app === 'object'")) as? Bool == true { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(try await webView.evaluateJavaScript("typeof window.app === 'object'") as? Bool == true)
    let cover = TeleportReturnCover(view: NSView(), webView: webView)
    var opened = false
    cover.leave(drawingWaitingScreen: true) { opened = true }
    let openDeadline = Date().addingTimeInterval(2)
    while !opened, Date() < openDeadline { try await Task.sleep(nanoseconds: 10_000_000) }
    #expect(opened)
    #expect(try await webView.evaluateJavaScript("window.shown") as? Bool == true)
    NotificationCenter.default.post(name: .superwallReturnLinkOpened, object: nil, userInfo: ["reason": "completed"])
    let returnDeadline = Date().addingTimeInterval(2)
    var reason: String?
    repeat {
      reason = (try? await webView.evaluateJavaScript("window.reason")) as? String
      if reason != nil { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    } while Date() < returnDeadline
    #expect(reason == "completed")
    cover.reset()
  }
}
#endif
