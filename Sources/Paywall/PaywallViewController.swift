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

internal class PaywallViewController: UIViewController {
    
    // Don't touch my private parts.
    
    private var _paywallResponse: PaywallResponse
    public var completion: ((PaywallPresentationResult) -> Void)?
    
    var presentationStyle: PaywallPresentationStyle {
        return _paywallResponse.presentationStyle
    }
    
    init?(paywallResponse: PaywallResponse, completion: ((PaywallPresentationResult) -> Void)? = nil) {
        self._paywallResponse =  paywallResponse
        self.completion = completion
        
        super.init(nibName: nil, bundle: nil)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let url = URL(string: self._paywallResponse.url)
            self.webview.load(URLRequest(url: url!))
            self.webview.alpha = 0.0
            self.view.backgroundColor = paywallResponse.paywallBackgroundColor
        }
        
        switch presentationStyle {
        case .sheet:
            break
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
        wv.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 10)//.scaledBy(x: 0.97, y: 0.97)

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
            webview.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 0),
            webview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
        ])
 
    }

    public override func viewWillAppear(_ animated: Bool) {

    }
    
    // WebPaywallViewController
    
    internal func complete(_ completionResult: PaywallPresentationResult) {
        completion?(completionResult)
        
        if completion == nil {
            log("[Internal] Warning: Completion not set")
        }
        
    }
    
}

extension PaywallViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        log("userContentController - start")
        
        guard let bodyString = message.body as?  String else {
            log("unable to convert WKScriptMessage.body to string")
            return
        }
        
        log("body string", bodyString)
        
        guard let bodyData = bodyString.data(using: .utf8) else {
            log("unable to convert bodyString to body data")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let wrappedPaywallEvents = try? decoder.decode(WrappedPaywallEvents.self, from: bodyData) else {
            log("failed to parse bodyString to WrappedPaywallEvent")
            return
        }
        
        log("body struct", wrappedPaywallEvents)
        
        let events = wrappedPaywallEvents.payload.events

        events.forEach({ self.handleEvent(event: $0) })
        
        log("userContentController - end")
    }
}

struct TemplateSubstitutions: Codable {
    var event_name: String
    var substitutions: [String: String]
}

struct TemplateVariables: Codable {
    var event_name: String
    var variables: [String: String]
}

// MARK: Event Handler

extension PaywallViewController {
    
    func handleEvent(event: PaywallEvent) {
        log("handleEvent", event)
    
        switch (event) {
        case .onReady:
        
            let subs = self._paywallResponse.substitutions.reduce([String: String]()) { (dict, sub) -> [String: String] in
                var dict = dict
                dict[sub.key] = sub.value
                return dict
            }
            
            let subsEvent = TemplateSubstitutions(event_name: "template_substitutions", substitutions: subs)
            let subsEventData = try? JSONEncoder().encode(subsEvent)
            let subsEventString = subsEventData != nil ? String(data: subsEventData!, encoding: .utf8) ?? "{}" : "{}"
            
            let varsEvent = TemplateVariables(event_name: "template_variables", variables: ["price": "$89.99"])
            let varsEventData = try? JSONEncoder().encode(varsEvent)
            let varsEventString = varsEventData != nil ? String(data: varsEventData!, encoding: .utf8) ?? "{}" : "{}"
            
            let scriptSrc = """
                window.paywall.accept(JSON.parse('\(subsEventString)'));
                window.paywall.accept(JSON.parse('\(varsEventString)'));
            """
            
            print("sriptSrc", scriptSrc)
            webview.evaluateJavaScript(scriptSrc) { (result, error) in
                if let result = result {
                    print("Label is updated with message: \(result)")
                } else if let error = error {
                    print("An error occurred: \(error)")
                }

                DispatchQueue.main.async {
                    UIView.animate(withDuration: 1.0, delay: 0.6, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                        self?.webview.alpha = 1.0
                        self?.webview.transform = .identity
                        self?.shimmerView.alpha = 0.0
//                        self?.shimmerView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
                    }, completion: { [weak self] _ in
                        self?.shimmerView.isShimmering = false
                    })
                }
                
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
            let alert = UIAlertController.init(title: "Restore", message: "You selected to restore purchase", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "OK",
                    style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            complete(.initiateResotre)
            self.present(alert, animated: true)
        default:
            break
        }
    }
}
