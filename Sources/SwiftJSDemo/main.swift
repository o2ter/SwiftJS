//
//  main.swift
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
import SwiftJS

let context = SwiftJS()

// === SwiftJS Streaming Verification Test ===
print("=== SwiftJS Streaming Verification Test ===")
print("Testing upload and download streaming capabilities...\n")

// Test 1: Verify basic streaming infrastructure
print("1. Testing basic streaming infrastructure...")
let streamingInfrastructureTest = """
// Check that all stream classes exist and are constructible
const readableStreamExists = typeof ReadableStream === 'function';
const writableStreamExists = typeof WritableStream === 'function';
const transformStreamExists = typeof TransformStream === 'function';

console.log('ReadableStream exists:', readableStreamExists);
console.log('WritableStream exists:', writableStreamExists);
console.log('TransformStream exists:', transformStreamExists);

// Test basic stream creation
try {
    const readable = new ReadableStream();
    const writable = new WritableStream();
    const transform = new TransformStream();
    console.log('✓ All stream types can be instantiated');
} catch (error) {
    console.error('✗ Stream instantiation error:', error.message);
}
"""

context.evaluateScript(streamingInfrastructureTest)

// Test 2: Upload streaming simulation
print("\n2. Testing upload streaming simulation...")
let uploadStreamingTest = """
async function testUploadStreaming() {
    console.log('Testing upload streaming...');
    
    // Create a readable stream that simulates large data being uploaded
    const uploadData = 'This is chunk of upload data. ';
    const totalChunks = 5;
    let chunksSent = 0;
    
    const uploadStream = new ReadableStream({
        start(controller) {
            console.log('Upload stream started');
        },
        pull(controller) {
            if (chunksSent < totalChunks) {
                const chunk = new TextEncoder().encode(uploadData + `Chunk ${chunksSent + 1}. `);
                controller.enqueue(chunk);
                chunksSent++;
                console.log(`Enqueued upload chunk ${chunksSent}/${totalChunks}`);
            } else {
                controller.close();
                console.log('Upload stream closed');
            }
        }
    });
    
    // Simulate reading the stream (as would happen during upload)
    const reader = uploadStream.getReader();
    const uploadedChunks = [];
    let totalUploadedBytes = 0;
    
    try {
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            uploadedChunks.push(value);
            totalUploadedBytes += value.byteLength;
            console.log(`Uploaded chunk: ${value.byteLength} bytes`);
        }
        
        console.log(`✓ Upload complete: ${uploadedChunks.length} chunks, ${totalUploadedBytes} bytes total`);
        
        // Verify the data integrity
        let combinedData = new Uint8Array(totalUploadedBytes);
        let offset = 0;
        uploadedChunks.forEach(chunk => {
            combinedData.set(chunk, offset);
            offset += chunk.byteLength;
        });
        
        const finalText = new TextDecoder().decode(combinedData);
        console.log('✓ Upload data integrity check:', finalText.includes('Chunk 5') ? 'PASSED' : 'FAILED');
        
    } catch (error) {
        console.error('✗ Upload streaming error:', error.message);
    } finally {
        reader.releaseLock();
    }
}

testUploadStreaming().catch(error => {
    console.error('✗ Upload streaming test failed:', error.message);
});
"""

context.evaluateScript(uploadStreamingTest)

// Test 3: Download streaming simulation
print("\n3. Testing download streaming simulation...")
let downloadStreamingTest = """
async function testDownloadStreaming() {
    console.log('Testing download streaming...');
    
    // Simulate a Response with streaming body (like from fetch)
    const responseData = 'This is streaming response data. '.repeat(10);
    const response = new Response(responseData);
    
    console.log('✓ Response body is ReadableStream:', response.body instanceof ReadableStream);
    
    // Test progressive reading of the response
    const reader = response.body.getReader();
    const downloadedChunks = [];
    let totalDownloadedBytes = 0;
    let chunkCount = 0;
    
    try {
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            chunkCount++;
            downloadedChunks.push(value);
            totalDownloadedBytes += value.byteLength;
            console.log(`Downloaded chunk ${chunkCount}: ${value.byteLength} bytes`);
            
            // Simulate processing data as it arrives (streaming processing)
            const chunkText = new TextDecoder().decode(value);
            if (chunkText.includes('streaming')) {
                console.log(`✓ Found "streaming" keyword in chunk ${chunkCount}`);
            }
        }
        
        console.log(`✓ Download complete: ${chunkCount} chunks, ${totalDownloadedBytes} bytes total`);
        
        // Verify data integrity
        let combinedData = new Uint8Array(totalDownloadedBytes);
        let offset = 0;
        downloadedChunks.forEach(chunk => {
            combinedData.set(chunk, offset);
            offset += chunk.byteLength;
        });
        
        const finalText = new TextDecoder().decode(combinedData);
        console.log('✓ Download data integrity check:', finalText === responseData ? 'PASSED' : 'FAILED');
        
    } catch (error) {
        console.error('✗ Download streaming error:', error.message);
    } finally {
        reader.releaseLock();
    }
}

testDownloadStreaming().catch(error => {
    console.error('✗ Download streaming test failed:', error.message);
});
"""

