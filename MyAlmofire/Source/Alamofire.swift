//
//  Alamofire.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/19.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

public protocol RequestAdapter {
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest
}

public protocol URLConvertible {
    func asURL() throws -> URL
}

extension String: URLConvertible {
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else { throw AFError.invalidURL(url: self)  }
        return url
    }
}

extension URL: URLConvertible {
    public func asURL() throws -> URL {
        return self
    }
}

extension URLComponents: URLConvertible {
    public func asURL() throws -> URL {
        guard let url = url else { throw AFError.invalidURL(url: self)  }
        return url
    }
}
//MARKl: -

/// adopting
public protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

extension URLRequestConvertible {
    public var urlReques: URLRequest? { return try? asURLRequest()}
}

extension URLRequest: URLRequestConvertible {
    public func asURLRequest() throws -> URLRequest {
        return self
    }
}

//MARK: -

extension URLRequest {
    func adapt(using adapter: RequestAdapter?) throws -> URLRequest {
        guard let adapter = adapter else { return self }
        return try adapter.adapt(self)
    }
    public init (url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders? = nil) throws {
       let url = try url.asURL()
       self.init(url: url)
        httpMethod = method.rawValue
        if let headers = headers {
            for (headerField, headerValue) in headers {
                setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
    }
}

//MARK: - data request

@discardableResult
public func request(_ url: URLConvertible, method: HTTPMethod = .get, parameters: Parameters, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil) -> DataRequest {
    return SessionManager.default.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
}


@discardableResult
public func request(_ urlRequest: URLRequestConvertible) -> DataRequest {
    return SessionManager.default.request(urlRequest)
}

@discardableResult
public func download(_ url: URLRequestConvertible, method: HTTPMethod = .get, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, to destination: DownloadRequest.DownloadFileDestination? = nil) {
    
}
