//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//

import WebKit
import UIKit
import Foundation
import SafariServices

protocol SWPaywallViewControllerDelegate: AnyObject {
	func eventDidOccur(
    paywallViewController: SWPaywallViewController,
    result: PaywallPresentationResult
  )
}

// swiftlint:disable:next type_body_length
final class SWPaywallViewController: UIViewController {
  // MARK: - Properties
	weak var delegate: SWPaywallViewControllerDelegate?
	typealias DismissalCompletionBlock = (Bool, String?, PaywallInfo?) -> Void
	var dismissalCompletion: DismissalCompletionBlock?
	var isPresented = false
	var calledDismiss = false
  var paywallResponse: PaywallResponse?
	var fromEventData: EventData?
  var calledByIdentifier = false
	var readyForEventTracking = false
	var showRefreshTimer: Timer?
	var isSafariVCPresented = false

	var isActive: Bool {
		return isPresented || isBeingPresented
	}

  // Views
	lazy var shimmerView = ShimmeringView(frame: self.view.bounds)

	lazy var webview: WKWebView = {
		wkConfig.userContentController.add(
      LeakAvoider(delegate: self),
      name: "paywallMessageHandler"
    )

		let webView = WKWebView(
      frame: CGRect(),
      configuration: wkConfig
    )
		webView.translatesAutoresizingMaskIntoConstraints = false
		webView.allowsBackForwardNavigationGestures = true
		webView.allowsLinkPreview = false
		webView.backgroundColor = .clear
		webView.scrollView.maximumZoomScale = 1.0
		webView.scrollView.minimumZoomScale = 1.0
		webView.isOpaque = false

    if #available(iOS 11.0, *) {
      webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

		webView.scrollView.bounces = true
		webView.scrollView.contentInset = .init(top: 0, left: 0, bottom: 0, right: 0)
		webView.scrollView.scrollIndicatorInsets = .zero
		webView.scrollView.showsVerticalScrollIndicator = false
		webView.scrollView.showsHorizontalScrollIndicator = false
		webView.scrollView.maximumZoomScale = 1.0
		webView.scrollView.minimumZoomScale = 1.0
		webView.scrollView.backgroundColor = .clear
		webView.scrollView.isOpaque = false
    return webView
	}()

