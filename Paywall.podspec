Pod::Spec.new do |s|

	s.name         = "Paywall"
    s.version      = "1.0.15"
	s.summary      = "Superwall: In-App Paywalls Made Easy"
	s.description  = "Paywall is a client for the Superwall paywall iteration anbd event tracking system. It is an open source framework that provides a wrapper around Webkit for presenting and creating paywalls. The Superwall backend for implementing new paywalls lets you iterate on the fly in Swift or Objective-C easy!"

	s.homepage     = "https://github.com/superwall-me/paywall-ios"
	s.license      = "MIT"
	s.source       = { :git => "https://github.com/superwall-me/paywall-ios", :tag => "#{s.version}" }

	s.author       = { "Jake Mor" => "jake@superwall.me" }

	s.swift_versions = ['5.3']
	s.ios.deployment_target = '12.0'
	s.requires_arc = true

  s.source_files  = "Sources/**/*.{swift}"
  s.resources  = "Sources/Paywall/*.xcassets"
  s.dependency 'TPInAppReceipt', '~> 3.0.0'

end
