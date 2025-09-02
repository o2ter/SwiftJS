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

@MainActor
final class SwiftJSTests: XCTestCase {
    
    // Each test creates its own SwiftJS context to avoid shared state
    
    // MARK: - Core SwiftJS Tests
    
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
    
    func testGlobalObjectsExist() {
        // Test that our polyfill objects are available
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("console"))
        XCTAssertTrue(globals.toString().contains("setTimeout"))
        XCTAssertTrue(globals.toString().contains("clearTimeout"))
        XCTAssertTrue(globals.toString().contains("setInterval"))
        XCTAssertTrue(globals.toString().contains("clearInterval"))
        // Network APIs are tested in NetworkingTests.swift
        XCTAssertTrue(globals.toString().contains("XMLHttpRequest"))
        XCTAssertTrue(globals.toString().contains("fetch"))
        XCTAssertTrue(globals.toString().contains("Headers"))
        XCTAssertTrue(globals.toString().contains("Request"))
        XCTAssertTrue(globals.toString().contains("Response"))
    }
    
    // MARK: - Event System Tests
    
    func testEventTargetInstantiation() {
        let script = """
            const target = new EventTarget();
            target instanceof EventTarget
        """
        let context = SwiftJS()
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
        let context = SwiftJS()
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
        let context = SwiftJS()
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
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "Hello, SwiftJS!")
    }

    // MARK: - Timer Tests
    
    func testSetTimeoutExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof setTimeout")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testSetIntervalExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof setInterval")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testClearTimeoutExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof clearTimeout")
        XCTAssertEqual(result.toString(), "function")
    }

    func testClearIntervalExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof clearInterval")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - Console Tests

    func testConsoleExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof console")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testConsoleLog() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof console.log")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - Promise Tests

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
    
    // MARK: - Crypto API Tests
    
    func testCryptoExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof crypto")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testCryptoRandomUUID() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof crypto.randomUUID")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testCryptoGetRandomValues() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof crypto.getRandomValues")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - Process Info Tests

    func testProcessExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process")
        XCTAssertEqual(result.toString(), "object")
    }

    func testProcessPid() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process.pid")
        XCTAssertEqual(result.toString(), "number")
    }
    
    // MARK: - Global Native API Tests

    func testAppleSpecExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__")
        XCTAssertEqual(result.toString(), "object")
    }

    func testAppleSpecCrypto() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.crypto")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testAppleSpecProcessInfo() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.processInfo")
        XCTAssertEqual(result.toString(), "object")
    }
    
    // MARK: - Bridge Performance Tests
    
    func testSwiftJavaScriptBridgeBasic() {
        let context = SwiftJS()
        let result = context.evaluateScript("__APPLE_SPEC__.processInfo.processIdentifier")
        XCTAssertTrue((result.numberValue ?? 0) > 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testJavaScriptExceptionHandling() {
        let context = SwiftJS()
        let result = context.evaluateScript(
            """
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
}
