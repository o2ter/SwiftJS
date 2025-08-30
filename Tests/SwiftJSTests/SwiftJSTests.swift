//
//  SwiftJSTests.swift
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

final class SwiftJSTests: XCTestCase {
    
    var context: SwiftJS!
    
    override func setUp() {
        super.setUp()
        context = SwiftJS()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    // MARK: - Core SwiftJS Tests
    
    func testSwiftJSCreation() {
        XCTAssertNotNil(context)
        XCTAssertNotNil(context.globalObject)
    }
    
    func testBasicJavaScriptExecution() {
        let result = context.evaluateScript("2 + 3")
        XCTAssertEqual(result.numberValue, 5.0)
    }
    
    func testGlobalObjectsExist() {
        // Test that our polyfill objects are available
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("XMLHttpRequest"))
        XCTAssertTrue(globals.toString().contains("fetch"))
        XCTAssertTrue(globals.toString().contains("Headers"))
        XCTAssertTrue(globals.toString().contains("Request"))
        XCTAssertTrue(globals.toString().contains("Response"))
    }
    
    // MARK: - XMLHttpRequest Tests
    
    func testXMLHttpRequestExists() {
        let result = context.evaluateScript("typeof XMLHttpRequest")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testXMLHttpRequestInstantiation() {
        let result = context.evaluateScript("""
            const xhr = new XMLHttpRequest();
            xhr.readyState
        """)
        XCTAssertEqual(result.numberValue, 0) // UNSENT state
    }
    
    func testXMLHttpRequestConstants() {
        let script = """
            [
                XMLHttpRequest.UNSENT,
                XMLHttpRequest.OPENED,
                XMLHttpRequest.HEADERS_RECEIVED,
                XMLHttpRequest.LOADING,
                XMLHttpRequest.DONE
            ]
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result[0].numberValue, 0)
        XCTAssertEqual(result[1].numberValue, 1)
        XCTAssertEqual(result[2].numberValue, 2)
        XCTAssertEqual(result[3].numberValue, 3)
        XCTAssertEqual(result[4].numberValue, 4)
    }
    
    func testXMLHttpRequestOpen() {
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://httpbin.org/json');
            xhr.readyState
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.numberValue, 1) // OPENED state
    }
    
    func testXMLHttpRequestSetRequestHeader() {
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://httpbin.org/json');
            xhr.setRequestHeader('Content-Type', 'application/json');
            'success'
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "success")
    }
    
    func testXMLHttpRequestAsyncRequest() {
        let expectation = XCTestExpectation(description: "XMLHttpRequest async completion")
        let testContext = context  // Capture context to avoid self capture
        
        let script = """
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://httpbin.org/json');
            xhr.onload = function() {
                globalThis.testResult = {
                    status: xhr.status,
                    readyState: xhr.readyState,
                    responseLength: xhr.responseText.length
                };
            };
            xhr.onerror = function() {
                globalThis.testResult = { error: true };
            };
            xhr.send();
        """
        
        context.evaluateScript(script)
        
        // Wait for the async request to complete
        Task { @MainActor in
            try await Task.sleep(for: .seconds(3))
            let result = context.evaluateScript("globalThis.testResult")
            XCTAssertFalse(result.isUndefined)
            XCTAssertEqual(result["status"].numberValue, 200)
            XCTAssertEqual(result["readyState"].numberValue, 4) // DONE
            XCTAssertTrue((result["responseLength"].numberValue ?? 0) > 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - fetch API Tests
    
    func testFetchExists() {
        let result = context.evaluateScript("typeof fetch")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFetchReturnsPromise() {
        let script = """
            const promise = fetch('https://httpbin.org/json');
            promise instanceof Promise
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFetchAPI() {
        let expectation = XCTestExpectation(description: "Fetch API async completion")
        let testContext = context  // Capture context to avoid self capture
        
        let script = """
            fetch('https://httpbin.org/json')
                .then(response => response.json())
                .then(data => {
                    globalThis.fetchResult = {
                        success: true,
                        hasData: data !== null,
                        type: typeof data
                    };
                })
                .catch(error => {
                    globalThis.fetchResult = { error: error.message };
                });
        """
        
        context.evaluateScript(script)
        
        // Wait for the async request to complete
        Task { @MainActor in
            try await Task.sleep(for: .seconds(3))
            let result = context.evaluateScript("globalThis.fetchResult")
            XCTAssertFalse(result.isUndefined)
            XCTAssertTrue(result["success"].boolValue ?? false)
            XCTAssertTrue(result["hasData"].boolValue ?? false)
            XCTAssertEqual(result["type"].stringValue, "object")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchPOSTRequest() {
        let expectation = XCTestExpectation(description: "fetch POST completion")
        let testContext = context  // Capture context to avoid self capture
        
        let script = """
            fetch('https://httpbin.org/post', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ test: 'data', framework: 'SwiftJS' })
            })
            .then(response => response.json())
            .then(data => {
                globalThis.postResult = {
                    success: true,
                    json: data.json,
                    method: data.method
                };
            })
            .catch(error => {
                globalThis.postResult = { error: error.message };
            });
        """
        
        context.evaluateScript(script)
        
        // Wait for the async request to complete
        Task { @MainActor in
            try await Task.sleep(for: .seconds(3.0))
            let result = context.evaluateScript("globalThis.postResult")
            XCTAssertFalse(result.isUndefined)
            XCTAssertTrue(result["success"].boolValue ?? false)
            XCTAssertEqual(result["method"].toString(), "POST")
            XCTAssertEqual(result["json"]["framework"].toString(), "SwiftJS")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Headers Tests
    
    func testHeadersInstantiation() {
        let script = """
            const headers = new Headers();
            headers instanceof Headers
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testHeadersSetAndGet() {
        let script = """
            const headers = new Headers();
            headers.set('Content-Type', 'application/json');
            headers.get('content-type') // Should be case-insensitive
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "application/json")
    }
    
    func testHeadersFromObject() {
        let script = """
            const headers = new Headers({
                'Authorization': 'Bearer token123',
                'Content-Type': 'application/json'
            });
            [headers.has('authorization'), headers.get('authorization')]
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result[0].boolValue ?? false)
        XCTAssertEqual(result[1].toString(), "Bearer token123")
    }
    
    // MARK: - Request Tests
    
    func testRequestInstantiation() {
        let script = """
            const request = new Request('https://example.com');
            [request.url, request.method]
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result[0].toString(), "https://example.com")
        XCTAssertEqual(result[1].toString(), "GET")
    }
    
    func testRequestWithOptions() {
        let script = """
            const request = new Request('https://example.com', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ key: 'value' })
            });
            [request.method, request.headers.get('content-type')]
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result[0].toString(), "POST")
        XCTAssertEqual(result[1].toString(), "application/json")
    }
    
    // MARK: - Response Tests
    
    func testResponseInstantiation() {
        let script = """
            const response = new Response('{"test": true}', {
                status: 200,
                headers: { 'Content-Type': 'application/json' }
            });
            [response.status, response.ok, response.headers.get('content-type')]
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result[0].numberValue, 200)
        XCTAssertTrue(result[1].boolValue ?? false)
        XCTAssertEqual(result[2].toString(), "application/json")
    }
    
    func testResponseTextMethod() {
        let expectation = XCTestExpectation(description: "response.text() completion")
        let testContext = context  // Capture context to avoid self capture
        
        let script = """
            const response = new Response('Hello, SwiftJS!');
            response.text().then(text => {
                globalThis.responseTextResult = text;
            });
        """
        
        context.evaluateScript(script)
        
        Task { @MainActor in
            try await Task.sleep(for: .seconds(0.1))
            let result = context.evaluateScript("globalThis.responseTextResult")
            XCTAssertEqual(result.toString(), "Hello, SwiftJS!")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testResponseJSONMethod() {
        let expectation = XCTestExpectation(description: "response.json() completion")
        let testContext = context  // Capture context to avoid self capture
        
        let script = """
            const response = new Response('{"message": "Hello", "framework": "SwiftJS"}');
            response.json().then(data => {
                globalThis.responseJsonResult = data;
            });
        """
        
        context.evaluateScript(script)
        
        Task { @MainActor in
            try await Task.sleep(for: .seconds(0.1))
            let result = context.evaluateScript("globalThis.responseJsonResult")
            XCTAssertEqual(result["message"].toString(), "Hello")
            XCTAssertEqual(result["framework"].toString(), "SwiftJS")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Event System Tests
    
    func testEventTargetInstantiation() {
        let script = """
            const target = new EventTarget();
            target instanceof EventTarget
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testEventListeners() {
        let script = """
            const target = new EventTarget();
            let fired = false;
            target.addEventListener('test', () => { fired = true; });
            target.dispatchEvent(new Event('test'));
            fired
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Text Encoding Tests
    
    func testTextEncoder() {
        let script = """
            const encoder = new TextEncoder();
            const encoded = encoder.encode('Hello, 世界!');
            encoded instanceof Uint8Array
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testTextDecoder() {
        let script = """
            const decoder = new TextDecoder();
            const encoder = new TextEncoder();
            const encoded = encoder.encode('Hello, SwiftJS!');
            const decoded = decoder.decode(encoded);
            decoded
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "Hello, SwiftJS!")
    }
    
    // MARK: - Error Handling Tests
    
    func testXMLHttpRequestErrorHandling() {
        let script = """
            const xhr = new XMLHttpRequest();
            try {
                xhr.setRequestHeader('Test', 'value'); // Should fail - not opened
                false
            } catch (error) {
                error.message.includes('InvalidStateError')
            }
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFetchInvalidURL() {
        let expectation = XCTestExpectation(description: "fetch error handling")
        let testContext = context  // Capture context to avoid self capture
        
        let script = """
            fetch('invalid://url')
                .then(() => {
                    globalThis.fetchErrorResult = { success: true };
                })
                .catch(error => {
                    globalThis.fetchErrorResult = { error: true, message: error.message };
                });
        """
        
        context.evaluateScript(script)
        
        Task { @MainActor in
            try await Task.sleep(for: .seconds(2.0))
            let result = context.evaluateScript("globalThis.fetchErrorResult")
            XCTAssertTrue(result["error"].boolValue ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Integration Tests
    
    func testXMLHttpRequestAndFetchCompatibility() {
        let expectation = XCTestExpectation(description: "XHR and fetch both work")
        let testContext = context  // Capture context to avoid self capture
        var xhrCompleted = false
        var fetchCompleted = false
        
        let script = """
            // Test XMLHttpRequest
            const xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://httpbin.org/json');
            xhr.onload = function() {
                globalThis.xhrDone = xhr.status === 200;
            };
            xhr.send();
            
            // Test fetch
            fetch('https://httpbin.org/json')
                .then(response => {
                    globalThis.fetchDone = response.ok;
                });
        """
        
        context.evaluateScript(script)
        
        // Check both completed successfully
        Task { @MainActor in
            try await Task.sleep(for: .seconds(3.0))
            xhrCompleted = context.evaluateScript("globalThis.xhrDone").boolValue ?? false
            fetchCompleted = context.evaluateScript("globalThis.fetchDone").boolValue ?? false
            
            XCTAssertTrue(xhrCompleted, "XMLHttpRequest should complete successfully")
            XCTAssertTrue(fetchCompleted, "fetch should complete successfully")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
