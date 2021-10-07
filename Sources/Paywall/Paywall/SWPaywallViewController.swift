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
    func userDismissedPaywallWhileLoading()
}

internal class SWPaywallViewController: UIViewController {
    
    // Don't touch my private parts.
    
    private var _paywallResponse: PaywallResponse? = nil
    
    public var completion: ((PaywallPresentationResult) -> Void)?
    
    internal var readyForEventTracking = false
    
    weak var delegate: SWPaywallViewControllerDelegate? = nil
    
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
            DispatchQueue.main.async { [weak self] in
                
                guard let loadingState = self?.loadingState else { return }
            
                
                switch loadingState {
                case .unknown:
                    break
                case .loadingPurchase:
                    self?.shimmerView.isShimmering = false
                    self?.shimmerView.alpha = 0.0
                    self?.shimmerView.transform = .identity
//                    self?.purchaseLoadingIndicator.startAnimating()
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
                    
                    UIView.animate(withDuration: 0.618, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                        self?.webview.alpha = 0.0
                        self?.shimmerView.alpha = 1.0
                        self?.webview.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)//.scaledBy(x: 0.97, y: 0.97)
                        self?.shimmerView.transform = .identity
                        self?.purchaseLoadingIndicator.alpha = 0.0
                        self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
                    }, completion: {  _ in
//                        self?.purchaseLoadingIndicator.stopAnimating()
                    })
                case .ready:
                    // delay to prevent flicker
                    self?.webview.transform = oldValue == .loadingPurchase ? CGAffineTransform.identity.scaledBy(x: 0.97, y: 0.97) : CGAffineTransform.identity.translatedBy(x: 0, y: 10)
                    
                    UIView.animate(withDuration: 1.0, delay: 0.25, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                        self?.webview.alpha = 1.0
                        self?.webview.transform = .identity
                        self?.shimmerView.alpha = 0.0
                        self?.purchaseLoadingIndicator.alpha = 0.0
                        self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
                    }, completion: { [weak self] _ in
                        self?.shimmerView.isShimmering = false
//                        self?.purchaseLoadingIndicator.stopAnimating()
                    })
                    
                }
                    
            }
        }
    }
    
    init?(paywallResponse: PaywallResponse?, completion: ((PaywallPresentationResult) -> Void)? = nil) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        
        if let pr = paywallResponse {
            set(paywallResponse: pr)
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
            self.contentPlaceholderImageView.tintColor = loadingColor.withAlphaComponent(0.5)
            
            if let urlString = self._paywallResponse?.url {
                if let url = URL(string: urlString) {
                    Paywall.track(.paywallWebviewLoadStart(paywallId: paywallResponse.id ?? ""))
                    self.webview.load(URLRequest(url: url))
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
    
    // Views
    
    var wkConfig: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
		
		let preferences = WKPreferences()
		if #available(iOS 15.0, *) {
			preferences.isTextInteractionEnabled = false
		}
		preferences.javaScriptCanOpenWindowsAutomatically = true
		
		config.preferences = preferences
		
        return config
    }()
    
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
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.bounces = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
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
    
    lazy var shimmerView = ShimmeringView(frame: self.view.bounds)
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // UIViewController
    
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
        ])
 
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		if #available(iOS 15.0, *) {
			webview.setAllMediaPlaybackSuspended(false, completionHandler: nil)
		}
		
		if UIWindow.isLandscape {
			contentPlaceholderImageView.image = UIImage(named: "paywall_placeholder_landscape", in: Bundle.module, compatibleWith: nil)!
		}
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if readyForEventTracking {
            Paywall.track(.paywallClose(paywallId: _paywallResponse?.id ?? ""))
        }
		if #available(iOS 15.0, *) {
			webview.setAllMediaPlaybackSuspended(true, completionHandler: nil)
		}
    }
    
    // WebPaywallViewController
    
    internal func complete(_ completionResult: PaywallPresentationResult) {
        completion?(completionResult)
        
        if completion == nil {
            Logger.superwallDebug(string: "[Internal] Warning: Completion not set")
        }
        
    }
    
    func presentAlert(title: String? = nil, message: String? = nil, actionTitle: String? = nil, action: (() -> ())? = nil) {
        
        if presentedViewController == nil {
            let vc = UIAlertController(title: title, message: message, preferredStyle: .alert)
           
            if let s = actionTitle {
                let ca = UIAlertAction(title: s, style: .default, handler: { a in
                    action?()
                })
                vc.addAction(ca)
            }
            
            let a = UIAlertAction(title: "Done", style: .cancel, handler: nil)
            vc.addAction(a)
            

            present(vc, animated: true, completion: { [weak self] in
                self?.loadingState = .ready
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
//                        self?.purchaseLoadingIndicatorContainer.alpha = 0.5
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
//                    self?.purchaseLoadingIndicatorContainer.alpha = 1.0
                    self?.purchaseLoadingIndicatorContainer.transform = CGAffineTransform.identity
                }, completion: nil)
            }
        }
        
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
		if (Paywall.isGameControllerEnabled && GameControllerManager.shared.delegate == self) {
			GameControllerManager.shared.delegate = nil
		}
    }
    
}

