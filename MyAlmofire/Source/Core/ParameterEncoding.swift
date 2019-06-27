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
    //MARK: Helper Types
    public enum Destination {
        case methodDependent, queryString, httpBody
    }
    
    public enum ArrayEncoding {
        case brackets, noBrackets
        func encode(key: String) -> String {
            switch self {
            case .brackets:
                return "\(key)[]"
            case .noBrackets:
                return key
            }
        }
    }
    
    public enum BoolEncoding {
        case numeric, literal
        func encode(value: Bool) -> String {
            switch self {
            case .numeric:
                return value ? "1" : "0"
            case .literal:
                return value ? "true" : "false"
            }
        }
    }
    
    //MARK: Properties
    //````````` 大写键 + ~键
    public static var `default`: URLEncoding { return URLEncoding()}
    
    public static var methodDependent: URLEncoding {
        return URLEncoding()
    }
    
    public static var querying: URLEncoding {
        return URLEncoding(destination: .queryString)
    }
    
    public static var httpBody: URLEncoding {
        return URLEncoding(destination: .httpBody)
    }
    public let destination: Destination
    
    public let arraryEncoding: ArrayEncoding
    
    public let boolEncoding: BoolEncoding
    
    public init(destination: Destination = .methodDependent, arrayEncoding: ArrayEncoding = .brackets, boolEncoding: BoolEncoding = .numeric) {
        self.destination = destination
        self.arraryEncoding = arrayEncoding
        self.boolEncoding = boolEncoding
    }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters else { return urlRequest }
        if let method = HTTPMethod(rawValue: urlRequest.httpMethod ?? "GET"), encodesParametersInURL(with: method) {
            guard let url = urlRequest.url else {
              throw AFError.parameterEncodingFailed(reason: .missingURL)
            }
            if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), !parameters.isEmpty {
                let percentEncodeedQuery = (urlComponents.percentEncodedQuery.map({$0 + "&"}) ?? "") + query(parameters)
                urlComponents.percentEncodedQuery = percentEncodeedQuery
                urlRequest.url = urlComponents.url
            }
        } else {
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }
            urlRequest.httpBody = query(parameters).data(using: .utf8, allowLossyConversion: false)
        }
        return urlRequest
    }
    
    public func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []
        if let dictionary = value as? [String: Any] {
            for (nestedKey, value) in dictionary {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        } else if let array = value as? [Any] {
            for value in array {
                components += queryComponents(fromKey: arraryEncoding.encode(key: key), value: value)
            }
        } else if let value = value as? NSNumber {
            if value.isBool {
                components.append((escape(key), escape(boolEncoding.encode(value: value.boolValue))))
            } else {
                components.append((escape(key), escape("\(value)")))
            }
        } else if let bool = value as? Bool {
            components.append((escape(key), escape(boolEncoding.encode(value: bool))))
        } else {
            components.append((escape(key), escape("\(value)")))
        }
        return components
    }
    
    public func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'*+,;="
        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        var escaped = ""
        if #available(iOS 8.3, *) {
            escaped = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
        } else {
            let batchSize = 50
            var index = string.startIndex
            while index != string.endIndex {
                let startIndex = index
                let endIndex = string.index(index, offsetBy: batchSize, limitedBy: string.endIndex) ?? string.endIndex
                let range = startIndex..<endIndex
                let substring = string[range]
                escaped += substring.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? String(substring)
                index = endIndex
            }
        }
        return escaped
    }
    
    private func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        return components.map({"\($0)=\($1)"}).joined(separator: "&")
    }
    
    private func encodesParametersInURL(with method: HTTPMethod) -> Bool {
        switch destination {
        case .queryString:
            return true
        case .httpBody:
            return true
        default:
            break
        }
        
        switch method {
        case .get, .head, .delete:
            return true
        default:
            return false
        }
    }
    
}

//MARK: -

public struct JSONEncoding: ParameterEncoding {
    
    public static var `default`: JSONEncoding { return JSONEncoding()}
    
    public static var prettyPrinted: JSONEncoding { return JSONEncoding(options: .prettyPrinted)}
    
    public let options: JSONSerialization.WritingOptions
    public init(options: JSONSerialization.WritingOptions = []) {
        self.options = options
    }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
       var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters else { return urlRequest }
        do {
           let data = try  JSONSerialization.data(withJSONObject: parameters, options: options)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        return urlRequest
    }
    
    public func encode(_ urlRequest: URLRequestConvertible, withJOSNObject jsonObject: Any? = nil) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let jsonObjcet = jsonObject else { return urlRequest }
    
        do {
           let data = try JSONSerialization.data(withJSONObject: jsonObjcet, options: options)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            urlRequest.httpBody = data
        } catch  {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        return urlRequest
    }
    
}

//MARK: -
public struct PropertyListEncoding: ParameterEncoding {
    
    public static var `default`: PropertyListEncoding { return PropertyListEncoding() }
    
    public static var xml: PropertyListEncoding { return PropertyListEncoding(format: .xml) }
    
    public static var binary: PropertyListEncoding {
        return PropertyListEncoding(format: .binary)
    }
    
    public let format: PropertyListSerialization.PropertyListFormat
    public let options: PropertyListSerialization.WriteOptions
    public init(format: PropertyListSerialization.PropertyListFormat = .xml, options: PropertyListSerialization.WriteOptions = 0) {
        self.format = format
        self.options = options
    }
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters else { return urlRequest }
        do {
           let data =  try PropertyListSerialization.data(fromPropertyList: parameters, format: format, options: options)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/x-plist", forHTTPHeaderField: "Content-Type")
            }
            urlRequest.httpBody = data
        } catch  {
            throw AFError.parameterEncodingFailed(reason: .propretyListEncodingFailed(error: error))
        }
        return urlRequest
    }
    
    
}

//MARK: -
extension NSNumber {
    fileprivate var isBool: Bool {
        return CFBooleanGetTypeID() == CFGetTypeID(self)
    }
}
