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

    
    lazy var exitButton: UIButton = {
        let b = UIButton()
        b.setTitle("Done", for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitleColor(PrimaryColor, for: .normal)
        b.addTarget(self, action: #selector(pressedExitButton), for: .primaryActionTriggered)
        return b
    }()
    
    lazy var previewPickerButton: BounceButton = {
        let b = BounceButton()
        b.setTitle("", for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        b.backgroundColor = PrimaryButtonBackgroundColor
        b.setTitleColor(PrimaryColor, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(named: "down_arrow", in: Bundle.module, compatibleWith: nil)!
        b.semanticContentAttribute = .forceRightToLeft
        b.titleEdgeInsets = UIEdgeInsets(top: 0, left: -1, bottom: 0, right: 0)
        b.imageEdgeInsets = UIEdgeInsets(top: 1, left: 5, bottom: -1, right: -3)
        b.setImage(image, for: .normal)
        b.imageView?.tintColor = PrimaryColor
        if #available(iOS 13.0, *) {
            b.layer.cornerCurve = .continuous
        }
        b.layer.cornerRadius = 64.0 / 3
        b.addTarget(self, action: #selector(pressedPickerButton), for: .primaryActionTriggered)
        return b
    }()
    
    lazy var previewOpenButton: BounceButton = {
        let b = BounceButton()
        b.setTitle("T A P   T O   O P E N", for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        b.backgroundColor = LightBackgroundColor
        b.setTitleColor(PrimaryColor, for: .normal)
        b.titleEdgeInsets = UIEdgeInsets(top: -1, left: 0, bottom: 0, right: 0)
        b.translatesAutoresizingMaskIntoConstraints = false
//        let image = UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!
//        b.setImage(image, for: .normal)
        b.imageView?.tintColor = PrimaryColor
        b.layer.cornerRadius = 10
//        b.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
//        b.layer.borderWidth = 1.0
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
        view.addSubview(previewPickerButton)
        previewContainerView.addSubview(previewOpenButton)
        view.backgroundColor = LightBackgroundColor
        
        previewContainerView.clipsToBounds = false
        
        NSLayoutConstraint.activate([
            
            previewContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainerView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 25),
            previewContainerView.bottomAnchor.constraint(equalTo: previewPickerButton.topAnchor, constant: -30),
            
            logoImageView.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor, constant: -10),
            logoImageView.heightAnchor.constraint(equalToConstant: 24),
            logoImageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 20),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            exitButton.trailingAnchor.constraint(equalTo: logoImageView.trailingAnchor),
            exitButton.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            
            activityIndicator.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),
            
            previewPickerButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            previewPickerButton.heightAnchor.constraint(equalToConstant: 64),
            previewPickerButton.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor, constant: -10),
            previewPickerButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -10),
            
            previewOpenButton.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor, constant: 0),
            previewOpenButton.heightAnchor.constraint(equalToConstant: 26),
            previewOpenButton.widthAnchor.constraint(equalToConstant: 130),
            previewOpenButton.centerYAnchor.constraint(equalTo: previewContainerView.bottomAnchor)
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
            
            let ratio = Double(previewContainerView.frame.size.height / view.frame.size.height)
            
            child.view.transform = CGAffineTransform.identity.scaledBy(x: ratio, y: ratio)
            
            child.view.layer.cornerRadius = 52
            
            if #available(iOS 13.0, *) {
                child.view.layer.cornerCurve = .continuous
            }
            
        }
    }
    
    @objc func pressedPickerButton() {
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
    
    @objc func pressedPreview() {
        
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
        
        previewPickerButton.setImage(nil, for: .normal)
        previewPickerButton.showLoading = true
        
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
                            self?.previewPickerButton.showLoading = false
                            self?.previewPickerButton.setImage(UIImage(named: "down_arrow", in: Bundle.module, compatibleWith: nil)!, for: .normal)
                        })
                    })
                    
                    
                case .failure(let error):
                    Logger.superwallDebug(string: "Debug Mode Error", error: error)
                    self?.activityIndicator.stopAnimating()
                }
                
                
            }
            
        }
        
 
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Paywall.set(response: nil, completion: nil)
    }

}


extension DebugViewController {
    
    
    func presentAlert(title: String?, message: String?, options: [AlertOption]) {
        
        let view = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        view.tintColor = PrimaryColor
        
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
