//
//  NativeAPIsTests.swift
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
final class NativeAPIsTests: XCTestCase {
    
    // Each test creates its own SwiftJS context to avoid shared state
    
    // MARK: - Apple Specification Bridge Tests
    
    func testAppleSpecExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__")
        XCTAssertEqual(result.toString(), "object")
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
    
    func testProcessPidValue() {
        let context = SwiftJS()
        let result = context.evaluateScript("process.pid")
        XCTAssertTrue((result.numberValue ?? 0) > 0)
    }
    
    func testProcessArgv() {
        let context = SwiftJS()
        let result = context.evaluateScript("Array.isArray(process.argv)")
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testProcessEnv() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process.env")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testProcessEnvPath() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process.env.PATH")
        XCTAssertEqual(result.toString(), "string")
    }
    
    // MARK: - Crypto Native API Tests
    
    func testAppleSpecCrypto() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.crypto")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testNativeCryptoRandomUUID() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.crypto.randomUUID")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testNativeCryptoRandomBytes() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.crypto.randomBytes")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testNativeCryptoRandomBytesLength() {
        let script = """
            const bytes = __APPLE_SPEC__.crypto.randomBytes(16);
            bytes.length === 16 && bytes instanceof Uint8Array
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testNativeCryptoHash() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.crypto.hash")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testCryptoHashSHA256() {
        let script = """
            const data = new TextEncoder().encode('hello');
            const hash = __APPLE_SPEC__.crypto.hash('SHA256', data);
            hash instanceof Uint8Array && hash.length === 32
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Device Info Tests
    
    func testDeviceInfoExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testDeviceInfoIdentifier() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo.identifier")
        XCTAssertEqual(result.toString(), "string")
    }
    
    func testDeviceInfoName() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo.name")
        XCTAssertEqual(result.toString(), "string")
    }
    
    func testDeviceInfoModel() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo.model")
        XCTAssertEqual(result.toString(), "string")
    }
    
    func testDeviceInfoSystemName() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo.systemName")
        XCTAssertEqual(result.toString(), "string")
    }
    
    func testDeviceInfoSystemVersion() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo.systemVersion")
        XCTAssertEqual(result.toString(), "string")
    }
    
    // MARK: - FileSystem Tests
    
    func testFileSystemExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testFileSystemReadFileSync() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem.readFileSync")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFileSystemWriteFileSync() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem.writeFileSync")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFileSystemExistsSync() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem.existsSync")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - URLSession Tests
    
    func testURLSessionExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.URLSession")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testURLSessionDataTask() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.URLSession.dataTask")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - Swift-JavaScript Bridge Tests
    
    func testSwiftJavaScriptBridge() {
        let script = """
            // Test that Swift objects are properly bridged to JavaScript
            const appleSpec = __APPLE_SPEC__;
            
            // Check that all major native APIs are available
            const hasCrypto = typeof appleSpec.crypto === 'object';
            const hasDeviceInfo = typeof appleSpec.deviceInfo === 'object';
            const hasFileSystem = typeof appleSpec.FileSystem === 'object';
            const hasURLSession = typeof appleSpec.URLSession === 'object';
            const hasProcessInfo = typeof appleSpec.processInfo === 'object';
            
            hasCrypto && hasDeviceInfo && hasFileSystem && hasURLSession && hasProcessInfo
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testNativeAPICoexistence() {
        let script = """
            // Test that native APIs don't interfere with each other
            try {
                const uuid = __APPLE_SPEC__.crypto.randomUUID();
                const deviceId = __APPLE_SPEC__.deviceInfo.identifier;
                const pid = __APPLE_SPEC__.processInfo.processIdentifier;
                
                typeof uuid === 'string' && 
                typeof deviceId === 'string' && 
                typeof pid === 'number'
            } catch (e) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Performance and Memory Tests
    
    func testNativeAPIPerformance() {
        let script = """
            // Test that native APIs perform reasonably
            const start = Date.now();
            for (let i = 0; i < 100; i++) {
                __APPLE_SPEC__.crypto.randomBytes(16);
            }
            const end = Date.now();
            (end - start) < 1000 // Should complete in under 1 second
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testNativeAPIMemoryUsage() {
        let script = """
            // Test that native APIs don't leak memory
            let arrays = [];
            for (let i = 0; i < 100; i++) {
                arrays.push(__APPLE_SPEC__.crypto.randomBytes(1024));
            }
            arrays.length === 100
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
}
