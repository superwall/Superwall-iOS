//
//  CheckoutWebViewController.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/09/2025.
//
// swiftlint:disable implicitly_unwrapped_optional

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import WebKit

#if os(macOS)
/// The checkout page, shown as a sheet over the paywall.
///
/// It closes from its Close button or Escape, and reports that through
/// `onDismiss` like the iOS sheet does.
final class CheckoutWebViewController: NSViewController {
  private let webView: WKWebView
  private let url: URL
  var onDismiss: (() -> Void)?
  @DispatchQueueBacked
  var hasHandledRedemption = false

  /// Room for a checkout form without crowding a laptop screen.
  static let preferredSize = CGSize(width: 520, height: 720)

  init(url: URL) {
    self.url = url
    self.webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    super.init(nibName: nil, bundle: nil)
    preferredContentSize = Self.preferredSize
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = NSView(frame: NSRect(origin: .zero, size: Self.preferredSize))
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let closeButton = NSButton(
      title: LocalizationLogic.localizedBundle().localizedString(
        forKey: "alert_action_done",
        value: "Done",
        table: nil
      ),
      target: self,
      action: #selector(closeCheckout)
    )
    closeButton.bezelStyle = .rounded
    closeButton.keyEquivalent = "\u{1b}"
    closeButton.translatesAutoresizingMaskIntoConstraints = false

    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.navigationDelegate = self

    view.addSubview(webView)
    view.addSubview(closeButton)

    NSLayoutConstraint.activate([
      closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
      closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
      webView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 10),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    webView.load(URLRequest(url: url))
  }

  override func viewDidDisappear() {
    super.viewDidDisappear()
    onDismiss?()
  }

  @objc private func closeCheckout() {
    dismiss(nil)
  }
}

// MARK: - WKNavigationDelegate
extension CheckoutWebViewController: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    decisionHandler(navigationPolicy(for: navigationAction))
  }
}
#elseif !os(visionOS)
final class CheckoutWebViewController: UIViewController {
  private let webView: WKWebView
  private let url: URL
  var onDismiss: (() -> Void)?
  @DispatchQueueBacked
  var hasHandledRedemption = false

