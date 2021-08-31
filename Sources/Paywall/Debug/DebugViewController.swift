//
//  File.swift
//  
//
//  Created by Jake Mor on 8/26/21.
//
import UIKit
import Foundation

internal var PrimaryColor = UIColor(hexString: "#75FFF1")
internal var PrimaryButtonBackgroundColor = UIColor(hexString: "#203133")
internal var SecondaryButtonBackgroundColor = UIColor(hexString: "#44494F")
internal var LightBackgroundColor = UIColor(hexString: "#181A1E")
internal var DarkBackgroundColor = UIColor(hexString: "#0D0F12")

internal struct AlertOption {
    var title: String? = ""
    var action: (() -> ())?
    var style: UIAlertAction.Style = .default
}



internal class DebugViewController: UIViewController {
    
    var logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "superwall_logo", in: Bundle.module, compatibleWith: nil)!)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = false
        return imageView
    }()

    
    lazy var exitButton: BounceButton = {
        let b = BounceButton()
        let image = UIImage(named: "exit", in: Bundle.module, compatibleWith: nil)!
        b.setImage(image, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.imageView?.tintColor = UIColor.white.withAlphaComponent(0.5)
        b.addTarget(self, action: #selector(pressedExitButton), for: .primaryActionTriggered)
        return b
    }()
    
    lazy var bottomButton: BounceButton = {
        let b = BounceButton()
        b.setTitle("Preview", for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        b.backgroundColor = PrimaryButtonBackgroundColor
        b.setTitleColor(PrimaryColor, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!
        b.titleEdgeInsets = UIEdgeInsets(top: -1, left: 0, bottom: 0, right: 0)
//        b.imageEdgeInsets = UIEdgeInsets(top: 1, left: 5, bottom: -1, right: -3)
        b.setImage(image, for: .normal)
        b.imageView?.tintColor = PrimaryColor
        if #available(iOS 13.0, *) {
            b.layer.cornerCurve = .continuous
        }
        b.layer.cornerRadius = 64.0 / 3
        b.addTarget(self, action: #selector(pressedBottomButton), for: .primaryActionTriggered)
        return b
    }()
    
    lazy var previewPickerButton: BounceButton = {
        let b = BounceButton()
        b.setTitle("", for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        b.backgroundColor = LightBackgroundColor
        b.setTitleColor(PrimaryColor, for: .normal)
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.imageView?.tintColor = PrimaryColor
        b.layer.cornerRadius = 10
        let image = UIImage(named: "down_arrow", in: Bundle.module, compatibleWith: nil)!
        b.semanticContentAttribute = .forceRightToLeft
        b.setImage(image, for: .normal)
        b.imageView?.tintColor = PrimaryColor
        b.addTarget(self, action: #selector(pressedPreview), for: .primaryActionTriggered)
        return b
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        view.startAnimating()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.style = .whiteLarge
        view.color = PrimaryColor
        return view
    }()
    
    lazy var previewContainerView: BounceButton = {
        let v = BounceButton()
        v.shouldAnimateLightly = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addTarget(self, action: #selector(pressedPreview), for: .primaryActionTriggered)
        return v
    }()
    
    var paywallId: String? = nil
    var paywallResponse: PaywallResponse? = nil
    var paywallResponses: [PaywallResponse] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(previewContainerView)
        view.addSubview(activityIndicator)
        view.addSubview(logoImageView)
        view.addSubview(exitButton)
        view.addSubview(bottomButton)
        previewContainerView.addSubview(previewPickerButton)
        view.backgroundColor = LightBackgroundColor
        
        previewContainerView.clipsToBounds = false
        
        NSLayoutConstraint.activate([
            
            previewContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainerView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 25),
            previewContainerView.bottomAnchor.constraint(equalTo: bottomButton.topAnchor, constant: -30),
            
            logoImageView.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor, constant: -10),
            logoImageView.heightAnchor.constraint(equalToConstant: 23),
            logoImageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 20),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            exitButton.centerXAnchor.constraint(equalTo: bottomButton.trailingAnchor),
            exitButton.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            
            activityIndicator.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),
            
            bottomButton.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
            bottomButton.heightAnchor.constraint(equalToConstant: 64),
            bottomButton.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor, constant: -40),
            bottomButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -10),
            
            previewPickerButton.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor, constant: 0),
            previewPickerButton.heightAnchor.constraint(equalToConstant: 26),
//            previewPickerButton.widthAnchor.constraint(equalToConstant: 130),
            previewPickerButton.centerYAnchor.constraint(equalTo: previewContainerView.bottomAnchor)
        ])
        
        loadPreview()
        
    }
    
    var previewViewContent: UIView? = nil
    
    func loadPreview() {
        activityIndicator.startAnimating()
        previewViewContent?.removeFromSuperview()
        
//        previewPickerButton.setTitle("", for: .normal)
        
        Network.shared.paywalls { [weak self] result in
            switch(result){
            case .success(let response):
                let paywalls = response.paywalls
                self?.paywallResponses = response.paywalls
                
                let paywallResponse = paywalls.first { p in
                    p.id == self?.paywallId
                }
                
                self?.paywallResponse = paywallResponse
                
                OnMain { [weak self] in
                    self?.previewPickerButton.setTitle("\(paywallResponse?.name ?? "Preview")", for: .normal)
                }
                
                
                
                if let paywallResponse = self?.paywallResponse {
                    StoreKitManager.shared.getVariables(forResponse: paywallResponse) { variables in
                        self?.paywallResponse?.variables = variables
                        OnMain { [weak self] in
                            self?.activityIndicator.stopAnimating()
                            self?.addPaywallPreview()
                        }
                    }
                }
                
  
                
            case .failure(let error):
                Logger.superwallDebug(string: "Debug Mode Error", error: error)
                
            }
            

        }
        
    }
    
    func addPaywallPreview() {
        if let child = PaywallViewController(paywallResponse: paywallResponse, completion: nil) {
            addChild(child)
            previewContainerView.insertSubview(child.view, at: 0)
            previewViewContent = child.view
            child.didMove(toParent: self)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            child.view.isUserInteractionEnabled = false
            NSLayoutConstraint.activate([
                child.view.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0),
                child.view.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1.0),
                child.view.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
                child.view.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),
            ])
            
            child.view.clipsToBounds = true
            child.view.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
            child.view.layer.borderWidth = 1.0
            
            let ratio = CGFloat(Double(previewContainerView.frame.size.height / view.frame.size.height))
            
            child.view.transform = CGAffineTransform.identity.scaledBy(x: ratio, y: ratio)
            
            child.view.layer.cornerRadius = 52
            
            if #available(iOS 13.0, *) {
                child.view.layer.cornerCurve = .continuous
            }
            
        }
    }
    
    @objc func pressedPreview() {
        guard let id = paywallId else { return }
        
        let options: [AlertOption] = paywallResponses.map { response in
            
            var name = response.name ?? ""
            
            if id == response.id ?? "none" {
                name = "\(name) ✓"
            }
         
            let a = AlertOption(title: name, action: { [weak self] in
                self?.paywallId = response.id
                self?.paywallResponse = response
                
                self?.previewViewContent?.removeFromSuperview()
                
                OnMain { [weak self] in
                    self?.activityIndicator.startAnimating()
                    self?.previewPickerButton.setTitle(response.name, for: .normal)
                }
                
                if let paywallResponse = self?.paywallResponse {
                    StoreKitManager.shared.getVariables(forResponse: paywallResponse) { variables in
                        self?.paywallResponse?.variables = variables
                        OnMain { [weak self] in
                            self?.activityIndicator.stopAnimating()
                            self?.addPaywallPreview()
                        }
                    }
                }
                
            }, style: .default)
            
            return a
        }
        
        presentAlert(title: nil, message: "Your Paywalls", options: options)

    }
    
    @objc func pressedExitButton() {
        
        presentingViewController?.dismiss(animated: true, completion: nil)
        

    }
    
    @objc func pressedBottomButton() {
        
        presentAlert(title: nil, message: "Which version?", options: [
            AlertOption(title: "With Free Trial", action: { [weak self] in
                self?.loadAndShowPaywall(freeTrialAvailable: true)
            
        }, style: .default),
            AlertOption(title: "Without Free Trial", action: {  [weak self] in
            self?.loadAndShowPaywall(freeTrialAvailable: false)
            
        }, style: .default),
        ])
        

        
    }
    
    func loadAndShowPaywall(freeTrialAvailable: Bool = false) {
        Paywall.isFreeTrialAvailableOverride = freeTrialAvailable
        
        bottomButton.setImage(nil, for: .normal)
        bottomButton.showLoading = true
        
        Network.shared.paywalls { [weak self] result in
            
            OnMain {
                switch(result){
                case .success(let response):
                    let paywalls = response.paywalls
                    
                    let paywallResponse = paywalls.first { p in
                        p.id == self?.paywallId
                    }
                    
                    Paywall.set(response: paywallResponse, completion: { [weak self] _ in
                        Paywall.present(on: self, presentationCompletion: {
                            self?.bottomButton.showLoading = false
                            self?.bottomButton.setImage(UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!, for: .normal)
                        })
                    })
                    
                    
                case .failure(let error):
                    Logger.superwallDebug(string: "Debug Mode Error", error: error)
                    self?.activityIndicator.stopAnimating()
                }
                
                
            }
            
        }
        
 
    }
    
    
    var oldTintColor: UIColor? = UIColor.systemBlue
    
    override func viewDidAppear(_ animated: Bool) {
        let view = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        oldTintColor = view.tintColor
        view.tintColor = PrimaryColor
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Paywall.set(response: nil, completion: nil)
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = oldTintColor
        Paywall.isDebuggerLaunched = false
    }

}


extension DebugViewController {
    
    
    func presentAlert(title: String?, message: String?, options: [AlertOption]) {
        
        let v = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        v.view.tintColor = PrimaryColor
        for o in options {
            let action = UIAlertAction(title: o.title, style: o.style, handler: { _ in
                o.action?()
            })
            v.addAction(action)
        }
        
        
        
        v.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
        v.view.tintColor = PrimaryColor

        present(v, animated: true, completion: {
            v.view.tintColor = PrimaryColor
        })
        
        
        
    }
    
    
}
