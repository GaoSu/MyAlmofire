//
//  ResponseSerialization.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/24.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

public protocol DataResponseSerializerProtocl {
    associatedtype SerializedObject
    var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<SerializedObject> { get }
}


public struct DataResponseSerializer<Value>: DataResponseSerializerProtocl {
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Value>
    
    public typealias SerializedObject = Value
   
    public init(serializaResponse: @escaping (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Value>) {
        self.serializeResponse = serializaResponse
    }
}

public protocol DownloadResponseSerializerProtocol {
    associatedtype SerializedObject
    var serializeResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<SerializedObject> { get }
}

public struct DownloadResponseSerializer<Value>: DownloadResponseSerializerProtocol {
    public typealias SerializedObject = Value
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Value>
    public init(serializeResponse: @escaping (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Value>) {
        self.serializeResponse = serializeResponse
    }
}


extension Request {
    var timeline: Timeline {
        let requestStartTime = self.startTime ?? CFAbsoluteTimeGetCurrent()
        let requestCompletedTime = self.endTime ?? CFAbsoluteTimeGetCurrent()
        let initialResponseTime = self.delegate.initialResponseTime ?? requestCompletedTime
        return Timeline(requestStartTime: requestStartTime, initialResponseTime: initialResponseTime, requestCompletedTime: requestCompletedTime, serializationCompletedTime: CFAbsoluteTimeGetCurrent())
    }
    
}

extension DataRequest {
    @discardableResult
    public func response(queue: DispatchQueue? = nil, completionHandler: @escaping (DefaultDataResponse) -> Void) -> Self {
        delegate.queue?.addOperation {
            (queue ?? DispatchQueue.main).async {
                var dataResponse = DefaultDataResponse(request: self.request, response: self.response, data: self.delegate.data ?? Data(), error: self.delegate.error, timeline: self.timeline, metrices: nil)
              dataResponse.add(self.delegate.metrics)
              completionHandler(dataResponse)
            }
        }
        return self
    }
    
    @discardableResult
    public func response<T: DataResponseSerializerProtocl>(queue: DispatchQueue? = nil, responseSerializer: T, completionHandler: @escaping (DataResponse<T.SerializedObject>) -> Void) -> Self {
        delegate.queue?.addOperation {
            let reqult = responseSerializer.serializeResponse(
                self.request,
                self.response,
                self.delegate.data,
                self.delegate.error
            )
            var dataResponse = DataResponse<T.SerializedObject>(request: self.request, response: self.response, data: self.delegate.data, result: reqult, timeline: self.timeline)
            dataResponse.add(self.delegate.metrics)
            (queue ?? DispatchQueue.main).async {
                completionHandler(dataResponse)
            }
        }
        return self
    }
}

extension DownloadRequest {
    @discardableResult
    public func response(queue: DispatchQueue? = nil, completionHandler: @escaping (DefaultDownloadResponse) -> Void) -> Self {
        delegate.queue?.addOperation {
            (queue ?? DispatchQueue.main).async {
                var downloadResponse = DefaultDownloadResponse(request: self.request, response: self.response, temporaryURL: self.downloadDelegate.temporaryURL, destinationURL: self.downloadDelegate.destinationURL, resumeData: self.downloadDelegate.resumeData, error: self.downloadDelegate.error, timeline: self.timeline, metrics: nil)
                downloadResponse.add(self.delegate.metrics)
                completionHandler(downloadResponse)
            }
        }
        return self
    }
    
