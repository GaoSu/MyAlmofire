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
    public enum MultipartEncodingFailureReason {
        case bodyPartURLInvalid(url: URL)
        case bodyPartFilenameInvalid(in: URL)
        case bodyPartFileNotReachable(at: URL)
        case bodyPartFileNotReachableWithError(atURL: URL, error: Error)
        case bodyPartFileIsDirectory(at: URL)
        case bodyPartFileSizeNotAvailable(at: URL)
        case bodyPartFileSizeQueryFailedWithError(forURL: URL, error: Error)
        case bodyPartInputStreamCreationFailed(for: URL)
        
        case outputStreamCreationFailed(for: URL)
        case outputStreamFileAlreadyExists(at: URL)
        case outputStreamURLInvalid(url: URL)
        case outputStreamWriteFailed(error: Error)
        
        case inputStreamReadFailed(error: Error)
    }
    
    case multipartEncodingFailed(reason: MultipartEncodingFailureReason)
}

extension Error {
    var underlyingAdaptError: Error? { return (self as? AdaptError)?.error }
}
