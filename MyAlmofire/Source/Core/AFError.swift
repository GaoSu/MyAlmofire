//
//  AFError.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/19.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation
struct AdaptError: Error {
    let error: Error
}

public enum AFError: Error {
    public enum ParameterEncodingFailureReason {
        case missingURL
        case josnEncodingFailed(error: Error)
        case propretyListEncodingFailed(error: Error)
    }
    
    case invalidURL(url: URLConvertible)
}

extension Error {
    var underlyingAdaptError: Error? { return (self as? AdaptError)?.error }
}
