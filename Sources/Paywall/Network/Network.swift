//
//  File.swift
//
//
//  Created by Brian Anglin on 2/3/21.
//
import UIKit
import Foundation

internal class Network {
    internal var userId:String?
    internal static let shared = Network()
    

    internal let urlSession: URLSession = URLSession(configuration: .ephemeral)
    
    internal var hostDomain: String {
        
        switch Paywall.networkEnvironment {
        case .release:
            return "superwall.me"
        case .releaseCandidate:
            return "superwallcanary.com"
        case .developer:
            return "superwall.dev"
        }
    }
    
    internal var baseURL: URL {
        return URL(string: "https://api.\(hostDomain)/api/v1/")!
    }

    internal var analyticsBaseURL: URL {
        return URL(string: "https://collector.\(hostDomain)/api/v1/")!
    }
    
}



extension Network {
    enum Error: LocalizedError {
        case unknown
        case notAuthenticated
        case decoding
		case notFound
        
        var errorDescription: String? {
            switch self {
                case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
                case .notAuthenticated: return NSLocalizedString("Unauthorized.", comment: "")
                case .decoding: return NSLocalizedString("Decoding error.", comment: "")
				case .notFound: return NSLocalizedString("Not found", comment: "")
            }
        }
    }
}

// MARK: Private extension for actually making requests
extension Network {
    
    func send<ResponseType: Decodable>(_ request: URLRequest, isDebugRequest: Bool = false, completion: @escaping (Result<ResponseType, Swift.Error>) -> Void) {
        var request = request

        let auth = "Bearer " + ((isDebugRequest ? Store.shared.debugKey : Store.shared.apiKey) ?? "")
        request.setValue(auth, forHTTPHeaderField:  "Authorization")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("SDK", forHTTPHeaderField: "X-Platform-Environment")
        request.setValue(Store.shared.appUserId ?? "", forHTTPHeaderField: "X-App-User-ID")
        request.setValue(Store.shared.aliasId ?? "", forHTTPHeaderField: "X-Alias-ID")
        request.setValue(DeviceHelper.shared.vendorId, forHTTPHeaderField: "X-Vendor-ID")
        request.setValue(DeviceHelper.shared.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(DeviceHelper.shared.osVersion, forHTTPHeaderField: "X-OS-Version")
        request.setValue(DeviceHelper.shared.model, forHTTPHeaderField: "X-Device-Model")
        request.setValue(DeviceHelper.shared.locale, forHTTPHeaderField: "X-Device-Locale") // en_US, en_GB
        request.setValue(DeviceHelper.shared.languageCode, forHTTPHeaderField: "X-Device-Language-Code") // en
        request.setValue(DeviceHelper.shared.currencyCode, forHTTPHeaderField: "X-Device-Currency-Code") // USD
        request.setValue(DeviceHelper.shared.currencySymbol, forHTTPHeaderField: "X-Device-Currency-Symbol") // $
        request.setValue(DeviceHelper.shared.secondsFromGMT, forHTTPHeaderField: "X-Device-Timezone-Offset") // $
        request.setValue(DeviceHelper.shared.appInstallDate, forHTTPHeaderField: "X-App-Install-Date") // $
		request.setValue(SDK_VERSION, forHTTPHeaderField: "X-SDK-Version")
        

        let task = self.urlSession.dataTask(with: request) { (data, response, error) in
            do {
                guard let unWrappedData = data else { return completion(.failure(error ?? Error.unknown))}
				
				if let response = response {
					print("the response is:", response)
				}
                
				if let response = response as? HTTPURLResponse {
					
					if response.statusCode == 401 {
						Logger.superwallDebug(string: "Unable to authenticate, please make sure your Superwall API KEY is correct.")
						return completion(.failure(Error.notAuthenticated))
					}
				
					if response.statusCode == 404 {
						Logger.superwallDebug(string: "Paywall not found.")
						return completion(.failure(Error.notFound))
					}
                }
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(ResponseType.self, from: unWrappedData)
                completion(.success(response))
            } catch let error {
                Logger.superwallDebug(string: "Error requesting: \(request.url?.absoluteString ?? "unknown absolute string")")
                Logger.superwallDebug(string: "Unable to decode response to type \(ResponseType.self)", error: error)
                Logger.superwallDebug(string: String(decoding: data ?? Data(), as: UTF8.self))
                completion(.failure(Error.decoding))
            }
        }
        task.resume()
        
        
    }
}



extension Network {
    func events(events: EventsRequest, completion: @escaping (Result<EventsResponse, Swift.Error>) -> Void) {
        let components = URLComponents(string: "events")!
        let requestURL = components.url(relativeTo: analyticsBaseURL)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        // Bail if we can't encode
        do {
            request.httpBody = try encoder.encode(events)
        } catch {
            return completion(.failure(Error.unknown))
        }

        send(request, completion: { (result: Result<EventsResponse, Swift.Error>)  in
            switch result {
                case .failure(let error):
                    Logger.superwallDebug(string: "[network POST /events] - failure")
                    completion(.failure(error))
                case .success(let response):
                    completion(.success(response))
            }

        })
    }
}

extension Network {
	func paywall(withIdentifier: String? = nil, fromEvent event: EventData? = nil, completion: @escaping (Result<PaywallResponse, Swift.Error>) -> Void) {
                
        let components = URLComponents(string: "paywall")!
        let requestURL = components.url(relativeTo: baseURL)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        // Bail if we can't encode
        do {
			
			if let id = withIdentifier {
				let paywallRequest = ["identifier": id]
				request.httpBody = try encoder.encode(paywallRequest)
			} else if let e = event {
				let paywallRequest = ["event": e.jsonData]
				request.httpBody = try encoder.encode(paywallRequest)
			} else {
				let paywallRequest = PaywallRequest(appUserId: Store.shared.userId ?? "")
				request.httpBody = try encoder.encode(paywallRequest)
			}
			
        } catch {
            return completion(.failure(Error.unknown))
        }
        
        Logger.superwallDebug(String(data: request.httpBody ?? Data(), encoding: .utf8)!)
        
        let t = Date().timeIntervalSince1970
        Logger.superwallDebug("[SW Elapsed Time /paywall] START \(Date().timeIntervalSince1970)")
        
        send(request, completion: { (result: Result<PaywallResponse, Swift.Error>)  in
            switch result {
                case .failure(let error):
                    Logger.superwallDebug(string: "[network POST /paywall] - failure")
                    completion(.failure(error))
                case .success(let response):
                    completion(.success(response))
                    Logger.superwallDebug("[SW Elapsed Time /paywall] END: \(Date().timeIntervalSince1970 - t)")
            }
            
        })

    }
}


extension Network {
    