context.evaluateScript(downloadStreamingTest)

// Test 4: Transform stream for data processing during upload/download
print("\n4. Testing transform streaming (processing data in transit)...")
let transformStreamingTest = """
async function testTransformStreaming() {
    console.log('Testing transform streaming...');
    
    // Create a transform that compresses whitespace (simulating data processing)
    const compressionTransform = new TransformStream({
        transform(chunk, controller) {
            try {
                const text = new TextDecoder().decode(chunk);
                const compressed = text.replace(/\\s+/g, ' ').trim();
                const compressedChunk = new TextEncoder().encode(compressed);
                controller.enqueue(compressedChunk);
                console.log(`Transformed chunk: ${chunk.byteLength} -> ${compressedChunk.byteLength} bytes`);
            } catch (error) {
                console.error('✗ Transform error:', error.message);
                controller.error(error);
            }
        }
    });
    
    // Create source data with extra whitespace
    const sourceData = 'This    has     extra    whitespace     and     should     be     compressed.';
    const sourceStream = new ReadableStream({
        start(controller) {
            controller.enqueue(new TextEncoder().encode(sourceData));
            controller.close();
        }
    });
    
    // Pipe through transform
    const reader = sourceStream.getReader();
    const writer = compressionTransform.writable.getWriter();
    const outputReader = compressionTransform.readable.getReader();
    
    // Pipe source to transform
    try {
        while (true) {
            const { done, value } = await reader.read();
            if (done) {
                await writer.close();
                break;
            }
            await writer.write(value);
        }
    } catch (error) {
        console.error('✗ Piping error:', error.message);
    }
    
    // Read transformed output
    try {
        const { value } = await outputReader.read();
        if (value) {
            const result = new TextDecoder().decode(value);
            console.log('Original:', sourceData);
            console.log('Transformed:', result);
            console.log('✓ Transform successful:', result.includes('compressed') && !result.includes('  ') ? 'PASSED' : 'FAILED');
        }
    } catch (error) {
        console.error('✗ Transform output reading error:', error.message);
    }
}

testTransformStreaming().catch(error => {
    console.error('✗ Transform streaming test failed:', error.message);
});
"""

context.evaluateScript(transformStreamingTest)

// Test 5: Request with streaming body (simulating actual upload)
print("\n5. Testing Request with streaming body...")
let requestBodyStreamingTest = """
async function testRequestStreamingBody() {
    console.log('Testing Request with streaming body...');
    
    try {
        // Create a stream for request body
        let chunkCount = 0;
        const requestBodyStream = new ReadableStream({
            start(controller) {
                const data = '{"message": "This is streaming request data", "chunks": [';
                controller.enqueue(new TextEncoder().encode(data));
            },
            pull(controller) {
                // Simulate multiple chunks of JSON data
                if (chunkCount < 3) {
                    const chunk = `{"id": ${chunkCount}, "data": "chunk${chunkCount}"}`;
                    if (chunkCount > 0) {
                        controller.enqueue(new TextEncoder().encode(','));
                    }
                    controller.enqueue(new TextEncoder().encode(chunk));
                    chunkCount++;
                } else {
                    controller.enqueue(new TextEncoder().encode(']}'));
                    controller.close();
                }
            }
        });
        
        // Create request with streaming body
        const request = new Request('https://httpbin.org/post', {
            method: 'POST',
            body: requestBodyStream,
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✓ Request created successfully');
        console.log('✓ Request has body:', request.body !== null);
        console.log('✓ Request body is stream:', request.body instanceof ReadableStream);
        console.log('✓ Request method:', request.method);
        console.log('✓ Request content-type:', request.headers.get('Content-Type'));
        
        // Read the request body to verify it works
        if (request.body) {
            const bodyText = await request.text();
            console.log('✓ Request body content length:', bodyText.length);
            console.log('✓ Body is valid JSON:', (() => {
                try { JSON.parse(bodyText); return 'PASSED'; } catch { return 'FAILED'; }
            })());
        }
        
    } catch (error) {
        console.error('✗ Request streaming body error:', error.message);
    }
}

testRequestStreamingBody().catch(error => {
    console.error('✗ Request streaming body test failed:', error.message);
});
"""

