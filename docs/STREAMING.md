# Streaming Support in SwiftJS

SwiftJS now includes comprehensive streaming support for network operations, providing Web Streams API compatibility similar to modern browsers and Node.js.

## Overview

Streaming support has been added to the networking layer, allowing for:

- **Streaming request bodies**: Send data as streams to servers
- **Streaming response bodies**: Receive data progressively from servers  
- **Stream transformation**: Process data as it flows through pipelines
- **Memory efficiency**: Handle large data transfers without loading everything into memory

## Stream Classes

### ReadableStream
```javascript
const stream = new ReadableStream({
  start(controller) {
    controller.enqueue(new TextEncoder().encode('Hello'));
    controller.enqueue(new TextEncoder().encode(' World'));
    controller.close();
  }
});

const reader = stream.getReader();
const { value, done } = await reader.read();
```

### WritableStream
```javascript
const stream = new WritableStream({
  write(chunk) {
    console.log('Received:', new TextDecoder().decode(chunk));
  }
});

const writer = stream.getWriter();
await writer.write(new TextEncoder().encode('Hello'));
await writer.close();
```

### TransformStream
```javascript
const transform = new TransformStream({
  transform(chunk, controller) {
    const text = new TextDecoder().decode(chunk);
    const upper = text.toUpperCase();
    controller.enqueue(new TextEncoder().encode(upper));
  }
});

// Use with readable and writable sides
const readable = transform.readable;
const writable = transform.writable;
```

## Response Body Streaming

All Response objects now have streaming body support:

```javascript
const response = new Response('Hello, streaming world!');

// Body is automatically a ReadableStream
console.log(response.body instanceof ReadableStream); // true

// Traditional methods still work
const text = await response.text();
const buffer = await response.arrayBuffer();
const json = await response.json();

// Manual stream reading
const reader = response.body.getReader();
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  console.log('Chunk:', new TextDecoder().decode(value));
}
```

## Request Body Streaming

Requests can now accept ReadableStream as body:

```javascript
const stream = new ReadableStream({
  start(controller) {
    controller.enqueue(new TextEncoder().encode('{"data": "streaming"}'));
    controller.close();
  }
});

const request = new Request('https://api.example.com/data', {
  method: 'POST',
  body: stream,
  headers: { 'Content-Type': 'application/json' }
});

const response = await fetch(request);
```

## Fetch API Streaming

The fetch API now creates streaming responses by default:

```javascript
const response = await fetch('https://api.example.com/data');

// Response body is a ReadableStream
const reader = response.body.getReader();
const decoder = new TextDecoder();

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  
  const chunk = decoder.decode(value, { stream: true });
  console.log('Received chunk:', chunk);
}
```

## Stream Utilities

### Stream Teeing
Split a stream into two identical streams:

```javascript
const [stream1, stream2] = originalStream.tee();
// Both streams will receive the same data
```

### Response Cloning
Clone responses with streams:

```javascript
const response = await fetch('/data');
const clone = response.clone();

// Both response and clone can be read independently
const text1 = await response.text();
const text2 = await clone.text();
```

## Error Handling

Streams support proper error propagation:

```javascript
const stream = new ReadableStream({
  start(controller) {
    controller.error(new Error('Stream failed'));
  }
});

try {
  const reader = stream.getReader();
  await reader.read();
} catch (error) {
  console.error('Stream error:', error.message);
}
```

## Performance Benefits

- **Memory efficiency**: Process large files without loading entirely into memory
- **Progressive processing**: Start working with data before transfer completes
- **Backpressure**: Built-in flow control to prevent overwhelming consumers
- **Cancellation**: Abort streams early when no longer needed

## Compatibility

The streaming implementation follows Web Streams API standards and is compatible with:
- Fetch API
- Request/Response objects
- FormData (automatically converted to streams)
- ArrayBuffer and TypedArrays
- String data (automatically encoded)

## Native Integration

Streaming support is built on top of SwiftJS's native URLSession integration, providing:
- Efficient memory usage through Swift's URLSession
- Proper error handling and cancellation
- Integration with iOS/macOS networking stack
- Support for all HTTP methods and headers

## Example: File Upload with Progress

```javascript
async function uploadWithProgress(file) {
  const stream = new ReadableStream({
    start(controller) {
      const reader = file.stream().getReader();
      
      function pump() {
        return reader.read().then(({ done, value }) => {
          if (done) {
            controller.close();
            return;
          }
          
          console.log(`Uploading chunk: ${value.byteLength} bytes`);
          controller.enqueue(value);
          return pump();
        });
      }
      
      return pump();
    }
  });

  const response = await fetch('/upload', {
    method: 'POST',
    body: stream,
    headers: { 'Content-Type': 'application/octet-stream' }
  });

  return response.ok;
}
```

This comprehensive streaming support makes SwiftJS suitable for modern web applications that need efficient data processing and transfer capabilities.
