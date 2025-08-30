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
    
    func testFormDataExists() {
        let result = context.evaluateScript("typeof FormData")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFormDataBasicFunctionality() {
        let script = """
            try {
                const formData = new FormData();
                formData.append('name', 'John Doe');
                formData.append('age', '30');
                formData.append('email', 'john@example.com');
                
                globalThis.formDataTest = {
                    hasName: formData.has('name'),
                    getName: formData.get('name'),
                    hasAge: formData.has('age'),
                    getAge: formData.get('age'),
                    hasEmail: formData.has('email'),
                    getEmail: formData.get('email'),
                    hasNonExistent: formData.has('nonexistent'),
                    getNonExistent: formData.get('nonexistent'),
                    iterableLength: [...formData.entries()].length
                };
            } catch (error) {
                globalThis.formDataTest = { error: error.message };
            }
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.formDataTest")
        
        XCTAssertFalse(result.isUndefined)
        XCTAssertTrue(result["hasName"].boolValue ?? false)
        XCTAssertEqual(result["getName"].toString(), "John Doe")
        XCTAssertTrue(result["hasAge"].boolValue ?? false)
        XCTAssertEqual(result["getAge"].toString(), "30")
        XCTAssertTrue(result["hasEmail"].boolValue ?? false)
        XCTAssertEqual(result["getEmail"].toString(), "john@example.com")
        XCTAssertFalse(result["hasNonExistent"].boolValue ?? true)
        XCTAssertEqual(result["getNonExistent"].numberValue, 0) // null becomes 0 in JavaScript conversion
        XCTAssertEqual(result["iterableLength"].numberValue, 3)
    }
    
    func testFormDataMultipleValues() {
        let script = """
            try {
                const formData = new FormData();
                formData.append('color', 'red');
                formData.append('color', 'blue');
                formData.append('color', 'green');
                
                globalThis.multiValueTest = {
                    firstColor: formData.get('color'),
                    allColors: formData.getAll('color'),
                    allColorsLength: formData.getAll('color').length
                };
            } catch (error) {
                globalThis.multiValueTest = { error: error.message };
            }
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.multiValueTest")
        
        XCTAssertFalse(result.isUndefined)
        XCTAssertEqual(result["firstColor"].toString(), "red")
        XCTAssertEqual(result["allColorsLength"].numberValue, 3)
        
        let allColors = result["allColors"]
        XCTAssertEqual(allColors[0].toString(), "red")
        XCTAssertEqual(allColors[1].toString(), "blue")
        XCTAssertEqual(allColors[2].toString(), "green")
    }
    
    func testFormDataWithFetch() {
        let script = """
            try {
                const formData = new FormData();
                formData.append('username', 'testuser');
                formData.append('message', 'Hello from SwiftJS!');
                
                // Create a request with FormData
                const request = new Request('https://httpbin.org/post', {
                    method: 'POST',
                    body: formData
                });
                
                globalThis.formDataFetchTest = {
                    requestMethod: request.method,
                    requestUrl: request.url,
                    hasBody: request.body !== null,
                    bodyIsFormData: request.body instanceof FormData
                };
            } catch (error) {
                globalThis.formDataFetchTest = { error: error.message };
            }
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.formDataFetchTest")
        
        XCTAssertFalse(result.isUndefined)
        XCTAssertEqual(result["requestMethod"].toString(), "POST")
        XCTAssertEqual(result["requestUrl"].toString(), "https://httpbin.org/post")
        XCTAssertTrue(result["hasBody"].boolValue ?? false)
        XCTAssertTrue(result["bodyIsFormData"].boolValue ?? false)
    }
}
