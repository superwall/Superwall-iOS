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
	func eventDidOccur(paywallViewController: SWPaywallViewController, result: PaywallPresentationResult)
}





internal class SWPaywallViewController: UIViewController {
	
	
	
	
	
	
	// ----------------
	// MARK: Properties
	// ----------------
	
	
	
	
	
	internal weak var delegate: SWPaywallViewControllerDelegate? = nil
	internal typealias DismissalCompletionBlock = (Bool, String?, PaywallInfo?) -> ()
	internal var dismissalCompletion: DismissalCompletionBlock? = nil
	internal var isPresented: Bool = false
	internal var calledDismiss = false
    internal var _paywallResponse: PaywallResponse? = nil
	internal var fromEventData: EventData? = nil
	internal var calledByIdentifier: Bool = false
	internal var readyForEventTracking = false
	internal var showRefreshTimer: Timer? = nil
	internal var isSafariVCPresented: Bool = false
	
	internal var isActive: Bool {
		return isPresented || isBeingPresented
	}
	
//	override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
//		
//		print("swipe bottom")
//
//		return .bottom
//	}
	
	// Views
	
	lazy var shimmerView = ShimmeringView(frame: self.view.bounds)
	
	lazy var webview: WKWebView = {
		wkConfig.userContentController.add(LeakAvoider(delegate:self), name: "paywallMessageHandler")
		
		let wv = WKWebView(frame: CGRect(), configuration: wkConfig)
		wv.translatesAutoresizingMaskIntoConstraints = false
		wv.allowsBackForwardNavigationGestures = true
		wv.allowsLinkPreview = false
		wv.backgroundColor = .clear
		wv.scrollView.maximumZoomScale = 1.0
		wv.scrollView.minimumZoomScale = 1.0
		wv.isOpaque = false
		
        if #available(iOS 11.0, *) {
            wv.scrollView.contentInsetAdjustmentBehavior = .never
        }
		
		wv.scrollView.bounces = true
		wv.scrollView.contentInset = .init(top: 0, left: 0, bottom: 0, right: 0)
		wv.scrollView.scrollIndicatorInsets = .zero
		wv.scrollView.showsVerticalScrollIndicator = false
		wv.scrollView.showsHorizontalScrollIndicator = false
		wv.scrollView.maximumZoomScale = 1.0
		wv.scrollView.minimumZoomScale = 1.0
		wv.scrollView.backgroundColor = .clear
		wv.scrollView.isOpaque = false