	var wkConfig: WKWebViewConfiguration = {
		let config = WKWebViewConfiguration()
		config.allowsInlineMediaPlayback = true
		config.allowsAirPlayForMediaPlayback = true
		config.allowsPictureInPictureMediaPlayback = true
		config.mediaTypesRequiringUserActionForPlayback = []

		let preferences = WKPreferences()
		if #available(iOS 15.0, *) {
			if !DeviceHelper.shared.isMac {
				preferences.isTextInteractionEnabled = false // ignore-xcode-12
			}
		}
		preferences.javaScriptCanOpenWindowsAutomatically = true
		config.preferences = preferences
		return config
	}()

	var paywallInfo: PaywallInfo? {
		return paywallResponse?.getPaywallInfo(
      fromEvent: fromEventData,
      calledByIdentifier: calledByIdentifier,
      includeExperiment: true
    )
	}

  var presentationStyle: PaywallPresentationStyle {
    return paywallResponse?.presentationStyle ?? .sheet
  }

  private var purchaseLoadingIndicatorContainer: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isUserInteractionEnabled = false
    view.clipsToBounds = false
    return view
  }()

  private var purchaseLoadingIndicator: UIActivityIndicatorView = {
    let spinner = UIActivityIndicatorView()
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.style = .whiteLarge
    spinner.hidesWhenStopped = false
    spinner.alpha = 0.0
    spinner.startAnimating()
    return spinner
  }()

  enum LoadingState {
    case unknown
    case loadingPurchase
    case loadingResponse
    case ready
  }

  var loadingState: LoadingState  = .unknown {
    didSet {
      self.loadingStateDidChange(oldValue: oldValue)
    }
  }

	lazy var refreshPaywallButton: UIButton = {
		let button = UIButton()
    // swiftlint:disable:next force_unwrapping
    let reloadImage = UIImage(named: "reload_paywall", in: Bundle.module, compatibleWith: nil)!
		button.setImage(reloadImage, for: .normal)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: #selector(pressedRefreshPaywall), for: .primaryActionTriggered)
		button.isHidden = true
		return button
	}()

	lazy var exitButton: UIButton = {
		let button = UIButton()
    // swiftlint:disable:next force_unwrapping
    let exitImage = UIImage(named: "exit_paywall", in: Bundle.module, compatibleWith: nil)!
		button.setImage(exitImage, for: .normal)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: #selector(pressedExitPaywall), for: .primaryActionTriggered)
		button.isHidden = true
		return button
	}()

	var contentPlaceholderImageView: UIImageView = {
    // swiftlint:disable:next force_unwrapping
    let placeholder = UIImage(named: "paywall_placeholder", in: Bundle.module, compatibleWith: nil)!
		let imageView = UIImageView(image: placeholder)
		imageView.contentMode = .scaleAspectFit
		imageView.tintColor = .white
		imageView.backgroundColor = .clear
		imageView.clipsToBounds = true
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.isHidden = false
		imageView.alpha = 1.0 - 0.618
		return imageView
	}()


	// MARK: - Functions

	init?(paywallResponse: PaywallResponse?, delegate: SWPaywallViewControllerDelegate? = nil) {
		self.delegate = delegate
		super.init(nibName: nil, bundle: nil)

		if let paywallResponse = paywallResponse {
			set(paywallResponse: paywallResponse)
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  override func viewDidLoad() {
    super.viewDidLoad()

		NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive(_:)),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
		NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive(_:)),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

		shimmerView.isShimmering = true
		view.addSubview(shimmerView)
		view.addSubview(purchaseLoadingIndicatorContainer)
		purchaseLoadingIndicatorContainer.addSubview(purchaseLoadingIndicator)
		view.addSubview(webview)
		shimmerView.translatesAutoresizingMaskIntoConstraints = false
		shimmerView.contentView = contentPlaceholderImageView

		view.addSubview(refreshPaywallButton)
		view.addSubview(exitButton)

		NSLayoutConstraint.activate([
			purchaseLoadingIndicatorContainer.topAnchor.constraint(equalTo: view.topAnchor),
			purchaseLoadingIndicatorContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			purchaseLoadingIndicatorContainer.widthAnchor.constraint(equalTo: view.widthAnchor),
			purchaseLoadingIndicatorContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),

			purchaseLoadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			purchaseLoadingIndicator.centerYAnchor.constraint(equalTo: purchaseLoadingIndicatorContainer.bottomAnchor),

			shimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			shimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			shimmerView.topAnchor.constraint(equalTo: view.topAnchor),
			shimmerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

			webview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			webview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			webview.topAnchor.constraint(equalTo: view.topAnchor),
			webview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),

			refreshPaywallButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 17),
			refreshPaywallButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: 0),
			refreshPaywallButton.widthAnchor.constraint(equalToConstant: 55),
			refreshPaywallButton.heightAnchor.constraint(equalToConstant: 55),

			exitButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 17),
			exitButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 0),
			exitButton.widthAnchor.constraint(equalToConstant: 55),
			exitButton.heightAnchor.constraint(equalToConstant: 55)
		])
	}

  override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if isActive && !isSafariVCPresented {
			if #available(iOS 15.0, *) {
				if !DeviceHelper.shared.isMac {
					webview.setAllMediaPlaybackSuspended(false, completionHandler: nil) // ignore-xcode-12
				}
			}

			if UIWindow.isLandscape {
        // swiftlint:disable:next force_unwrapping
        let placeholder = UIImage(named: "paywall_placeholder_landscape", in: Bundle.module, compatibleWith: nil)!
				contentPlaceholderImageView.image = placeholder
			}

			// if the loading state is ready, re template user attributes
			if self.loadingState == .ready {
				handleEvent(event: .templateParamsAndUserAttributes)
			}
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if isPresented && !isSafariVCPresented {
			if !calledDismiss {
				Paywall.delegate?.willDismissPaywall?()
			}
		}
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		if isPresented && !isSafariVCPresented {
			if readyForEventTracking {
				trackClose()
			}
			if #available(iOS 15.0, *) {
				if !DeviceHelper.shared.isMac {
					webview.setAllMediaPlaybackSuspended(true, completionHandler: nil) // ignore-xcode-12
				}
			}

			if !calledDismiss {
				didDismiss(didPurchase: false, productId: nil, paywallInfo: paywallInfo, completion: nil)
			}

			calledDismiss = false
		}
	}

	func loadingStateDidChange(oldValue: LoadingState) {
		DispatchQueue.main.async { [weak self] in
			guard let loadingState = self?.loadingState else { return }

			switch loadingState {
			case .unknown:
				break
			case .loadingPurchase:
				self?.shimmerView.isShimmering = false
				self?.showRefreshButtonAfterTimeout(show: true)
				self?.shimmerView.alpha = 0.0
				self?.shimmerView.transform = .identity
				self?.purchaseLoadingIndicator.alpha = 0.0
				self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)

				UIView.animate(
          withDuration: 0.618,
          delay: 0.0,
          usingSpringWithDamping: 0.8,
          initialSpringVelocity: 1.2,
          options: [.allowUserInteraction, .curveEaseInOut]
        ) { [weak self] in
					self?.webview.alpha = 0.0
					self?.webview.transform = CGAffineTransform.identity.scaledBy(x: 0.97, y: 0.97)
					self?.purchaseLoadingIndicator.alpha = 1.0
					self?.purchaseLoadingIndicator.transform = .identity
				}
			case .loadingResponse:
				self?.shimmerView.isShimmering = true
				self?.shimmerView.alpha = 0.0
				self?.shimmerView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
				self?.showRefreshButtonAfterTimeout(show: true)

				UIView.animate(
          withDuration: 0.618,
          delay: 0.0,
          usingSpringWithDamping: 0.8,
          initialSpringVelocity: 1.2,
          options: [.allowUserInteraction, .curveEaseInOut]
        ) { [weak self] in
					self?.webview.alpha = 0.0
					self?.shimmerView.alpha = 1.0
					self?.webview.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)// .scaledBy(x: 0.97, y: 0.97)
					self?.shimmerView.transform = .identity
					self?.purchaseLoadingIndicator.alpha = 0.0
					self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
				}
			case .ready:
        let translation = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
        let scaling = CGAffineTransform.identity.scaledBy(x: 0.97, y: 0.97)
				self?.webview.transform = oldValue == .loadingPurchase ? scaling : translation
				self?.showRefreshButtonAfterTimeout(show: false)
				UIView.animate(
          withDuration: 1.0,
          delay: 0.25,
          usingSpringWithDamping: 0.8,
          initialSpringVelocity: 1.2,
          options: [.allowUserInteraction, .curveEaseInOut],
          animations: {  [weak self] in
            self?.webview.alpha = 1.0
            self?.webview.transform = .identity
            self?.shimmerView.alpha = 0.0
            self?.purchaseLoadingIndicator.alpha = 0.0
            self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
          },
          completion: { [weak self] _ in
            self?.shimmerView.isShimmering = false
          }
        )
			}
		}
	}

	func showRefreshButtonAfterTimeout(show: Bool) {
		showRefreshTimer?.invalidate()
		showRefreshTimer = nil

		if show {
      showRefreshTimer = Timer.scheduledTimer(
        withTimeInterval: 4.0,
        repeats: false
      ) { [weak self] _ in
        self?.refreshPaywallButton.isHidden = false
        self?.refreshPaywallButton.alpha = 0.0
        self?.exitButton.isHidden = false
        self?.exitButton.alpha = 0.0
        UIView.animate(
          withDuration: 2.0,
          delay: 0.0,
          usingSpringWithDamping: 0.8,
          initialSpringVelocity: 1.2,
          options: [.allowUserInteraction, .curveEaseInOut]
        ) { [weak self] in
          self?.refreshPaywallButton.alpha = 1.0
          self?.exitButton.alpha = 1.0
        }
      }
		} else {
			hideRefreshButton()
			return
		}
	}

	func hideRefreshButton() {
		showRefreshTimer?.invalidate()
		showRefreshTimer = nil
		UIView.animate(
      withDuration: 0.618,
      delay: 0.0,
      usingSpringWithDamping: 0.8,
      initialSpringVelocity: 1.2,
      options: [.allowUserInteraction, .curveEaseInOut],
      animations: {  [weak self] in
        self?.refreshPaywallButton.alpha = 0.0
        self?.exitButton.alpha = 0.0
      },
      completion: { [weak self] _ in
        self?.refreshPaywallButton.isHidden = true
        self?.exitButton.isHidden = true
      }
    )
	}

	@objc func pressedRefreshPaywall() {
		dismiss(shouldCallCompletion: false, didPurchase: false, productId: nil, paywallInfo: nil) {
			Paywall.presentAgain()
		}
	}

	@objc func pressedExitPaywall() {
		dismiss(shouldCallCompletion: true, didPurchase: false, productId: nil, paywallInfo: nil) {
			PaywallManager.shared.removePaywall(viewController: self)
		}
	}

	func set(paywallResponse: PaywallResponse) {
    self.paywallResponse = paywallResponse

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }

      self.webview.alpha = 0.0
      self.view.backgroundColor = paywallResponse.paywallBackgroundColor
      let loadingColor = paywallResponse.paywallBackgroundColor.readableOverlayColor
      self.purchaseLoadingIndicator.color = loadingColor
      self.refreshPaywallButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
      self.exitButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
      self.contentPlaceholderImageView.tintColor = loadingColor.withAlphaComponent(0.5)

      if let urlString = self.paywallResponse?.url,
        let url = URL(string: urlString) {
        if let paywallInfo = self.paywallInfo {
          Paywall.track(.paywallWebviewLoadStart(paywallInfo: paywallInfo))
        }

        self.webview.load(URLRequest(url: url))
        if self.paywallResponse?.webViewLoadStartTime == nil, self.paywallResponse != nil {
          self.paywallResponse?.webViewLoadStartTime = Date()
        }
        self.loadingState = .loadingResponse
      }
    }

    switch presentationStyle {
    case .sheet:
      modalPresentationStyle = .formSheet
    case .modal:
      modalPresentationStyle = .formSheet
    case .fullscreen:
      modalPresentationStyle = .overFullScreen
    }
  }

	func set(fromEventData: EventData?, calledFromIdentifier: Bool, dismissalBlock: DismissalCompletionBlock?) {
		self.fromEventData = fromEventData
		self.calledByIdentifier = calledFromIdentifier
		self.dismissalCompletion = dismissalBlock
	}

	func trackOpen() {
		if let i = paywallInfo {
			Paywall.track(.paywallOpen(paywallInfo: i))
		}
	}

	func trackClose() {
		if let i = paywallInfo {
			Paywall.track(.paywallClose(paywallInfo: i))
		}
	}

  func complete(_ completionResult: PaywallPresentationResult) {
    self.delegate?.eventDidOccur(paywallViewController: self, result: completionResult)
  }

	func presentAlert(
    title: String? = nil,
    message: String? = nil,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil,
    closeActionTitle: String = "Done"
  ) {
    if presentedViewController == nil {
      let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

      if let actionTitle = actionTitle {
        let alertAction = UIAlertAction(title: actionTitle, style: .default) { _ in
          action?()
        }
        alertController.addAction(alertAction)
      }

      let action = UIAlertAction(title: closeActionTitle, style: .cancel, handler: nil)
      alertController.addAction(action)

      present(alertController, animated: true) { [weak self] in
        if let loadingState = self?.loadingState,
          loadingState != .loadingResponse {
          self?.loadingState = .ready
        }
      }
    }
  }

  @objc func applicationWillResignActive(_ sender: AnyObject? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.loadingState == .loadingPurchase {
        UIView.animate(
          withDuration: 0.618,
          delay: 0,
          usingSpringWithDamping: 0.8,
          initialSpringVelocity: 1.2,
          options: [.allowUserInteraction, .curveEaseInOut]
        ) { [weak self] in
          if let height = self?.purchaseLoadingIndicatorContainer.frame.size.height {
            let transform = CGAffineTransform.identity.translatedBy(x: 0, y: height * 0.5 * -1)
            self?.purchaseLoadingIndicatorContainer.transform = transform
          }
        }
      }
    }
  }

  @objc func applicationDidBecomeActive(_ sender: AnyObject? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.loadingState == .loadingPurchase {
        UIView.animate(
          withDuration: 0.618,
          delay: 0,
          usingSpringWithDamping: 0.8,
          initialSpringVelocity: 1.2,
          options: [.allowUserInteraction, .curveEaseInOut]
        ) { [weak self] in
          self?.purchaseLoadingIndicatorContainer.transform = CGAffineTransform.identity
        }
      }
    }
  }
}

