//
//  CheckoutWebViewController.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/09/2025.
//
// swiftlint:disable implicitly_unwrapped_optional

import UIKit
import WebKit

final class CheckoutWebViewController: UIViewController {
  private let webView: WKWebView
  private let url: URL
  var onDismiss: (() -> Void)?

  deinit {
    NotificationCenter.default.removeObserver(self)
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
    if #available(iOS 15.0, *) {
      presentationController?.delegate = self
    }

    // Add keyboard observers to detect when keyboard causes detent changes
    setupKeyboardObservers()
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
      if #available(iOS 16.0, *) {
        guard let sheetController = self?.sheetPresentationController else { return }
        sheetController.invalidateDetents()
      }
      if #available(iOS 15.0, *) {
        self?.updateScrollingForDetent()
      }
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    onDismiss?()
  }

  @available(iOS 15.0, *)
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
}

// MARK: - WKNavigationDelegate
extension CheckoutWebViewController: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction
  ) async -> WKNavigationActionPolicy {
    guard let url = navigationAction.request.url else {
      return .allow
    }

    // Check if this should be opened externally (deep links or universal links)
    if let scheme = url.scheme {
      // Custom schemes (deep links) - always open in app
      if !scheme.hasPrefix("http") && UIApplication.shared.canOpenURL(url) {
        await UIApplication.shared.open(url)
        return .cancel
      }

      // Superwall deep links (universal links) - use existing system
      if url.isSuperwallDeepLink {
        await UIApplication.shared.open(url)
        return .cancel
      }
    }

    // Allow all other navigation types for payment flows and SSO authentication
    return .allow
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // Hide loading indicator if needed
    // Initial scroll state update after page loads
    if #available(iOS 15.0, *) {
      updateScrollingForDetent()
    }
  }
}

// MARK: - UISheetPresentationControllerDelegate
@available(iOS 15.0, *)
extension CheckoutWebViewController: UISheetPresentationControllerDelegate {
  func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
    _ sheetPresentationController: UISheetPresentationController
  ) {
    updateScrollingForDetent()
  }
}
