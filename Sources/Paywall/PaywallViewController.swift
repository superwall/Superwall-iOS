//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//

import WebKit
import UIKit
import Foundation

internal class PaywallViewController: UIViewController {
    
    // Don't touch my private parts.
    
    private var _paywallResponse: PaywallResponse
//    private var _complete = false
    
    public var completion: ((PaywallPresentationResult) -> Void)?
    
    init?(paywallResponse: PaywallResponse, completion: ((PaywallPresentationResult) -> Void)? = nil) {
        self._paywallResponse =  paywallResponse
        self.completion = completion
        
        super.init(nibName: nil, bundle: nil)
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            
            let url = URL(string: self._paywallResponse.url)
            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
            self.webview.load(URLRequest(url: url!))
            self.webview.alpha = 0.0
//            })
            
            
            self.view.backgroundColor = UIColor(hexString: "#181A1F")
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
        imageView.alpha = 0.2
             
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
        view.addSubview(self.webview)
        shimmerView.translatesAutoresizingMaskIntoConstraints = false
        shimmerView.contentView = contentPlaceholderImageView
    
        NSLayoutConstraint.activate([
            
            shimmerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            shimmerView.topAnchor.constraint(equalTo: self.view.topAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
//            self.contentPlaceholderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
//            self.contentPlaceholderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
//            self.contentPlaceholderImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
//            self.contentPlaceholderImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            self.webview.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webview.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.webview.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0),
            self.webview.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0),
        ])
 
    }

    public override func viewWillAppear(_ animated: Bool) {

    }
    
    // WebPaywallViewController
    
    internal func complete(_ completionResult: PaywallPresentationResult) {
        completion?(completionResult)
        
        if completion == nil {
            log("[Internal] warning: Completion not set")
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

        guard let wrappedPaywallEvents = try? JSONDecoder().decode(WrappedPaywallEvents.self, from: bodyData) else {
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

// MARK: Event Handler

extension PaywallViewController {
    
    func handleEvent(event: PaywallEvent) {
        log("handleEvent", event)
    
//        if event == .ping {
//
//        }
//
        switch (event) {
        case .ping:
        
            let subs = self._paywallResponse.substitutions.reduce([String: String]()) { (dict, sub) -> [String: String] in
                var dict = dict
                dict[sub.key] = sub.value
                return dict
            }
            let subsEvent = TemplateSubstitutions(event_name: "template_substitutions", substitutions: subs)
            let eventData = try? JSONEncoder().encode(subsEvent)
            let eventString = eventData != nil ? String(data: eventData!, encoding: .utf8) ?? "{}" : "{}"
            let scriptSrc = """
                window.paywall.accept(JSON.parse('\(eventString)'))
            """
            print("sriptSrc", scriptSrc)
            self.webview.evaluateJavaScript(scriptSrc) { (result, error) in
                if let result = result {
                    print("Label is updated with message: \(result)")
                } else if let error = error {
                    print("An error occurred: \(error)")
                }
//                if #available(iOS 14.0, *) {
//                    self.webview.createPDF { (result) in
//                        print(result)
//                    }
//                } else {
//                    // Fallback on earlier versions
//                }
                
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 1.0, delay: 0.6, usingSpringWithDamping: 0.8, initialSpringVelocity: 1.2, options: [.allowUserInteraction, .curveEaseInOut], animations: {  [weak self] in
                        self?.webview.alpha = 1.0
                        self?.webview.transform = .identity
                        self?.shimmerView.alpha = 0.0
                    }, completion: { [weak self] _ in
                        self?.shimmerView.isShimmering = false
                    })
                }
                
            }
            


        case .close:
            UIImpactFeedbackGenerator().impactOccurred()
            complete(.closed)
        case .openURL(let url):
            UIImpactFeedbackGenerator().impactOccurred()
            complete(.openedURL(url: url))
            UIApplication.shared.open(url, options: [:])
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
