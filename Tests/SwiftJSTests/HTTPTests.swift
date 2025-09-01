//
//  HTTPTests.swift
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
@testable import SwiftJS

@MainActor
final class HTTPTests: XCTestCase {
    
    
    // MARK: - JSURLRequest Tests
    
    func testJSURLRequestCreation() {
        let request = JSURLRequest(url: "https://example.com")
        XCTAssertEqual(request.url, "https://example.com")
        XCTAssertEqual(request.httpMethod, "GET") // Default method
    }
    
    func testJSURLRequestWithInvalidURL() {
        let request = JSURLRequest(url: "invalid url")
        XCTAssertNotNil(request.url) // Should fallback to about:blank
    }
    
    func testJSURLRequestHTTPMethod() {
        let request = JSURLRequest(url: "https://example.com")
        request.httpMethod = "POST"
        XCTAssertEqual(request.httpMethod, "POST")
    }
    
    func testJSURLRequestHeaders() {
        let request = JSURLRequest(url: "https://example.com")
        request.setValueForHTTPHeaderField("application/json", "Content-Type")
        XCTAssertEqual(request.valueForHTTPHeaderField("Content-Type"), "application/json")
    }
    
    func testJSURLRequestCachePolicy() {
        let request = JSURLRequest.withCachePolicy("https://example.com", 1, 30.0)
        XCTAssertEqual(request.url, "https://example.com")
        XCTAssertEqual(request.timeoutInterval, 30.0)
    }
    
    // MARK: - JSURLSession Tests
    
    func testJSURLSessionShared() {
        let session1 = JSURLSession.getShared()
        let session2 = JSURLSession.getShared()
        XCTAssertTrue(session1 === session2)  // Should be the same instance
    }
    
    // MARK: - Network Request Tests
    