extension SWPaywallViewController: WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Did Receive Message",
      info: ["message": message.debugDescription],
      error: nil
    )

    guard let bodyString = message.body as? String else {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Unable to Convert Message to String",
        info: ["message": message.debugDescription],
        error: nil
      )
      return
    }

    guard let bodyData = bodyString.data(using: .utf8) else {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Unable to Convert Message to Data",
        info: ["message": message.debugDescription],
        error: nil
      )
      return
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    guard let wrappedPaywallEvents = try? decoder.decode(WrappedPaywallEvents.self, from: bodyData) else {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Invalid WrappedPaywallEvent",
        info: ["message": message.debugDescription],
        error: nil
      )
      return
    }

    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Body Converted",
      info: ["message": message.debugDescription, "events": wrappedPaywallEvents],
      error: nil
    )

    let events = wrappedPaywallEvents.payload.events

    events.forEach { [weak self] in
      self?.handleEvent(event: $0)
    }
  }
}

// MARK: Event Handler

extension SWPaywallViewController {
	func hapticFeedback() {
		if !Paywall.isGameControllerEnabled {
			UIImpactFeedbackGenerator().impactOccurred()
		}
	}

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  func handleEvent(event: PaywallEvent) {
		Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Handle Event",
      info: ["event": event],
      error: nil
    )

