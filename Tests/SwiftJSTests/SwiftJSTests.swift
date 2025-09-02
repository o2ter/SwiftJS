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
    
    // Integration tests that verify the complete SwiftJS system works together
    // Individual component tests are in specialized files:
    // - CoreTests.swift: Core engine functionality
    // - WebAPIsTests.swift: Web API implementations
    // - NativeAPIsTests.swift: Native Swift APIs
    // - NetworkingTests.swift: HTTP/networking functionality
    // - FormDataTests.swift: FormData API
    // - PerformanceTests.swift: Performance benchmarks
    
    // MARK: - Integration Tests
    
    func testCompletePolyfillIntegration() {
        // Test that all polyfilled APIs are available and working together
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        let globalsList = globals.toString()

        // Core Web APIs
        XCTAssertTrue(globalsList.contains("console"))
        XCTAssertTrue(globalsList.contains("setTimeout"))
        XCTAssertTrue(globalsList.contains("clearTimeout"))
        XCTAssertTrue(globalsList.contains("setInterval"))
        XCTAssertTrue(globalsList.contains("clearInterval"))

        // Networking APIs
        XCTAssertTrue(globalsList.contains("XMLHttpRequest"))
        XCTAssertTrue(globalsList.contains("fetch"))
        XCTAssertTrue(globalsList.contains("Headers"))
        XCTAssertTrue(globalsList.contains("Request"))
        XCTAssertTrue(globalsList.contains("Response"))
        XCTAssertTrue(globalsList.contains("FormData"))

        // Text APIs
        XCTAssertTrue(globalsList.contains("TextEncoder"))
        XCTAssertTrue(globalsList.contains("TextDecoder"))

        // Event APIs
        XCTAssertTrue(globalsList.contains("EventTarget"))
        XCTAssertTrue(globalsList.contains("Event"))

        // Crypto APIs
        XCTAssertTrue(globalsList.contains("crypto"))

        // Process APIs
        XCTAssertTrue(globalsList.contains("process"))
    }
    
    func testCrossAPIIntegration() {
        // Test that different API categories work together
        let script = """
            // Combine multiple APIs in a single operation
            const encoder = new TextEncoder();
            const data = encoder.encode('test data');
            
            const formData = new FormData();
            formData.append('data', 'test');
            
            const event = new Event('test');
            const target = new EventTarget();
            
            const uuid = crypto.randomUUID();
            const pid = process.pid;
            
            // Verify all operations succeeded
            data instanceof Uint8Array &&
            formData.has('data') &&
            event instanceof Event &&
            target instanceof EventTarget &&
            typeof uuid === 'string' &&
            typeof pid === 'number'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testNativeSwiftBridgeIntegration() {
        // Test that Swift native APIs integrate properly with JavaScript polyfills
        let script = """
            // Use both polyfilled and native APIs together
            const polyfillUUID = crypto.randomUUID();
            const nativeUUID = __APPLE_SPEC__.crypto.randomUUID();
            const processId = __APPLE_SPEC__.processInfo.processIdentifier;
            const hasDeviceFunction = typeof __APPLE_SPEC__.deviceInfo.identifierForVendor;
            
            typeof polyfillUUID === 'string' &&
            typeof nativeUUID === 'string' &&
            typeof processId === 'number' &&
            hasDeviceFunction === 'function' &&
            polyfillUUID !== nativeUUID  // They should be different UUIDs
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testAsyncIntegration() {
        // Test that async operations work with the polyfill system
        let script = """
            // Test Promise integration with polyfilled APIs
            const promise = new Promise((resolve) => {
                setTimeout(() => {
                    const uuid = crypto.randomUUID();
                    resolve(uuid);
                }, 1);
            });
            
            promise instanceof Promise
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testCompleteSystemBootstrap() {
        // Test that a fresh SwiftJS context has everything needed
        let context = SwiftJS()
        
        // Verify core JavaScript features
        XCTAssertEqual(context.evaluateScript("2 + 3").numberValue, 5.0)
        XCTAssertEqual(context.evaluateScript("typeof Promise").toString(), "function")

        // Verify polyfilled APIs are available
        XCTAssertEqual(context.evaluateScript("typeof console").toString(), "object")
        XCTAssertEqual(context.evaluateScript("typeof fetch").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof crypto").toString(), "object")

        // Verify native APIs are available
        XCTAssertEqual(context.evaluateScript("typeof __APPLE_SPEC__").toString(), "object")
        XCTAssertEqual(context.evaluateScript("typeof process").toString(), "object")

        // Verify error handling works
        let errorResult = context.evaluateScript(
            """
            try {
                throw new Error("test");
            } catch (e) {
                e.message;
            }
            """)
        XCTAssertEqual(errorResult.toString(), "test")
    }
    
    func testMultiContextIsolation() {
        // Test that multiple SwiftJS contexts don't interfere with each other
        let context1 = SwiftJS()
        let context2 = SwiftJS()

        context1.evaluateScript("globalThis.testValue = 'context1'")
        context2.evaluateScript("globalThis.testValue = 'context2'")

        let result1 = context1.evaluateScript("globalThis.testValue")
        let result2 = context2.evaluateScript("globalThis.testValue")

        XCTAssertEqual(result1.toString(), "context1")
        XCTAssertEqual(result2.toString(), "context2")
    }
    
    func testPolyfillConsistency() {
        // Test that polyfills behave consistently across multiple contexts
        let context1 = SwiftJS()
        let context2 = SwiftJS()

        let uuid1 = context1.evaluateScript("crypto.randomUUID()")
        let uuid2 = context2.evaluateScript("crypto.randomUUID()")

        // Both should be valid UUIDs but different
        XCTAssertNotEqual(uuid1.toString(), uuid2.toString())
        XCTAssertTrue(uuid1.toString().count > 30)  // UUID should be long
        XCTAssertTrue(uuid2.toString().count > 30)
    }
}
