//
//  PipeMethodsTests.swift
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
final class PipeMethodsTests: XCTestCase {
    
    // MARK: - pipeTo Method Tests
    
    func testPipeToMethodExists() {
        let context = SwiftJS()
        let script = """
            const stream = new ReadableStream();
            typeof stream.pipeTo === 'function'
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testPipeToBasicFunctionality() {
        let expectation = XCTestExpectation(description: "pipeTo basic functionality")
        
        let script = """
            const chunks = [];
            
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello '));
                    controller.enqueue(new TextEncoder().encode('World!'));
                    controller.close();
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    chunks.push(new TextDecoder().decode(chunk));
                },
                close() {
                    testCompleted({ 
                        result: chunks.join(''),
                        chunkCount: chunks.length
                    });
                }
            });
            
            source.pipeTo(destination).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello World!")
            XCTAssertEqual(Int(result["chunkCount"].numberValue ?? 0), 2)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testPipeToWithLargeData() {
        let expectation = XCTestExpectation(description: "pipeTo with large data")
        
        let script = """
            const expectedSize = 10000;
            let receivedSize = 0;
            
            const source = new ReadableStream({
                start(controller) {
                    for (let i = 0; i < expectedSize; i++) {
                        controller.enqueue(new TextEncoder().encode('A'));
                    }
                    controller.close();
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    receivedSize += chunk.byteLength;
                },
                close() {
                    testCompleted({ 
                        expectedSize: expectedSize,
                        receivedSize: receivedSize,
                        matches: expectedSize === receivedSize
                    });
                }
            });
            
            source.pipeTo(destination).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["matches"].boolValue ?? false)
            XCTAssertEqual(Int(result["expectedSize"].numberValue ?? 0), 10000)
            XCTAssertEqual(Int(result["receivedSize"].numberValue ?? 0), 10000)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testPipeToErrorPropagation() {
        let expectation = XCTestExpectation(description: "pipeTo error propagation")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Before error'));
                    setTimeout(() => {
                        controller.error(new Error('Source stream error'));
                    }, 10);
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    // Should receive at least one chunk
                }
            });
            
            source.pipeTo(destination)
                .then(() => {
                    testCompleted({ error: 'Should have failed' });
                })
                .catch(error => {
                    testCompleted({ 
                        caughtError: true,
                        errorMessage: error.message,
                        isExpectedError: error.message === 'Source stream error'
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["caughtError"].boolValue ?? false)
            XCTAssertTrue(result["isExpectedError"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    // MARK: - pipeThrough Method Tests
    
    func testPipeThroughMethodExists() {
        let context = SwiftJS()
        let script = """
            const stream = new ReadableStream();
            typeof stream.pipeThrough === 'function'
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testPipeThroughBasicTransform() {
        let expectation = XCTestExpectation(description: "pipeThrough basic transform")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('world'));
                    controller.close();
                }
            });
            
            const upperCaseTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    const upperText = text.toUpperCase();
                    controller.enqueue(new TextEncoder().encode(upperText));
                }
            });
            
            const chunks = [];
            const destination = new WritableStream({
                write(chunk) {
                    chunks.push(new TextDecoder().decode(chunk));
                },
                close() {
                    // Don't call testCompleted here - let the pipeTo promise handle it
                }
            });
            
            const transformedStream = source.pipeThrough(upperCaseTransform);
            
            // Verify pipeThrough returns the readable side
            const isReadableStream = transformedStream instanceof ReadableStream;
            
            transformedStream.pipeTo(destination).then(() => {
                testCompleted({ 
                    result: chunks.join(''),
                    isReadableStream: isReadableStream
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "HELLO WORLD")
            XCTAssertTrue(result["isReadableStream"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testPipeThroughComplexPipeline() {
        let expectation = XCTestExpectation(description: "pipeThrough complex pipeline")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('test data'));
                    controller.close();
                }
            });
            
            // Transform 1: uppercase
            const upperTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    controller.enqueue(new TextEncoder().encode(text.toUpperCase()));
                }
            });
            
            // Transform 2: add prefix
            const prefixTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    controller.enqueue(new TextEncoder().encode('PROCESSED: ' + text));
                }
            });
            
            // Transform 3: add suffix
            const suffixTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    controller.enqueue(new TextEncoder().encode(text + ' [DONE]'));
                }
            });
            
            let finalResult = '';
            const destination = new WritableStream({
                write(chunk) {
                    finalResult += new TextDecoder().decode(chunk);
                },
                close() {
                    testCompleted({ 
                        result: finalResult,
                        expected: 'PROCESSED: TEST DATA [DONE]',
                        matches: finalResult === 'PROCESSED: TEST DATA [DONE]'
                    });
                }
            });
            
            // Chain multiple transforms
            source
                .pipeThrough(upperTransform)
                .pipeThrough(prefixTransform)
                .pipeThrough(suffixTransform)
                .pipeTo(destination)
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["matches"].boolValue ?? false)
            XCTAssertEqual(result["result"].toString(), "PROCESSED: TEST DATA [DONE]")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    // MARK: - Options and Control Tests
    
    func testPipeToWithAbortController() {
        let expectation = XCTestExpectation(description: "pipeTo with AbortController")
        
        let script = """
            const controller = new AbortController();
            let receivedChunks = 0;
            
            const source = new ReadableStream({
                start(streamController) {
                    let count = 0;
                    const interval = setInterval(() => {
                        streamController.enqueue(new TextEncoder().encode(`chunk-${count++}`));
                        if (count >= 20) {
                            streamController.close();
                            clearInterval(interval);
                        }
                    }, 10);
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    receivedChunks++;
                    // Don't process too many chunks
                }
            });
            
            // Abort after receiving some chunks
            setTimeout(() => {
                controller.abort();
            }, 50);
            
            source.pipeTo(destination, { signal: controller.signal })
                .then(() => {
                    testCompleted({ error: 'Should not have completed normally' });
                })
                .catch(error => {
                    testCompleted({ 
                        isAbortError: error.message === 'AbortError',
                        receivedChunks: receivedChunks,
                        receivedSome: receivedChunks > 0 && receivedChunks < 20
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["isAbortError"].boolValue ?? false)
            XCTAssertTrue(result["receivedSome"].boolValue ?? false)
            let receivedCount = Int(result["receivedChunks"].numberValue ?? 0)
            XCTAssertGreaterThan(receivedCount, 0)
            XCTAssertLessThan(receivedCount, 20)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testPipeToWithPreventCloseOption() {
        let expectation = XCTestExpectation(description: "pipeTo with preventClose option")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('test'));
                    controller.close();
                }
            });
            
            let destinationClosed = false;
            const destination = new WritableStream({
                write(chunk) {
                    // Process chunk
                },
                close() {
                    destinationClosed = true;
                }
            });
            
            source.pipeTo(destination, { preventClose: true })
                .then(() => {
                    // Give it a moment to see if close was called
                    setTimeout(() => {
                        testCompleted({ 
                            destinationClosed: destinationClosed,
                            preventedClose: !destinationClosed
                        });
                    }, 10);
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertFalse(result["destinationClosed"].boolValue ?? true)
            XCTAssertTrue(result["preventedClose"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    // MARK: - Type Validation Tests
    
    func testPipeToTypeValidation() {
        let context = SwiftJS()
        let script = """
            const source = new ReadableStream({
                start(controller) { controller.close(); }
            });
            
            const testCases = [];
            
            // Test null
            try {
                source.pipeTo(null);
                testCases.push({ test: 'null', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'null', 
                    passed: error instanceof TypeError,
                    errorType: error.constructor.name
                });
            }
            
            // Test undefined
            try {
                source.pipeTo(undefined);
                testCases.push({ test: 'undefined', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'undefined', 
                    passed: error instanceof TypeError,
                    errorType: error.constructor.name
                });
            }
            
            // Test string
            try {
                source.pipeTo('not a stream');
                testCases.push({ test: 'string', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'string', 
                    passed: error instanceof TypeError,
                    errorType: error.constructor.name
                });
            }
            
            globalThis.pipeToValidationResults = testCases;
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.pipeToValidationResults")
        
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 3)
        
        for i in 0..<3 {
            let testCase = result[i]
            XCTAssertTrue(testCase["passed"].boolValue ?? false, "Test case \(testCase["test"].toString()) failed")
            XCTAssertEqual(testCase["errorType"].toString(), "TypeError")
        }
    }
    
    func testPipeThroughTypeValidation() {
        let context = SwiftJS()
        let script = """
            const source = new ReadableStream({
                start(controller) { controller.close(); }
            });
            
            const testCases = [];
            
            // Test null
            try {
                source.pipeThrough(null);
                testCases.push({ test: 'null', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'null', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            // Test object without required properties
            try {
                source.pipeThrough({});
                testCases.push({ test: 'empty object', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'empty object', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            // Test object with only writable
            try {
                source.pipeThrough({ writable: new WritableStream() });
                testCases.push({ test: 'only writable', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'only writable', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            // Test object with only readable
            try {
                source.pipeThrough({ readable: new ReadableStream() });
                testCases.push({ test: 'only readable', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'only readable', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            globalThis.pipeThroughValidationResults = testCases;
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.pipeThroughValidationResults")
        
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 4)
        
        for i in 0..<4 {
            let testCase = result[i]
            XCTAssertTrue(testCase["passed"].boolValue ?? false, "Test case \(testCase["test"].toString()) failed: \(testCase["errorMessage"].toString())")
        }
    }
    
    // MARK: - Integration Tests
    
    func testPipeWithResponseStreams() {
        let expectation = XCTestExpectation(description: "Pipe with Response streams")
        
        let script = """
            // Create a response with some data
            const response = new Response('{"name": "test", "value": 42}');
            
            // Transform to parse JSON and modify
            const jsonTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    try {
                        const data = JSON.parse(text);
                        data.processed = true;
                        data.timestamp = Date.now();
                        const modifiedText = JSON.stringify(data);
                        controller.enqueue(new TextEncoder().encode(modifiedText));
                    } catch (e) {
                        controller.error(e);
                    }
                }
            });
            
            let result = '';
            const destination = new WritableStream({
                write(chunk) {
                    result += new TextDecoder().decode(chunk);
                },
                close() {
                    try {
                        const parsed = JSON.parse(result);
                        testCompleted({
                            hasOriginalData: parsed.name === 'test' && parsed.value === 42,
                            hasProcessedFlag: parsed.processed === true,
                            hasTimestamp: typeof parsed.timestamp === 'number',
                            result: result
                        });
                    } catch (e) {
                        testCompleted({ error: e.message });
                    }
                }
            });
            
            response.body
                .pipeThrough(jsonTransform)
                .pipeTo(destination)
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["hasOriginalData"].boolValue ?? false)
            XCTAssertTrue(result["hasProcessedFlag"].boolValue ?? false)
            XCTAssertTrue(result["hasTimestamp"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
}
