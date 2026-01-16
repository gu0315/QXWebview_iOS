//
//  NetworkManager.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import UIKit

/// 网络管理器 - 统一处理网络请求
class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let cache = URLCache.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = cache
        self.session = URLSession(configuration: config)
    }
    
    /// 发送GET请求
    func get<T: Codable>(url: String, 
                        parameters: [String: Any]? = nil,
                        responseType: T.Type,
                        completion: @escaping (Result<T, NetworkError>) -> Void) {
        request(url: url, method: "GET", parameters: parameters, responseType: responseType, completion: completion)
    }
    
    /// 发送POST请求
    func post<T: Codable>(url: String,
                         parameters: [String: Any]? = nil,
                         responseType: T.Type,
                         completion: @escaping (Result<T, NetworkError>) -> Void) {
        request(url: url, method: "POST", parameters: parameters, responseType: responseType, completion: completion)
    }
    
    private func request<T: Codable>(url: String,
                                   method: String,
                                   parameters: [String: Any]? = nil,
                                   responseType: T.Type,
                                   completion: @escaping (Result<T, NetworkError>) -> Void) {
        
        guard let url = URL(string: url) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                completion(.failure(.encodingError))
                return
            }
        }
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(.decodingError))
                }
            }
        }.resume()
    }
}

/// 网络错误类型
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case encodingError
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "没有数据返回"
        case .encodingError:
            return "数据编码错误"
        case .decodingError:
            return "数据解码错误"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