    guard let paywallResponse = self.paywallResponse else {
      return
    }

    switch event {
    case .templateParamsAndUserAttributes:
      let scriptSrc = """
        window.paywall.accept64('\(paywallResponse.getBase64EventsString(params: fromEventData?.parameters))');
      """
      webview.evaluateJavaScript(scriptSrc) { _, error in
        if let error = error {
          Logger.debug(
            logLevel: .error,
            scope: .paywallViewController,
            message: "Error Evaluating JS",
            info: ["message": scriptSrc],
            error: error
          )
        }
      }

      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Posting Message",
        info: ["message": scriptSrc],
        error: nil
      )
    case .onReady:
      if let i = self.paywallInfo {
        if self.paywallResponse != nil {
          if self.paywallResponse?.webViewLoadCompleteTime == nil {
            self.paywallResponse?.webViewLoadCompleteTime = Date()
          }
        }

        Paywall.track(.paywallWebviewLoadComplete(paywallInfo: i))
      }

      let scriptSrc = """
        window.paywall.accept64('\(paywallResponse.getBase64EventsString(params: fromEventData?.parameters))');
        window.paywall.accept64('\(paywallResponse.paywalljsEvent)');
      """

      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Posting Message",
        info: ["message": scriptSrc],
        error: nil
      )

      webview.evaluateJavaScript(scriptSrc) { [weak self] _, error in
        if let error = error {
          Logger.debug(
            logLevel: .error,
            scope: .paywallViewController,
            message: "Error Evaluating JS",
            info: ["message": scriptSrc],
            error: error
          )
        }
        self?.loadingState = .ready
      }

      // block selection
      // swiftlint:disable:next line_length
      let selectionString = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none} .w-webflow-badge { display: none !important; }'; "
        + "var head = document.head || document.getElementsByTagName('head')[0]; "
        + "var style = document.createElement('style'); style.type = 'text/css'; "
        + "style.appendChild(document.createTextNode(css)); head.appendChild(style); "

      let selectionScript = WKUserScript(source: selectionString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      webview.configuration.userContentController.addUserScript(selectionScript)

      // swiftlint:disable:next line_length
      let preventSelection = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none}'; var head = document.head || document.getElementsByTagName('head')[0]; var style = document.createElement('style'); style.type = 'text/css'; style.appendChild(document.createTextNode(css)); head.appendChild(style);"
      webview.evaluateJavaScript(preventSelection, completionHandler: nil)

      // swiftlint:disable:next line_length
      let preventZoom: String = "var meta = document.createElement('meta');" + "meta.name = 'viewport';" + "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" + "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
      webview.evaluateJavaScript(preventZoom, completionHandler: nil)

    case .close:
      hapticFeedback()
      complete(.closed)
    case .openUrl(let url):
      if self != Paywall.shared.paywallViewController {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Received Event on Hidden Paywall",
          info: [
            "self": self,
            "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription,
            "event": "openUrl",
            "url": url
          ],
          error: nil
        )
      }
      hapticFeedback()
      complete(.openedURL(url: url))
      let safariVC = SFSafariViewController(url: url)
      self.isSafariVCPresented = true
      present(safariVC, animated: true)
    case .openDeepLink(let url):
      if self != Paywall.shared.paywallViewController {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Received Event on Hidden Paywall",
          info: [
            "self": self,
            "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription,
            "event": "openDeepLink",
            "url": url
          ],
          error: nil
        )
      }
      hapticFeedback()
      complete(.openedDeepLink(url: url))
      // TODO: Handle deep linking
    case .restore:
      if self != Paywall.shared.paywallViewController {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Received Event on Hidden Paywall",
          info: [
            "self": self,
            "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription,
            "event": "restore"
          ],
          error: nil
        )
      }
      hapticFeedback()
      complete(.initiateRestore)
    case .purchase(product: let productName):
      if self != Paywall.shared.paywallViewController {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Received Event on Hidden Paywall",
          info: [
            "self": self,
            "Paywall.shared.paywallViewController":
              Paywall.shared.paywallViewController.debugDescription,
            "event": "purchase"
          ],
          error: nil
        )
      }

      hapticFeedback()
      let product = paywallResponse.products.first { product -> Bool in
        return product.type == productName
      }
      if let product = product {
        complete(.initiatePurchase(productId: product.id))
      }
    case .custom(data: let string):
      if self != Paywall.shared.paywallViewController {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Received Event on Hidden Paywall",
          info: [
            "self": self,
            "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription,
            "event": "custom",
            "custom_event": string
          ],
          error: nil
        )
      }
      complete(.custom(string: string))
    }
  }
}

