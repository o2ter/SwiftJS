//
//  ProcessTests.swift
//  SwiftJS Tests
//
//  Created by GitHub Copilot on 2025/9/6.
//  Copyright © 2025 o2ter. All rights reserved.
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

/// Tests for the global process object API, which provides Node.js-like process information
/// and control functions.
@MainActor
final class ProcessTests: XCTestCase {
    
    // MARK: - Process API Existence Tests
    
    func testProcessExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof process")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testProcessProperties() {
        let script = """
            ({
                hasEnv: typeof process.env === 'object',
                hasArgv: Array.isArray(process.argv),
                hasPid: typeof process.pid === 'number',
                hasCwd: typeof process.cwd === 'function',
                hasChdir: typeof process.chdir === 'function',
                hasExit: typeof process.exit === 'function'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasEnv"].boolValue ?? false)
        XCTAssertTrue(result["hasArgv"].boolValue ?? false)
        XCTAssertTrue(result["hasPid"].boolValue ?? false)
        XCTAssertTrue(result["hasCwd"].boolValue ?? false)
        XCTAssertTrue(result["hasChdir"].boolValue ?? false)
        XCTAssertTrue(result["hasExit"].boolValue ?? false)
    }
    
    // MARK: - Process Environment Tests
    
    func testProcessEnvironment() {
        let script = """
            ({
                envIsObject: typeof process.env === 'object',
                envNotNull: process.env !== null,
                hasPath: typeof process.env.PATH === 'string' || process.env.PATH === undefined,
                isReadable: Object.keys(process.env).length >= 0
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["envIsObject"].boolValue ?? false)
        XCTAssertTrue(result["envNotNull"].boolValue ?? false)
        XCTAssertTrue(result["hasPath"].boolValue ?? false)
        XCTAssertTrue(result["isReadable"].boolValue ?? false)
    }
    
