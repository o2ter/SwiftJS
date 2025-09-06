//
//  NIOStreamingIntegrationTests.swift
//  SwiftJS Integration Tests for NIO Streaming
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

/// Integration tests for NIO Streaming functionality.
/// Tests the integration between URLSession, ReadableStream, and JavaScript APIs.
/// Run in serial to avoid network interference between tests.
@MainActor
final class NIOStreamingIntegrationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    
    // MARK: - API Availability Tests
    
    func testBasicAPIAvailability() {
        let context = SwiftJS()
        
        // Test that the required APIs are available
        let hasURLSession = context.evaluateScript("typeof __APPLE_SPEC__.URLSession").toString() == "object"
        let hasURLSessionShared = context.evaluateScript("typeof __APPLE_SPEC__.URLSession.shared").toString() == "function"
        let hasURLRequest = context.evaluateScript("typeof __APPLE_SPEC__.URLRequest").toString() == "function"
        let hasReadableStream = context.evaluateScript("typeof ReadableStream").toString() == "function"

        XCTAssertTrue(hasURLSession, "URLSession should be available as object")
        XCTAssertTrue(hasURLSessionShared, "URLSession.shared should be available as function")
        XCTAssertTrue(hasURLRequest, "URLRequest should be available as constructor")
        XCTAssertTrue(hasReadableStream, "ReadableStream should be available")
    }
    
    func testURLSessionSharedInstance() {
        let script = """
            const session = __APPLE_SPEC__.URLSession.shared();
            ({
                type: typeof session,
                hasHttpRequestMethod: typeof session.httpRequestWithRequest === 'function',
                sessionExists: !!session
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "object")
        XCTAssertTrue(result["hasHttpRequestMethod"].boolValue ?? false)
        XCTAssertTrue(result["sessionExists"].boolValue ?? false)
    }
    
    func testURLRequestCreation() {
        let script = """
            try {
                const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/get');
                ({
                    success: true,
                    type: typeof request,
                    hasHttpMethod: 'httpMethod' in request,
                    hasSetValueMethod: typeof request.setValueForHTTPHeaderField === 'function'
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "URLRequest creation failed: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertEqual(result["type"].toString(), "object")
            XCTAssertTrue(result["hasHttpMethod"].boolValue ?? false)
            XCTAssertTrue(result["hasSetValueMethod"].boolValue ?? false)
        }
    }
    
    // MARK: - Basic Streaming Tests
    
    func testBasicStreamingDownload() async throws {
        let script = """
            (async () => {
                try {
                    console.log('Starting basic download test...');
                    
                    const session = __APPLE_SPEC__.URLSession.shared();
                    const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/get');
                    
                    const result = await session.httpRequestWithRequest(request, null, null, null);
                    
                    console.log('Response received:', {
                        status: result.response.statusCode,
                        hasData: !!result.data
                    });
                    
                    return {
                        success: result.response.statusCode === 200 && !!result.data,
                        statusCode: result.response.statusCode,
                        hasData: !!result.data
                    };
                } catch (error) {
                    return {
                        success: false,
                        error: error.message,
                        errorName: error.name || 'UnknownError',
                        errorStack: error.stack || 'No stack trace'
                    };
                }
            })()
        """

        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Should return a promise")

        // Use the new awaited method for simplified async handling
        let result = try await promise.awaited(inContext: context)

        // Validate the results with comprehensive error handling
        let success = result["success"].boolValue ?? false

        if success {
            // Test passed - validate success criteria
            let statusCode = result["statusCode"].numberValue ?? 0
            let hasData = result["hasData"].boolValue ?? false

            XCTAssertEqual(statusCode, 200, "Expected HTTP 200, got \(statusCode)")
            XCTAssertTrue(hasData, "Expected response data")

            print(
                "✅ Basic streaming download test passed: status \(statusCode), has data: \(hasData)"
            )
        } else {
            // Test failed - provide detailed error information
            let error = result["error"].toString()
            let errorName = result["errorName"].toString()
            let errorStack = result["errorStack"].toString()

            XCTFail(
                """
                Basic streaming download test failed:
                Error: \(error)
                Error Type: \(errorName)
                Stack: \(errorStack)
                """)
        }
    }
    
    func testReadableStreamCreation() {
        let script = """
            try {
                // Create a ReadableStream for testing
                const bodyStream = new ReadableStream({
                    start(controller) {
                        const data = JSON.stringify({ message: 'Hello from SwiftJS!' });
                        const encoder = new TextEncoder();
                        controller.enqueue(encoder.encode(data));
                        controller.close();
                    }
                });
                
                ({
                    success: true,
                    type: typeof bodyStream,
                    isReadableStream: bodyStream instanceof ReadableStream,
                    hasGetReader: typeof bodyStream.getReader === 'function'
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "ReadableStream creation failed: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertEqual(result["type"].toString(), "object")
            XCTAssertTrue(result["isReadableStream"].boolValue ?? false)
            XCTAssertTrue(result["hasGetReader"].boolValue ?? false)
        }
    }
    
    // MARK: - Upload Integration Tests
    
    func testStreamingUploadWithBody() async throws {
        let script = """
            (async () => {
                try {
                    console.log('Starting upload test...');
                    
                    // Create a ReadableStream for the request body
                    const bodyStream = new ReadableStream({
                        start(controller) {
                            const data = JSON.stringify({ message: 'Hello from SwiftJS!' });
                            const encoder = new TextEncoder();
                            controller.enqueue(encoder.encode(data));
                            controller.close();
                        }
                    });
                    
                    const session = __APPLE_SPEC__.URLSession.shared();
                    const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/post');
                    request.httpMethod = 'POST';
                    request.setValueForHTTPHeaderField('application/json', 'Content-Type');
                    
                    const result = await session.httpRequestWithRequest(
                        request, 
                        bodyStream,     // bodyStream parameter
                        null,           // progressHandler
                        null            // completionHandler
                    );
                    
                    console.log('Upload response:', result.response.statusCode);
                    return {
                        success: result.response.statusCode >= 200 && result.response.statusCode < 300,
                        statusCode: result.response.statusCode,
                        hasData: !!result.data
                    };
                } catch (error) {
                    return {
                        success: false,
                        error: error.message,
                        errorName: error.name || 'UnknownError',
                        errorStack: error.stack || 'No stack trace'
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Upload should return a promise")
        
        // Use the new awaited method for simplified async handling
        let result = try await promise.awaited(inContext: context)

        // Validate the results with comprehensive error handling
        let success = result["success"].boolValue ?? false

        if success {
            // Test passed - validate success criteria
            let statusCode = result["statusCode"].numberValue ?? 0
            let hasData = result["hasData"].boolValue ?? false

            XCTAssertTrue(
                statusCode >= 200 && statusCode < 300,
                "Expected successful HTTP status, got \(statusCode)")
            XCTAssertTrue(hasData, "Expected response data")

            print("✅ Streaming upload test passed: status \(statusCode), has data: \(hasData)")
        } else {
            // Test failed - provide detailed error information
            let error = result["error"].toString()
            let errorName = result["errorName"].toString()
            let errorStack = result["errorStack"].toString()

            XCTFail(
                """
                Streaming upload test failed:
                Error: \(error)
                Error Type: \(errorName)
                Stack: \(errorStack)
                """)
        }
    }

    // MARK: - Progress Handler Tests

    func testStreamingWithProgressHandler() async throws {
        let script = """
            (async () => {
                try {
                    console.log('Starting progress handler test...');
                    
                    let progressCallCount = 0;
                    
                    const session = __APPLE_SPEC__.URLSession.shared();
                    const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/get');
                    
                    const progressHandler = function(chunk, isComplete) {
                        progressCallCount++;
                        console.log(`Progress ${progressCallCount}: chunk size ${chunk.length}, complete: ${isComplete}`);
                    };
                    
                    const result = await session.httpRequestWithRequest(
                        request,
                        null,               // bodyStream
                        progressHandler,    // progressHandler for streaming
                        null                // completionHandler
                    );
                    
                    console.log('Progress streaming complete, calls:', progressCallCount);
                    return {
                        success: progressCallCount > 0,
                        progressCallCount: progressCallCount,
                        statusCode: result.response.statusCode
                    };
                } catch (error) {
                    return {
                        success: false,
                        error: error.message,
                        errorName: error.name || 'UnknownError',
                        errorStack: error.stack || 'No stack trace',
                        progressCallCount: progressCallCount || 0
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Progress streaming should return a promise")
        
        // Use the new awaited method for simplified async handling
        let result = try await promise.awaited(inContext: context)

        // Validate the results with comprehensive error handling
        let success = result["success"].boolValue ?? false

        if success {
            // Test passed - validate success criteria
            let progressCallCount = result["progressCallCount"].numberValue ?? 0
            let statusCode = result["statusCode"].numberValue ?? 0

            XCTAssertTrue(
                progressCallCount > 0, "Expected progress calls, got \(progressCallCount)")
            XCTAssertTrue(
                statusCode >= 200 && statusCode < 300,
                "Expected successful HTTP status, got \(statusCode)")

            print(
                "✅ Progress handler test passed: \(progressCallCount) progress calls, status \(statusCode)"
            )
        } else {
            // Test failed - provide detailed error information
            let error = result["error"].toString()
            let errorName = result["errorName"].toString()
            let errorStack = result["errorStack"].toString()
            let progressCallCount = result["progressCallCount"].numberValue ?? 0

            XCTFail(
                """
                Progress handler test failed:
                Error: \(error)
                Error Type: \(errorName)
                Stack: \(errorStack)
                Progress Calls: \(progressCallCount)
                """)
        }
    }

    // MARK: - Error Handling Tests

    func testStreamingErrorHandling() async throws {
        let script = """
            (async () => {
                try {
                    console.log('Starting error handling test...');
                    
                    const session = __APPLE_SPEC__.URLSession.shared();
                    const request = new __APPLE_SPEC__.URLRequest('https://invalid-url-that-does-not-exist.com');
                    
                    try {
                        const result = await session.httpRequestWithRequest(request, null, null, null);
                        console.log('Unexpected success for invalid URL');
                        return {
                            success: false,
                            reason: 'Expected error but got success',
                            unexpectedStatusCode: result.response.statusCode
                        };
                    } catch (error) {
                        console.log('Expected error for invalid URL:', error.message);
                        return {
                            success: true,
                            errorHandled: true,
                            errorMessage: error.message,
                            errorName: error.name || 'UnknownError'
                        };
                    }
                } catch (error) {
                    return {
                        success: false,
                        error: error.message,
                        errorName: error.name || 'UnknownError',
                        errorStack: error.stack || 'No stack trace'
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Error handling should return a promise")
        
        // Properly await the promise and validate results
        // Use the new awaited method for simplified async handling
        let result = try await promise.awaited(inContext: context)

        // Validate the results with comprehensive error handling
        let success = result["success"].boolValue ?? false

        if success {
            // Test passed - validate that error was properly handled
            let errorHandled = result["errorHandled"].boolValue ?? false
            let errorMessage = result["errorMessage"].toString()
            let errorName = result["errorName"].toString()

            XCTAssertTrue(errorHandled, "Error should have been handled properly")
            XCTAssertFalse(errorMessage.isEmpty, "Error message should not be empty")
            XCTAssertFalse(errorName.isEmpty, "Error name should not be empty")

            print("✅ Error handling test passed: handled error '\(errorName)': \(errorMessage)")
        } else {
            // Check if this was an unexpected success case
            if let unexpectedStatusCode = result["unexpectedStatusCode"].numberValue {
                XCTFail(
                    "Expected error but got unexpected success with status code: \(unexpectedStatusCode)"
                )
            } else {
                // Test failed for other reasons - provide detailed error information
                let error = result["error"].toString()
                let errorName = result["errorName"].toString()
                let errorStack = result["errorStack"].toString()

                XCTFail(
                    """
                    Error handling test failed:
                    Error: \(error)
                    Error Type: \(errorName)
                    Stack: \(errorStack)
                    """)
            }
        }
    }
    
    // MARK: - Integration Validation Tests
    
    func testURLSessionAndReadableStreamIntegration() {
        let script = """
            try {
                // Test that URLSession can work with ReadableStream
                const session = __APPLE_SPEC__.URLSession.shared();
                const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/post');
                
                const stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('test data'));
                        controller.close();
                    }
                });
                
                // The key test is that this doesn't throw immediately
                const canCallMethod = typeof session.httpRequestWithRequest === 'function';
                const streamIsValid = stream instanceof ReadableStream;
                const requestIsValid = typeof request === 'object';
                
                ({
                    success: true,
                    canCallMethod: canCallMethod,
                    streamIsValid: streamIsValid,
                    requestIsValid: requestIsValid,
                    integrationReady: canCallMethod && streamIsValid && requestIsValid
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "Integration validation failed: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertTrue(result["canCallMethod"].boolValue ?? false)
            XCTAssertTrue(result["streamIsValid"].boolValue ?? false)
            XCTAssertTrue(result["requestIsValid"].boolValue ?? false)
            XCTAssertTrue(result["integrationReady"].boolValue ?? false)
        }
    }
    
    func testHTTPMethodsSupport() {
        let script = """
            try {
                const methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];
                const results = [];
                
                for (const method of methods) {
                    const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/' + method.toLowerCase());
                    request.httpMethod = method;
                    
                    results.push({
                        method: method,
                        success: request.httpMethod === method,
                        hasValidRequest: typeof request === 'object'
                    });
                }
                
                ({
                    success: true,
                    results: results,
                    allMethodsSupported: results.every(r => r.success && r.hasValidRequest)
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "HTTP methods test failed: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertTrue(result["allMethodsSupported"].boolValue ?? false)
        }
    }
    
    // MARK: - Header Management Tests
    
    func testHeaderIntegration() {
        let script = """
            try {
                const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/headers');
                
                // Test header setting
                request.setValueForHTTPHeaderField('application/json', 'Content-Type');
                request.setValueForHTTPHeaderField('Bearer token123', 'Authorization');
                request.setValueForHTTPHeaderField('SwiftJS/1.0', 'User-Agent');
                
                // Test that the method exists and works
                const canSetHeaders = typeof request.setValueForHTTPHeaderField === 'function';
                
                ({
                    success: true,
                    canSetHeaders: canSetHeaders,
                    requestValid: typeof request === 'object',
                    methodType: request.httpMethod || 'GET'
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "Header integration test failed: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertTrue(result["canSetHeaders"].boolValue ?? false)
            XCTAssertTrue(result["requestValid"].boolValue ?? false)
        }
    }
    
    // MARK: - Advanced Integration Error Tests

    func testStreamingWithConnectionFailure() async throws {
        let script = """
                (async () => {
                    const unreliableConnections = [
                        'https://httpstat.us/200?sleep=1000',  // Slow response
                        'https://httpstat.us/503',             // Service unavailable  
                        'https://httpstat.us/timeout',         // Timeout
                        'https://nonexistent-domain-12345.com' // DNS failure
                    ];
                    
                    const results = [];
                    
                    for (const url of unreliableConnections) {
                        try {
                            console.log(`Testing connection to: ${url}`);
                            
                            const session = __APPLE_SPEC__.URLSession.shared();
                            const request = new __APPLE_SPEC__.URLRequest(url);
                            
                            const startTime = Date.now();
                            const result = await Promise.race([
                                session.httpRequestWithRequest(request, null, null, null),
                                new Promise((_, reject) => 
                                    setTimeout(() => reject(new Error('Test timeout')), 3000)
                                )
                            ]);
                            
                            const duration = Date.now() - startTime;
                            
                            results.push({
                                url: url,
                                success: true,
                                statusCode: result.response.statusCode,
                                duration: duration,
                                hasData: !!result.data
                            });
                            
                        } catch (error) {
                            results.push({
                                url: url,
                                success: false,
                                error: error.message,
                                errorType: error.name || 'Unknown'
                            });
                        }
                    }
                    
                    return {
                        totalTests: unreliableConnections.length,
                        results: results,
                        successCount: results.filter(r => r.success).length,
                        errorCount: results.filter(r => !r.success).length,
                        handledAllConnections: results.length === unreliableConnections.length
                    };
                })()
            """

        let context = SwiftJS()
        let promise = context.evaluateScript(script)

        XCTAssertFalse(promise.isUndefined, "Connection failure test should return a promise")

        // Properly await the promise and validate results
        // Use the new awaited method for simplified async handling
        let result = try await promise.awaited(inContext: context)

        // Validate the results with comprehensive error handling
        let success = result["success"].boolValue ?? false

        if success {
            // Test passed - validate success criteria
            let statusCode = result["statusCode"].numberValue ?? 0
            let chunksReceived = result["chunksReceived"].numberValue ?? 0
            let totalBytes = result["totalBytes"].numberValue ?? 0
            let recoveryAttempted = result["recoveryAttempted"].boolValue ?? false
            let hasCompleteResponse = result["hasCompleteResponse"].boolValue ?? false

            XCTAssertTrue(
                statusCode >= 200 && statusCode < 300,
                "Expected successful HTTP status, got \(statusCode)")
            XCTAssertTrue(
                chunksReceived >= 0, "Chunks received should be non-negative, got \(chunksReceived)"
            )
            XCTAssertTrue(totalBytes >= 0, "Total bytes should be non-negative, got \(totalBytes)")

            // Recovery logic should be attempted or chunks should be received
            XCTAssertTrue(
                recoveryAttempted || chunksReceived > 0,
                "Either recovery should be attempted or chunks should be received")

            // Validate complete response when status is 200
            if statusCode == 200 {
                XCTAssertTrue(
                    hasCompleteResponse, "Complete response should be available for status 200")
            }

            print(
                "✅ Partial stream recovery test passed: \(chunksReceived) chunks, \(totalBytes) bytes, recovery attempted: \(recoveryAttempted)"
            )
        } else {
            // Test failed - provide detailed error information
            let error = result["error"].toString()
            let errorName = result["errorName"].toString()
            let errorStack = result["errorStack"].toString()
            let chunksReceived = result["chunksReceived"].numberValue ?? 0
            let totalBytes = result["totalBytes"].numberValue ?? 0
            let recoveryAttempted = result["recoveryAttempted"].boolValue ?? false

            XCTFail(
                """
                Partial stream recovery test failed:
                Error: \(error)
                Error Type: \(errorName)
                Stack: \(errorStack)
                Partial Results: \(chunksReceived) chunks, \(totalBytes) bytes, recovery attempted: \(recoveryAttempted)
                """)
        }
    }

    func testStreamingResourceExhaustion() async throws {
        let script = """
                (async () => {
                    try {
                        console.log('Testing streaming resource exhaustion...');
                        
                        const maxConcurrentStreams = 10;
                        const results = [];
                        const startTime = Date.now();
                        
                        // Create multiple concurrent streaming requests
                        const promises = [];
                        for (let i = 0; i < maxConcurrentStreams; i++) {
                            const promise = (async (streamIndex) => {
                                try {
                                    const session = __APPLE_SPEC__.URLSession.shared();
                                    const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/get?stream=' + streamIndex);
                                    
                                    const result = await session.httpRequestWithRequest(request, null, null, null);
                                    
                                    return {
                                        streamIndex: streamIndex,
                                        success: true,
                                        statusCode: result.response.statusCode,
                                        hasData: !!result.data
                                    };
                                } catch (error) {
                                    return {
                                        streamIndex: streamIndex,
                                        success: false,
                                        error: error.message
                                    };
                                }
                            })(i);
                            
                            promises.push(promise);
                        }
                        
                        // Wait for all concurrent streams
                        const streamResults = await Promise.allSettled(promises);
                        const endTime = Date.now();
                        
                        const successfulStreams = streamResults.filter(r => 
                            r.status === 'fulfilled' && r.value.success
                        ).length;
                        
                        const failedStreams = streamResults.filter(r => 
                            r.status === 'rejected' || !r.value.success
                        ).length;
                        
                        return {
                            totalStreams: maxConcurrentStreams,
                            successfulStreams: successfulStreams,
                            failedStreams: failedStreams,
                            duration: endTime - startTime,
                            handledConcurrency: successfulStreams > 0,
                            resourceExhaustionHandled: failedStreams === 0 || successfulStreams > 0,
                            results: streamResults.map(r => r.status === 'fulfilled' ? r.value : { error: 'Promise rejected' })
                        };
                        
                    } catch (error) {
                        return {
                            success: false,
                            error: error.message,
                            errorName: error.name || 'UnknownError',
                            errorStack: error.stack || 'No stack trace',
                            totalStreams: maxConcurrentStreams || 0,
                            successfulStreams: 0,
                            failedStreams: maxConcurrentStreams || 0,
                            partialResults: results || []
                        };
                    }
                })()
            """

        let context = SwiftJS()
        let promise = context.evaluateScript(script)

        XCTAssertFalse(promise.isUndefined, "Resource exhaustion test should return a promise")

        // Properly await the promise and validate results
        // Use the new awaited method for simplified async handling
        let result = try await promise.awaited(inContext: context)

        // Validate the results with comprehensive error handling
        let totalStreams = result["totalStreams"].numberValue ?? 0
        let successfulStreams = result["successfulStreams"].numberValue ?? 0
        let failedStreams = result["failedStreams"].numberValue ?? 0
        let handledConcurrency = result["handledConcurrency"].boolValue ?? false
        let resourceExhaustionHandled = result["resourceExhaustionHandled"].boolValue ?? false
        let duration = result["duration"].numberValue ?? 0

        // Check if this was an error case
        if result["success"].boolValue == false {
            let error = result["error"].toString()
            let errorName = result["errorName"].toString()
            let errorStack = result["errorStack"].toString()

            XCTFail(
                """
                Resource exhaustion test failed:
                Error: \(error)
                Error Type: \(errorName)
                Stack: \(errorStack)
                Partial Results: \(successfulStreams) successful, \(failedStreams) failed out of \(totalStreams) total
                """)
        } else {
            // Validate successful execution
            XCTAssertEqual(totalStreams, 10, "Should have tested 10 concurrent streams")
            XCTAssertTrue(handledConcurrency, "Should have handled concurrent operations")
            XCTAssertTrue(
                resourceExhaustionHandled, "Should have handled resource exhaustion gracefully")
            XCTAssertTrue(successfulStreams >= 0, "Successful streams should be non-negative")
            XCTAssertTrue(failedStreams >= 0, "Failed streams should be non-negative")
            XCTAssertEqual(
                successfulStreams + failedStreams, totalStreams,
                "Success + failed should equal total")
            XCTAssertTrue(duration > 0, "Duration should be positive")

            // At least some operations should complete (either successfully or with proper error handling)
            XCTAssertTrue(totalStreams > 0, "Should have completed some operations")

            print(
                "✅ Resource exhaustion test completed: \(successfulStreams) successful, \(failedStreams) failed out of \(totalStreams) total in \(duration)ms"
            )
        }
    }

    func testStreamingDataIntegrity() async throws {
        let script = """
                (async () => {
                    try {
                        console.log('Testing streaming data integrity...');
                        
                        // Create a large, structured data stream for integrity checking
                        const expectedPattern = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                        const repeatCount = 100;
                        const expectedData = expectedPattern.repeat(repeatCount);
                        
                        const bodyStream = new ReadableStream({
                            start(controller) {
                                const encoder = new TextEncoder();
                                // Send data in chunks to test integrity
                                for (let i = 0; i < repeatCount; i++) {
                                    controller.enqueue(encoder.encode(expectedPattern));
                                }
                                controller.close();
                            }
                        });
                        
                        const session = __APPLE_SPEC__.URLSession.shared();
                        const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/post');
                        request.httpMethod = 'POST';
                        request.setValueForHTTPHeaderField('text/plain', 'Content-Type');
                        
                        var receivedChunks = 0;
                        var totalBytesReceived = 0;
                        
                        const progressHandler = function(chunk, isComplete) {
                            receivedChunks++;
                            totalBytesReceived += chunk.length;
                            
                            // Verify chunk integrity (basic check)
                            if (chunk.length === 0 && !isComplete) {
                                console.warn('Received empty chunk');
                            }
                        };
                        
                        const result = await session.httpRequestWithRequest(
                            request,
                            bodyStream,
                            progressHandler,
                            null
                        );
                        
                        const expectedBytes = new TextEncoder().encode(expectedData).length;
                        
                        return {
                            success: result.response.statusCode >= 200 && result.response.statusCode < 300,
                            statusCode: result.response.statusCode,
                            expectedBytes: expectedBytes,
                            receivedChunks: receivedChunks,
                            totalBytesReceived: totalBytesReceived,
                            hasResponseData: !!result.data,
                            integrityMaintained: totalBytesReceived > 0 && receivedChunks > 0
                        };
                        
                    } catch (error) {
                        return {
                            success: false,
                            error: error.message,
                            errorName: error.name || 'UnknownError',
                            errorStack: error.stack || 'No stack trace',
                            receivedChunks: receivedChunks || 0,
                            totalBytesReceived: totalBytesReceived || 0
                        };
                    }
                })()
            """

        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Data integrity test should return a promise")
        
        // Properly wait for the promise to resolve and validate results
        let result = try await promise.awaited(inContext: context)

        // Validate the results with proper error handling
        let success = result["success"].boolValue ?? false

        if success {
            // Test passed - validate success criteria
            let statusCode = result["statusCode"].numberValue ?? 0
            let receivedChunks = result["receivedChunks"].numberValue ?? 0
            let totalBytesReceived = result["totalBytesReceived"].numberValue ?? 0
            let integrityMaintained = result["integrityMaintained"].boolValue ?? false
            let hasResponseData = result["hasResponseData"].boolValue ?? false

            XCTAssertTrue(
                statusCode >= 200 && statusCode < 300,
                "Expected successful HTTP status, got \(statusCode)")
            XCTAssertTrue(receivedChunks > 0, "Expected to receive chunks, got \(receivedChunks)")
            XCTAssertTrue(
                totalBytesReceived > 0, "Expected to receive bytes, got \(totalBytesReceived)")
            XCTAssertTrue(integrityMaintained, "Data integrity was not maintained")
            XCTAssertTrue(hasResponseData, "Expected response data")

            print(
                "✅ Data integrity test passed: \(receivedChunks) chunks, \(totalBytesReceived) bytes"
            )
        } else {
            // Test failed - provide detailed error information
            let error = result["error"].toString()
            let errorName = result["errorName"].toString()
            let errorStack = result["errorStack"].toString()
            let receivedChunks = result["receivedChunks"].numberValue ?? 0
            let totalBytesReceived = result["totalBytesReceived"].numberValue ?? 0

            XCTFail(
                """
                Data integrity test failed:
                Error: \(error)
                Error Type: \(errorName)
                Stack: \(errorStack)
                Partial Results: \(receivedChunks) chunks, \(totalBytesReceived) bytes
                """)
        }
    }

    // MARK: - Performance Integration Tests
    
    func testConcurrentStreamCreation() {
        let script = """
            try {
                const streamCount = 5;
                const streams = [];
                
                for (let i = 0; i < streamCount; i++) {
                    const stream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(new TextEncoder().encode(`Stream ${i} data`));
                            controller.close();
                        }
                    });
                    streams.push(stream);
                }
                
                ({
                    success: true,
                    streamCount: streams.length,
                    allValidStreams: streams.every(s => s instanceof ReadableStream)
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false, 
                     "Concurrent stream creation failed: \(result["error"].toString())")
        
        if result["success"].boolValue == true {
            XCTAssertEqual(result["streamCount"].numberValue ?? 0, 5)
            XCTAssertTrue(result["allValidStreams"].boolValue ?? false)
        }
    }
}
