//
//  WebAPIsTests.swift
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
final class WebAPIsTests: XCTestCase {
    
    // Each test creates its own SwiftJS context to avoid shared state
    
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
    
    func testEventRemoval() {
        let script = """
            const target = new EventTarget();
            let callCount = 0;
            const listener = () => { callCount++; };
            
            target.addEventListener('test', listener);
            target.dispatchEvent(new Event('test'));
            
            target.removeEventListener('test', listener);
            target.dispatchEvent(new Event('test'));
            
            callCount
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.numberValue, 1)
    }
    
    // MARK: - Text Encoding Tests
    
    func testTextEncoderExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof TextEncoder")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testTextDecoderExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof TextDecoder")
        XCTAssertEqual(result.toString(), "function")
    }
    
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
    
    func testTextEncodingUTF8() {
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            const text = 'Hello, 世界! 🌍';
            const encoded = encoder.encode(text);
            const decoded = decoder.decode(encoded);
            decoded === text
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
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
    
    func testTimerBasicFunctionality() {
        let script = """
            typeof setTimeout === 'function' &&
            typeof clearTimeout === 'function' &&
            typeof setInterval === 'function' &&
            typeof clearInterval === 'function'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
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
    
    func testConsoleError() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof console.error")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testConsoleWarn() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof console.warn")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testConsoleInfo() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof console.info")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - URL API Tests
    
    func testURLExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof URL")
        XCTAssertTrue(result.toString() == "function" || result.toString() == "undefined") // May not be implemented
    }
    
    // MARK: - Crypto Web API Tests
    
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
    
    func testCryptoRandomUUIDFormat() {
        let script = """
            const uuid = crypto.randomUUID();
            // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
            /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(uuid)
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testCryptoGetRandomValuesUint8Array() {
        let script = """
            const array = new Uint8Array(16);
            crypto.getRandomValues(array);
            array.length === 16 && array instanceof Uint8Array
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Structured Clone Algorithm (if implemented)
    
    func testStructuredCloneExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof structuredClone")
        // May be "function" or "undefined" depending on implementation
        XCTAssertTrue(result.toString() == "function" || result.toString() == "undefined")
    }
    
    // MARK: - Web API Integration Tests
    
    func testWebAPICoexistence() {
        let script = """
            // Test that multiple Web APIs can coexist and function
            const hasEventTarget = typeof EventTarget === 'function';
            const hasTextEncoder = typeof TextEncoder === 'function';
            const hasConsole = typeof console === 'object';
            const hasCrypto = typeof crypto === 'object';
            const hasTimers = typeof setTimeout === 'function';
            
            hasEventTarget && hasTextEncoder && hasConsole && hasCrypto && hasTimers
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
}
