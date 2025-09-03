//
//  StreamingTests.swift
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

import Testing
@testable import SwiftJS

@Suite(.serialized) // Run streaming tests in sequence to avoid interference
struct NIOStreamingTests {

    @Test func testBasicStreamingDownload() async throws {
        let js = SwiftJS()
        let success = try await js.evaluate("""
            (async () => {
                try {
                    console.log('Starting streaming download test...');
                    
                    // Test streaming a small response
                    const session = __APPLE_SPEC__.URLSession.shared;
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/json');
                    
                    const result = await session.streamingDataTaskWithRequestCompletionHandler(request);
                    
                    console.log('Streaming response received:', {
                        status: result.response.statusCode,
                        hasBody: !!result.body,
                        bodyType: typeof result.body
                    });
                    
                    // Check if we have a streaming response
                    return result.response.statusCode === 200 && !!result.body;
                } catch (error) {
                    console.error('Streaming download error:', error.message);
                    return false;
                }
            })()
        """).toBool()
        
        #expect(success, "Basic streaming download should succeed")
    }
    
    @Test func testStreamingUploadWithBody() async throws {
        let js = SwiftJS()
        let success = try await js.evaluate("""
            (async () => {
                try {
                    console.log('Starting streaming upload test...');
                    
                    // Create a ReadableStream for the request body
                    const bodyStream = new ReadableStream({
                        start(controller) {
                            const data = JSON.stringify({ message: 'Hello from SwiftJS streaming!' });
                            const encoder = new TextEncoder();
                            controller.enqueue(encoder.encode(data));
                            controller.close();
                        }
                    });
                    
                    // Test streaming upload
                    const session = __APPLE_SPEC__.URLSession.shared;
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/post');
                    request.httpMethod = 'POST';
                    request.setValueForHTTPHeaderField('application/json', 'Content-Type');
                    
                    const result = await session.streamingUploadTaskWithRequestBodyStreamProgressHandler(
                        request, 
                        bodyStream
                    );
                    
                    console.log('Streaming upload response received:', {
                        status: result.response.statusCode,
                        hasBody: !!result.body
                    });
                    
                    return result.response.statusCode >= 200 && result.response.statusCode < 300;
                } catch (error) {
                    console.error('Streaming upload error:', error.message);
                    return false;
                }
            })()
        """).toBool()
        
        #expect(success, "Streaming upload with body should succeed")
    }
    
    @Test func testStreamingLargeFile() async throws {
        let js = SwiftJS()
        let success = try await js.evaluate("""
            (async () => {
                try {
                    console.log('Starting large file streaming test...');
                    
                    // Test streaming a larger response to verify progressive processing
                    const session = __APPLE_SPEC__.URLSession.shared;
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/bytes/1024');
                    
                    const result = await session.streamingDataTaskWithRequestCompletionHandler(request);
                    
                    console.log('Large file streaming response:', {
                        status: result.response.statusCode,
                        contentLength: result.response.expectedContentLength,
                        hasBody: !!result.body
                    });
                    
                    return result.response.statusCode === 200 && 
                           result.response.expectedContentLength > 0 &&
                           !!result.body;
                } catch (error) {
                    console.error('Large file streaming error:', error.message);
                    return false;
                }
            })()
        """).toBool()
        
        #expect(success, "Large file streaming should succeed")
    }
    
    @Test func testStreamingErrorHandling() async throws {
        let js = SwiftJS()
        let success = try await js.evaluate("""
            (async () => {
                try {
                    console.log('Starting streaming error handling test...');
                    
                    // Test streaming to an invalid URL to verify error handling
                    const session = __APPLE_SPEC__.URLSession.shared;
                    const request = new __APPLE_SPEC__.URLRequest('https://invalid-url-that-does-not-exist.com');
                    
                    try {
                        const result = await session.streamingDataTaskWithRequestCompletionHandler(request);
                        console.log('Unexpected success for invalid URL');
                        return false;
                    } catch (error) {
                        console.log('Expected error for invalid URL:', error.message);
                        return true; // Error handling worked correctly
                    }
                } catch (error) {
                    console.error('Streaming error handling test failed:', error.message);
                    return false;
                }
            })()
        """).toBool()
        
        #expect(success, "Streaming error handling should work correctly")
    }
    
