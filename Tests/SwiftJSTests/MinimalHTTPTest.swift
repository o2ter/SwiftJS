//
//  MinimalHTTPTest.swift
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

final class MinimalHTTPTest: XCTestCase {
    
    var context: SwiftJS!
    
    override func setUp() {
        super.setUp()
        context = SwiftJS()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    func testSwiftJSCanBeCreated() {
        XCTAssertNotNil(context)
    }
    
    func testBasicJavaScript() {
        let result = context.evaluateScript("2 + 2")
        XCTAssertEqual(result.numberValue, 4.0)
    }
    
    func testXMLHttpRequestExists() {
        let result = context.evaluateScript("typeof XMLHttpRequest")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFetchExists() {
        let result = context.evaluateScript("typeof fetch")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testHeadersExist() {
        let result = context.evaluateScript("typeof Headers")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testHTTPBasicTest() {
        // This is a simple test that just checks the APIs exist and can be instantiated
        let script = """
            try {
                const xhr = new XMLHttpRequest();
                const headers = new Headers();
                const request = new Request('https://example.com');
                globalThis.testSuccess = {
                    xhrReady: xhr.readyState === 0,
                    headersMethod: typeof headers.get === 'function',
                    requestUrl: request.url === 'https://example.com'
                };
            } catch (error) {
                globalThis.testSuccess = { error: error.message };
            }
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.testSuccess")
        
        XCTAssertFalse(result.isUndefined)
        XCTAssertTrue(result["xhrReady"].boolValue ?? false)
        XCTAssertTrue(result["headersMethod"].boolValue ?? false)
        XCTAssertTrue(result["requestUrl"].boolValue ?? false)
    }
}
