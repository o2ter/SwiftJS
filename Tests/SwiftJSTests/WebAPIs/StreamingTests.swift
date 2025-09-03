//
//  StreamingTests.swift
//  SwiftJS Streaming API Tests
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

/// Tests for the Web Streams API including ReadableStream, WritableStream,
/// TransformStream, and pipe methods (pipeTo, pipeThrough).
@MainActor
final class StreamingTests: XCTestCase {
    
    // MARK: - Stream API Existence Tests
    
    func testStreamAPIExistence() {
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("ReadableStream"))
        XCTAssertTrue(globals.toString().contains("WritableStream"))
        XCTAssertTrue(globals.toString().contains("TransformStream"))
    }
    
    func testStreamConstructors() {
        let context = SwiftJS()
        
        XCTAssertEqual(context.evaluateScript("typeof ReadableStream").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof WritableStream").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof TransformStream").toString(), "function")
    }
    
    // MARK: - ReadableStream Tests
    
    func testReadableStreamCreation() {
        let script = """
            const stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('World'));
                    controller.close();
                }
            });
            stream instanceof ReadableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testReadableStreamReading() {
        let expectation = XCTestExpectation(description: "ReadableStream reading")
        
        let script = """
            const stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('World'));
                    controller.close();
                }
            });
            
            const reader = stream.getReader();
            const chunks = [];
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        reader.releaseLock();
                        // Combine all chunks
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                        return;
                    }
                    chunks.push(value);
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello World")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testReadableStreamTee() {
        let expectation = XCTestExpectation(description: "ReadableStream tee")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('World'));
                    controller.close();
                }
            });
            
            const [stream1, stream2] = source.tee();
            
            const results = [];
            
            async function readStream(stream, index) {
                const reader = stream.getReader();
                const chunks = [];
                
                try {
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks.push(value);
                    }
                    
                    let totalLength = 0;
                    chunks.forEach(chunk => totalLength += chunk.byteLength);
                    const combined = new Uint8Array(totalLength);
                    let offset = 0;
                    chunks.forEach(chunk => {
                        combined.set(chunk, offset);
                        offset += chunk.byteLength;
                    });
                    const text = new TextDecoder().decode(combined);
                    results[index] = text;
                } finally {
                    reader.releaseLock();
                }
            }
            
            Promise.all([
                readStream(stream1, 0),
                readStream(stream2, 1)
            ]).then(() => {
                testCompleted({
                    stream1: results[0],
                    stream2: results[1],
                    areEqual: results[0] === results[1]
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["stream1"].toString(), "Hello World")
            XCTAssertEqual(result["stream2"].toString(), "Hello World")
            XCTAssertTrue(result["areEqual"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    // MARK: - WritableStream Tests
    
    func testWritableStreamCreation() {
        let script = """
            const stream = new WritableStream({
                write(chunk) {
                    // Process the chunk
                }
            });
            stream instanceof WritableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testWritableStreamWriting() {
        let expectation = XCTestExpectation(description: "WritableStream writing")
        
        let script = """
            const chunks = [];
            const stream = new WritableStream({
                write(chunk) {
                    chunks.push(chunk);
                },
                close() {
                    // Combine all chunks and decode
                    let totalLength = 0;
                    chunks.forEach(chunk => totalLength += chunk.byteLength);
                    const combined = new Uint8Array(totalLength);
                    let offset = 0;
                    chunks.forEach(chunk => {
                        combined.set(chunk, offset);
                        offset += chunk.byteLength;
                    });
                    const text = new TextDecoder().decode(combined);
                    testCompleted({ result: text });
                }
            });
            
            const writer = stream.getWriter();
            writer.write(new TextEncoder().encode('Streaming '))
                .then(() => writer.write(new TextEncoder().encode('in ')))
                .then(() => writer.write(new TextEncoder().encode('SwiftJS!')))
                .then(() => writer.close())
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Streaming in SwiftJS!")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    // MARK: - TransformStream Tests
    
    func testTransformStreamCreation() {
        let script = """
            const transform = new TransformStream({
                transform(chunk, controller) {
                    // Transform the chunk
                    controller.enqueue(chunk);
                }
            });
            transform instanceof TransformStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testTransformStreamPipeline() {
        let expectation = XCTestExpectation(description: "TransformStream pipeline")
        
        let script = """
            // Create a transform that uppercases text
            const upperCaseTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    const upperText = text.toUpperCase();
                    controller.enqueue(new TextEncoder().encode(upperText));
                }
            });
            
            // Create source stream
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('hello '));
                    controller.enqueue(new TextEncoder().encode('streaming '));
                    controller.enqueue(new TextEncoder().encode('world'));
                    controller.close();
                }
            });
            
            // Read from the transformed stream
            const reader = upperCaseTransform.readable.getReader();
            const writer = upperCaseTransform.writable.getWriter();
            
            // Pipe source to transform
            const sourceReader = source.getReader();
            function pump() {
                return sourceReader.read().then(({ done, value }) => {
                    if (done) {
                        writer.close();
                        return;
                    }
                    return writer.write(value).then(pump);
                });
            }
            
            // Read transformed output
            const chunks = [];
            function readOutput() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        // Combine and decode
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                        return;
                    }
                    chunks.push(value);
                    return readOutput();
                });
            }
            
            Promise.all([pump(), readOutput()]).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "HELLO STREAMING WORLD")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
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
    
    func testClearTimeout() {
        let expectation = XCTestExpectation(description: "clearTimeout")
        
        let script = """
            let timeoutExecuted = false;
            
            const timeoutId = setTimeout(() => {
                timeoutExecuted = true;
            }, 100);
            
            clearTimeout(timeoutId);
            
            // Wait longer than the timeout to verify it was cancelled
            setTimeout(() => {
                testCompleted({ executed: timeoutExecuted });
            }, 200);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["executed"].boolValue ?? true)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
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
    
    // MARK: - Pipe Options Tests
    
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
    
    // MARK: - Response Body Stream Tests
    
    func testResponseBodyIsStream() {
        let script = """
            const response = new Response('Hello, streaming world!');
            response.body instanceof ReadableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testResponseStreamReading() {
        let expectation = XCTestExpectation(description: "Response stream reading")
        
        let script = """
            const response = new Response('Hello, streaming world!');
            const reader = response.body.getReader();
            const chunks = [];
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        // Combine chunks
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                        return;
                    }
                    chunks.push(value);
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello, streaming world!")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testResponseCloneWithStream() {
        let expectation = XCTestExpectation(description: "Response clone with stream")
        
        let script = """
            const original = new Response('Hello, cloned world!');
            const cloned = original.clone();
            
            Promise.all([
                original.text(),
                cloned.text()
            ]).then(([originalText, clonedText]) => {
                testCompleted({
                    original: originalText,
                    cloned: clonedText,
                    areEqual: originalText === clonedText
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["original"].toString(), "Hello, cloned world!")
            XCTAssertEqual(result["cloned"].toString(), "Hello, cloned world!")
            XCTAssertTrue(result["areEqual"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    func testResponsePipeThrough() {
        let expectation = XCTestExpectation(description: "Response stream pipeThrough")

        let script = """
                const response = new Response('hello world');
                
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
                        chunks.push(chunk);
                    },
                    close() {
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                    }
                });
                
                response.body
                    .pipeThrough(upperCaseTransform)
                    .pipeTo(destination)
                    .catch(error => {
                        testCompleted({ error: error.message });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "HELLO WORLD")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    // MARK: - Error Handling Tests
    
    func testStreamErrorHandling() {
        let expectation = XCTestExpectation(description: "Stream error handling")
        
        let script = """
            const stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.error(new Error('Stream error'));
                }
            });
            
            const reader = stream.getReader();
            reader.read()
                .then(({ done, value }) => {
                    if (!done) {
                        const text = new TextDecoder().decode(value);
                        return reader.read(); // This should error
                    }
                })
                .then(() => {
                    testCompleted({ error: 'Should have errored' });
                })
                .catch(error => {
                    testCompleted({ 
                        caughtError: true,
                        errorMessage: error.message 
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["caughtError"].boolValue ?? false)
            XCTAssertEqual(result["errorMessage"].toString(), "Stream error")
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
}
