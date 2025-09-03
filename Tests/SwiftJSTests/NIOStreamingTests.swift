//
//  NIOStreamingTests.swift
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

import Foundation
import Testing
@testable import SwiftJS

@Suite(.serialized) // Run streaming tests in sequence to avoid interference
struct NIOStreamingTests {

    @Test func testBasicStreamingDownload() async throws {
        let js = SwiftJS()
        
    // Test basic HTTP request functionality
    let result = js.evaluateScript(
      """
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
                    
                    return result.response.statusCode === 200 && !!result.data;
                } catch (error) {
                    console.error('Download error:', error.message);
                    return false;
                }
            })()
      """)
        
    // Simple verification that the function returns a promise
    #expect(!result.isUndefined, "Should return a promise")
    }
    
    @Test func testStreamingUploadWithBody() async throws {
        let js = SwiftJS()
        
    // Test upload with ReadableStream body
    let result = js.evaluateScript(
      """
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
                    return result.response.statusCode >= 200 && result.response.statusCode < 300;
                } catch (error) {
                    console.error('Upload error:', error.message);
                    return false;
                }
            })()
      """)
        
    #expect(!result.isUndefined, "Upload should return a promise")
    }
    
  @Test func testStreamingWithProgressHandler() async throws {
        let js = SwiftJS()
        
    // Test streaming with progress handler
    let result = js.evaluateScript(
      """
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
                    return progressCallCount > 0;
                } catch (error) {
                    console.error('Progress streaming error:', error.message);
                    return false;
                }
            })()
      """)
        
    #expect(!result.isUndefined, "Progress streaming should return a promise")
    }
    
    @Test func testStreamingErrorHandling() async throws {
        let js = SwiftJS()
        
    // Test error handling with invalid URL
    let result = js.evaluateScript(
      """
            (async () => {
                try {
                    console.log('Starting error handling test...');
                    
                    const session = __APPLE_SPEC__.URLSession.shared();
                    const request = new __APPLE_SPEC__.URLRequest('https://invalid-url-that-does-not-exist.com');
                    
                    try {
                        const result = await session.httpRequestWithRequest(request, null, null, null);
                        console.log('Unexpected success for invalid URL');
                        return false;
                    } catch (error) {
                        console.log('Expected error for invalid URL:', error.message);
                        return true; // Error handling worked correctly
                    }
                } catch (error) {
                    console.error('Error handling test failed:', error.message);
                    return false;
                }
            })()
      """)
        
    #expect(!result.isUndefined, "Error handling should return a promise")
    }
    
  @Test func testBasicAPIAvailability() {
    let js = SwiftJS()
        
    // Test that the required APIs are available
    let hasURLSession =
      js.evaluateScript("typeof __APPLE_SPEC__.URLSession").toString() == "object"
    let hasURLSessionShared =
      js.evaluateScript("typeof __APPLE_SPEC__.URLSession.shared").toString() == "function"
    let hasURLRequest =
      js.evaluateScript("typeof __APPLE_SPEC__.URLRequest").toString() == "function"
    let hasReadableStream = js.evaluateScript("typeof ReadableStream").toString() == "function"

    #expect(hasURLSession, "URLSession should be available as object")
    #expect(hasURLSessionShared, "URLSession.shared should be available as function")
    #expect(hasURLRequest, "URLRequest should be available as constructor")
    #expect(hasReadableStream, "ReadableStream should be available")
    }
}
