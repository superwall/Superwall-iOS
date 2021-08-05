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
    
    internal let baseURL: URL
    internal let analyticsBaseURL: URL
    internal let urlSession: URLSession
    
    
    public init(
        urlSession: URLSession = URLSession(configuration: .ephemeral),
        baseURL: URL = URL(string: "https://paywall-next.herokuapp.com/api/v1/")!,
        analyticsBaseURL: URL = URL(string: "https://collector.paywalrus.com/v1/")!) {
        
        self.urlSession = (urlSession)
        self.baseURL = baseURL
        self.analyticsBaseURL = analyticsBaseURL
    }
}

struct EmptyResponse: Decodable {}

extension Network {
    enum Error: LocalizedError {
        case unknown
        case notAuthenticated
        case decoding
        
        var errorDescription: String? {
            switch self {
                case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
                case .notAuthenticated: return NSLocalizedString("Unauthorized.", comment: "")
                case .decoding: return NSLocalizedString("Decoding error.", comment: "")
            }
        }
    }
}

// MARK: Private extension for actually making requests
extension Network {
    func send<ResponseType: Decodable>(_ request: URLRequest, completion: @escaping (Result<ResponseType, Swift.Error>) -> Void) {
        var request = request

        
        request.setValue("Bearer " + (Store.shared.apiKey ?? ""), forHTTPHeaderField:  "Authorization")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        
        
        let task = self.urlSession.dataTask(with: request) { (data, response, error) in
            do {
                guard let unWrappedData = data else { return completion(.failure(error ?? Error.unknown))}
                
                if let response = response as? HTTPURLResponse, response.statusCode == 401
                {
                    Logger.shareThatToDebug(string: "Unable to authenticate, please make sure your ShareThatToClientId is correct.")
                    return completion(.failure(Error.notAuthenticated))
                }
                let response = try JSONDecoder().decode(ResponseType.self, from: unWrappedData)
                completion(.success(response))
            } catch let error {
                Logger.shareThatToDebug(string: "Unable to decode response to type \(ResponseType.self)")
                completion(.failure(Error.decoding))
            }
        }
        task.resume()
    }
}

struct Substitution: Decodable {
    var key: String
    var value: String
}

struct PaywallResponse: Decodable {
    var url: String
    var substitutions: [Substitution]
}

struct PaywallRequest: Codable {
    var userId: String
}

extension Network {
    func paywall(paywallRequest: PaywallRequest, completion: @escaping (Result<PaywallResponse, Swift.Error>) -> Void) {
        
        let components = URLComponents(string: "paywall")!
        let requestURL = components.url(relativeTo: baseURL)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Bail if we can't encode
        do {
            request.httpBody = try JSONEncoder().encode(paywallRequest)
        } catch {
            return completion(.failure(Error.unknown))
        }
        
        send(request, completion: { (result: Result<PaywallResponse, Swift.Error>)  in
            switch result {
                case .failure(let error):
                    Logger.shareThatToDebug(string: "[network POST /paywall] - failure")
                    completion(.failure(error))
                case .success(let response):
                    completion(.success(response))
            }
            
        })

    }
}
