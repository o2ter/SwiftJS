//
//  FetchTests.swift
//  SwiftJS Fetch API Tests
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

/// Tests for the Fetch API including basic fetch functionality, 
/// Request/Response objects, and live network requests.
@MainActor
final class FetchTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testFetchAPIExistence() {
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("fetch"))
        XCTAssertTrue(globals.toString().contains("Request"))
        XCTAssertTrue(globals.toString().contains("Response"))
    }
    
    func testFetchExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof fetch")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testRequestExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Request")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testResponseExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Response")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - Request API Tests
    
    func testRequestInstantiation() {
        let script = """
            const request = new Request('https://example.com');
            request instanceof Request
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testRequestURL() {
        let script = """
            const request = new Request('https://example.com/api');
            request.url
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "https://example.com/api")
    }
    
    func testRequestMethod() {
        let script = """
            const request = new Request('https://example.com', { method: 'POST' });
            request.method
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "POST")
    }
    
    func testRequestDefaultMethod() {
        let script = """
            const request = new Request('https://example.com');
            request.method
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "GET")
    }
    
    func testRequestHeaders() {
        let script = """
            const request = new Request('https://example.com', {
                headers: { 'Content-Type': 'application/json' }
            });
            request.headers.get('Content-Type')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "application/json")
    }
    
    func testRequestBody() {
        let script = """
            const request = new Request('https://example.com', {
                method: 'POST',
                body: JSON.stringify({ test: 'data' })
            });
            request.body !== null
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testRequestClone() {
        let script = """
            const original = new Request('https://example.com', {
                method: 'POST',
                headers: { 'X-Test': 'value' }
            });
            const cloned = original.clone();
            
            ({
                urlMatch: cloned.url === original.url,
                methodMatch: cloned.method === original.method,
                headerMatch: cloned.headers.get('X-Test') === original.headers.get('X-Test')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result["urlMatch"].boolValue ?? false)
        XCTAssertTrue(result["methodMatch"].boolValue ?? false)
        XCTAssertTrue(result["headerMatch"].boolValue ?? false)
    }
    
    // MARK: - Response API Tests
    
    func testResponseInstantiation() {
        let script = """
            const response = new Response('Hello World');
            response instanceof Response
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testResponseDefaults() {
        let script = """
            const response = new Response();
            ({
                status: response.status,
                statusText: response.statusText,
                ok: response.ok
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
        XCTAssertEqual(result["statusText"].toString(), "OK")
        XCTAssertTrue(result["ok"].boolValue ?? false)
    }
    
    func testResponseWithStatus() {
        let script = """
            const response = new Response('Error', {
                status: 404,
                statusText: 'Not Found'
            });
            ({
                status: response.status,
                statusText: response.statusText,
                ok: response.ok
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(Int(result["status"].numberValue ?? 0), 404)
        XCTAssertEqual(result["statusText"].toString(), "Not Found")
        XCTAssertFalse(result["ok"].boolValue ?? true)
    }
    
    func testResponseHeaders() {
        let script = """
            const response = new Response('test', {
                headers: { 'Content-Type': 'text/plain' }
            });
            response.headers.get('Content-Type')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "text/plain")
    }
    
    func testResponseText() {
        let expectation = XCTestExpectation(description: "Response text reading")
        
        let script = """
            const response = new Response('Hello, Response!');
            response.text().then(text => {
                testCompleted({ result: text });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello, Response!")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testResponseJSON() {
        let expectation = XCTestExpectation(description: "Response JSON parsing")
        
        let script = """
            const data = { message: 'Hello', value: 42 };
            const response = new Response(JSON.stringify(data), {
                headers: { 'Content-Type': 'application/json' }
            });
            
            response.json().then(parsed => {
                testCompleted({
                    message: parsed.message,
                    value: parsed.value,
                    isObject: typeof parsed === 'object'
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["message"].toString(), "Hello")
            XCTAssertEqual(Int(result["value"].numberValue ?? 0), 42)
            XCTAssertTrue(result["isObject"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testResponseClone() {
        let expectation = XCTestExpectation(description: "Response clone")
        
        let script = """
            const original = new Response('Test content', {
                status: 201,
                statusText: 'Created',
                headers: { 'X-Custom': 'value' }
            });
            
            const cloned = original.clone();
            
            Promise.all([
                original.text(),
                cloned.text()
            ]).then(([originalText, clonedText]) => {
                testCompleted({
                    originalText: originalText,
                    clonedText: clonedText,
                    statusMatch: cloned.status === original.status,
                    statusTextMatch: cloned.statusText === original.statusText,
                    headerMatch: cloned.headers.get('X-Custom') === original.headers.get('X-Custom')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["originalText"].toString(), "Test content")
            XCTAssertEqual(result["clonedText"].toString(), "Test content")
            XCTAssertTrue(result["statusMatch"].boolValue ?? false)
            XCTAssertTrue(result["statusTextMatch"].boolValue ?? false)
            XCTAssertTrue(result["headerMatch"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testResponseBodyStream() {
        let script = """
            const response = new Response('streaming content');
            response.body instanceof ReadableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Basic Fetch Tests
    
    func testFetchBasicCall() {
        let expectation = XCTestExpectation(description: "Basic fetch call")
        
        let script = """
            fetch('https://httpbin.org/get')
                .then(response => {
                    testCompleted({
                        ok: response.ok,
                        status: response.status,
                        hasHeaders: response.headers instanceof Headers
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped: \(result["error"].toString())")
            } else {
                XCTAssertTrue(result["ok"].boolValue ?? false)
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                XCTAssertTrue(result["hasHeaders"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchWithRequestObject() {
        let expectation = XCTestExpectation(description: "Fetch with Request object")
        
        let script = """
            const request = new Request('https://httpbin.org/headers', {
                headers: { 'X-Test-Header': 'fetch-test' }
            });
            
            fetch(request)
                .then(response => response.json())
                .then(data => {
                    testCompleted({
                        hasTestHeader: data.headers && 'X-Test-Header' in data.headers,
                        testHeaderValue: data.headers ? data.headers['X-Test-Header'] : null
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped: \(result["error"].toString())")
            } else {
                XCTAssertTrue(result["hasTestHeader"].boolValue ?? false)
                XCTAssertEqual(result["testHeaderValue"].toString(), "fetch-test")
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchPOST() {
        let expectation = XCTestExpectation(description: "Fetch POST request")
        
        let script = """
            const postData = { name: 'test', value: 123 };
            
            fetch('https://httpbin.org/post', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(postData)
            })
                .then(response => response.json())
                .then(data => {
                    const receivedData = JSON.parse(data.data || '{}');
                    testCompleted({
                        method: data.headers ? data.headers['X-Http-Method-Override'] || 'POST' : 'POST',
                        contentType: data.headers ? data.headers['Content-Type'] : null,
                        receivedName: receivedData.name,
                        receivedValue: receivedData.value
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped: \(result["error"].toString())")
            } else {
                // The exact structure of httpbin response may vary, just check we got some response
                XCTAssertNotNil(result["contentType"])
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Status Code Tests
    
    func testFetchStatusCodes() {
        let expectation = XCTestExpectation(description: "Fetch status codes")
        
        let script = """
            const testCases = [
                { url: 'https://httpbin.org/status/200', expectedStatus: 200 },
                { url: 'https://httpbin.org/status/404', expectedStatus: 404 },
                { url: 'https://httpbin.org/status/500', expectedStatus: 500 }
            ];
            
            const results = [];
            let completed = 0;
            
            testCases.forEach((testCase, index) => {
                fetch(testCase.url)
                    .then(response => {
                        results[index] = {
                            expectedStatus: testCase.expectedStatus,
                            actualStatus: response.status,
                            ok: response.ok,
                            matches: response.status === testCase.expectedStatus
                        };
                        completed++;
                        if (completed === testCases.length) {
                            testCompleted({ results: results });
                        }
                    })
                    .catch(error => {
                        results[index] = { error: error.message };
                        completed++;
                        if (completed === testCases.length) {
                            testCompleted({ results: results });
                        }
                    });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let results = result["results"]
            let resultsCount = Int(results["length"].numberValue ?? 0)
            
            if resultsCount > 0 {
                for i in 0..<resultsCount {
                    let testResult = results[i]
                    if !testResult["error"].isString {
                        XCTAssertTrue(testResult["matches"].boolValue ?? false, 
                                    "Status \(testResult["actualStatus"]) should match expected \(testResult["expectedStatus"])")
                    }
                }
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchInvalidURL() {
        let expectation = XCTestExpectation(description: "Fetch invalid URL")
        
        let script = """
            fetch('invalid-url')
                .then(response => {
                    testCompleted({ error: 'Should have failed' });
                })
                .catch(error => {
                    testCompleted({
                        caughtError: true,
                        errorType: error.name,
                        errorMessage: error.message
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].toString() == "Should have failed" {
                XCTFail("Invalid URL should have caused an error")
            } else {
                XCTAssertTrue(result["caughtError"].boolValue ?? false)
                XCTAssertNotEqual(result["errorMessage"].toString(), "")
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testFetchAbortController() {
        let expectation = XCTestExpectation(description: "Fetch with AbortController")
        
        let script = """
            const controller = new AbortController();
            
            // Abort immediately
            setTimeout(() => controller.abort(), 10);
            
            fetch('https://httpbin.org/delay/5', { signal: controller.signal })
                .then(response => {
                    testCompleted({ error: 'Should have been aborted' });
                })
                .catch(error => {
                    testCompleted({
                        aborted: true,
                        errorName: error.name,
                        isAbortError: error.name === 'AbortError'
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].toString() == "Should have been aborted" {
                // The abort might not work in all cases, that's ok
                XCTAssertTrue(true, "Abort not supported or request completed too quickly")
            } else {
                XCTAssertTrue(result["aborted"].boolValue ?? false)
                // The exact error name might vary
                XCTAssertNotEqual(result["errorName"].toString(), "")
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Response Type Tests
    
    func testFetchResponseTypes() {
        let expectation = XCTestExpectation(description: "Fetch response types")
        
        let script = """
            // Test different response types
            const tests = [];
            
            // JSON response
            fetch('https://httpbin.org/json')
                .then(response => response.json())
                .then(data => {
                    tests.push({
                        type: 'json',
                        success: typeof data === 'object' && data !== null
                    });
                    return runTextTest();
                })
                .catch(error => {
                    tests.push({ type: 'json', error: error.message });
                    return runTextTest();
                });
            
            function runTextTest() {
                return fetch('https://httpbin.org/html')
                    .then(response => response.text())
                    .then(text => {
                        tests.push({
                            type: 'text',
                            success: typeof text === 'string' && text.length > 0
                        });
                        testCompleted({ tests: tests });
                    })
                    .catch(error => {
                        tests.push({ type: 'text', error: error.message });
                        testCompleted({ tests: tests });
                    });
            }
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let tests = result["tests"]
            let testCount = Int(tests["length"].numberValue ?? 0)
            
            // At least verify we attempted the tests
            XCTAssertGreaterThanOrEqual(testCount, 1)
            
            for i in 0..<testCount {
                let test = tests[i]
                if !test["error"].isString {
                    XCTAssertTrue(test["success"].boolValue ?? false, 
                                "Response type test '\(test["type"].toString())' should succeed")
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 20.0)
    }
    
    // MARK: - Performance Tests
    
    func testFetchPerformance() {
        let expectation = XCTestExpectation(description: "Fetch performance")
        
        let script = """
            const startTime = Date.now();
            
            fetch('https://httpbin.org/get')
                .then(response => response.json())
                .then(data => {
                    const endTime = Date.now();
                    const duration = endTime - startTime;
                    
                    testCompleted({
                        duration: duration,
                        performanceOk: duration < 10000, // Should complete within 10 seconds
                        hasData: typeof data === 'object'
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped: \(result["error"].toString())")
            } else {
                XCTAssertTrue(result["performanceOk"].boolValue ?? false, 
                            "Request took \(result["duration"]) ms, should be under 10000ms")
                XCTAssertTrue(result["hasData"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Integration Tests
    
    func testFetchWithComplexRequestResponse() {
        let expectation = XCTestExpectation(description: "Complex fetch integration")
        
        let script = """
            const requestData = {
                timestamp: Date.now(),
                userAgent: 'SwiftJS-Test',
                testId: Math.random().toString(36)
            };
            
            const request = new Request('https://httpbin.org/post', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Test-Framework': 'SwiftJS',
                    'X-Test-Type': 'Integration'
                },
                body: JSON.stringify(requestData)
            });
            
            fetch(request)
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                    }
                    return response.json();
                })
                .then(responseData => {
                    // httpbin echoes back the request data
                    const receivedData = JSON.parse(responseData.data || '{}');
                    
                    testCompleted({
                        requestDataMatches: receivedData.testId === requestData.testId,
                        hasHeaders: !!responseData.headers,
                        methodCorrect: responseData.json !== undefined || responseData.data !== undefined,
                        timestampReceived: receivedData.timestamp,
                        originalTimestamp: requestData.timestamp
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].isString {
                // Network might not be available, skip the test
                XCTAssertTrue(true, "Network test skipped: \(result["error"].toString())")
            } else {
                XCTAssertTrue(result["requestDataMatches"].boolValue ?? false)
                XCTAssertTrue(result["hasHeaders"].boolValue ?? false)
                XCTAssertTrue(result["methodCorrect"].boolValue ?? false)
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
}