  deinit {
    NotificationCenter.default.removeObserver(self)
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "fieldFocus")
  }

  init(url: URL) {
    self.url = url
    let webConfiguration = WKWebViewConfiguration()
    self.webView = WKWebView(frame: .zero, configuration: webConfiguration)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Set up web view
    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.navigationDelegate = self

    // Add subviews
    view.addSubview(webView)

    // Set up constraints - web view fills the entire view
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    // Set background color
    view.backgroundColor = .systemBackground

    // Load the URL
    let request = URLRequest(url: url)
    webView.load(request)

    // Set self as presentation controller delegate to track detent changes
    presentationController?.delegate = self

    // Add keyboard observers to detect when keyboard causes detent changes
    setupKeyboardObservers()

    // Configure script message handler for field focus detection
    webView.configuration.userContentController.add(self, name: "fieldFocus")
  }

  private func setupKeyboardObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardDidShow),
      name: UIResponder.keyboardDidShowNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardDidHide),
      name: UIResponder.keyboardDidHideNotification,
      object: nil
    )
  }

  @objc private func keyboardDidShow() {
    // When keyboard appears, directly enable scrolling since sheet is functionally expanded
    webView.scrollView.isScrollEnabled = true

    // Re-enable scrolling via JavaScript
    let enableScrollScript = """
      document.body.style.overflow = '';
      document.documentElement.style.overflow = '';
      delete window.scrollTo;
      delete Element.prototype.scrollIntoView;
    """
    webView.evaluateJavaScript(enableScrollScript)
  }

  @objc private func keyboardDidHide() {
    // When keyboard hides, sheet might collapse back to medium detent
    // Add a small delay to ensure sheet animation is complete
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      if #available(iOS 16.0, macOS 13.0, *) {
        guard let sheetController = self?.sheetPresentationController else { return }
        sheetController.invalidateDetents()
      }
      self?.updateScrollingForDetent()
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    onDismiss?()
  }

  private func updateScrollingForDetent() {
    guard let sheetController = sheetPresentationController else {
      return
    }

    // Check if current detent is medium
    // selectedDetentIdentifier is nil on first appearance but defaults to medium
    // However, if keyboard is visible, we should treat it as large detent regardless
    let isMediumDetent = (sheetController.selectedDetentIdentifier == .medium ||
      sheetController.selectedDetentIdentifier == nil)

    // Disable scrolling in medium detent, enable in large detent
    webView.scrollView.isScrollEnabled = !isMediumDetent

    // Also prevent programmatic scrolling via JavaScript
    if isMediumDetent {
      // First scroll to top using native scroll view
      webView.scrollView.setContentOffset(.zero, animated: true)

      // Then use JavaScript to scroll and prevent further scrolling
      let scrollToTopAndDisableScript = """
        document.body.style.overflow = 'hidden';
        document.documentElement.style.overflow = 'hidden';
        window.scrollTo = function() {};
        Element.prototype.scrollIntoView = function() {};
      """
      webView.evaluateJavaScript(scrollToTopAndDisableScript)
    } else {
      // Re-enable scrolling
      let enableScrollScript = """
        document.body.style.overflow = '';
        document.documentElement.style.overflow = '';
        delete window.scrollTo;
        delete Element.prototype.scrollIntoView;
      """
      webView.evaluateJavaScript(enableScrollScript)
    }
  }

  private func injectFieldFocusDetection() {
    let fieldFocusScript = """
      (function() {
        function expandToLargeDetent() {
          window.webkit.messageHandlers.fieldFocus.postMessage('focus');
        }

        // Listen for focus events on input fields
        document.addEventListener('focusin', function(event) {
          const target = event.target;
          const isFormField = target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' ||
            target.tagName === 'SELECT' || target.contentEditable === 'true';
          if (isFormField) {
            expandToLargeDetent();
          }
        });

        // Also listen for click events on input fields as a backup
        document.addEventListener('click', function(event) {
          const target = event.target;
          const isFormField = target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' ||
            target.tagName === 'SELECT' || target.contentEditable === 'true';
          if (isFormField) {
            expandToLargeDetent();
          }
        });
      })();
    """

    webView.evaluateJavaScript(fieldFocusScript)
  }

  private func expandToLargeDetent() {
    guard let sheetController = sheetPresentationController else {
      return
    }

    // Animate to large detent if not already there
    if sheetController.selectedDetentIdentifier != .large {
      sheetController.animateChanges {
        sheetController.selectedDetentIdentifier = .large
      }
    }
  }
}

// MARK: - WKNavigationDelegate
extension CheckoutWebViewController: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    decisionHandler(navigationPolicy(for: navigationAction))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // Hide loading indicator if needed
    // Initial scroll state update after page loads
    updateScrollingForDetent()

    // Inject JavaScript to detect field focus events
    injectFieldFocusDetection()
  }
}

// MARK: - UISheetPresentationControllerDelegate
extension CheckoutWebViewController: UISheetPresentationControllerDelegate {
  func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
    _ sheetPresentationController: UISheetPresentationController
  ) {
    updateScrollingForDetent()
  }
}

// MARK: - WKScriptMessageHandler
extension CheckoutWebViewController: WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    if message.name == "fieldFocus" {
      expandToLargeDetent()
    }
  }
}
#endif

#if !os(visionOS)
extension CheckoutWebViewController {
  /// Lets checkout navigate anywhere except to Superwall deep links, which it
  /// routes itself, once, so a redemption can't run twice.
  func navigationPolicy(for navigationAction: WKNavigationAction) -> WKNavigationActionPolicy {
    guard let url = navigationAction.request.url else {
      return .allow
    }

    // Block Superwall deep links from checkout to prevent duplicate redemptions
    if url.isSuperwallDeepLink {
      if $hasHandledRedemption.testAndSetTrue() {
        return .cancel
      }

      _ = Superwall.shared.dependencyContainer.deepLinkRouter.route(url: url)
      return .cancel
    }

    // Allow all other navigation types for payment flows and SSO authentication
    return .allow
  }
}
#endif