    @Test func testConcurrentStreamingRequests() async throws {
        let js = SwiftJS()
        let success = try await js.evaluate("""
            (async () => {
                try {
                    console.log('Starting concurrent streaming requests test...');
                    
                    const session = __APPLE_SPEC__.URLSession.shared;
                    
                    // Create multiple concurrent streaming requests
                    const requests = [
                        'https://httpbin.org/json',
                        'https://httpbin.org/uuid',
                        'https://httpbin.org/headers'
                    ].map(url => {
                        const request = new __APPLE_SPEC__.URLRequest(url);
                        return session.streamingDataTaskWithRequestCompletionHandler(request);
                    });
                    
                    // Wait for all requests to complete
                    const results = await Promise.all(requests);
                    
                    console.log('Concurrent streaming results:', results.map(r => ({
                        status: r.response.statusCode,
                        hasBody: !!r.body
                    })));
                    
                    // Check that all requests succeeded
                    return results.every(result => 
                        result.response.statusCode === 200 && !!result.body
                    );
                } catch (error) {
                    console.error('Concurrent streaming error:', error.message);
                    return false;
                }
            })()
        """).toBool()
        
        #expect(success, "Concurrent streaming requests should succeed")
    }
    
    @Test func testStreamingRequestHeaders() async throws {
        let js = SwiftJS()
        let success = try await js.evaluate("""
            (async () => {
                try {
                    console.log('Starting streaming request headers test...');
                    
                    const session = __APPLE_SPEC__.URLSession.shared;
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/headers');
                    
                    // Add custom headers
                    request.setValueForHTTPHeaderField('SwiftJS-Test', 'X-Custom-Header');
                    request.setValueForHTTPHeaderField('application/json', 'Accept');
                    request.setValueForHTTPHeaderField('SwiftJS/1.0', 'User-Agent');
                    
                    const result = await session.streamingDataTaskWithRequestCompletionHandler(request);
                    
                    console.log('Headers streaming response:', {
                        status: result.response.statusCode,
                        contentType: result.response.value('Content-Type'),
                        hasBody: !!result.body
                    });
                    
                    return result.response.statusCode === 200 && !!result.body;
                } catch (error) {
                    console.error('Streaming headers error:', error.message);
                    return false;
                }
            })()
        """).toBool()
        
        #expect(success, "Streaming with custom headers should succeed")
    }
    
    @Test func testStreamingResponseMetadata() async throws {
        let js = SwiftJS()
        let success = try await js.evaluate("""
            (async () => {
                try {
                    console.log('Starting streaming response metadata test...');
                    
                    const session = __APPLE_SPEC__.URLSession.shared;
                    const request = new __APPLE_SPEC__.URLRequest('https://httpbin.org/json');
                    
                    const result = await session.streamingDataTaskWithRequestCompletionHandler(request);
                    
                    console.log('Response metadata:', {
                        status: result.response.statusCode,
                        url: result.response.url,
                        headers: Object.keys(result.response.allHeaderFields),
                        contentType: result.response.mimeType,
                        contentLength: result.response.expectedContentLength
                    });
                    
                    // Verify essential response metadata
                    return result.response.statusCode === 200 &&
                           !!result.response.url &&
                           typeof result.response.allHeaderFields === 'object' &&
                           Object.keys(result.response.allHeaderFields).length > 0;
                } catch (error) {
                    console.error('Response metadata error:', error.message);
                    return false;
                }
            })()
        """).toBool()
        
        #expect(success, "Streaming response metadata should be accessible")
    }
}
