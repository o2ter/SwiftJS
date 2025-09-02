import SwiftJS

print("Testing SwiftJS Streaming Support...")

let context = SwiftJS()

// Test 1: Basic ReadableStream functionality
print("\n1. Testing ReadableStream creation and reading...")
let streamTest = """
const stream = new ReadableStream({
    start(controller) {
        controller.enqueue(new TextEncoder().encode('Hello '));
        controller.enqueue(new TextEncoder().encode('Streaming '));
        controller.enqueue(new TextEncoder().encode('World!'));
        controller.close();
    }
});

const reader = stream.getReader();
const chunks = [];

async function readAll() {
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
    
    return new TextDecoder().decode(combined);
}

readAll().then(text => {
    console.log('Stream result:', text);
}).catch(error => {
    console.error('Stream error:', error.message);
});
"""

context.evaluateScript(streamTest)

// Test 2: Response body streaming
print("\n2. Testing Response body streaming...")
let responseTest = """
const response = new Response('Hello from Response body stream!');
console.log('Response body is ReadableStream:', response.body instanceof ReadableStream);

response.text().then(text => {
    console.log('Response text:', text);
}).catch(error => {
    console.error('Response error:', error.message);
});
"""

context.evaluateScript(responseTest)

// Test 3: Stream tee functionality
print("\n3. Testing stream tee functionality...")
let teeTest = """
const source = new ReadableStream({
    start(controller) {
        controller.enqueue(new TextEncoder().encode('Tee test'));
        controller.close();
    }
});

const [stream1, stream2] = source.tee();

Promise.all([
    stream1.getReader().read(),
    stream2.getReader().read()
]).then(([result1, result2]) => {
    const text1 = new TextDecoder().decode(result1.value);
    const text2 = new TextDecoder().decode(result2.value);
    console.log('Tee result 1:', text1);
    console.log('Tee result 2:', text2);
    console.log('Tee results equal:', text1 === text2);
}).catch(error => {
    console.error('Tee error:', error.message);
});
"""

context.evaluateScript(teeTest)

// Test 4: Request with streaming body
print("\n4. Testing Request with streaming body...")
let requestTest = """
try {
    const stream = new ReadableStream({
        start(controller) {
            controller.enqueue(new TextEncoder().encode('Streaming request body'));
            controller.close();
        }
    });
    
    const request = new Request('https://example.com', {
        method: 'POST',
        body: stream
    });
    
    console.log('Request body is stream:', request.body instanceof ReadableStream);
    console.log('Request method:', request.method);
} catch (error) {
    console.error('Request stream error:', error.message);
}
"""

context.evaluateScript(requestTest)

print("\n5. Running event loop to process async operations...")

// Run the event loop to let async operations complete
import Foundation
let runLoop = RunLoop.current
let future = Date().addingTimeInterval(2.0)
while runLoop.run(mode: .default, before: future) && future.timeIntervalSinceNow > 0 {
    // Keep running until timeout
}

print("\nStreaming tests completed!")