	   return wv
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
		return _paywallResponse?.getPaywallInfo(fromEvent: fromEventData, calledByIdentifier: calledByIdentifier, includeExperiment: true)
	}
    
    var presentationStyle: PaywallPresentationStyle {
        return _paywallResponse?.presentationStyle ?? .sheet
    }
    
    private var purchaseLoadingIndicatorContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        v.clipsToBounds = false
        return v
    }()
    
    private var purchaseLoadingIndicator: UIActivityIndicatorView = {
        let av = UIActivityIndicatorView()
        av.translatesAutoresizingMaskIntoConstraints = false
        av.style = .whiteLarge
        av.hidesWhenStopped = false
        av.alpha = 0.0
        av.startAnimating()
        return av
    }()
    
    internal enum LoadingState {
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
		button.setImage(UIImage(named: "reload_paywall", in: Bundle.module, compatibleWith: nil)!, for: .normal)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: #selector(pressedRefreshPaywall), for: .primaryActionTriggered)
		button.isHidden = true
		return button
	}()
	
	lazy var exitButton: UIButton = {
		let button = UIButton()
		button.setImage(UIImage(named: "exit_paywall", in: Bundle.module, compatibleWith: nil)!, for: .normal)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: #selector(pressedExitPaywall), for: .primaryActionTriggered)
		button.isHidden = true
		return button
	}()
	
	var contentPlaceholderImageView: UIImageView = {
		let imageView = UIImageView(image: UIImage(named: "paywall_placeholder", in: Bundle.module, compatibleWith: nil)!)
		imageView.contentMode = .scaleAspectFit
		imageView.tintColor = .white
		imageView.backgroundColor = .clear
		imageView.clipsToBounds = true
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.isHidden = false
		imageView.alpha = 1.0 - 0.618
		return imageView
	 
	}()

	
	
	

	// ---------------
	// MARK: Functions
	// ---------------
	
	
	init?(paywallResponse: PaywallResponse?, delegate: SWPaywallViewControllerDelegate? = nil) {
		self.delegate = delegate
		super.init(nibName: nil, bundle: nil)
		
		if let pr = paywallResponse {
			set(paywallResponse: pr)
		}
		
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	public override func viewDidLoad() {
		
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
		
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
			exitButton.heightAnchor.constraint(equalToConstant: 55),
		])
 
	}
	
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if isActive && !isSafariVCPresented {
			if #available(iOS 15.0, *) {
				if !DeviceHelper.shared.isMac {
					webview.setAllMediaPlaybackSuspended(false, completionHandler: nil) // ignore-xcode-12
				}
			}
			
			if UIWindow.isLandscape {
				contentPlaceholderImageView.image = UIImage(named: "paywall_placeholder_landscape", in: Bundle.module, compatibleWith: nil)!
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
				
				UIView.animate(withDuration: 0.618, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
					self?.webview.alpha = 0.0
					self?.webview.transform = CGAffineTransform.identity.scaledBy(x: 0.97, y: 0.97)
					self?.purchaseLoadingIndicator.alpha = 1.0
					self?.purchaseLoadingIndicator.transform = .identity
				}, completion: nil)
				
			case .loadingResponse:
				self?.shimmerView.isShimmering = true
				self?.shimmerView.alpha = 0.0
				self?.shimmerView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
				self?.showRefreshButtonAfterTimeout(show: true)
				
				UIView.animate(withDuration: 0.618, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
					self?.webview.alpha = 0.0
					self?.shimmerView.alpha = 1.0
					self?.webview.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)//.scaledBy(x: 0.97, y: 0.97)
					self?.shimmerView.transform = .identity
					self?.purchaseLoadingIndicator.alpha = 0.0
					self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
				}, completion: {  _ in

				})
			case .ready:
				self?.webview.transform = oldValue == .loadingPurchase ? CGAffineTransform.identity.scaledBy(x: 0.97, y: 0.97) : CGAffineTransform.identity.translatedBy(x: 0, y: 10)
				self?.showRefreshButtonAfterTimeout(show: false)
				UIView.animate(withDuration: 1.0, delay: 0.25, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
					self?.webview.alpha = 1.0
					self?.webview.transform = .identity
					self?.shimmerView.alpha = 0.0
					self?.purchaseLoadingIndicator.alpha = 0.0
					self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
				}, completion: { [weak self] _ in
					self?.shimmerView.isShimmering = false
				})
			}
		}
	}
	
	func showRefreshButtonAfterTimeout(show: Bool) {
		showRefreshTimer?.invalidate()
		showRefreshTimer = nil
		
		if show {
			showRefreshTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false, block: { [weak self] t in
				self?.refreshPaywallButton.isHidden = false
				self?.refreshPaywallButton.alpha = 0.0
				self?.exitButton.isHidden = false
				self?.exitButton.alpha = 0.0
				UIView.animate(withDuration: 2.0, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
					self?.refreshPaywallButton.alpha = 1.0
					self?.exitButton.alpha = 1.0
				}, completion: nil)
			})
		} else {
			hideRefreshButton()
			return
		}
	}
	
	func hideRefreshButton() {
		showRefreshTimer?.invalidate()
		showRefreshTimer = nil
		UIView.animate(withDuration: 0.618, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
			self?.refreshPaywallButton.alpha = 0.0
			self?.exitButton.alpha = 0.0
		}, completion: { [weak self] _ in
			self?.refreshPaywallButton.isHidden = true
			self?.exitButton.isHidden = true
		})
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
        self._paywallResponse =  paywallResponse
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.webview.alpha = 0.0
            self.view.backgroundColor = paywallResponse.paywallBackgroundColor
            let loadingColor = paywallResponse.paywallBackgroundColor.readableOverlayColor
            self.purchaseLoadingIndicator.color = loadingColor
			self.refreshPaywallButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
			self.exitButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
            self.contentPlaceholderImageView.tintColor = loadingColor.withAlphaComponent(0.5)
            
            if let urlString = self._paywallResponse?.url {
                if let url = URL(string: urlString) {
					
					if let paywallInfo = self.paywallInfo {
						Paywall.track(.paywallWebviewLoadStart(paywallInfo: paywallInfo))
					}
                    
					self.webview.load(URLRequest(url: url))
					if self._paywallResponse?.webViewLoadStartTime == nil, self._paywallResponse != nil {
						self._paywallResponse?.webViewLoadStartTime = Date()
					}
                    self.loadingState = .loadingResponse
                }
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
    
    internal func complete(_ completionResult: PaywallPresentationResult) {
		self.delegate?.eventDidOccur(paywallViewController: self, result: completionResult)
    }
    
	func presentAlert(title: String? = nil, message: String? = nil, actionTitle: String? = nil, action: (() -> ())? = nil, closeActionTitle: String = "Done") {
        
        if presentedViewController == nil {
            let vc = UIAlertController(title: title, message: message, preferredStyle: .alert)
           
            if let s = actionTitle {
                let ca = UIAlertAction(title: s, style: .default, handler: { a in
                    action?()
                })
                vc.addAction(ca)
            }
            
            let a = UIAlertAction(title: closeActionTitle, style: .cancel, handler: nil)
            vc.addAction(a)
            

            present(vc, animated: true, completion: { [weak self] in
				if let ls = self?.loadingState {
					if ls != .loadingResponse {
						self?.loadingState = .ready
					}
				}
            })
        }
        
    }

    
    @objc func applicationWillResignActive(_ sender: AnyObject? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.loadingState == .loadingPurchase {
                UIView.animate(withDuration: 0.618, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                    if let height = self?.purchaseLoadingIndicatorContainer.frame.size.height {
                        self?.purchaseLoadingIndicatorContainer.transform = CGAffineTransform.identity.translatedBy(x: 0, y: height * 0.5 * -1)
                    }
                }, completion: nil)
            }
        }
    }
    
    @objc func applicationDidBecomeActive(_ sender: AnyObject? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.loadingState == .loadingPurchase {
                UIView.animate(withDuration: 0.618, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                    self?.purchaseLoadingIndicatorContainer.transform = CGAffineTransform.identity
                }, completion: nil)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
}

