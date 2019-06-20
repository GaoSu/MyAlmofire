//
//  ParameterEncoding.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/20.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

public enum HTTPMethod: String {
    case options = "OPTIONS"
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case trace = "TRACE"
    case connect = "CONNECT"
}

public typealias Parameters = [String: Any]

public protocol ParameterEncoding {
    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest
}
//MARK: -
public struct URLEncoding: ParameterEncoding {
    
    public enum Destination {
        case methodDependent, queryString, httpBody
    }
    //````````` 大写键 + ~键
    public static var `default`: URLEncoding { return URLEncoding()}
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        return URLRequest(url: URL(string: "")!)
    }
    
    
}


