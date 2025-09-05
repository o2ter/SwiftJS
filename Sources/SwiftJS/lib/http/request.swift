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
    
    var url: String? { get }
    var httpMethod: String { get set }
    var allHTTPHeaderFields: [String: String] { get set }
    var httpBody: JSValue? { get set }
    var timeoutInterval: Double { get set }
    
    func setValueForHTTPHeaderField(_ value: String?, _ field: String)
    func addValueForHTTPHeaderField(_ value: String, _ field: String)
    func valueForHTTPHeaderField(_ field: String) -> String?
}

@objc final class JSURLRequest: NSObject, JSURLRequestExport, @unchecked Sendable {
    
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
    private let customStatusCode: Int?
    private let customHeaders: [String: String]?
    private let customURL: String?
    
    init(response: HTTPURLResponse) {
        self.response = response
        self.customStatusCode = nil
        self.customHeaders = nil
        self.customURL = nil
        super.init()
    }

    // Convenience initializer for NIO responses
    init(statusCode: Int, headers: [String: String], url: String?) {
        // Create a dummy HTTPURLResponse for compatibility
        let dummyURL = URL(string: url ?? "https://example.com")!
        self.response = HTTPURLResponse(
            url: dummyURL, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
        self.customStatusCode = statusCode
        self.customHeaders = headers
        self.customURL = url
        super.init()
    }
    
    var url: String? {
        return customURL ?? response.url?.absoluteString
    }
    
    var statusCode: Int {
        return customStatusCode ?? response.statusCode
    }
    
    var allHeaderFields: [String: String] {
        if let customHeaders = customHeaders {
            return customHeaders
        }
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
        if let contentLength = customHeaders?["Content-Length"] ?? customHeaders?["content-length"]
        {
            return Int64(contentLength) ?? response.expectedContentLength
        }
        return response.expectedContentLength
    }
    
    var mimeType: String? {
        if let contentType = customHeaders?["Content-Type"] ?? customHeaders?["content-type"] {
            return contentType.components(separatedBy: ";").first?.trimmingCharacters(
                in: .whitespaces)
        }
        return response.mimeType
    }
    
    func value(forHTTPHeaderField field: String) -> String? {
        if let customHeaders = customHeaders {
            return customHeaders[field] ?? customHeaders[field.lowercased()]
        }
        return response.value(forHTTPHeaderField: field)
    }
}
