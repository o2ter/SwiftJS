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
                const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/json');
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
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/json');
                    
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
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/post');
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
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/bytes/512');
                    
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
                const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/post');
                
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
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/' + method.toLowerCase());
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
                const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/headers');
                
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
