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
    @objc init(url: String)
    @objc static func withCachePolicy(_ url: String, _ cachePolicy: Int, _ timeoutInterval: Double) -> JSURLRequest
    
    @objc var url: String? { get }
    @objc var httpMethod: String? { get set }
    @objc var allHTTPHeaderFields: [String: String]? { get set }
    @objc var httpBody: JSValue? { get set }
    @objc var timeoutInterval: Double { get set }
    @objc var cachePolicy: Int { get set }
    
    @objc func setValueForHTTPHeaderField(_ value: String?, _ field: String)
    @objc func addValueForHTTPHeaderField(_ value: String, _ field: String)
    @objc func valueForHTTPHeaderField(_ field: String) -> String?
}

@objc final class JSURLRequest: NSObject, JSURLRequestExport {
    
    private var request: URLRequest
    
    @objc init(url: String) {
        guard let url = URL(string: url) else {
            self.request = URLRequest(url: URL(string: "about:blank")!)
            super.init()
            return
        }
        self.request = URLRequest(url: url)
        super.init()
    }
    
    private init(url: String, cachePolicy: Int, timeoutInterval: Double) {
        guard let url = URL(string: url) else {
            self.request = URLRequest(url: URL(string: "about:blank")!)
            super.init()
            return
        }
        let policy = URLRequest.CachePolicy(rawValue: UInt(cachePolicy)) ?? .useProtocolCachePolicy
        self.request = URLRequest(url: url, cachePolicy: policy, timeoutInterval: timeoutInterval)
        super.init()
    }
    
    @objc static func withCachePolicy(_ url: String, _ cachePolicy: Int, _ timeoutInterval: Double) -> JSURLRequest {
        return JSURLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
    }
    
    @objc var url: String? {
        return request.url?.absoluteString
    }
    
    @objc var httpMethod: String? {
        get { return request.httpMethod }
        set { request.httpMethod = newValue }
    }
    
    @objc var allHTTPHeaderFields: [String: String]? {
        get { return request.allHTTPHeaderFields }
        set { request.allHTTPHeaderFields = newValue }
    }
    
    @objc var httpBody: JSValue? {
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
    
    @objc var timeoutInterval: Double {
        get { return request.timeoutInterval }
        set { request.timeoutInterval = newValue }
    }
    
    @objc var cachePolicy: Int {
        get { return Int(request.cachePolicy.rawValue) }
        set { 
            if let policy = URLRequest.CachePolicy(rawValue: UInt(newValue)) {
                request.cachePolicy = policy
            }
        }
    }
    
    @objc func setValueForHTTPHeaderField(_ value: String?, _ field: String) {
        request.setValue(value, forHTTPHeaderField: field)
    }
    
    @objc func addValueForHTTPHeaderField(_ value: String, _ field: String) {
        request.addValue(value, forHTTPHeaderField: field)
    }
    
    @objc func valueForHTTPHeaderField(_ field: String) -> String? {
        return request.value(forHTTPHeaderField: field)
    }
    
    var urlRequest: URLRequest {
        return request
    }
}

@objc protocol JSURLResponseExport: JSExport {
    @objc var url: String? { get }
    @objc var statusCode: Int { get }
    @objc var allHeaderFields: [String: String] { get }
    @objc var textEncodingName: String? { get }
    @objc var expectedContentLength: Int64 { get }
    @objc var mimeType: String? { get }
    
    @objc func value(forHTTPHeaderField field: String) -> String?
}

@objc final class JSURLResponse: NSObject, JSURLResponseExport {
    
    private let response: HTTPURLResponse
    
    init(response: HTTPURLResponse) {
        self.response = response
        super.init()
    }
    
    @objc var url: String? {
        return response.url?.absoluteString
    }
    
    @objc var statusCode: Int {
        return response.statusCode
    }
    
    @objc var allHeaderFields: [String: String] {
        return response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }
    }
    
    @objc var textEncodingName: String? {
        return response.textEncodingName
    }
    
    @objc var expectedContentLength: Int64 {
        return response.expectedContentLength
    }
    
    @objc var mimeType: String? {
        return response.mimeType
    }
    
    @objc func value(forHTTPHeaderField field: String) -> String? {
        return response.value(forHTTPHeaderField: field)
    }
}