final class LeakAvoider: NSObject, WKScriptMessageHandler {
  weak var delegate: WKScriptMessageHandler?

  init(delegate: WKScriptMessageHandler) {
    self.delegate = delegate
    super.init()
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    delegate?.userContentController(userContentController, didReceive: message)
  }
}

// presentation logic
extension SWPaywallViewController {
	func present(
    on presenter: UIViewController,
    fromEventData: EventData?,
    calledFromIdentifier: Bool,
    dismissalBlock: DismissalCompletionBlock?,
    completion: @escaping (Bool) -> Void
  ) {
		if Paywall.shared.isPaywallPresented || presenter is SWPaywallViewController || isBeingPresented {
			completion(false)
			return
		} else {
			prepareForPresentation()
			set(fromEventData: fromEventData, calledFromIdentifier: calledFromIdentifier, dismissalBlock: dismissalBlock)
      presenter.present(
        self,
        animated: Paywall.shouldAnimatePaywallPresentation
      ) { [weak self] in
        self?.isPresented = true
        self?.presentationDidFinish()
        completion(true)
      }
		}
	}

	func dismiss(
    shouldCallCompletion: Bool = true,
    didPurchase: Bool,
    productId: String?,
    paywallInfo: PaywallInfo?,
    completion: (() -> Void)?
  ) {
		calledDismiss = true
		Paywall.delegate?.willDismissPaywall?()
		dismiss(animated: Paywall.shouldAnimatePaywallDismissal) { [weak self] in
			self?.didDismiss(
        shouldCallCompletion: shouldCallCompletion,
        didPurchase: didPurchase,
        productId: productId,
        paywallInfo: paywallInfo,
        completion: completion
      )
		}
	}

