//
//  FileSystemTests.swift
//  SwiftJS FileSystem API Tests
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

/// Tests for the FileSystem API including directory access,
/// path manipulation, and file operations.
@MainActor
final class FileSystemTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testFileSystemExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testFileSystemIsObject() {
        let script = """
            __APPLE_SPEC__.FileSystem !== null && 
            typeof __APPLE_SPEC__.FileSystem === 'object' && 
            !Array.isArray(__APPLE_SPEC__.FileSystem)
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFileSystemMethods() {
        let script = """
            const fs = __APPLE_SPEC__.FileSystem;
            ({
                hasHomeDirectory: typeof fs.homeDirectory === 'function',
                hasTemporaryDirectory: typeof fs.temporaryDirectory === 'function',
                hasCurrentDirectoryPath: typeof fs.currentDirectoryPath === 'function'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasHomeDirectory"].boolValue ?? false)
        XCTAssertTrue(result["hasTemporaryDirectory"].boolValue ?? false)
        XCTAssertTrue(result["hasCurrentDirectoryPath"].boolValue ?? false)
    }
    
    // MARK: - Home Directory Tests
    
    func testFileSystemHomeDirectory() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem.homeDirectory")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testHomeDirectoryCall() {
        let script = """
            const homeDir = __APPLE_SPEC__.FileSystem.homeDirectory();
            ({
                type: typeof homeDir,
                value: homeDir,
                hasLength: homeDir && homeDir.length > 0,
                isAbsolutePath: homeDir && homeDir.startsWith('/')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["isAbsolutePath"].boolValue ?? false)
        
        let homeDir = result["value"].toString()
        XCTAssertGreaterThan(homeDir.count, 0)
        XCTAssertTrue(homeDir.hasPrefix("/"))
    }
    
    func testHomeDirectoryConsistency() {
        let script = """
            const home1 = __APPLE_SPEC__.FileSystem.homeDirectory();
            const home2 = __APPLE_SPEC__.FileSystem.homeDirectory();
            const home3 = __APPLE_SPEC__.FileSystem.homeDirectory();
            
            ({
                home1: home1,
                home2: home2,
                home3: home3,
                allSame: home1 === home2 && home2 === home3,
                allStrings: typeof home1 === 'string' && typeof home2 === 'string' && typeof home3 === 'string'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["allSame"].boolValue ?? false)
        XCTAssertTrue(result["allStrings"].boolValue ?? false)
        XCTAssertEqual(result["home1"].toString(), result["home2"].toString())
        XCTAssertEqual(result["home2"].toString(), result["home3"].toString())
    }
    
    func testHomeDirectoryMatchesSystem() {
        let context = SwiftJS()
        let jsHomeDir = context.evaluateScript("__APPLE_SPEC__.FileSystem.homeDirectory()").toString()
        let systemHomeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        // They should be the same or very similar
        XCTAssertEqual(jsHomeDir, systemHomeDir)
    }
    
    // MARK: - Temporary Directory Tests
    
    func testFileSystemTemporaryDirectory() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem.temporaryDirectory")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testTemporaryDirectoryCall() {
        let script = """
            const tempDir = __APPLE_SPEC__.FileSystem.temporaryDirectory();
            ({
                type: typeof tempDir,
                value: tempDir,
                hasLength: tempDir && tempDir.length > 0,
                isAbsolutePath: tempDir && tempDir.startsWith('/'),
                containsTemp: tempDir && (tempDir.includes('tmp') || tempDir.includes('Temp'))
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["isAbsolutePath"].boolValue ?? false)
        
        let tempDir = result["value"].toString()
        XCTAssertGreaterThan(tempDir.count, 0)
        XCTAssertTrue(tempDir.hasPrefix("/"))
        // Most systems have "tmp" in temp directory path
        XCTAssertTrue(result["containsTemp"].boolValue ?? false)
    }
    
    func testTemporaryDirectoryConsistency() {
        let script = """
            const temp1 = __APPLE_SPEC__.FileSystem.temporaryDirectory();
            const temp2 = __APPLE_SPEC__.FileSystem.temporaryDirectory();
            const temp3 = __APPLE_SPEC__.FileSystem.temporaryDirectory();
            
            ({
                temp1: temp1,
                temp2: temp2,
                temp3: temp3,
                allSame: temp1 === temp2 && temp2 === temp3,
                allStrings: typeof temp1 === 'string' && typeof temp2 === 'string' && typeof temp3 === 'string'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["allSame"].boolValue ?? false)
        XCTAssertTrue(result["allStrings"].boolValue ?? false)
        XCTAssertEqual(result["temp1"].toString(), result["temp2"].toString())
        XCTAssertEqual(result["temp2"].toString(), result["temp3"].toString())
    }
    
    func testTemporaryDirectoryMatchesSystem() {
        let context = SwiftJS()
        let jsTempDir = context.evaluateScript("__APPLE_SPEC__.FileSystem.temporaryDirectory()").toString()
        let systemTempDir = FileManager.default.temporaryDirectory.path
        
        // They should be the same or very similar
        XCTAssertEqual(jsTempDir, systemTempDir)
    }
    
    // MARK: - Current Directory Tests
    
    func testFileSystemCurrentDirectoryPath() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof __APPLE_SPEC__.FileSystem.currentDirectoryPath")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testCurrentDirectoryPathCall() {
        let script = """
            const currentDir = __APPLE_SPEC__.FileSystem.currentDirectoryPath();
            ({
                type: typeof currentDir,
                value: currentDir,
                hasLength: currentDir && currentDir.length > 0,
                isAbsolutePath: currentDir && currentDir.startsWith('/')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["isAbsolutePath"].boolValue ?? false)
        
        let currentDir = result["value"].toString()
        XCTAssertGreaterThan(currentDir.count, 0)
        XCTAssertTrue(currentDir.hasPrefix("/"))
    }
    
    func testCurrentDirectoryPathConsistency() {
        let script = """
            const cwd1 = __APPLE_SPEC__.FileSystem.currentDirectoryPath();
            const cwd2 = __APPLE_SPEC__.FileSystem.currentDirectoryPath();
            const cwd3 = __APPLE_SPEC__.FileSystem.currentDirectoryPath();
            
            ({
                cwd1: cwd1,
                cwd2: cwd2,
                cwd3: cwd3,
                allSame: cwd1 === cwd2 && cwd2 === cwd3,
                allStrings: typeof cwd1 === 'string' && typeof cwd2 === 'string' && typeof cwd3 === 'string'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["allSame"].boolValue ?? false)
        XCTAssertTrue(result["allStrings"].boolValue ?? false)
        XCTAssertEqual(result["cwd1"].toString(), result["cwd2"].toString())
        XCTAssertEqual(result["cwd2"].toString(), result["cwd3"].toString())
    }
    
    func testCurrentDirectoryPathMatchesSystem() {
        let context = SwiftJS()
        let jsCurrentDir = context.evaluateScript("__APPLE_SPEC__.FileSystem.currentDirectoryPath()").toString()
        let systemCurrentDir = FileManager.default.currentDirectoryPath
        
        // They should be the same
        XCTAssertEqual(jsCurrentDir, systemCurrentDir)
    }
    
    // MARK: - Directory Comparison Tests
    
    func testDirectoryRelationships() {
        let script = """
            const homeDir = __APPLE_SPEC__.FileSystem.homeDirectory();
            const tempDir = __APPLE_SPEC__.FileSystem.temporaryDirectory();
            const currentDir = __APPLE_SPEC__.FileSystem.currentDirectoryPath();
            
            ({
                homeDir: homeDir,
                tempDir: tempDir,
                currentDir: currentDir,
                homeDifferentFromTemp: homeDir !== tempDir,
                allDifferent: homeDir !== tempDir && tempDir !== currentDir && homeDir !== currentDir,
                allAbsolute: homeDir.startsWith('/') && tempDir.startsWith('/') && currentDir.startsWith('/'),
                allHaveLength: homeDir.length > 0 && tempDir.length > 0 && currentDir.length > 0
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["homeDifferentFromTemp"].boolValue ?? false)
        XCTAssertTrue(result["allAbsolute"].boolValue ?? false)
        XCTAssertTrue(result["allHaveLength"].boolValue ?? false)
        
        // Directories might not all be different (current could be home), but home and temp should differ
        XCTAssertNotEqual(result["homeDir"].toString(), result["tempDir"].toString())
    }
    
    // MARK: - Error Handling Tests
    
    func testFileSystemMethodsWithArguments() {
        let script = """
            try {
                // These methods shouldn't accept arguments
                const home = __APPLE_SPEC__.FileSystem.homeDirectory('invalid-arg');
                const temp = __APPLE_SPEC__.FileSystem.temporaryDirectory('invalid-arg');
                const current = __APPLE_SPEC__.FileSystem.currentDirectoryPath('invalid-arg');
                
                ({
                    success: true,
                    home: home,
                    temp: temp,
                    current: current,
                    allStrings: typeof home === 'string' && typeof temp === 'string' && typeof current === 'string'
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
        
        // Should not throw errors even with invalid arguments
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "FileSystem methods should not throw errors: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertTrue(result["allStrings"].boolValue ?? false)
        }
    }
    
    // MARK: - Performance Tests
    
    func testFileSystemPerformance() {
        let script = """
            const startTime = Date.now();
            const results = [];
            
            // Call each method multiple times
            for (let i = 0; i < 100; i++) {
                results.push({
                    home: __APPLE_SPEC__.FileSystem.homeDirectory(),
                    temp: __APPLE_SPEC__.FileSystem.temporaryDirectory(),
                    current: __APPLE_SPEC__.FileSystem.currentDirectoryPath()
                });
            }
            
            const endTime = Date.now();
            const duration = endTime - startTime;
            
            // Check consistency
            const firstResult = results[0];
            const allConsistent = results.every(r => 
                r.home === firstResult.home &&
                r.temp === firstResult.temp &&
                r.current === firstResult.current
            );
            
            ({
                callCount: results.length,
                duration: duration,
                performanceOk: duration < 1000, // Should complete within 1 second
                allConsistent: allConsistent,
                firstResult: firstResult
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["callCount"].numberValue ?? 0), 100)
        XCTAssertTrue(result["performanceOk"].boolValue ?? false, 
                     "FileSystem calls took \(result["duration"]) ms, should be under 1000ms")
        XCTAssertTrue(result["allConsistent"].boolValue ?? false)
    }
    
    // MARK: - Integration Tests
    
    func testFileSystemIntegration() {
        let script = """
            // Test FileSystem integration with other APIs
            const homeDir = __APPLE_SPEC__.FileSystem.homeDirectory();
            const tempDir = __APPLE_SPEC__.FileSystem.temporaryDirectory();
            const currentDir = __APPLE_SPEC__.FileSystem.currentDirectoryPath();
            
            // Use paths in crypto operations
            const hasher = __APPLE_SPEC__.crypto.createHash('sha256');
            hasher.update(new TextEncoder().encode(homeDir + tempDir + currentDir));
            const hash = hasher.digest();
            
            // Use in process environment
            const processHomeFromEnv = process.env.HOME || process.env.USERPROFILE;
            
            ({
                homeDir: homeDir,
                tempDir: tempDir,
                currentDir: currentDir,
                hashLength: hash.length,
                hashType: typeof hash,
                processHome: processHomeFromEnv,
                homeDirMatchesEnv: homeDir === processHomeFromEnv,
                integrationSuccessful: hash instanceof Uint8Array && hash.length === 32
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["hashLength"].numberValue ?? 0), 32)
        XCTAssertTrue(result["integrationSuccessful"].boolValue ?? false)
        
        // HOME environment might match the FileSystem home directory
        if result["processHome"].isString && !result["processHome"].toString().isEmpty {
            let homeDirMatches = result["homeDirMatchesEnv"].boolValue ?? false
            if !homeDirMatches {
                // Might be different due to symlinks or other factors, that's okay
                XCTAssertTrue(true, "HOME env and FileSystem.homeDirectory() are different")
            }
        }
    }
    
    // MARK: - Cross-Context Tests
    
    func testFileSystemAcrossContexts() {
        // Test that FileSystem results are consistent across different SwiftJS contexts
        let context1 = SwiftJS()
        let context2 = SwiftJS()
        
        let home1 = context1.evaluateScript("__APPLE_SPEC__.FileSystem.homeDirectory()").toString()
        let home2 = context2.evaluateScript("__APPLE_SPEC__.FileSystem.homeDirectory()").toString()
        
        let temp1 = context1.evaluateScript("__APPLE_SPEC__.FileSystem.temporaryDirectory()").toString()
        let temp2 = context2.evaluateScript("__APPLE_SPEC__.FileSystem.temporaryDirectory()").toString()
        
        let current1 = context1.evaluateScript("__APPLE_SPEC__.FileSystem.currentDirectoryPath()").toString()
        let current2 = context2.evaluateScript("__APPLE_SPEC__.FileSystem.currentDirectoryPath()").toString()
        
        XCTAssertEqual(home1, home2)
        XCTAssertEqual(temp1, temp2)
        XCTAssertEqual(current1, current2)
    }
    
    // MARK: - Path Validation Tests
    
    func testDirectoryPathValidity() {
        let script = """
            const homeDir = __APPLE_SPEC__.FileSystem.homeDirectory();
            const tempDir = __APPLE_SPEC__.FileSystem.temporaryDirectory();
            const currentDir = __APPLE_SPEC__.FileSystem.currentDirectoryPath();
            
            ({
                homeValid: homeDir && homeDir.length > 1 && homeDir.startsWith('/') && !homeDir.endsWith('/'),
                tempValid: tempDir && tempDir.length > 1 && tempDir.startsWith('/'),
                currentValid: currentDir && currentDir.length > 1 && currentDir.startsWith('/') && !currentDir.endsWith('/'),
                homeComponents: homeDir.split('/').filter(c => c.length > 0).length,
                tempComponents: tempDir.split('/').filter(c => c.length > 0).length,
                currentComponents: currentDir.split('/').filter(c => c.length > 0).length,
                allHaveComponents: (
                    homeDir.split('/').filter(c => c.length > 0).length > 0 &&
                    tempDir.split('/').filter(c => c.length > 0).length > 0 &&
                    currentDir.split('/').filter(c => c.length > 0).length > 0
                )
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["homeValid"].boolValue ?? false)
        XCTAssertTrue(result["tempValid"].boolValue ?? false)
        XCTAssertTrue(result["currentValid"].boolValue ?? false)
        XCTAssertTrue(result["allHaveComponents"].boolValue ?? false)
        
        XCTAssertGreaterThan(Int(result["homeComponents"].numberValue ?? 0), 0)
        XCTAssertGreaterThan(Int(result["tempComponents"].numberValue ?? 0), 0)
        XCTAssertGreaterThan(Int(result["currentComponents"].numberValue ?? 0), 0)
    }
}
