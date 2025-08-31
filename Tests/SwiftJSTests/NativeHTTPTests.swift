//
//  NativeHTTPTests.swift
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

import XCTest
import JavaScriptCore
@testable import SwiftJS

final class NativeHTTPTests: XCTestCase {
    
    // MARK: - JSURLRequest Tests
    
    func testJSURLRequestBasicProperties() {
        let request = JSURLRequest(url: "https://api.example.com/data")
        
        XCTAssertEqual(request.url, "https://api.example.com/data")
        XCTAssertEqual(request.httpMethod, "GET") // Default method
        XCTAssertEqual(request.timeoutInterval, 60.0) // Default timeout
    }
    
    func testJSURLRequestHTTPMethodSetting() {
        let request = JSURLRequest(url: "https://api.example.com/data")
        request.httpMethod = "POST"
        XCTAssertEqual(request.httpMethod, "POST")
        
        request.httpMethod = "PUT"
        XCTAssertEqual(request.httpMethod, "PUT")
    }
    
    func testJSURLRequestHeaderManagement() {
        let request = JSURLRequest(url: "https://api.example.com/data")
        
        // Test setting headers
        request.setValueForHTTPHeaderField("application/json", "Content-Type")
        request.setValueForHTTPHeaderField("Bearer token123", "Authorization")
        
        XCTAssertEqual(request.valueForHTTPHeaderField("Content-Type"), "application/json")
        XCTAssertEqual(request.valueForHTTPHeaderField("Authorization"), "Bearer token123")
        
        // Test case insensitivity
        XCTAssertEqual(request.valueForHTTPHeaderField("content-type"), "application/json")
        XCTAssertEqual(request.valueForHTTPHeaderField("AUTHORIZATION"), "Bearer token123")
    }
    
    func testJSURLRequestAddingHeaders() {
        let request = JSURLRequest(url: "https://api.example.com/data")
        
        request.setValueForHTTPHeaderField("value1", "X-Custom")
        request.addValueForHTTPHeaderField("value2", "X-Custom")
        
        // Should contain both values
        let headerValue = request.valueForHTTPHeaderField("X-Custom")
        XCTAssertTrue(headerValue?.contains("value1") == true)
        XCTAssertTrue(headerValue?.contains("value2") == true)
    }
    
    func testJSURLRequestWithCachePolicy() {
        let request = JSURLRequest.withCachePolicy("https://example.com", 1, 30.0)
        
        XCTAssertEqual(request.url, "https://example.com")
        XCTAssertEqual(request.timeoutInterval, 30.0)
        XCTAssertEqual(request.cachePolicy, 1)
    }
    
    func testJSURLRequestInvalidURL() {
        let request = JSURLRequest(url: "not a valid url")
        
        // Should fallback to about:blank
        XCTAssertNotNil(request.url)
        XCTAssertNotEqual(request.url, "not a valid url")
    }
    
    func testJSURLRequestBodySetting() {
        let context = JSContext()!
        let request = JSURLRequest(url: "https://example.com")
        
        // Test setting string body
        let stringBody = JSValue(object: "test data", in: context)!
        request.httpBody = stringBody
        
        // Test setting Uint8Array body
        let arrayBody = JSValue.uint8Array(count: 5, in: context) { buffer in
            buffer[0] = 72 // 'H'
            buffer[1] = 101 // 'e'
            buffer[2] = 108 // 'l'
            buffer[3] = 108 // 'l'
            buffer[4] = 111 // 'o'
        }
        request.httpBody = arrayBody
        
        // Test setting null body
        request.httpBody = JSValue(nullIn: context)
        
        // No crashes means success
        XCTAssertTrue(true)
    }
    
    // MARK: - JSURLResponse Tests
    
