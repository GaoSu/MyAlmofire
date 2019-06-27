//
//  Result.swift
//  MyAlmofire
//
//  Created by mini on 2019/6/24.
//  Copyright © 2019 刘航. All rights reserved.
//

import Foundation

public enum Result<Value> {
    case success(Value)
    case failure(Error)
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
      }
    }
    
    public var isFailure: Bool {
        return !isSuccess
    }
    
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
        
        public var error: Error? {
            switch self {
            case .success:
                return nil
            case .failure(let error):
                return error
            }
        }
}

extension Result: CustomStringConvertible {
    public var description: String {
        switch self {
        case .success:
            return "SUCCESS"
        case .failure:
            return "FAILURE"
        }
    }
}

extension Result: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .success(let value):
            return "SUCCESS: \(value)"
        case .failure(let error):
            return "FAILURE: \(error)"
        }
    }
}

extension Result {
    public init(value: () throws -> Value) {
        do {
            self = try .success(value())
        } catch {
            self = .failure(error)
        }
    }
    
    public func unwrap() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    public func map<T>(_ transform: (Value) -> T) -> Result<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func flatMap<T>(_ transform: (Value) throws -> T) -> Result<T> {
        switch self {
        case .success(let value):
            do {
                return try .success(transform(value))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func mapError<T: Error>(_ transform: (Error) -> T) -> Result {
        switch self {
        case .failure(let error):
            return .failure(error)
        case .success:
            return self
        }
    }
    
    public func flatMapError<T: Error>(_ transform: (Error) throws -> T) -> Result {
        switch self {
        case .failure(let error):
            do {
                return try .failure(transform(error))
            } catch {
                return .failure(error)
            }
        case .success:
            return self
        }
    }
    
   
    
    @discardableResult
    public func withValue(_ closure: (Value) -> Void) -> Result {
        if case let .success(value)  = self {
            closure(value)
        }
        return self
    }
    
    @discardableResult
    public func withError(_ closure: (Error) -> Void) -> Result {
        if case let .failure(error) = self {
            closure(error)
        }
        return self
    }
    
    @discardableResult
    public func ifSuccess(_ clouse: () -> Void) -> Result {
        if isSuccess {
            clouse()
        }
        return self
    }
    
    @discardableResult
    public func ifFailure(_ clouse: () -> Void) -> Result {
        if isFailure {
            clouse()
        }
        return self
    }
}