    @discardableResult
    public func response<T: DownloadResponseSerializerProtocol>(queue: DispatchQueue? = nil, responseSerializer: T, completionHandler: @escaping (DownloadResponse<T.SerializedObject>) -> Void) -> Self {
        delegate.queue?.addOperation {
            let result = responseSerializer.serializeResponse(self.request, self.response, self.downloadDelegate.fileURL, self.downloadDelegate.error)
            var downloadResponse = DownloadResponse<T.SerializedObject>(request: self.request, response: self.response, temporaryURL: self.downloadDelegate.temporaryURL, destinationURL: self.downloadDelegate.destinationURL, resumeData: self.downloadDelegate.resumeData, result: result, timeline: self.timeline)
           downloadResponse.add(self.delegate.metrics)
            (queue ?? DispatchQueue.main).async {
                completionHandler(downloadResponse)
            }
        }
        return self
    }
}

extension Request {
    public static func serializeResponseData(response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Data> {
        guard error == nil else {
            return .failure(error!)
        }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
           return .success(Data())
        }
        guard let validData = data else { return .failure(AFError.responseSerializationFailed(reason: .inputDataNil)) }
        return.success(validData)
    }
}

extension DataRequest {
    public static func dataResponseSerializer() -> DataResponseSerializer<Data> {
        return DataResponseSerializer { _ , response, data, error in
            return Request.serializeResponseData(response: response, data: data, error: error)
        }
    }
    
    @discardableResult
    public func responseData(queue: DispatchQueue? = nil, completionHanlder: @escaping (DataResponse<Data>) -> Void) -> Self {
        return response(queue, responseSerializer: DataRequest.dataResponseSerializer(), completionHandler: completionHanlder)
    }
    
    /// 刘
    ///
    /// - Parameters:
    ///   - queue:
    ///   - responseSerializer:
    ///   - completionHandler:
    /// - Returns:
    @discardableResult
    public func response<T: DataResponseSerializerProtocl>(_ queue: DispatchQueue? = nil, responseSerializer: T, completionHandler: @escaping (DataResponse<T.SerializedObject>) -> Void) -> Self {
        delegate.queue?.addOperation {
            let result = responseSerializer.serializeResponse(
                self.request,
                self.response,
                self.delegate.data,
                self.delegate.error
            )
            var dataResponse = DataResponse<T.SerializedObject>(
                request: self.request, response: self.response, data: self.delegate.data, result: result, timeline: self.timeline
            )
          dataResponse.add(self.delegate.metrics)
            (queue ?? DispatchQueue.main).async {
                completionHandler(dataResponse)
            }
        }
        return self
    }
}

extension DownloadRequest {
    public static func dataResponseSerializer() -> DownloadResponseSerializer<Data> {
        return DownloadResponseSerializer { _, response, fileURL, error in
            guard error == nil else {
               return .failure(error!)
            }
            guard let fileURL = fileURL else {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileNil))
            }
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponseData(response: response, data: data, error: error)
            } catch {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    
    @discardableResult
    public func responseData(queue: DispatchQueue? = nil, completionHandler: @escaping (DownloadResponse<Data>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.dataResponseSerializer(), completionHandler: completionHandler)
    }
}
//MARK: -
extension Request {
    public static func serializeResponseString(encoding: String.Encoding?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<String> {
        guard error == nil else {
            return .failure(error!)
        }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
            return .success("")
        }
        guard let validData = data else { return .failure(AFError.responseSerializationFailed(reason: .inputDataNil)) }
        var convertedEncoding = encoding
        if let encodingName = response?.textEncodingName as CFString?, convertedEncoding == nil {
            convertedEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringConvertIANACharSetNameToEncoding(encodingName))
            )
        }
        let actualEncoding = convertedEncoding ?? .isoLatin1
        if let string = String(data: validData, encoding: actualEncoding) {
            return .success(string)
        } else {
            return .failure(AFError.responseSerializationFailed(reason: .stringSerializationFailed(encoding: actualEncoding)))
        }
    }
}

extension DataRequest {
    public static func stringResponseSerializer(encoding: String.Encoding? = nil) -> DataResponseSerializer<String> {
        return DataResponseSerializer { _, response, data, error in
            return Request.serializeResponseString(encoding: encoding, response: response, data: data, error: error)
        }
    }
    