    func paywalls(completion: @escaping (Result<PaywallsResponse, Swift.Error>) -> Void) {
            
        let components = URLComponents(string: "paywalls")!
        let requestURL = components.url(relativeTo: baseURL)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        Logger.superwallDebug(String(data: request.httpBody ?? Data(), encoding: .utf8)!)
        
        send(request, isDebugRequest: true, completion: { (result: Result<PaywallsResponse, Swift.Error>)  in
            switch result {
                case .failure(let error):
                    Logger.superwallDebug(string: "[network POST /paywall] - failure")
                    completion(.failure(error))
                case .success(let response):
                    completion(.success(response))
            }
            
        })

    }
    
}


extension Network {
    
    func config(completion: @escaping (Result<ConfigResponse, Swift.Error>) -> Void) {
            
        let components = URLComponents(string: "config")!
        let requestURL = components.url(relativeTo: baseURL)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        Logger.superwallDebug(String(data: request.httpBody ?? Data(), encoding: .utf8)!)
        
        send(request, isDebugRequest: false, completion: { (result: Result<ConfigResponse, Swift.Error>)  in
            switch result {
                case .failure(let error):
                    Logger.superwallDebug(string: "[network POST /config] - failure")
                    completion(.failure(error))
                case .success(let response):
                    completion(.success(response))
            }
            
        })

    }
    
}
