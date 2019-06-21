//
//  MultipartFormData.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/21.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)
import MobileCoreServices
#elseif os(macOS)
import CoreServices
#endif
open class MultipartFormData {
    struct EncodingCharacters {
        static let crlf = "\r\n"
    }
    
    struct BoundaryGenerator {
        enum BoundaryType {
            case initial, encapsulated, final
        }
        static func randomBoundary() -> String {
            return String(format: "alamofire.boundary.%08x%08x", arc4random(), arc4random())
        }
        static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
            let boundaryText: String
            switch boundaryType {
            case .initial:
                boundaryText = "--\(boundary)\(EncodingCharacters.crlf)"
            case .encapsulated:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
            case .final:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
        }
         return boundaryText.data(using: .utf8, allowLossyConversion: false)!
      }
    }
    
    class BodyPart {
        let headers: HTTPHeaders
        let bodyStream: InputStream
        let bodyContentLength: UInt64
        var hasInitialBoundary = false
        var hasFinalBoundary = false
        init(headers: HTTPHeaders, bodyStream: InputStream, bodyContentLength: UInt64) {
            self.headers = headers
            self.bodyStream = bodyStream
            self.bodyContentLength = bodyContentLength
        }
    }
    
    open lazy var contentType: String = "multipart/form-data; boundary=\(self.boundary)"
    
    public let boundary: String
    
    public var contentLength: UInt64 { return bodyParts.reduce(0) { $0 + $1.bodyContentLength }}
    private var bodyParts: [BodyPart]
    private var bodyPartError: AFError?
    private let streamBufferSize: Int
    //MARK: Lifecycle
    public init() {
        self.boundary = BoundaryGenerator.randomBoundary()
        self.bodyParts = []
        self.streamBufferSize = 1024
    }
    //MARK: Body Parts
    public func append(_ data: Data, withName name: String) {
        let headers = contentHeaders(withName: name)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ stream: InputStream, withLength length: UInt64, headers: HTTPHeaders) {
        let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
    }
    
    public func append(_ fileURL: URL, withName name: String) {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension
        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
            setBodyPartyError(withReason: .bodyPartFilenameInvalid(in: fileURL))
        }
    }
    
    public func append(_ fileURL: URL, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        
        guard fileURL.isFileURL else {
            setBodyPartyError(withReason: .bodyPartURLInvalid(url: fileURL))
            return
        }
        //
        do {
            let isReachable = try fileURL.checkResourceIsReachable()
            guard isReachable else {
                setBodyPartyError(withReason: .bodyPartFileNotReachable(at: fileURL))
                return
            }
        } catch {
            setBodyPartyError(withReason: .bodyPartFileNotReachable(at: fileURL))
            return
        }
        //
        var isDirectory: ObjCBool = false
        let path = fileURL.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue else {
            setBodyPartyError(withReason: .bodyPartFileIsDirectory(at: fileURL))
            return
        }
        //
        let bodyContentLength: UInt64
        do {
            guard let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber else {
                setBodyPartyError(withReason: .bodyPartFileSizeNotAvailable(at: fileURL))
                return
            }
            bodyContentLength = fileSize.uint64Value
        } catch {
            setBodyPartyError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }
        
        guard let stream = InputStream(url: fileURL) else {
            setBodyPartyError(withReason: .outputStreamCreationFailed(for: fileURL))
            return
        }
        
       append(stream, withLength: bodyContentLength, headers: headers)
    }
    
    public func encode() throws -> Data {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        var encoded = Data()
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true
        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
        return encoded
    }
   
    private func encode(_ bodyPart: BodyPart) throws -> Data {
        var encoded = Data()
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
        encoded.append(initialData)
        let headerData = encodeHeaders(for: bodyPart)
        encoded.append(headerData)
        let bodyStreamData = try encodeBodyStream(for: bodyPart)
        encoded.append(bodyStreamData)
        if bodyPart.hasFinalBoundary {
            encoded.append(finalBoundaryData())
        }
        return encoded
    }
    
    private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer {
            inputStream.close()
        }
        var encoded = Data()
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            if let error = inputStream.streamError {
                throw AFError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
            }
            if bytesRead > 0 {
                encoded.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        return encoded
    }
    
    private func encodeHeaders(for bodyPart: BodyPart) -> Data {
        var headerText = ""
        for (key, value) in bodyPart.headers {
            headerText += "\(key): \(value)\(EncodingCharacters.crlf)"
        }
        headerText += EncodingCharacters.crlf
        return headerText.data(using: .utf8, allowLossyConversion: false)!
    }
    
    private func initialBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
    }
    
    private func finalBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
    }
    
    private func encapsulatedBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
    }
    
    private func mimeType(forPathExtension pathExtension: String) -> String {
        if let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue()  {
            return contentType as String
        }
        return "application/octet-stream"
    }
    
    private func contentHeaders(withName name: String, fileName: String? = nil, mimeType: String? = nil) -> [String: String] {
        var disposition = "form-data; name=\"\(name)\""
        if let fileName = fileName { disposition += "; filename=\"\(fileName)\"" }
        
        var headers = ["Content-Disposition": disposition]
        if let mimeType = mimeType { headers["Content-Type"] = mimeType }
        
        return headers
    }
    
    private func setBodyPartyError(withReason reason: AFError.MultipartEncodingFailureReason) {
        guard bodyPartError == nil else {
            return
        }
        bodyPartError = AFError.multipartEncodingFailed(reason: reason)
    }
}