extension SWPaywallViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		Logger.debug(logLevel: .debug, scope: .paywallViewController, message: "Did Receive Message", info: ["message": message.debugDescription], error: nil)
        
        guard let bodyString = message.body as?  String else {
			Logger.debug(logLevel: .warn, scope: .paywallViewController, message: "Unable to Convert Message to String", info: ["message": message.debugDescription], error: nil)
            return
        }
        
        guard let bodyData = bodyString.data(using: .utf8) else {
			Logger.debug(logLevel: .warn, scope: .paywallViewController, message: "Unable to Convert Message to Data", info: ["message": message.debugDescription], error: nil)
            return
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let wrappedPaywallEvents = try? decoder.decode(WrappedPaywallEvents.self, from: bodyData) else {
			Logger.debug(logLevel: .warn, scope: .paywallViewController, message: "Invalid WrappedPaywallEvent", info: ["message": message.debugDescription], error: nil)
            return
        }
        
		Logger.debug(logLevel: .debug, scope: .paywallViewController, message: "Body Converted", info: ["message": message.debugDescription, "events": wrappedPaywallEvents], error: nil)
        
        let events = wrappedPaywallEvents.payload.events

        events.forEach({ [weak self] in self?.handleEvent(event: $0) })
    }
}

// MARK: Event Handler

