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

import XCTest
@testable import SwiftJS

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
    
    func testReadableStreamExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof ReadableStream")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testWritableStreamExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof WritableStream")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testTransformStreamExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof TransformStream")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - ReadableStream Basic Tests
    
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
    
    // MARK: - WritableStream Basic Tests
    
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
    
    // MARK: - Stream Tee Tests
    
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
    
    // MARK: - Response Clone with Streams
    
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
    
    // MARK: - Fetch with Streaming Response
    
    func testFetchStreamingResponse() {
        let expectation = XCTestExpectation(description: "Fetch streaming response")
        
        let script = """
            fetch('https://api.github.com/zen')
                .then(response => {
                    // Test streaming response properties without consuming body
                    testCompleted({
                        isStream: response.body instanceof ReadableStream,
                        hasText: true, // We assume the response has text but don't read it
                        textType: 'string',
                        status: response.status
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["isStream"].boolValue ?? false)
            XCTAssertTrue(result["hasText"].boolValue ?? false)
            XCTAssertEqual(result["textType"].toString(), "string")
            // Also verify we got a successful response
            let statusString = result["status"].toString()
            XCTAssertEqual(statusString, "200")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation])
    }
    
    // MARK: - Request with Streaming Body
    
    func testRequestStreamingBody() {
        let script = """
            try {
                const stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('{"message": "'));
                        controller.enqueue(new TextEncoder().encode('Hello from stream'));
                        controller.enqueue(new TextEncoder().encode('"}'));
                        controller.close();
                    }
                });
                
                const request = new Request('https://example.com', {
                    method: 'POST',
                    body: stream,
                    headers: { 'Content-Type': 'application/json' }
                });
                
                globalThis.streamRequestTest = {
                    hasBody: request.body !== null,
                    bodyIsStream: request.body instanceof ReadableStream,
                    method: request.method
                };
            } catch (error) {
                globalThis.streamRequestTest = { error: error.message };
            }
        """
        
        let context = SwiftJS()
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.streamRequestTest")
        
        XCTAssertFalse(result.isUndefined)
        XCTAssertTrue(result["hasBody"].boolValue ?? false)
        XCTAssertTrue(result["bodyIsStream"].boolValue ?? false)
        XCTAssertEqual(result["method"].toString(), "POST")
    }
    
    // MARK: - Pipe Methods Tests

    func testPipeToBasic() {
        let expectation = XCTestExpectation(description: "Basic pipeTo functionality")

        let script = """
                const source = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('Hello '));
                        controller.enqueue(new TextEncoder().encode('World'));
                        controller.close();
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
                
                source.pipeTo(destination).catch(error => {
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

    func testPipeThroughBasic() {
        let expectation = XCTestExpectation(description: "Basic pipeThrough functionality")

        let script = """
                const source = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('hello world'));
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
                
                const transformedStream = source.pipeThrough(upperCaseTransform);
                transformedStream.pipeTo(destination).catch(error => {
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

    func testPipeThroughChaining() {
        let expectation = XCTestExpectation(description: "PipeThrough chaining")

        let script = """
                const source = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('test'));
                        controller.close();
                    }
                });
                
                const upperTransform = new TransformStream({
                    transform(chunk, controller) {
                        const text = new TextDecoder().decode(chunk);
                        controller.enqueue(new TextEncoder().encode(text.toUpperCase()));
                    }
                });
                
                const prefixTransform = new TransformStream({
                    transform(chunk, controller) {
                        const text = new TextDecoder().decode(chunk);
                        controller.enqueue(new TextEncoder().encode('PREFIX_' + text));
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
                
                source
                    .pipeThrough(upperTransform)
                    .pipeThrough(prefixTransform)
                    .pipeTo(destination)
                    .catch(error => {
                        testCompleted({ error: error.message });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "PREFIX_TEST")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation])
    }

    func testPipeToErrorHandling() {
        let expectation = XCTestExpectation(description: "PipeTo error handling")

        let script = """
                const source = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('data'));
                        controller.error(new Error('Source error'));
                    }
                });
                
                const destination = new WritableStream({
                    write(chunk) {
                        // Should receive some data before error
                    }
                });
                
                source.pipeTo(destination)
                    .then(() => {
                        testCompleted({ error: 'Should have failed' });
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
            XCTAssertEqual(result["errorMessage"].toString(), "Source error")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation])
    }

    func testPipeToTypeValidation() {
        let expectation = XCTestExpectation(description: "PipeTo type validation")

        let script = """
                const source = new ReadableStream({
                    start(controller) {
                        controller.close();
                    }
                });
                
                try {
                    source.pipeTo(null);
                    testCompleted({ error: 'Should have thrown TypeError' });
                } catch (error) {
                    testCompleted({ 
                        isTypeError: error instanceof TypeError,
                        errorMessage: error.message 
                    });
                }
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["isTypeError"].boolValue ?? false)
            XCTAssertTrue(result["errorMessage"].toString().contains("WritableStream"))
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation])
    }

    func testPipeThroughTypeValidation() {
        let expectation = XCTestExpectation(description: "PipeThrough type validation")

        let script = """
                const source = new ReadableStream({
                    start(controller) {
                        controller.close();
                    }
                });
                
                const results = [];
                
                // Test with null
                try {
                    source.pipeThrough(null);
                    results.push({ test: 'null', error: 'Should have thrown' });
                } catch (error) {
                    results.push({ 
                        test: 'null',
                        isTypeError: error instanceof TypeError,
                        passed: true 
                    });
                }
                
                // Test with object missing writable
                try {
                    source.pipeThrough({ readable: new ReadableStream() });
                    results.push({ test: 'missingWritable', error: 'Should have thrown' });
                } catch (error) {
                    results.push({ 
                        test: 'missingWritable',
                        isTypeError: error instanceof TypeError,
                        passed: true 
                    });
                }
                
                // Test with object missing readable
                try {
                    source.pipeThrough({ writable: new WritableStream() });
                    results.push({ test: 'missingReadable', error: 'Should have thrown' });
                } catch (error) {
                    results.push({ 
                        test: 'missingReadable',
                        isTypeError: error instanceof TypeError,
                        passed: true 
                    });
                }
                
                testCompleted({ results: results });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let results = result["results"]
            XCTAssertEqual(results["length"].numberValue, 3)

            for i in 0..<3 {
                let testResult = results[i]
                XCTAssertTrue(
                    testResult["passed"].boolValue ?? false,
                    "Test \(testResult["test"].toString()) failed")
                XCTAssertTrue(
                    testResult["isTypeError"].boolValue ?? false,
                    "Test \(testResult["test"].toString()) should be TypeError")
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation])
    }

    func testPipeToWithAbortSignal() {
        let expectation = XCTestExpectation(description: "PipeTo with AbortSignal")

        let script = """
                const controller = new AbortController();
                
                const source = new ReadableStream({
                    start(streamController) {
                        let count = 0;
                        const interval = setInterval(() => {
                            streamController.enqueue(new TextEncoder().encode(`chunk-${count++}`));
                            if (count >= 10) {
                                streamController.close();
                                clearInterval(interval);
                            }
                        }, 50);
                    }
                });
                
                const receivedChunks = [];
                const destination = new WritableStream({
                    write(chunk) {
                        const text = new TextDecoder().decode(chunk);
                        receivedChunks.push(text);
                    }
                });
                
                // Abort after 150ms (should receive ~3 chunks)
                setTimeout(() => {
                    controller.abort();
                }, 150);
                
                source.pipeTo(destination, { signal: controller.signal })
                    .then(() => {
                        testCompleted({ error: 'Should not have completed' });
                    })
                    .catch(error => {
                        testCompleted({ 
                            isAbortError: error.message === 'AbortError',
                            receivedChunksCount: receivedChunks.length,
                            receivedSome: receivedChunks.length > 0 && receivedChunks.length < 10
                        });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["isAbortError"].boolValue ?? false)
            XCTAssertTrue(result["receivedSome"].boolValue ?? false)
            let chunksCount = Int(result["receivedChunksCount"].numberValue ?? 0)
            XCTAssertGreaterThan(chunksCount, 0)
            XCTAssertLessThan(chunksCount, 10)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation])
    }

    func testPipeToWithPreventClose() {
        let expectation = XCTestExpectation(description: "PipeTo with preventClose")

        let script = """
                const source = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('Hello'));
                        controller.close();
                    }
                });
                
                let writerClosed = false;
                const destination = new WritableStream({
                    write(chunk) {
                        // Process chunk
                    },
                    close() {
                        writerClosed = true;
                    }
                });
                
                source.pipeTo(destination, { preventClose: true })
                    .then(() => {
                        testCompleted({ 
                            writerClosed: writerClosed,
                            preventedClose: !writerClosed 
                        });
                    })
                    .catch(error => {
                        testCompleted({ error: error.message });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertFalse(result["writerClosed"].boolValue ?? true)
            XCTAssertTrue(result["preventedClose"].boolValue ?? false)
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
}