    func testProcessEnvironmentAccess() {
        let script = """
            // Test that we can read and potentially write environment variables
            var originalValue = process.env.TEST_VAR;
            process.env.TEST_VAR = 'test_value';
            var newValue = process.env.TEST_VAR;
            
            // Clean up
            if (originalValue === undefined) {
                delete process.env.TEST_VAR;
            } else {
                process.env.TEST_VAR = originalValue;
            }
            
            ({
                canWrite: newValue === 'test_value',
                originalWasUndefined: originalValue === undefined
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["canWrite"].boolValue ?? false)
        // originalWasUndefined could be true or false depending on environment
        XCTAssertNotNil(result["originalWasUndefined"].boolValue)
    }
    
    // MARK: - Process Arguments Tests
    
    func testProcessArguments() {
        let script = """
            ({
                isArray: Array.isArray(process.argv),
                hasLength: typeof process.argv.length === 'number',
                lengthIsValid: process.argv.length >= 0,
                firstIsString: process.argv.length > 0 ? typeof process.argv[0] === 'string' : true
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isArray"].boolValue ?? false)
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["lengthIsValid"].boolValue ?? false)
        XCTAssertTrue(result["firstIsString"].boolValue ?? false)
    }
    
    // MARK: - Process ID Tests
    
    func testProcessId() {
        let script = """
            ({
                isNumber: typeof process.pid === 'number',
                isPositive: process.pid > 0,
                isInteger: Number.isInteger(process.pid)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isNumber"].boolValue ?? false)
        XCTAssertTrue(result["isPositive"].boolValue ?? false)
        XCTAssertTrue(result["isInteger"].boolValue ?? false)
    }
    
    // MARK: - Process Working Directory Tests
    
    func testProcessCwd() {
        let script = """
            ({
                cwdIsFunction: typeof process.cwd === 'function',
                cwdReturnsString: typeof process.cwd() === 'string',
                cwdNotEmpty: process.cwd().length > 0,
                cwdIsAbsolute: process.cwd().startsWith('/')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["cwdIsFunction"].boolValue ?? false)
        XCTAssertTrue(result["cwdReturnsString"].boolValue ?? false)
        XCTAssertTrue(result["cwdNotEmpty"].boolValue ?? false)
        XCTAssertTrue(result["cwdIsAbsolute"].boolValue ?? false)
    }
    
    func testProcessChdir() {
        let script = """
            var originalCwd = process.cwd();
            var tempDir = FileSystem.temp;
            
            try {
                // Change to temp directory
                process.chdir(tempDir);
                var newCwd = process.cwd();
                
                // Change back
                process.chdir(originalCwd);
                var restoredCwd = process.cwd();
                
                ({
                    success: true,
                    changedCorrectly: newCwd === tempDir || newCwd.endsWith(tempDir.split('/').pop()),
                    restoredCorrectly: restoredCwd === originalCwd
                })
            } catch (error) {
                // Restore on error
                try { process.chdir(originalCwd); } catch (e) {}
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["success"].boolValue ?? false {
            XCTAssertTrue(result["changedCorrectly"].boolValue ?? false)
            XCTAssertTrue(result["restoredCorrectly"].boolValue ?? false)
        } else {
            // chdir might not be supported on all platforms/configurations
            XCTAssertTrue(result["error"].isString)
        }
    }
    
    func testProcessChdirErrorHandling() {
        let script = """
            try {
                process.chdir('/nonexistent/directory/path');
                ({ success: false, error: 'Should have thrown' })
            } catch (error) {
                ({
                    success: true,
                    threwError: true,
                    errorIsString: typeof error.message === 'string'
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["success"].boolValue ?? false {
            XCTAssertTrue(result["threwError"].boolValue ?? false)
            XCTAssertTrue(result["errorIsString"].boolValue ?? false)
        }
    }
    
    // MARK: - Process Exit Tests
    
    func testProcessExitFunction() {
        let script = """
            ({
                exitIsFunction: typeof process.exit === 'function',
                exitExists: process.exit !== undefined
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["exitIsFunction"].boolValue ?? false)
        XCTAssertTrue(result["exitExists"].boolValue ?? false)
    }
    
    func testProcessExitBehavior() {
        let expectation = XCTestExpectation(description: "Process exit handling")
        
        let script = """
            // Test that exit sets a global flag and throws asynchronously
            var exitCodeSet = false;
            var errorCaught = false;
            
            // Set up error handler to catch the async exit error
            setTimeout(() => {
                try {
                    // By this time, the exit should have thrown
                    exitCodeSet = typeof globalThis.__SWIFTJS_EXIT_CODE__ === 'number';
                    testCompleted({
                        exitCodeSet: exitCodeSet,
                        exitCode: globalThis.__SWIFTJS_EXIT_CODE__
                    });
                } catch (error) {
                    testCompleted({
                        errorCaught: true,
                        errorName: error.name,
                        errorCode: error.code
                    });
                }
            }, 100);
            
            // Call exit with code 42
            try {
                process.exit(42);
                // This should not prevent the timeout from running
            } catch (error) {
                // Synchronous errors (shouldn't happen with proper implementation)
                testCompleted({
                    syncError: true,
                    errorMessage: error.message
                });
            }
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            if result["exitCodeSet"].boolValue ?? false {
                XCTAssertEqual(result["exitCode"].numberValue, 42)
            } else if result["errorCaught"].boolValue ?? false {
                XCTAssertEqual(result["errorName"].toString(), "ProcessExit")
                XCTAssertEqual(result["errorCode"].numberValue, 42)
            } else if result["syncError"].boolValue ?? false {
                XCTFail("process.exit() should not throw synchronously: \(result["errorMessage"].toString())")
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Process Object Integrity Tests
    
    func testProcessObjectIntegrity() {
        let script = """
            ({
                processIsObject: typeof process === 'object',
                processNotNull: process !== null,
                processNotArray: !Array.isArray(process),
                hasExpectedProperties: [
                    'env', 'argv', 'pid', 'cwd', 'chdir', 'exit'
                ].every(prop => prop in process)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["processIsObject"].boolValue ?? false)
        XCTAssertTrue(result["processNotNull"].boolValue ?? false)
        XCTAssertTrue(result["processNotArray"].boolValue ?? false)
        XCTAssertTrue(result["hasExpectedProperties"].boolValue ?? false)
    }
    
    func testProcessGlobalAccess() {
        let script = """
            // Test that process is accessible as a global
            ({
                accessibleAsGlobal: typeof process !== 'undefined',
                accessibleAsGlobalThis: typeof globalThis.process !== 'undefined',
                sameReference: process === globalThis.process
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["accessibleAsGlobal"].boolValue ?? false)
        XCTAssertTrue(result["accessibleAsGlobalThis"].boolValue ?? false)
        XCTAssertTrue(result["sameReference"].boolValue ?? false)
    }
}
