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

protocol PaywallViewControllerDelegate: AnyObject {
    func userDismissedPaywallWhileLoading()
}

internal class PaywallViewController: UIViewController {
    
    // Don't touch my private parts.
    
    private var _paywallResponse: PaywallResponse? = nil
    
    public var completion: ((PaywallPresentationResult) -> Void)?
    
    weak var delegate: PaywallViewControllerDelegate? = nil
    
    var presentationStyle: PaywallPresentationStyle {
        return _paywallResponse?.presentationStyle ?? .sheet
    }
    
    internal enum LoadingState {
        case unknown
        case loading
        case ready
    }
    
    var loadingState: LoadingState  = .unknown {
        didSet {
            
            
            if loadingState == .loading {
                DispatchQueue.main.async { [weak self] in
                    
                    self?.shimmerView.isShimmering = true
                    self?.shimmerView.alpha = 0.0
                    self?.shimmerView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
                    
                    UIView.animate(withDuration: 0.618, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                        self?.webview.alpha = 0.0
                        self?.shimmerView.alpha = 1.0
                        self?.webview.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)//.scaledBy(x: 0.97, y: 0.97)
                        self?.shimmerView.transform = .identity
                    }, completion: { [weak self] _ in
                        self?.modalPresentationStyle = .formSheet
                    })
                    
                }
                

                
                
            } else if loadingState == .ready {
                DispatchQueue.main.async { [weak self] in
                    // delay to prevent flicker
                    self?.webview.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
                    UIView.animate(withDuration: 1.0, delay: 0.25, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                        self?.webview.alpha = 1.0
                        self?.webview.transform = .identity
                        self?.shimmerView.alpha = 0.0
                    }, completion: { [weak self] _ in
                        self?.shimmerView.isShimmering = false
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
            
            if let urlString = self._paywallResponse?.url {
                if let url = URL(string: urlString) {
                    self.webview.load(URLRequest(url: url))
                    self.loadingState = .loading
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
    
    lazy var webview: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        
        config.userContentController.add(self, name: "paywallMessageHandler")
        
        let wv = WKWebView(frame: CGRect(), configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.allowsBackForwardNavigationGestures = true
        wv.allowsLinkPreview = false
        wv.backgroundColor = .clear
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
        imageView.tintColor = .red
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
       
        shimmerView.isShimmering = true
        view.addSubview(shimmerView)
        view.addSubview(webview)
        shimmerView.translatesAutoresizingMaskIntoConstraints = false
        shimmerView.contentView = contentPlaceholderImageView
    
        NSLayoutConstraint.activate([
            
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
    
}

extension PaywallViewController: WKScriptMessageHandler {
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

        events.forEach({ self.handleEvent(event: $0) })
        
        Logger.superwallDebug(string: "userContentController - end")
    }
}

// MARK: Event Handler

extension PaywallViewController {
    
    func handleEvent(event: PaywallEvent) {
        Logger.superwallDebug("handleEvent", event)
        
        guard let paywallResponse = self._paywallResponse else { return }
    
        switch (event) {
        case .onReady:
            
            

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
        default:
            break
        }
    }
}