	func didDismiss(
    shouldCallCompletion: Bool = true,
    didPurchase: Bool,
    productId: String?,
    paywallInfo: PaywallInfo?,
    completion: (() -> Void)?
  ) {
		isPresented = false
		if Paywall.isGameControllerEnabled && GameControllerManager.shared.delegate == self {
			GameControllerManager.shared.delegate = nil
		}
		Paywall.delegate?.didDismissPaywall?()
    //  loadingState = .ready
		if shouldCallCompletion {
			dismissalCompletion?(didPurchase, productId, paywallInfo)
		}
		completion?()
		Paywall.shared.destroyPresentingWindow()
	}

	func prepareForPresentation() {
		readyForEventTracking = false
		willMove(toParent: nil)
		view.removeFromSuperview()
		removeFromParent()
		view.alpha = 1.0
		view.transform = .identity
		webview.scrollView.contentOffset = CGPoint.zero

		Paywall.delegate?.willPresentPaywall?()
		Paywall.shared.paywallWasPresentedThisSession = true
		Paywall.shared.recentlyPresented = true
	}

	func presentationDidFinish() {
		Paywall.delegate?.didPresentPaywall?()
		readyForEventTracking = true
		trackOpen()

		if Paywall.isGameControllerEnabled {
			GameControllerManager.shared.delegate = self
		}

		if Paywall.delegate == nil {
			presentAlert(
        title: "Almost Done...",
        message: "Set Paywall.delegate to handle purchases, restores and more!",
        actionTitle: "Docs →",
        action: {
          if let url = URL(string: "https://docs.superwall.me/docs/configuring-the-sdk-1") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
          }
        },
        closeActionTitle: "Done"
      )
		}
	}
}

// MARK: - SFSafariViewControllerDelegate
extension SWPaywallViewController: SFSafariViewControllerDelegate {
	func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
		self.isSafariVCPresented = false
	}
}

// MARK: - GameControllerDelegate
extension SWPaywallViewController: GameControllerDelegate {
  func connectionStatusDidChange(isConnected: Bool) {
    Logger.debug(
      logLevel: .debug,
      scope: .gameControllerManager,
      message: "Status Changed",
      info: ["connected": isConnected],
      error: nil
    )
  }

  func gameControllerEventDidOccur(event: GameControllerEvent) {
    if let payload = event.jsonString {
      let script = "window.paywall.accept([\(payload)])"
      webview.evaluateJavaScript(script, completionHandler: nil)
      Logger.debug(
        logLevel: .debug,
        scope: .gameControllerManager,
        message: "Received Event",
        info: ["payload": payload],
        error: nil
      )
    }
  }
  // swiftlint:disable:next file_length
}
