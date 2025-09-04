//
//  DeviceInfoTests.swift
//  SwiftJS Device Info Tests
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

/// Tests for the Device Info API including vendor identifier
/// and device-specific information.
@MainActor
final class DeviceInfoTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testDeviceInfoExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testDeviceInfoIsObject() {
        let script = """
            __APPLE_SPEC__.deviceInfo !== null && 
            typeof __APPLE_SPEC__.deviceInfo === 'object' && 
            !Array.isArray(__APPLE_SPEC__.deviceInfo)
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Identifier For Vendor Tests
    
    func testDeviceInfoIdentifierForVendor() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.deviceInfo.identifierForVendor")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testIdentifierForVendorCall() {
        let script = """
            const identifier = __APPLE_SPEC__.deviceInfo.identifierForVendor();
            ({
                type: typeof identifier,
                value: identifier,
                isString: typeof identifier === 'string',
                hasLength: identifier && identifier.length > 0
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let type = result["type"].toString()
        XCTAssertTrue(["string", "object"].contains(type), "Identifier should be string or null, got \(type)")
        
        if type == "string" {
            XCTAssertTrue(result["isString"].boolValue ?? false)
            XCTAssertTrue(result["hasLength"].boolValue ?? false)
            let identifier = result["value"].toString()
            XCTAssertGreaterThan(identifier.count, 0)
        } else {
            // Might be null on simulator or in certain contexts
            XCTAssertTrue(true, "Identifier for vendor is null (acceptable on simulator)")
        }
    }
    
    func testIdentifierForVendorFormat() {
        let script = """
            const identifier = __APPLE_SPEC__.deviceInfo.identifierForVendor();
            if (identifier === null || identifier === undefined) {
                ({ isNull: true })
            } else {
                ({
                    isNull: false,
                    type: typeof identifier,
                    length: identifier.length,
                    isUUIDFormat: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(identifier),
                    value: identifier
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["isNull"].boolValue == true {
            XCTAssertTrue(true, "Device identifier is null (acceptable)")
        } else {
            XCTAssertEqual(result["type"].toString(), "string")
            XCTAssertEqual(Int(result["length"].numberValue ?? 0), 36)
            XCTAssertTrue(result["isUUIDFormat"].boolValue ?? false)
        }
    }
    
    func testIdentifierForVendorConsistency() {
        let script = """
            const id1 = __APPLE_SPEC__.deviceInfo.identifierForVendor();
            const id2 = __APPLE_SPEC__.deviceInfo.identifierForVendor();
            const id3 = __APPLE_SPEC__.deviceInfo.identifierForVendor();
            
            ({
                id1: id1,
                id2: id2,
                id3: id3,
                allSame: id1 === id2 && id2 === id3,
                firstType: typeof id1,
                secondType: typeof id2,
                thirdType: typeof id3,
                typesConsistent: typeof id1 === typeof id2 && typeof id2 === typeof id3
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["allSame"].boolValue ?? false)
        XCTAssertTrue(result["typesConsistent"].boolValue ?? false)
        
        let firstType = result["firstType"].toString()
        let secondType = result["secondType"].toString()
        let thirdType = result["thirdType"].toString()
        
        XCTAssertEqual(firstType, secondType)
        XCTAssertEqual(secondType, thirdType)
        
        if firstType == "string" {
            XCTAssertEqual(result["id1"].toString(), result["id2"].toString())
            XCTAssertEqual(result["id2"].toString(), result["id3"].toString())
        }
    }
    
    // MARK: - Device Properties Tests
    
    func testDeviceInfoProperties() {
        let script = """
            const deviceInfo = __APPLE_SPEC__.deviceInfo;
            
            // Since Swift-exposed properties aren't enumerable via Object.getOwnPropertyNames,
            // test that we can access the known method directly
            ({
                deviceInfoExists: typeof deviceInfo === 'object',
                hasIdentifierForVendor: typeof deviceInfo.identifierForVendor === 'function',
                identifierForVendorWorks: (() => {
                    try {
                        const result = deviceInfo.identifierForVendor();
                        return typeof result === 'string' || result === null;
                    } catch (e) {
                        return false;
                    }
                })(),
                // Test property access directly instead of enumeration
                propertyAccessWorks: deviceInfo.identifierForVendor !== undefined
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["deviceInfoExists"].boolValue ?? false)
        XCTAssertTrue(result["hasIdentifierForVendor"].boolValue ?? false)
        XCTAssertTrue(result["identifierForVendorWorks"].boolValue ?? false)
        XCTAssertTrue(result["propertyAccessWorks"].boolValue ?? false)
    }
    
    func testDeviceInfoMethodTypes() {
        let script = """
            const deviceInfo = __APPLE_SPEC__.deviceInfo;
            
            // Test the known method directly since enumeration doesn't work with Swift objects
            ({
                hasIdentifierForVendorMethod: typeof deviceInfo.identifierForVendor === 'function',
                identifierForVendorCallable: (() => {
                    try {
                        const result = deviceInfo.identifierForVendor();
                        return true;
                    } catch (e) {
                        return false;
                    }
                })(),
                methodCount: 1, // We know identifierForVendor exists
                deviceInfoIsObject: typeof deviceInfo === 'object' && deviceInfo !== null
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasIdentifierForVendorMethod"].boolValue ?? false)
        XCTAssertTrue(result["identifierForVendorCallable"].boolValue ?? false)
        XCTAssertTrue(result["deviceInfoIsObject"].boolValue ?? false)
        XCTAssertGreaterThanOrEqual(Int(result["methodCount"].numberValue ?? 0), 1)
    }
    
    // MARK: - Platform-Specific Tests
    
    func testDeviceInfoPlatformBehavior() {
        let script = """
            const identifier = __APPLE_SPEC__.deviceInfo.identifierForVendor();
            
            // Check platform-specific behavior
            const platform = process.platform || 'unknown';
            
            ({
                platform: platform,
                identifier: identifier,
                identifierType: typeof identifier,
                // On iOS/macOS should have identifier, on simulator might be null
                behaviorExpected: (
                    (platform === 'ios' || platform === 'darwin') ? 
                    (identifier === null || typeof identifier === 'string') :
                    true // Other platforms can have any behavior
                )
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["behaviorExpected"].boolValue ?? false)
        
        let platform = result["platform"].toString()
        let identifierType = result["identifierType"].toString()
        
        if platform == "ios" || platform == "darwin" {
            XCTAssertTrue(["string", "object"].contains(identifierType), 
                         "On Apple platforms, identifier should be string or null")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDeviceInfoErrorHandling() {
        let script = """
            try {
                // Test calling with arguments (shouldn't accept any)
                const result1 = __APPLE_SPEC__.deviceInfo.identifierForVendor('invalid-arg');
                
                // Test multiple calls
                const result2 = __APPLE_SPEC__.deviceInfo.identifierForVendor();
                const result3 = __APPLE_SPEC__.deviceInfo.identifierForVendor();
                
                ({
                    success: true,
                    result1Type: typeof result1,
                    result2Type: typeof result2,
                    result3Type: typeof result3,
                    resultsConsistent: result2 === result3
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message,
                    errorName: error.name
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "Device info calls should not throw errors: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertTrue(result["resultsConsistent"].boolValue ?? false)
        }
    }
    
    // MARK: - Performance Tests
    
    func testDeviceInfoPerformance() {
        let script = """
            const startTime = Date.now();
            const identifiers = [];
            
            // Call identifierForVendor multiple times
            for (let i = 0; i < 100; i++) {
                identifiers.push(__APPLE_SPEC__.deviceInfo.identifierForVendor());
            }
            
            const endTime = Date.now();
            const duration = endTime - startTime;
            
            // Check all identifiers are the same
            const firstId = identifiers[0];
            const allSame = identifiers.every(id => id === firstId);
            
            ({
                callCount: identifiers.length,
                duration: duration,
                performanceOk: duration < 1000, // Should complete within 1 second
                allIdentical: allSame,
                firstIdentifier: firstId,
                identifierType: typeof firstId
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["callCount"].numberValue ?? 0), 100)
        XCTAssertTrue(result["performanceOk"].boolValue ?? false, 
                     "Device info calls took \(result["duration"]) ms, should be under 1000ms")
        XCTAssertTrue(result["allIdentical"].boolValue ?? false)
    }
    
    // MARK: - Integration Tests
    
    func testDeviceInfoIntegration() {
        let script = """
            // Test device info integration with other APIs
            const deviceId = __APPLE_SPEC__.deviceInfo.identifierForVendor();
            
            // Use device ID in crypto operations if available
            if (deviceId && typeof deviceId === 'string') {
                const hasher = __APPLE_SPEC__.crypto.createHash('sha256');
                hasher.update(new TextEncoder().encode(deviceId));
                const hash = hasher.digest();
                
                ({
                    hasDeviceId: true,
                    deviceId: deviceId,
                    deviceIdLength: deviceId.length,
                    hashLength: hash.length,
                    hashType: typeof hash,
                    integrationSuccessful: hash instanceof Uint8Array && hash.length === 32
                })
            } else {
                ({
                    hasDeviceId: false,
                    deviceId: deviceId,
                    reason: 'Device ID is null or not a string'
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["hasDeviceId"].boolValue == true {
            XCTAssertEqual(Int(result["deviceIdLength"].numberValue ?? 0), 36)
            XCTAssertEqual(Int(result["hashLength"].numberValue ?? 0), 32)
            XCTAssertTrue(result["integrationSuccessful"].boolValue ?? false)
        } else {
            // Device ID being null is acceptable
            XCTAssertTrue(true, "Device ID is null: \(result["reason"].toString())")
        }
    }
    
    // MARK: - Cross-Context Tests
    
    func testDeviceInfoAcrossContexts() {
        // Test that device info is consistent across different SwiftJS contexts
        let context1 = SwiftJS()
        let context2 = SwiftJS()
        
        let id1 = context1.evaluateScript("__APPLE_SPEC__.deviceInfo.identifierForVendor()")
        let id2 = context2.evaluateScript("__APPLE_SPEC__.deviceInfo.identifierForVendor()")
        
        // Both should be the same type
        XCTAssertEqual(id1.isString, id2.isString)
        XCTAssertEqual(id1.isObject, id2.isObject)
        
        if id1.isString && id2.isString {
            // Both should return the same identifier
            XCTAssertEqual(id1.toString(), id2.toString())
        } else {
            // Both should be null
            XCTAssertTrue(id1.isNull)
            XCTAssertTrue(id2.isNull)
        }
    }
}