    @discardableResult
    public func responseString(queue: DispatchQueue? = nil, encoding: String.Encoding? = nil, completionHandler: @escaping (DataResponse<String>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.stringResponseSerializer(encoding: encoding), completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    public static func stringReponseSerializer(encoding: String.Encoding? = nil) -> DownloadResponseSerializer<String> {
        return DownloadResponseSerializer { _, response, fileURL, error in
            guard error == nil else {
                return .failure(error!)
            }
            guard let fileURL = fileURL else {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileNil))
            }
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponseString(encoding: encoding, response: response, data: data, error: error)
            } catch {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func responseString(_ queue: DispatchQueue? = nil, encoding: String.Encoding? = nil, completionsHandler: @escaping (DownloadResponse<String>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.stringReponseSerializer(encoding: encoding), completionHandler: completionsHandler)
    }
}

//MARK: JOSN
extension Request {
    public static func serializeResponseJSON(options: JSONSerialization.ReadingOptions, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Any> {
        guard error == nil else {
            return .failure(error!)
        }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
            return .success(NSNull())
        }
        guard let validData = data, validData.count > 0 else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        do {
            let json = try JSONSerialization.jsonObject(with: validData, options: options)
            return .success(json)
        } catch {
            return .failure(AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error)))
        }
    }
}

extension DataRequest {
    public static func jsonResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments) -> DataResponseSerializer<Any> {
        return DataResponseSerializer { _, response, data, error in
            return Request.serializeResponseJSON(options: options, response: response, data: data, error: error)
        }
    }
    
    @discardableResult
    public func responseJSON(queue: DispatchQueue? = nil, options: JSONSerialization.ReadingOptions = .allowFragments, completionHandler: @escaping (DataResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.jsonResponseSerializer(options: options), completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    public static func josnResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments) -> DownloadResponseSerializer<Any> {
        return DownloadResponseSerializer { _, response, fileURL, error in
            guard error == nil else {
                return .failure(error!)
            }
            guard let fileURL = fileURL else {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileNil))
            }
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponseJSON(options: options, response: response, data: data, error: error)
            } catch {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func responseJSON(queue: DispatchQueue? = nil, options: JSONSerialization.ReadingOptions = .allowFragments, completionHandler: @escaping (DownloadResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.josnResponseSerializer(options: options), completionHandler: completionHandler)
    }
}

extension Request {
    public static func serializeResponsePropertyList(options: PropertyListSerialization.ReadOptions, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Any> {
        guard error == nil else {
            return .failure(error!)
        }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
            return .success(NSNull())
        }
        guard let validData = data, validData.count > 0 else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        do {
            let plist = try PropertyListSerialization.propertyList(from: validData, options: options, format: nil)
            return .success(plist)
        } catch {
            return .failure(AFError.responseSerializationFailed(reason: .propertyListSerializationFailed(error: error)))
        }
    }
}

extension DataRequest {
    public static func propertyListResponseSerializer(options: PropertyListSerialization.ReadOptions = []) -> DataResponseSerializer<Any> {
        return DataResponseSerializer { _, response, data, error in
            return Request.serializeResponsePropertyList(options: options, response: response, data: data, error: error)
        }
    }
    
    @discardableResult
    public func responsePropertyList(queue: DispatchQueue? = nil, options: PropertyListSerialization.ReadOptions = [], completionHandler: @escaping (DataResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.propertyListResponseSerializer(options: options), completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    public static func propertyListResponseSerializer(options: PropertyListSerialization.ReadOptions = []) -> DownloadResponseSerializer<Any> {
        return DownloadResponseSerializer { _, response, fileURL, error in
            guard error == nil else {
                return .failure(error!)
            }
            guard let fileURL = fileURL else {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileNil))
            }
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponsePropertyList(options: options, response: response, data: data, error: error)
            } catch {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func reponsePropertyList(queue: DispatchQueue? = nil, options: PropertyListSerialization.ReadOptions = [], completionHandler: @escaping(DownloadResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.propertyListResponseSerializer(options: options), completionHandler: completionHandler)
    }
}


private let emptyDataStatusCodes: Set<Int> = [204, 205]
