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


extension URLRequest {
    func adapt(using adapter: RequestAdapter?) throws -> URLRequest {
        guard let adapter = adapter else { return self }
        return try adapter.adapt(self)
    }
}