    func testJSURLResponseCreation() {
        let url = URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Content-Length": "100"
            ]
        )!
        
        let jsResponse = JSURLResponse(response: httpResponse)
        
        XCTAssertEqual(jsResponse.url, "https://example.com")
        XCTAssertEqual(jsResponse.statusCode, 200)
        XCTAssertEqual(jsResponse.allHeaderFields["Content-Type"], "application/json")
        XCTAssertEqual(jsResponse.allHeaderFields["Content-Length"], "100")
    }
    
    func testJSURLResponseHeaderAccess() {
        let url = URL(string: "https://api.example.com")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 201,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Location": "/api/resource/123",
                "X-RateLimit-Remaining": "99"
            ]
        )!
        
        let jsResponse = JSURLResponse(response: httpResponse)
        
        XCTAssertEqual(jsResponse.value(forHTTPHeaderField: "Location"), "/api/resource/123")
        XCTAssertEqual(jsResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"), "99")
        XCTAssertNil(jsResponse.value(forHTTPHeaderField: "NonExistent"))
    }
    
    // MARK: - JSURLSession Tests
    
    func testJSURLSessionSharedInstance() {
        let session1 = JSURLSession.getShared()
        let session2 = JSURLSession.getShared()
        
        // Should return the same instance
        XCTAssertTrue(session1 === session2)
    }
    
    func testJSURLSessionWithConfiguration() {
        let config = JSURLSessionConfiguration.default
        let session = JSURLSession(configuration: config)
        
        XCTAssertNotNil(session.configuration)
        XCTAssertTrue(session.configuration === config)
    }
    
    func testJSURLSessionDataTaskCreation() {
        let session = JSURLSession.getShared()
        let request = JSURLRequest(url: "https://httpbin.org/get")
        
        // Create a JSContext for the test
        _ = JSContext()!
        // Ensure polyfills/native bindings are initialized
        let _ = SwiftJS()

    let task = session.dataTaskWithRequestCompletionHandler(request, nil)
        
        // Should return a Promise (JSValue)
        XCTAssertNotNil(task)
    }
    
    // MARK: - JSURLSessionConfiguration Tests
    
    func testJSURLSessionConfigurationDefault() {
        let config = JSURLSessionConfiguration.default
        XCTAssertNotNil(config.configuration)
    }
    
    func testJSURLSessionConfigurationEphemeral() {
        let config = JSURLSessionConfiguration.ephemeral
        XCTAssertNotNil(config.configuration)
    }
    
    // MARK: - Integration Tests
    
    func testRequestResponseCycle() {
        let expectation = XCTestExpectation(description: "HTTP request completion")
        
        let session = JSURLSession.getShared()
        let request = JSURLRequest(url: "https://httpbin.org/get")
        request.setValueForHTTPHeaderField("SwiftJS-Test", "X-Test-Header")
        
        // Ensure SwiftJS polyfills are initialized for this test
        let _ = SwiftJS()
        let context = JSContext()!
        
        // Set up promise handling
    let promise = session.dataTaskWithRequestCompletionHandler(request, nil)
        XCTAssertNotNil(promise)
        
        // Add promise handlers
        let thenHandler = JSValue(newFunctionIn: context) { args, this in
            let result = args[0]
            let response = result.forProperty("response")
            
            // Verify the response
            XCTAssertEqual(response?.forProperty("statusCode").toInt32(), 200)
            XCTAssertEqual(response?.forProperty("url").toString(), "https://httpbin.org/get")
            
            expectation.fulfill()
            return JSValue(undefinedIn: context)
        }
        
        let catchHandler = JSValue(newFunctionIn: context) { args, this in
            XCTFail("Request should not fail: \(args[0].toString() ?? "unknown error")")
            expectation.fulfill()
            return JSValue(undefinedIn: context)
        }
        
        promise?.invokeMethod("then", withArguments: [thenHandler])
            .invokeMethod("catch", withArguments: [catchHandler])
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testErrorHandling() {
        let expectation = XCTestExpectation(description: "HTTP error handling")
        
        let session = JSURLSession.getShared()
        let request = JSURLRequest(url: "https://invalid-domain-that-does-not-exist.com")
        
        // Ensure SwiftJS polyfills are initialized for this test
        let _ = SwiftJS()
        let context = JSContext()!

    let promise = session.dataTaskWithRequestCompletionHandler(request, nil)
        XCTAssertNotNil(promise)
        
        let thenHandler = JSValue(newFunctionIn: context) { args, this in
            XCTFail("Request to invalid domain should fail")
            expectation.fulfill()
            return JSValue(undefinedIn: context)
        }
        
        let catchHandler = JSValue(newFunctionIn: context) { args, this in
            // Should reach here due to invalid domain
            XCTAssertTrue(true, "Error handler called as expected")
            expectation.fulfill()
            return JSValue(undefinedIn: context)
        }
        
        promise?.invokeMethod("then", withArguments: [thenHandler])
            .invokeMethod("catch", withArguments: [catchHandler])
        
        wait(for: [expectation], timeout: 10.0)
    }
}
