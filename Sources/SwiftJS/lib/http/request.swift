//
//  request.swift
//
//  The MIT License
//  Copyright (c) 2021 - 2025 O2ter Limited. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import JavaScriptCore

@objc protocol JSURLRequestExport: JSExport {
    init(url: String)
    static func withCachePolicy(_ url: String, _ cachePolicy: Int, _ timeoutInterval: Double) -> JSURLRequest
    
    var url: String? { get }
    var httpMethod: String { get set }
    var allHTTPHeaderFields: [String: String] { get set }
    var httpBody: JSValue? { get set }
    var timeoutInterval: Double { get set }
    var cachePolicy: Int { get set }
    
    func setValueForHTTPHeaderField(_ value: String?, _ field: String)
    func addValueForHTTPHeaderField(_ value: String, _ field: String)
    func valueForHTTPHeaderField(_ field: String) -> String?
}

@objc final class JSURLRequest: NSObject, JSURLRequestExport {
    
    private var request: URLRequest
    
    init(url: String) {
        guard let url = URL(string: url) else {
            self.request = URLRequest(url: URL(string: "about:blank")!)
            super.init()
            self.request.httpMethod = "GET" // Set default method
            return
        }
        self.request = URLRequest(url: url)
        self.request.httpMethod = "GET" // Set default method
        super.init()
    }
    
    private init(url: String, cachePolicy: Int, timeoutInterval: Double) {
        guard let url = URL(string: url) else {
            self.request = URLRequest(url: URL(string: "about:blank")!)
            super.init()
            self.request.httpMethod = "GET" // Set default method
            return
        }
        let policy = URLRequest.CachePolicy(rawValue: UInt(cachePolicy)) ?? .useProtocolCachePolicy
        self.request = URLRequest(url: url, cachePolicy: policy, timeoutInterval: timeoutInterval)
        self.request.httpMethod = "GET" // Set default method
        super.init()
    }
    
    static func withCachePolicy(_ url: String, _ cachePolicy: Int, _ timeoutInterval: Double) -> JSURLRequest {
        return JSURLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
    }
    
    var url: String? {
        return request.url?.absoluteString
    }
    
    var httpMethod: String {
        get { return request.httpMethod ?? "GET" }
        set { request.httpMethod = newValue }
    }
    
    var allHTTPHeaderFields: [String: String] {
        get { return request.allHTTPHeaderFields ?? [:] }
        set { request.allHTTPHeaderFields = newValue }
    }
    
    var httpBody: JSValue? {
        get {
            guard let data = request.httpBody,
                  let context = JSContext.current() else { return nil }
            return JSValue.uint8Array(count: data.count, in: context) { buffer in
                data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
            }
        }
        set {
            if let jsValue = newValue, jsValue.isTypedArray {
                let bytes = jsValue.typedArrayBytes
                request.httpBody = Data(bytes.bindMemory(to: UInt8.self))
            } else if let jsValue = newValue, jsValue.isString {
                request.httpBody = jsValue.toString().data(using: .utf8)
            } else {
                request.httpBody = nil
            }
        }
    }
    
    var timeoutInterval: Double {
        get { return request.timeoutInterval }
        set { request.timeoutInterval = newValue }
    }
    
    var cachePolicy: Int {
        get { return Int(request.cachePolicy.rawValue) }
        set { 
            if let policy = URLRequest.CachePolicy(rawValue: UInt(newValue)) {
                request.cachePolicy = policy
            }
        }
    }
    
    func setValueForHTTPHeaderField(_ value: String?, _ field: String) {
        request.setValue(value, forHTTPHeaderField: field)
    }
    
    func addValueForHTTPHeaderField(_ value: String, _ field: String) {
        request.addValue(value, forHTTPHeaderField: field)
    }
    
    func valueForHTTPHeaderField(_ field: String) -> String? {
        return request.value(forHTTPHeaderField: field)
    }
    
    var urlRequest: URLRequest {
        return request
    }
}

@objc protocol JSURLResponseExport: JSExport {
    var url: String? { get }
    var statusCode: Int { get }
    var allHeaderFields: [String: String] { get }
    var textEncodingName: String? { get }
    var expectedContentLength: Int64 { get }
    var mimeType: String? { get }
    
    func value(forHTTPHeaderField field: String) -> String?
}

@objc final class JSURLResponse: NSObject, JSURLResponseExport {
    
    private let response: HTTPURLResponse
    
    init(response: HTTPURLResponse) {
        self.response = response
        super.init()
    }
    
    var url: String? {
        return response.url?.absoluteString
    }
    
    var statusCode: Int {
        return response.statusCode
    }
    
    var allHeaderFields: [String: String] {
        return response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }
    }
    
    var textEncodingName: String? {
        return response.textEncodingName
    }
    
    var expectedContentLength: Int64 {
        return response.expectedContentLength
    }
    
    var mimeType: String? {
        return response.mimeType
    }
    
    func value(forHTTPHeaderField field: String) -> String? {
        return response.value(forHTTPHeaderField: field)
    }
}
