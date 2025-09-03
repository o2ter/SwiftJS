# SwiftNIO Streaming Integration

SwiftJS now includes comprehensive streaming support powered by SwiftNIO and AsyncHTTPClient, providing true streaming capabilities for both request and response bodies.

## Overview

The NIO streaming integration enables:

- **True streaming requests**: Upload data progressively without buffering entire payload
- **True streaming responses**: Download and process data as it arrives
- **Memory efficiency**: Constant memory usage regardless of transfer size
- **Concurrent streaming**: Multiple parallel streaming operations
- **Backpressure support**: Built-in flow control mechanisms
- **Error handling**: Robust error propagation and recovery

## Key Components

### NIOHTTPClient
Core streaming HTTP client that leverages AsyncHTTPClient for true streaming:

```swift
// Singleton instance for efficient connection pooling
let client = NIOHTTPClient.shared

// Execute streaming request
let responseHead = try await client.executeStreamingRequest(
    request, 
    streamController: streamController
)

// Execute streaming upload with body stream
let responseHead = try await client.executeStreamingUpload(
    request,
    bodyStream: dataStream,
    streamController: responseController
)
```

### SwiftJSStreamController
Bridges Swift NIO streams to JavaScript ReadableStreams:

```swift
let streamController = SwiftJSStreamController(context: context, controller: jsController)

// Enqueue data chunks as they arrive
streamController.enqueue(data)

// Handle errors
streamController.error(error)

// Close stream when complete
streamController.close()
```

### JSStreamReader
Converts JavaScript ReadableStream to Swift AsyncStream for request bodies:

```swift
let streamReader = JSStreamReader(stream: bodyStream, context: context)
let dataStream = streamReader.createAsyncStream()

// Use with NIO streaming upload
for await chunk in dataStream {
    // Process chunk
}
```

## JavaScript API

### Streaming Downloads

```javascript
// Create streaming request
const session = __APPLE_SPEC__.URLSession.shared;
const request = new __APPLE_SPEC__.URLRequest('https://example.com/large-file');

// Execute with streaming response
const result = await session.streamingDataTaskWithRequestCompletionHandler(request);

console.log('Response:', result.response.statusCode);
console.log('Streaming body:', result.body); // ReadableStream

// The response body is immediately available as a ReadableStream
// Data is processed progressively as it arrives
```

### Streaming Uploads

```javascript
// Create streaming request body
const bodyStream = new ReadableStream({
    start(controller) {
        // Enqueue data chunks
        controller.enqueue(new TextEncoder().encode('chunk 1'));
        controller.enqueue(new TextEncoder().encode('chunk 2'));
        controller.close();
    }
});

// Upload with streaming body
const request = new __APPLE_SPEC__.URLRequest('https://example.com/upload');
request.httpMethod = 'POST';

const result = await session.streamingUploadTaskWithRequestBodyStreamProgressHandler(
    request, 
    bodyStream
);
```

### Concurrent Streaming

```javascript
// Multiple parallel streaming requests
const requests = urls.map(url => {
    const request = new __APPLE_SPEC__.URLRequest(url);
    return session.streamingDataTaskWithRequestCompletionHandler(request);
});

// All streams process concurrently
const results = await Promise.all(requests);
```

## Performance Benefits

### Memory Efficiency
- **Traditional**: Buffers entire response in memory (size * num_requests)
- **NIO Streaming**: Constant memory usage regardless of response size

### Progressive Processing
- **Traditional**: Wait for complete download before processing
- **NIO Streaming**: Process data immediately as it arrives

### Concurrent Operations
- **Traditional**: Limited by memory for large files
- **NIO Streaming**: Scale to many concurrent operations

## Use Cases

### Large File Operations
```javascript
// Download large files without memory spikes
const response = await session.streamingDataTaskWithRequestCompletionHandler(
    new __APPLE_SPEC__.URLRequest('https://example.com/large-video.mp4')
);

// Process video stream progressively
const reader = response.body.getReader();
while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    // Process chunk immediately
    processVideoChunk(value);
}
```

### Real-time Data Processing
```javascript
// Stream real-time data feed
const response = await session.streamingDataTaskWithRequestCompletionHandler(
    new __APPLE_SPEC__.URLRequest('https://api.example.com/live-feed')
);

// Process data as it arrives
const reader = response.body.getReader();
const decoder = new TextDecoder();

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    const chunk = decoder.decode(value, { stream: true });
    // Process real-time data immediately
    handleRealtimeData(chunk);
}
```

### Chunked Uploads
```javascript
// Upload large file in chunks
const fileStream = new ReadableStream({
    start(controller) {
        // Read file in chunks and stream upload
        readFileInChunks((chunk) => {
            controller.enqueue(chunk);
        }, () => {
            controller.close();
        });
    }
});

const result = await session.streamingUploadTaskWithRequestBodyStreamProgressHandler(
    request,
    fileStream
);
```

## Error Handling

Streaming operations include comprehensive error handling:

```javascript
try {
    const result = await session.streamingDataTaskWithRequestCompletionHandler(request);
    
    // Handle response stream errors
    const reader = result.body.getReader();
    
    try {
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            // Process chunk
            processChunk(value);
        }
    } catch (streamError) {
        console.error('Stream processing error:', streamError);
    }
    
} catch (requestError) {
    console.error('Request error:', requestError);
}
```

## Implementation Details

### NIO Integration
- Uses AsyncHTTPClient for HTTP/1.1 and HTTP/2 support
- Leverages NIO's EventLoop for efficient async operations
- Connection pooling and reuse for optimal performance

### Thread Safety
- All streaming operations are thread-safe
- Proper synchronization between Swift and JavaScript contexts
- Safe concurrent access to stream controllers

### Resource Management
- Automatic cleanup of streams and connections
- Proper handling of cancellation and timeouts
- Memory management through Swift's ARC

## Migration Guide

### From URLSession to NIO Streaming

**Before:**
```javascript
const result = await session.dataTaskWithRequestCompletionHandler(request);
const data = result.data; // Entire response buffered in memory
```

**After:**
```javascript
const result = await session.streamingDataTaskWithRequestCompletionHandler(request);
const stream = result.body; // Progressive streaming
```

### Benefits of Migration
1. **Reduced memory usage** for large responses
2. **Faster time-to-first-byte** for progressive processing
3. **Better scalability** for concurrent operations
4. **Real-time capabilities** for streaming data

## Testing

Run the streaming test suite:
```bash
swift test --filter StreamingTests
```

Test with demo scripts:
```bash
swift run SwiftJSRunner .temp/streaming-demo.js
swift run SwiftJSRunner .temp/performance-comparison.js
```

## Dependencies

The NIO streaming implementation requires:
- SwiftNIO (2.65.0+)
- AsyncHTTPClient (1.19.0+)
- NIOFoundationCompat

These are automatically included in the Package.swift dependencies.