context.evaluateScript(requestBodyStreamingTest)

// Test 6: Stream tee functionality (important for response cloning)
print("\n6. Testing stream tee functionality...")
let streamTeeTest = """
async function testStreamTee() {
    console.log('Testing stream tee functionality...');
    
    try {
        const source = new ReadableStream({
            start(controller) {
                controller.enqueue(new TextEncoder().encode('Hello Tee Test'));
                controller.close();
            }
        });
        
        const [stream1, stream2] = source.tee();
        
        const [result1, result2] = await Promise.all([
            stream1.getReader().read(),
            stream2.getReader().read()
        ]);
        
        const text1 = new TextDecoder().decode(result1.value);
        const text2 = new TextDecoder().decode(result2.value);
        
        console.log('✓ Tee result 1:', text1);
        console.log('✓ Tee result 2:', text2);
        console.log('✓ Tee results equal:', text1 === text2 ? 'PASSED' : 'FAILED');
        
    } catch (error) {
        console.error('✗ Tee error:', error.message);
    }
}

testStreamTee().catch(error => {
    console.error('✗ Tee test failed:', error.message);
});
"""

context.evaluateScript(streamTeeTest)

// Test 7: Actual fetch with streaming (if network available)
print("\n7. Testing actual fetch with streaming response processing...")
let actualFetchStreamingTest = """
async function testFetchStreaming() {
    console.log('Testing fetch with streaming response...');
    
    try {
        // Use a simple endpoint that returns some data
        console.log('Attempting to fetch from GitHub API...');
        const response = await fetch('https://api.github.com/zen');
        
        console.log('✓ Fetch completed');
        console.log('✓ Response status:', response.status);
        console.log('✓ Response body is stream:', response.body instanceof ReadableStream);
        
        if (response.body instanceof ReadableStream) {
            console.log('Processing response as stream...');
            
            const reader = response.body.getReader();
            const chunks = [];
            let totalBytes = 0;
            
            try {
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    
                    chunks.push(value);
                    totalBytes += value.byteLength;
                    console.log(`✓ Received chunk: ${value.byteLength} bytes`);
                    
                    // Process chunk immediately (streaming processing)
                    const chunkText = new TextDecoder().decode(value);
                    if (chunkText.length > 0) {
                        console.log('Chunk preview:', chunkText.substring(0, 50) + (chunkText.length > 50 ? '...' : ''));
                    }
                }
                
                console.log(`✓ Stream processing complete: ${chunks.length} chunks, ${totalBytes} bytes`);
                
                // Combine all chunks to verify complete data
                let combined = new Uint8Array(totalBytes);
                let offset = 0;
                chunks.forEach(chunk => {
                    combined.set(chunk, offset);
                    offset += chunk.byteLength;
                });
                
                const fullText = new TextDecoder().decode(combined);
                console.log('✓ Full response length:', fullText.length);
                console.log('✓ Response is valid text:', fullText.length > 0 ? 'PASSED' : 'FAILED');
                
            } finally {
                reader.releaseLock();
            }
        } else {
            console.log('✗ Response body is not a stream');
        }
        
    } catch (error) {
        console.log('⚠️  Fetch streaming error (network may be unavailable):', error.message);
        console.log('⚠️  This is expected if no internet connection is available');
    }
}

testFetchStreaming().catch(error => {
    console.log('⚠️  Fetch streaming test skipped (network issue):', error.message);
});
"""

context.evaluateScript(actualFetchStreamingTest)

print("\n8. Running event loop to process all async operations...")

// Run the event loop for a limited time to let all async operations complete
let eventLoop = RunLoop.current
let finishTime = Date().addingTimeInterval(5.0) // Give 5 seconds for all operations

while eventLoop.run(mode: .default, before: Date().addingTimeInterval(0.1)) && Date() < finishTime {
    // Continue running the event loop
}

print("\n=== Streaming Verification Results ===")
print("All streaming tests have been executed.")
print("Look for ✓ (success) and ✗ (failure) markers in the output above.")
print("\nExpected Results:")
print("✓ Basic streaming infrastructure should work")
print("✓ Upload streaming simulation should work") 
print("✓ Download streaming simulation should work")
print("✓ Transform streaming should work")
print("✓ Request with streaming body should work")
print("✓ Stream tee functionality should work")
print("⚠️  Fetch with real network is optional (depends on connectivity)")
print("\nIf all core tests show ✓, streaming is working correctly for upload and download!")