    func testSimpleGETRequest() {
        let expectation = XCTestExpectation(description: "GET request completion")
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://httpbin.org/get');
            xhr.onload = function() {
                globalThis.getResult = {
                    status: xhr.status,
                    success: xhr.status >= 200 && xhr.status < 300
                };
            };
            xhr.onerror = function() {
                globalThis.getResult = { error: true };
            };
            xhr.send();
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let result = context.evaluateScript("globalThis.getResult")
            XCTAssertFalse(result.isUndefined)
            XCTAssertTrue(result["success"].boolValue ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPOSTRequestWithData() {
        let expectation = XCTestExpectation(description: "POST request completion")
        
        
        let script = """
            const data = JSON.stringify({
                name: 'SwiftJS Test',
                version: '1.0',
                timestamp: Date.now()
            });
            
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://httpbin.org/post');
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.onload = function() {
                try {
                    const response = JSON.parse(xhr.responseText);
                    globalThis.postResult = {
                        status: xhr.status,
                        dataReceived: response.json && response.json.name === 'SwiftJS Test'
                    };
                } catch (e) {
                    globalThis.postResult = { parseError: true };
                }
            };
            xhr.onerror = function() {
                globalThis.postResult = { error: true };
            };
            xhr.send(data);
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let result = context.evaluateScript("globalThis.postResult")
            XCTAssertFalse(result.isUndefined)
            XCTAssertEqual(result["status"].numberValue, 200)
            XCTAssertTrue(result["dataReceived"].boolValue ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPUTRequest() {
        let expectation = XCTestExpectation(description: "PUT request completion")
        
        
        let script = """
            fetch('https://httpbin.org/put', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'update', id: 123 })
            })
            .then(response => response.json())
            .then(data => {
                globalThis.putResult = {
                    method: data.method,
                    json: data.json
                };
            })
            .catch(error => {
                globalThis.putResult = { error: error.message };
            });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.putResult")
            XCTAssertEqual(result["method"].toString(), "PUT")
            XCTAssertEqual(result["json"]["action"].toString(), "update")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDELETERequest() {
        let expectation = XCTestExpectation(description: "DELETE request completion")
        
        
        let script = """
            fetch('https://httpbin.org/delete', {
                method: 'DELETE',
                headers: { 'Authorization': 'Bearer test-token' }
            })
            .then(response => {
                globalThis.deleteResult = {
                    status: response.status,
                    ok: response.ok
                };
                return response.json();
            })
            .then(data => {
                globalThis.deleteResult.method = data.method;
            });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.deleteResult")
            XCTAssertEqual(result["status"].numberValue, 200)
            XCTAssertTrue(result["ok"].boolValue ?? false)
            XCTAssertEqual(result["method"].toString(), "DELETE")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Header Tests
    
    func testRequestHeaders() {
        let expectation = XCTestExpectation(description: "Request headers test")
        
        
        let script = """
            fetch('https://httpbin.org/headers', {
                headers: {
                    'X-Custom-Header': 'SwiftJS-Test',
                    'User-Agent': 'SwiftJS/1.0',
                    'Accept': 'application/json'
                }
            })
            .then(response => response.json())
            .then(data => {
                globalThis.headersResult = {
                    customHeader: data.headers['X-Custom-Header'],
                    userAgent: data.headers['User-Agent'],
                    accept: data.headers['Accept']
                };
            });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.headersResult")
            XCTAssertEqual(result["customHeader"].toString(), "SwiftJS-Test")
            XCTAssertEqual(result["userAgent"].toString(), "SwiftJS/1.0")
            XCTAssertEqual(result["accept"].toString(), "application/json")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Response Type Tests
    
    func testJSONResponse() {
        let expectation = XCTestExpectation(description: "JSON response test")
        
        
        let script = """
            fetch('https://httpbin.org/json')
                .then(response => response.json())
                .then(data => {
                    globalThis.jsonResult = {
                        hasSlideshow: !!data.slideshow,
                        author: data.slideshow?.author
                    };
                });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.jsonResult")
            XCTAssertTrue(result["hasSlideshow"].boolValue ?? false)
            XCTAssertEqual(result["author"].toString(), "Yours Truly")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testTextResponse() {
        let expectation = XCTestExpectation(description: "Text response test")
        
        
        let script = """
            fetch('https://httpbin.org/robots.txt')
                .then(response => response.text())
                .then(text => {
                    globalThis.textResult = {
                        isString: typeof text === 'string',
                        hasContent: text.length > 0,
                        hasUserAgent: text.includes('User-agent')
                    };
                });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.textResult")
            XCTAssertTrue(result["isString"].boolValue ?? false)
            XCTAssertTrue(result["hasContent"].boolValue ?? false)
            XCTAssertTrue(result["hasUserAgent"].boolValue ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Status Code Tests
    
    func test404Response() {
        let expectation = XCTestExpectation(description: "404 response test")
        
        
        let script = """
            fetch('https://httpbin.org/status/404')
                .then(response => {
                    globalThis.notFoundResult = {
                        status: response.status,
                        ok: response.ok,
                        statusText: response.statusText
                    };
                });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.notFoundResult")
            XCTAssertEqual(result["status"].numberValue, 404)
            XCTAssertFalse(result["ok"].boolValue ?? true)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func test500Response() {
        let expectation = XCTestExpectation(description: "500 response test")
        
        
        let script = """
            fetch('https://httpbin.org/status/500')
                .then(response => {
                    globalThis.serverErrorResult = {
                        status: response.status,
                        ok: response.ok
                    };
                });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.serverErrorResult")
            XCTAssertEqual(result["status"].numberValue, 500)
            XCTAssertFalse(result["ok"].boolValue ?? true)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testMultipleSimultaneousRequests() {
        let expectation = XCTestExpectation(description: "Multiple simultaneous requests")
        
        
        let script = """
            const requests = [
                fetch('https://httpbin.org/delay/1'),
                fetch('https://httpbin.org/get?test=1'),
                fetch('https://httpbin.org/get?test=2')
            ];
            
            Promise.all(requests)
                .then(responses => {
                    globalThis.multipleResult = {
                        count: responses.length,
                        allOk: responses.every(r => r.ok)
                    };
                });
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            let result = context.evaluateScript("globalThis.multipleResult")
            XCTAssertEqual(result["count"].numberValue, 3)
            XCTAssertTrue(result["allOk"].boolValue ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
}
