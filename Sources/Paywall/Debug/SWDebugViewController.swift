//
//  File.swift
//  
//
//  Created by Jake Mor on 8/26/21.
//
import UIKit
import Foundation
import StoreKit

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

internal class SWDebugViewController: UIViewController {
    
    var logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "superwall_logo", in: Bundle.module, compatibleWith: nil)!)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = false
        return imageView
    }()

    
    lazy var exitButton: SWBounceButton = {
        let b = SWBounceButton()
        let image = UIImage(named: "exit", in: Bundle.module, compatibleWith: nil)!
        b.setImage(image, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.imageView?.tintColor = UIColor.white.withAlphaComponent(0.5)
        b.addTarget(self, action: #selector(pressedExitButton), for: .primaryActionTriggered)
        return b
    }()
    
    lazy var consoleButton: SWBounceButton = {
        let b = SWBounceButton()
        let image = UIImage(named: "debugger", in: Bundle.module, compatibleWith: nil)!
        b.setImage(image, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.imageView?.tintColor = UIColor.white.withAlphaComponent(0.5)
        b.addTarget(self, action: #selector(pressedConsoleButton), for: .primaryActionTriggered)
        return b
    }()
    
    lazy var bottomButton: SWBounceButton = {
        let b = SWBounceButton()
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
    
    lazy var previewPickerButton: SWBounceButton = {
        let b = SWBounceButton()
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
    
    lazy var previewContainerView: SWBounceButton = {
        let v = SWBounceButton()
        v.shouldAnimateLightly = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addTarget(self, action: #selector(pressedPreview), for: .primaryActionTriggered)
        return v
    }()
    
    var paywallId: String? = nil
	var paywallIdentifier: String? = nil
    var paywallResponse: PaywallResponse? = nil
    var paywallResponses: [PaywallResponse] = []
    
    init() {
        super.init(nibName: nil, bundle: nil)
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(previewContainerView)
        view.addSubview(activityIndicator)
        view.addSubview(logoImageView)
        view.addSubview(consoleButton)
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
            logoImageView.heightAnchor.constraint(equalToConstant: 20),
            logoImageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 20),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            consoleButton.centerXAnchor.constraint(equalTo: bottomButton.leadingAnchor),
            consoleButton.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            
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
        
		if paywallResponses.count > 0 {
			finishLoadingPreview()
		} else {
			Network.shared.paywalls { [weak self] result in
				switch(result){
				case .success(let response):
					self?.paywallResponses = response.paywalls
					self?.finishLoadingPreview()
				case .failure(let error):
					Logger.debug(logLevel: .error, scope: .debugViewController, message: "Failed to Fetch Paywalls", info: nil, error: error)
				}
			}
		}



        
    }
	
	func finishLoadingPreview() {
		var pid: String? = nil
			
		if let paywallIdentifier = paywallIdentifier {
			pid = paywallIdentifier
		} else if let paywallId = paywallId {
			pid = paywallResponses.first(where: { $0.id == paywallId })?.identifier
			paywallIdentifier = pid
		}
			
		PaywallResponseManager.shared.getResponse(identifier: pid, event: nil) { [weak self] response, error in
			
			self?.paywallResponse = response
			
			OnMain { [weak self] in
				self?.previewPickerButton.setTitle("\(response?.name ?? "Preview")", for: .normal)
			}

			if let paywallResponse = self?.paywallResponse {
				StoreKitManager.shared.getVariables(forResponse: paywallResponse) { variables in
					self?.paywallResponse?.variables = variables
					OnMain { [weak self] in
						self?.activityIndicator.stopAnimating()
						self?.addPaywallPreview()
					}
				}
			} else {
				Logger.debug(logLevel: .error, scope: .debugViewController, message: "No Paywall Response", info: nil, error: error)
			}
			
		}
	}
    
    func addPaywallPreview() {
        if let child = SWPaywallViewController(paywallResponse: paywallResponse, delegate: nil) {
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
			child.view.alpha = 0.0
            
            let ratio = CGFloat(Double(previewContainerView.frame.size.height / view.frame.size.height))
            
            child.view.transform = CGAffineTransform.identity.scaledBy(x: ratio, y: ratio)
            
            child.view.layer.cornerRadius = 52
            
            if #available(iOS 13.0, *) {
                child.view.layer.cornerCurve = .continuous
            }
            
			UIView.animate(withDuration: 0.25, delay: 0.1, options: [], animations: {
				child.view.alpha = 1.0
			}, completion: nil)
			
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
				self?.paywallIdentifier = response.identifier
				self?.loadPreview()
                
            }, style: .default)
            
            return a
        }
        
        presentAlert(title: nil, message: "Your Paywalls", options: options)

    }
    
    @objc func pressedExitButton() {
		SWDebugManager.shared.closeDebugger(completion: nil)
    }
    
    @objc func pressedConsoleButton() {
		presentAlert(title: nil, message: "Menu", options: [
			AlertOption(title: "Localization", action: showLocalizationPicker, style: .default),
			AlertOption(title: "Templates", action: showConsole, style: .default),
		])
    }
	
	func showLocalizationPicker() {
		let vc = SWLocalizationViewController(completion: { [weak self] locale in
			LocalizationManager.shared.selectedLocale = locale
			self?.loadPreview()
		})
		
		let nc = UINavigationController(rootViewController: vc)
		self.present(nc, animated: true)
	}
	
	func showConsole() {
		if let paywallResponse = paywallResponse {
			StoreKitManager.shared.get(productsWithIds: paywallResponse.productIds) { [weak self] productsById in
				OnMain {
					var products = [SKProduct]()
					
					for id in paywallResponse.productIds {
						if let p = productsById[id] {
							products.append(p)
						}
					}
					
					let vc = SWConsoleViewController(products: products)
					let nc = UINavigationController(rootViewController: vc)
					nc.modalPresentationStyle = .overFullScreen
					self?.present(nc, animated: true)
				}
			}
		} else {
			Logger.debug(logLevel: .error, scope: .debugViewController, message: "Paywall Response is Nil", info: nil, error: nil)
		}
		
		

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
		
		Paywall.present(identifier: paywallIdentifier, on: self) { [weak self] info in
			self?.bottomButton.showLoading = false
			self?.bottomButton.setImage(UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!, for: .normal)
		} onDismiss: { _, _, _ in
			
		} onFail: { [weak self] error in
			
			self?.presentAlert(title: "Error Occurred", message: error?.localizedDescription, options: [])
			self?.bottomButton.showLoading = false
			self?.bottomButton.setImage(UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!, for: .normal)
			Logger.debug(logLevel: .error, scope: .debugViewController, message: "Failed to Show Paywall", info: nil, error: error)
			self?.activityIndicator.stopAnimating()
		}

		

        
//        Network.shared.paywalls { [weak self] result in
//
//            OnMain {
//                switch(result){
//                case .success(let response):
//                    let paywalls = response.paywalls
//
//                    let paywallResponse = paywalls.first { p in
//                        p.id == self?.paywallId
//                    }
//
//					Paywall.set(response: nil, completion: nil)
//                    Paywall.set(response: paywallResponse, completion: { [weak self] _ in
//						Paywall.present(on: self, onPresent: { _ in
//							self?.bottomButton.showLoading = false
//							self?.bottomButton.setImage(UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!, for: .normal)
//						})
//                    })
//
//                case .failure(let error):
//                    Logger.superwallDebug(string: "Debug Mode Error", error: error)
//                    self?.activityIndicator.stopAnimating()
//                }
//
//
//            }
//
//        }
        
 
    }
    
    
    var oldTintColor: UIColor? = UIColor.systemBlue
    
    override func viewDidAppear(_ animated: Bool) {
        let view = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        oldTintColor = view.tintColor
        view.tintColor = PrimaryColor
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
		PaywallManager.shared.clearCache() // TODO: test if we need this
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = oldTintColor
		SWDebugManager.shared.isDebuggerLaunched = false
		LocalizationManager.shared.selectedLocale = nil
    }

}


extension SWDebugViewController {
    
    
    func presentAlert(title: String?, message: String?, options: [AlertOption]) {
        
        let v = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        if #available(iOS 13.0, *) {
            v.overrideUserInterfaceStyle = .dark
            v.view.tintColor = PrimaryColor
        } else {
            v.view.tintColor = DarkBackgroundColor
        }
       
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