extension SWPaywallViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Logger.superwallDebug(string: "userContentController - start")
        
        guard let bodyString = message.body as?  String else {
            Logger.superwallDebug("unable to convert WKScriptMessage.body to string")
            return
        }
        
        Logger.superwallDebug("body string", bodyString)
        
        guard let bodyData = bodyString.data(using: .utf8) else {
            Logger.superwallDebug(string: "unable to convert bodyString to body data")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let wrappedPaywallEvents = try? decoder.decode(WrappedPaywallEvents.self, from: bodyData) else {
            Logger.superwallDebug(string: "failed to parse bodyString to WrappedPaywallEvent")
            return
        }
        
        Logger.superwallDebug("body struct", wrappedPaywallEvents)
        
        let events = wrappedPaywallEvents.payload.events

        events.forEach({ [weak self] in self?.handleEvent(event: $0) })
        
        Logger.superwallDebug(string: "userContentController - end")
    }
}

// MARK: Event Handler

extension SWPaywallViewController {
    
    func handleEvent(event: PaywallEvent) {
        Logger.superwallDebug("handleEvent", event)
        
        guard let paywallResponse = self._paywallResponse else { return }
    
        switch (event) {
        case .onReady:
            
            Paywall.track(.paywallWebviewLoadComplete(paywallId: self._paywallResponse?.id ?? ""))

            // TODO: Jake, I couldn't figure out how to encode these as an array, ideally we would have
            // [TemplateSubstitutions,TemplateVariables] and only call accept64 once.
            let scriptSrc = """
                window.paywall.accept64('\(paywallResponse.templateEventsBase64String)');
                window.paywall.accept64('\(paywallResponse.paywalljsEvent)');
            """
            
            print("sriptSrc", scriptSrc)
            webview.evaluateJavaScript(scriptSrc) { [weak self] (result, error) in
                if let result = result {
                    print("Label is updated with message: \(result)")
                } else if let error = error {
                    print("An error occurred: \(error)")
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
            UIImpactFeedbackGenerator().impactOccurred()
            complete(.closed)
        case .openUrl(let url):
            UIImpactFeedbackGenerator().impactOccurred()
            complete(.openedURL(url: url))
            let safariVC = SFSafariViewController(url: url)
            present(safariVC, animated: true, completion: nil)
        case .openDeepLink(let url):
            UIImpactFeedbackGenerator().impactOccurred()
            complete(.openedDeepLink(url: url))
            // TODO: Handle deep linking

        case .restore:
            UIImpactFeedbackGenerator().impactOccurred()
            complete(.initiateRestore)
        case .purchase(product: let productName):
            let product = paywallResponse.products.first { (product) -> Bool in
                return product.product == productName
            }
            if product != nil {
                complete(.initiatePurchase(productId: product!.productId))
            }
            break;
            
        case .custom(data: let string):
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



extension SWPaywallViewController: GameControllerDelegate {
	func connectionStatusDidChange(isConnected: Bool) {
		Logger.superwallDebug("Game Controller \(isConnected ? "Connected" : "Disconnected")")
	}
	
	func gameControllerEventDidOccur(event: GameControllerEvent) {
		if let payload = event.jsonString {
			let script = "window.paywall.accept('\(payload)')"
			webview.evaluateJavaScript(script, completionHandler: nil)
			Logger.superwallDebug("Game Controller Event", payload)
		}
	}
	
}
