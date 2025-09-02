//
//  CoreTests.swift
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
final class CoreTests: XCTestCase {
    
    // Each test creates its own SwiftJS context to avoid shared state
    
    // MARK: - SwiftJS Engine Tests
    
    func testSwiftJSCreation() {
        let context = SwiftJS()
        XCTAssertNotNil(context)
        XCTAssertNotNil(context.globalObject)
    }
    
    func testBasicJavaScriptExecution() {
        let context = SwiftJS()
        let result = context.evaluateScript("2 + 3")
        XCTAssertEqual(result.numberValue, 5.0)
    }
    
    func testBasicJavaScript() {
        let context = SwiftJS()
        let result = context.evaluateScript("2 + 2")
        XCTAssertEqual(result.numberValue, 4.0)
    }
    
    func testGlobalObjectsExist() {
        // Test that our polyfill objects are available
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        let globalsString = globals.toString()
        
        // Core JavaScript APIs
        XCTAssertTrue(globalsString.contains("console"))
        XCTAssertTrue(globalsString.contains("setTimeout"))
        XCTAssertTrue(globalsString.contains("clearTimeout"))
        XCTAssertTrue(globalsString.contains("setInterval"))
        XCTAssertTrue(globalsString.contains("clearInterval"))
        
        // Network APIs
        XCTAssertTrue(globalsString.contains("XMLHttpRequest"))
        XCTAssertTrue(globalsString.contains("fetch"))
        XCTAssertTrue(globalsString.contains("Headers"))
        XCTAssertTrue(globalsString.contains("Request"))
        XCTAssertTrue(globalsString.contains("Response"))
        XCTAssertTrue(globalsString.contains("FormData"))
        
        // Web APIs
        XCTAssertTrue(globalsString.contains("EventTarget"))
        XCTAssertTrue(globalsString.contains("TextEncoder"))
        XCTAssertTrue(globalsString.contains("TextDecoder"))
    }
    
    // MARK: - JavaScript Language Features
    
    func testPromiseExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Promise")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testPromiseCreation() {
        let script = """
            const promise = new Promise((resolve, reject) => {
                resolve('test');
            });
            promise instanceof Promise
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testJavaScriptExceptionHandling() {
        let context = SwiftJS()
        let result = context.evaluateScript("""
            try {
                throw new Error("Test error");
            } catch (e) {
                e.message;
            }
        """)
        XCTAssertEqual(result.toString(), "Test error")
    }
    
    func testUndefinedVariableAccess() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof undefinedVariable")
        XCTAssertEqual(result.toString(), "undefined")
    }
    
    // MARK: - Value Marshaling Tests
    
    func testStringMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("'Hello, SwiftJS!'")
        XCTAssertEqual(result.toString(), "Hello, SwiftJS!")
    }
    
    func testNumberMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("42.5")
        XCTAssertEqual(result.numberValue, 42.5)
    }
    
    func testBooleanMarshaling() {
        let context = SwiftJS()
        let trueResult = context.evaluateScript("true")
        let falseResult = context.evaluateScript("false")
        XCTAssertTrue(trueResult.boolValue ?? false)
        XCTAssertFalse(falseResult.boolValue ?? true)
    }
    
    func testArrayMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("[1, 2, 3, 'test']")
        XCTAssertEqual(result[0].numberValue, 1)
        XCTAssertEqual(result[1].numberValue, 2)
        XCTAssertEqual(result[2].numberValue, 3)
        XCTAssertEqual(result[3].toString(), "test")
    }
    
    func testObjectMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("({ name: 'SwiftJS', version: 1.0 })")
        XCTAssertEqual(result["name"].toString(), "SwiftJS")
        XCTAssertEqual(result["version"].numberValue, 1.0)
    }
    
    // MARK: - Basic API Compatibility Tests
    
    func testHTTPBasicAPITest() {
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
        
        let context = SwiftJS()
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.testSuccess")
        
        XCTAssertFalse(result.isUndefined)
        XCTAssertTrue(result["xhrReady"].boolValue ?? false)
        XCTAssertTrue(result["headersMethod"].boolValue ?? false)
        XCTAssertTrue(result["requestUrl"].boolValue ?? false)
    }
}