extension SWPaywallViewController {
	
	func hapticFeedback() {
		if !Paywall.isGameControllerEnabled {
			UIImpactFeedbackGenerator().impactOccurred()
		}
	}
    
    func handleEvent(event: PaywallEvent) {
		Logger.debug(logLevel: .debug, scope: .paywallViewController, message: "Handle Event", info: ["event": event], error: nil)
        guard let paywallResponse = self._paywallResponse else { return }
    
        switch (event) {
		case .templateParamsAndUserAttributes:
				
			let scriptSrc = """
				window.paywall.accept64('\(paywallResponse.getBase64EventsString(params: fromEventData?.parameters))');
			"""
				
			webview.evaluateJavaScript(scriptSrc) { (result, error) in
				if let error = error {
					Logger.debug(logLevel: .error, scope: .paywallViewController, message: "Error Evaluating JS", info: ["message": scriptSrc], error: error)
				}
			}
			
			Logger.debug(logLevel: .debug, scope: .paywallViewController, message: "Posting Message", info: ["message": scriptSrc], error: nil)
				
        case .onReady:
			if let i = self.paywallInfo {
				
				
				if self._paywallResponse != nil {
					if self._paywallResponse?.webViewLoadCompleteTime == nil {
						self._paywallResponse?.webViewLoadCompleteTime = Date()
					}
				}
			
				
				Paywall.track(.paywallWebviewLoadComplete(paywallInfo: i))
			}

            let scriptSrc = """
                window.paywall.accept64('\(paywallResponse.getBase64EventsString(params: fromEventData?.parameters))');
                window.paywall.accept64('\(paywallResponse.paywalljsEvent)');
            """
            	
			Logger.debug(logLevel: .debug, scope: .paywallViewController, message: "Posting Message", info: ["message": scriptSrc], error: nil)
				
            webview.evaluateJavaScript(scriptSrc) { [weak self] (result, error) in
                if let error = error {
					Logger.debug(logLevel: .error, scope: .paywallViewController, message: "Error Evaluating JS", info: ["message": scriptSrc], error: error)
                }

                self?.loadingState = .ready
                
            }
            
            // block selection
            let selectionString = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none} .w-webflow-badge { display: none !important; }'; "
                                + "var head = document.head || document.getElementsByTagName('head')[0]; "
                                + "var style = document.createElement('style'); style.type = 'text/css'; "
                                + "style.appendChild(document.createTextNode(css)); head.appendChild(style); "
            
             let selectionScript: WKUserScript = WKUserScript(source: selectionString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
             webview.configuration.userContentController.addUserScript(selectionScript)
            
            let preventSelection = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none}'; var head = document.head || document.getElementsByTagName('head')[0]; var style = document.createElement('style'); style.type = 'text/css'; style.appendChild(document.createTextNode(css)); head.appendChild(style);"
            webview.evaluateJavaScript(preventSelection, completionHandler: nil)
            
            let preventZoom: String = "var meta = document.createElement('meta');" + "meta.name = 'viewport';" + "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" + "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
            webview.evaluateJavaScript(preventZoom, completionHandler: nil)
  
        case .close:
			hapticFeedback()
            complete(.closed)
        case .openUrl(let url):
			if self != Paywall.shared.paywallViewController {
				Logger.debug(logLevel: .error, scope: .paywallViewController, message: "Received Event on Hidden Paywall", info: ["self": self, "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription, "event": "openUrl", "url": url], error: nil)
			}
			hapticFeedback()
            complete(.openedURL(url: url))
            let safariVC = SFSafariViewController(url: url)
			self.isSafariVCPresented = true
            present(safariVC, animated: true, completion: nil)
        case .openDeepLink(let url):
			if self != Paywall.shared.paywallViewController {
				Logger.debug(logLevel: .error, scope: .paywallViewController, message: "Received Event on Hidden Paywall", info: ["self": self, "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription, "event": "openDeepLink", "url": url], error: nil)
			}
			hapticFeedback()
            complete(.openedDeepLink(url: url))
            // TODO: Handle deep linking
        case .restore:
			if self != Paywall.shared.paywallViewController {
				Logger.debug(logLevel: .error, scope: .paywallViewController, message: "Received Event on Hidden Paywall", info: ["self": self, "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription, "event": "restore"], error: nil)
			}
			hapticFeedback()
            complete(.initiateRestore)
        case .purchase(product: let productName):
				
			if self != Paywall.shared.paywallViewController {
				Logger.debug(logLevel: .error, scope: .paywallViewController, message: "Received Event on Hidden Paywall", info: ["self": self, "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription, "event": "purchase"], error: nil)
			}
				
				
			hapticFeedback()
            let product = paywallResponse.products.first { (product) -> Bool in
                return product.product == productName
            }
            if product != nil {
                complete(.initiatePurchase(productId: product!.productId))
            }
            break;
            
        case .custom(data: let string):
			if self != Paywall.shared.paywallViewController {
				Logger.debug(logLevel: .error, scope: .paywallViewController, message: "Received Event on Hidden Paywall", info: ["self": self, "Paywall.shared.paywallViewController": Paywall.shared.paywallViewController.debugDescription, "event": "custom", "custom_event": string], error: nil)
			}
            complete(.custom(string: string))
        }
    }
}



class LeakAvoider : NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    
    init(delegate:WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}





// presentation logic

extension SWPaywallViewController {
	
	func present(on presentor: UIViewController, fromEventData: EventData?, calledFromIdentifier: Bool, dismissalBlock: DismissalCompletionBlock?, completion: @escaping (Bool) -> ()) {
		
		if Paywall.shared.isPaywallPresented || presentor is SWPaywallViewController || isBeingPresented {
			completion(false)
			return
		} else {
			prepareForPresentation()
			set(fromEventData: fromEventData, calledFromIdentifier: calledFromIdentifier, dismissalBlock: dismissalBlock)
			presentor.present(self, animated: Paywall.shouldAnimatePaywallPresentation, completion: { [weak self] in
				self?.isPresented = true
				self?.presentationDidFinish()
				completion(true)
			})
		}
		
	}
	
	func dismiss(shouldCallCompletion: Bool = true, didPurchase: Bool, productId: String?, paywallInfo: PaywallInfo?, completion: (() -> Void)?) {
		calledDismiss = true
		Paywall.delegate?.willDismissPaywall?()
		dismiss(animated: Paywall.shouldAnimatePaywallDismissal) { [weak self] in
			self?.didDismiss(shouldCallCompletion: shouldCallCompletion, didPurchase: didPurchase, productId: productId, paywallInfo: paywallInfo, completion: completion)
		}
		
	}
	
	func didDismiss(shouldCallCompletion: Bool = true, didPurchase: Bool, productId: String?, paywallInfo: PaywallInfo?, completion: (() -> Void)?) {
		isPresented = false
		if (Paywall.isGameControllerEnabled && GameControllerManager.shared.delegate == self) {
			GameControllerManager.shared.delegate = nil
		}
		Paywall.delegate?.didDismissPaywall?()
//		loadingState = .ready
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
		
		if (Paywall.isGameControllerEnabled) {
			GameControllerManager.shared.delegate = self
		}
		
		if Paywall.delegate == nil {
			presentAlert(title: "Almost Done...", message: "Set Paywall.delegate to handle purchases, restores and more!", actionTitle: "Docs →", action: {
				if let url = URL(string: "https://docs.superwall.me/docs/configuring-the-sdk-1") {
					UIApplication.shared.open(url, options: [:], completionHandler: nil)
				}
			}, closeActionTitle: "Done")
		}
		
	}
	
}


extension SWPaywallViewController: SFSafariViewControllerDelegate {
	func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
		self.isSafariVCPresented = false
	}
}
