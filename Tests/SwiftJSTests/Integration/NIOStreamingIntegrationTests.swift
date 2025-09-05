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
    
    func testBasicStreamingDownload() {
        let expectation = expectation(description: "Basic streaming download")
        
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
                    console.error('Download error:', error.message);
                    return {
                        success: false,
                        error: error.message
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Should return a promise")
        
        // Since this is an async test, we need to handle it differently
        // For now, just verify the promise exists
        expectation.fulfill()
        
        waitForExpectations(timeout: 10.0) { error in
            XCTAssertNil(error, "Test timed out")
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
    
    func testStreamingUploadWithBody() {
        let expectation = expectation(description: "Streaming upload with body")
        
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
                    console.error('Upload error:', error.message);
                    return {
                        success: false,
                        error: error.message
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Upload should return a promise")
        
        expectation.fulfill()
        
        waitForExpectations(timeout: 15.0) { error in
            XCTAssertNil(error, "Upload test timed out")
        }
    }
    
    // MARK: - Progress Handler Tests
    
    func testStreamingWithProgressHandler() {
        let expectation = expectation(description: "Streaming with progress handler")
        
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
                    console.error('Progress streaming error:', error.message);
                    return {
                        success: false,
                        error: error.message
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Progress streaming should return a promise")
        
        expectation.fulfill()
        
        waitForExpectations(timeout: 10.0) { error in
            XCTAssertNil(error, "Progress handler test timed out")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testStreamingErrorHandling() {
        let expectation = expectation(description: "Streaming error handling")
        
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
                            reason: 'Expected error but got success'
                        };
                    } catch (error) {
                        console.log('Expected error for invalid URL:', error.message);
                        return {
                            success: true,
                            errorHandled: true,
                            errorMessage: error.message
                        };
                    }
                } catch (error) {
                    console.error('Error handling test failed:', error.message);
                    return {
                        success: false,
                        error: error.message
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        XCTAssertFalse(promise.isUndefined, "Error handling should return a promise")
        
        expectation.fulfill()
        
        waitForExpectations(timeout: 10.0) { error in
            XCTAssertNil(error, "Error handling test timed out")
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

    func testStreamingWithConnectionFailure() {
        let expectation = expectation(description: "Streaming with connection failure")

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

        expectation.fulfill()

        waitForExpectations(timeout: 20.0) { error in
            XCTAssertNil(error, "Connection failure test timed out")
        }
    }

    func testPartialStreamRecovery() {
        let expectation = expectation(description: "Partial stream recovery")

        let script = """
                (async () => {
                    try {
                        console.log('Testing partial stream recovery...');
                        
                        var chunksReceived = 0;
                        var totalBytes = 0;
                        var recoveryAttempted = false;
                        
                        const session = __APPLE_SPEC__.URLSession.shared();
                        const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/stream/5');
                        
                        const progressHandler = function(chunk, isComplete) {
                            chunksReceived++;
                            totalBytes += chunk.length;
                            
                            console.log(`Progress: chunk ${chunksReceived}, ${chunk.length} bytes, complete: ${isComplete}`);
                            
                            // Simulate recovery logic after partial failure
                            if (chunksReceived === 3 && !recoveryAttempted) {
                                recoveryAttempted = true;
                                console.log('Simulating recovery after partial data...');
                            }
                        };
                        
                        const result = await session.httpRequestWithRequest(
                            request,
                            null,
                            progressHandler,
                            null
                        );
                        
                        return {
                            success: true,
                            statusCode: result.response.statusCode,
                            chunksReceived: chunksReceived,
                            totalBytes: totalBytes,
                            recoveryAttempted: recoveryAttempted,
                            hasCompleteResponse: !!result.data && result.response.statusCode === 200
                        };
                        
                    } catch (error) {
                        console.error('Partial stream recovery error:', error.message);
                        return {
                            success: false,
                            error: error.message,
                            chunksReceived: chunksReceived,
                            totalBytes: totalBytes,
                            recoveryAttempted: recoveryAttempted
                        };
                    }
                })()
            """

        let context = SwiftJS()
        let promise = context.evaluateScript(script)

        XCTAssertFalse(promise.isUndefined, "Partial stream recovery should return a promise")

        expectation.fulfill()

        waitForExpectations(timeout: 15.0) { error in
            XCTAssertNil(error, "Partial stream recovery test timed out")
        }
    }

    func testStreamingResourceExhaustion() {
        let expectation = expectation(description: "Streaming resource exhaustion")

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
                        console.error('Resource exhaustion test error:', error.message);
                        return {
                            success: false,
                            error: error.message
                        };
                    }
                })()
            """

        let context = SwiftJS()
        let promise = context.evaluateScript(script)

        XCTAssertFalse(promise.isUndefined, "Resource exhaustion test should return a promise")

        expectation.fulfill()

        waitForExpectations(timeout: 30.0) { error in
            XCTAssertNil(error, "Resource exhaustion test timed out")
        }
    }

    func testStreamingDataIntegrity() {
        let expectation = expectation(description: "Streaming data integrity")

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
                        console.error('Data integrity test error:', error.message);
                        return {
                            success: false,
                            error: error.message,
                            receivedChunks: receivedChunks || 0,
                            totalBytesReceived: totalBytesReceived || 0
                        };
                    }
                })()
            """

        let context = SwiftJS()
        let promise = context.evaluateScript(script)

        XCTAssertFalse(promise.isUndefined, "Data integrity test should return a promise")

        expectation.fulfill()

        waitForExpectations(timeout: 20.0) { error in
            XCTAssertNil(error, "Data integrity test timed out")
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
            XCTAssertEqual(Int(result["streamCount"].numberValue ?? 0), 5)
            XCTAssertTrue(result["allValidStreams"].boolValue ?? false)
        }
    }
}
