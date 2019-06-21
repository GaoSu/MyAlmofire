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
public func download(_ url: URLConvertible, method: HTTPMethod = .get, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
   return SessionManager.default.download(url, method: method, parameters: parameters, encoding: encoding, headers: headers, to: destination)
}

@discardableResult
public func download(_ urlRequest: URLRequestConvertible, to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
    return SessionManager.default.download(urlRequest, to: destination)
}

@discardableResult
public func download(resumingWith resumeData: Data, to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
    return SessionManager.default.download(resumingWith: resumeData, to: destination)
}

//MARK: - Upload Request
@discardableResult
public func upload(_ fileURL: URL, to url: URLConvertible, method: HTTPMethod = .post, headers: HTTPHeaders? = nil) -> UploadRequest {
    return SessionManager.default.upload(fileURL, to: url, method: method, headers: headers)
}

@discardableResult
public func upload(_ fileURL: URL, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(fileURL, with: urlRequest)
}

@discardableResult
public func upload(_ data: Data, to url: URLConvertible, method: HTTPMethod = .post, headers: HTTPHeaders? = nil) -> UploadRequest {
    return SessionManager.default.upload(data, to: url, method: method, headers: headers)
}

@discardableResult
public func upload(_ data: Data, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(data, with: urlRequest)
}

//MARK: InputStream
@discardableResult
public func upload(_ stream: InputStream, to url: URLConvertible, method: HTTPMethod = .post, headers: HTTPHeaders? = nil) -> UploadRequest {
    return SessionManager.default.upload(stream, to: url, method: method, headers: headers)
}

@discardableResult
public func upload(_ stream: InputStream, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(stream, with: urlRequest)
}

//MARK: MultipartFormData
public func upload(multipartFromData: (MultipartFormData) -> Void, usingThreshould encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold, to url: URLConvertible, method: HTTPMethod = .post, headers: HTTPHeaders? = nil, encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?) {
    
}
