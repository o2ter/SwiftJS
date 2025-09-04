# Streaming Support in SwiftJS

SwiftJS provides comprehensive streaming support through the Web Streams API, enabling efficient processing of large data sets with minimal memory footprint. The implementation follows web standards and integrates seamlessly with the fetch API and native networking capabilities.

## Table of Contents

- [Overview](#overview)
- [Web Streams API](#web-streams-api)
- [Integration with Fetch](#integration-with-fetch)
- [Native Streaming Support](#native-streaming-support)
- [Performance Benefits](#performance-benefits)
- [Examples](#examples)
- [Best Practices](#best-practices)

## Overview

SwiftJS streaming support includes:

- **Web Streams API**: ReadableStream, WritableStream, TransformStream
- **Fetch Integration**: Streaming request and response bodies
- **Native Backend**: SwiftNIO and AsyncHTTPClient for true streaming
- **Memory Efficiency**: Constant memory usage regardless of data size
- **Backpressure**: Built-in flow control mechanisms
- **Standards Compliance**: Following WHATWG Streams specification

## Web Streams API

### ReadableStream

ReadableStream represents a source of streaming data that can be read chunk by chunk.

#### Creating a ReadableStream

```javascript
const stream = new ReadableStream({
    start(controller) {
        // Initialize the stream
        controller.enqueue('First chunk');
        controller.enqueue('Second chunk');
        controller.close();
    }
});
```

#### Reading from a Stream

```javascript
const reader = stream.getReader();

try {
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        console.log('Received chunk:', value);
    }
} finally {
    reader.releaseLock();
}
```

#### Advanced ReadableStream

```javascript
const dataStream = new ReadableStream({
    start(controller) {
        this.controller = controller;
        this.data = ['chunk1', 'chunk2', 'chunk3'];
        this.index = 0;
    },
    
    pull(controller) {
        if (this.index < this.data.length) {
            controller.enqueue(this.data[this.index]);
            this.index++;
        } else {
            controller.close();
        }
    },
    
    cancel(reason) {
        console.log('Stream cancelled:', reason);
    }
});
```

### WritableStream

WritableStream represents a destination for streaming data.

```javascript
const stream = new WritableStream({
    start(controller) {
        console.log('WritableStream started');
    },
    
    write(chunk, controller) {
        console.log('Writing chunk:', chunk);
        // Process the chunk
    },
    
    close() {
        console.log('WritableStream closed');
    },
    
    abort(reason) {
        console.error('WritableStream aborted:', reason);
    }
});

const writer = stream.getWriter();
await writer.write('Hello, ');
await writer.write('streaming ');
await writer.write('world!');
await writer.close();
```

### TransformStream

TransformStream sits between a ReadableStream and WritableStream, transforming data as it passes through.

```javascript
const upperCaseTransform = new TransformStream({
    transform(chunk, controller) {
        if (typeof chunk === 'string') {
            controller.enqueue(chunk.toUpperCase());
        } else {
            // Handle binary data
            const text = new TextDecoder().decode(chunk);
            const upperText = text.toUpperCase();
            controller.enqueue(new TextEncoder().encode(upperText));
        }
    },
    
    flush(controller) {
        // Final processing when stream ends
        console.log('Transform complete');
    }
});

// Use the transform stream
const readable = upperCaseTransform.readable;
const writable = upperCaseTransform.writable;
```

## Stream Piping

### pipeTo()

Pipe a ReadableStream directly to a WritableStream:

```javascript
const source = new ReadableStream({
    start(controller) {
        controller.enqueue('hello ');
        controller.enqueue('streaming ');
        controller.enqueue('world');
        controller.close();
    }
});

const destination = new WritableStream({
    write(chunk) {
        console.log('Received:', chunk);
    }
});

await source.pipeTo(destination);
```

### pipeThrough()

Pipe a ReadableStream through a TransformStream:

```javascript
const source = new ReadableStream({
    start(controller) {
        controller.enqueue('hello world');
        controller.close();
    }
});

const transform = new TransformStream({
    transform(chunk, controller) {
        controller.enqueue(chunk.toUpperCase());
    }
});

const destination = new WritableStream({
    write(chunk) {
        console.log('Final result:', chunk); // "HELLO WORLD"
    }
});

await source
    .pipeThrough(transform)
    .pipeTo(destination);
```

### Pipeline Composition

Create complex data processing pipelines:

```javascript
// JSON parsing transform
const jsonParser = new TransformStream({
    transform(chunk, controller) {
        const text = new TextDecoder().decode(chunk);
        const lines = text.split('
').filter(line => line.trim());
        
        for (const line of lines) {
            try {
                const data = JSON.parse(line);
                controller.enqueue(data);
            } catch (e) {
                console.error('Invalid JSON:', line);
            }
        }
    }
});

// Data filter transform
const activeFilter = new TransformStream({
    transform(chunk, controller) {
        if (chunk.active === true) {
            controller.enqueue(chunk);
        }
    }
});

// Enhancement transform
const enhancer = new TransformStream({
    transform(chunk, controller) {
        chunk.processed = true;
        chunk.timestamp = Date.now();
        controller.enqueue(new TextEncoder().encode(JSON.stringify(chunk) + '
'));
    }
});

// Process data through pipeline
await source
    .pipeThrough(jsonParser)
    .pipeThrough(activeFilter)
    .pipeThrough(enhancer)
    .pipeTo(destination);
```

## Integration with Fetch

### Streaming Responses

All fetch responses have streaming bodies by default:

```javascript
const response = await fetch('https://postman-echo.com/large-dataset');

// Response body is automatically a ReadableStream
console.log(response.body instanceof ReadableStream); // true

// Process response progressively
const reader = response.body.getReader();
const decoder = new TextDecoder();

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    const chunk = decoder.decode(value, { stream: true });
    console.log('Received chunk:', chunk);
}
```

### Streaming Requests

Send data as a stream in request bodies:

```javascript
// Create a streaming request body
const bodyStream = new ReadableStream({
    start(controller) {
        const data = ['chunk1', 'chunk2', 'chunk3'];
        data.forEach(chunk => {
            controller.enqueue(new TextEncoder().encode(chunk));
        });
        controller.close();
    }
});

// Send streaming request
const response = await fetch('https://postman-echo.com/upload', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/octet-stream'
    },
    body: bodyStream
});
```

### Response Processing Pipeline

Process large responses efficiently:

```javascript
async function processLargeResponse(url) {
    const response = await fetch(url);
    
    if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const results = [];
    
    // Create processing pipeline
    const jsonLineParser = new TransformStream({
        transform(chunk, controller) {
            const text = new TextDecoder().decode(chunk);
            const lines = text.split('
');
            
            for (const line of lines) {
                if (line.trim()) {
                    try {
                        const data = JSON.parse(line);
                        controller.enqueue(data);
                    } catch (e) {
                        console.warn('Skipping invalid JSON line:', line);
                    }
                }
            }
        }
    });
    
    const collector = new WritableStream({
        write(chunk) {
            results.push(chunk);
        }
    });
    
    // Process the response stream
    await response.body
        .pipeThrough(jsonLineParser)
        .pipeTo(collector);
    
    return results;
}

// Usage
const data = await processLargeResponse('https://postman-echo.com/large-data.jsonl');
console.log(`Processed ${data.length} records`);
```

## Native Streaming Support

SwiftJS uses SwiftNIO and AsyncHTTPClient for true streaming capabilities at the native layer.

### Backend Architecture

```
JavaScript ReadableStream → SwiftJS Bridge → NIO AsyncStream → AsyncHTTPClient
```

### Memory Efficiency

Unlike traditional buffered approaches, SwiftJS streaming maintains constant memory usage:

```javascript
// Traditional approach (high memory usage)
const response = await fetch('https://postman-echo.com/1gb-file');
const data = await response.arrayBuffer(); // Loads entire file into memory

// Streaming approach (constant memory usage)
const response = await fetch('https://postman-echo.com/1gb-file');
const reader = response.body.getReader();

while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    // Process chunk immediately without storing entire file
    processChunk(value);
}
```

### Connection Pooling

The native backend efficiently manages HTTP connections:

- Connection reuse across multiple requests
- HTTP/2 multiplexing support
- Automatic connection pooling
- Proper connection lifecycle management

## Performance Benefits

### Memory Usage Comparison

| Approach | Memory Usage | Processing Delay |
|----------|-------------|------------------|
| Traditional Buffering | Size × Concurrent Requests | Wait for complete download |
| SwiftJS Streaming | Constant (chunk size) | Immediate processing |

### Throughput Comparison

```javascript
// Benchmark: Processing 100MB of JSON data

// Traditional approach
console.time('traditional');
const response = await fetch('/api/large-data');
const text = await response.text();
const lines = text.split('
');
const data = lines.map(line => JSON.parse(line));
console.timeEnd('traditional'); // ~3000ms, high memory

// Streaming approach
console.time('streaming');
const results = [];
const response = await fetch('/api/large-data');

const lineProcessor = new TransformStream({
    transform(chunk, controller) {
        const text = new TextDecoder().decode(chunk);
        const lines = text.split('
');
        lines.forEach(line => {
            if (line.trim()) {
                controller.enqueue(JSON.parse(line));
            }
        });
    }
});

const collector = new WritableStream({
    write(chunk) { results.push(chunk); }
});

await response.body
    .pipeThrough(lineProcessor)
    .pipeTo(collector);
console.timeEnd('streaming'); // ~800ms, constant memory
```

## Examples

### Large File Download with Progress

```javascript
async function downloadWithProgress(url, onProgress) {
    const response = await fetch(url);
    const contentLength = response.headers.get('Content-Length');
    const total = parseInt(contentLength, 10);
    let loaded = 0;
    
    const progressTransform = new TransformStream({
        transform(chunk, controller) {
            loaded += chunk.byteLength;
            onProgress({ loaded, total, percentage: (loaded / total) * 100 });
            controller.enqueue(chunk);
        }
    });
    
    const chunks = [];
    const collector = new WritableStream({
        write(chunk) {
            chunks.push(chunk);
        }
    });
    
    await response.body
        .pipeThrough(progressTransform)
        .pipeTo(collector);
    
    // Combine chunks into final result
    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0);
    const result = new Uint8Array(totalLength);
    let offset = 0;
    
    for (const chunk of chunks) {
        result.set(chunk, offset);
        offset += chunk.byteLength;
    }
    
    return result;
}

// Usage
const data = await downloadWithProgress('https://postman-echo.com/large-file.zip', 
    ({ loaded, total, percentage }) => {
        console.log(`Download progress: ${percentage.toFixed(1)}% (${loaded}/${total})`);
    }
);
```

### Real-time Data Processing

```javascript
async function processRealTimeStream(url) {
    const response = await fetch(url);
    
    // Create real-time processing pipeline
    const messageParser = new TransformStream({
        transform(chunk, controller) {
            const text = new TextDecoder().decode(chunk);
            const messages = text.split('

'); // Assuming messages are separated by double newlines
            
            for (const message of messages) {
                if (message.trim()) {
                    try {
                        const data = JSON.parse(message);
                        controller.enqueue(data);
                    } catch (e) {
                        console.warn('Invalid message format:', message);
                    }
                }
            }
        }
    });
    
    const processor = new WritableStream({
        write(message) {
            // Process each message immediately
            console.log('Real-time message:', message);
            
            // Handle different message types
            switch (message.type) {
                case 'heartbeat':
                    console.log('Heartbeat received');
                    break;
                case 'data':
                    handleDataMessage(message.payload);
                    break;
                case 'error':
                    console.error('Stream error:', message.error);
                    break;
            }
        }
    });
    
    // Process the real-time stream
    await response.body
        .pipeThrough(messageParser)
        .pipeTo(processor);
}

function handleDataMessage(payload) {
    // Process real-time data
    console.log('Processing data:', payload);
}
```

### File Upload with Chunking

```javascript
async function uploadLargeFile(file, chunkSize = 1024 * 1024) { // 1MB chunks
    const totalSize = file.size;
    let uploaded = 0;
    
    const chunkStream = new ReadableStream({
        start(controller) {
            this.offset = 0;
        },
        
        async pull(controller) {
            if (this.offset >= totalSize) {
                controller.close();
                return;
            }
            
            const chunk = file.slice(this.offset, Math.min(this.offset + chunkSize, totalSize));
            const arrayBuffer = await chunk.arrayBuffer();
            
            controller.enqueue(new Uint8Array(arrayBuffer));
            this.offset += chunkSize;
            uploaded = Math.min(this.offset, totalSize);
            
            console.log(`Upload progress: ${((uploaded / totalSize) * 100).toFixed(1)}%`);
        }
    });
    
    const response = await fetch('/api/upload', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': totalSize.toString()
        },
        body: chunkStream
    });
    
    return response.ok;
}

// Usage with file input
const fileInput = document.getElementById('fileInput');
fileInput.addEventListener('change', async (event) => {
    const file = event.target.files[0];
    if (file) {
        const success = await uploadLargeFile(file);
        console.log('Upload', success ? 'successful' : 'failed');
    }
});
```

## Best Practices

### Memory Management

1. **Always release readers**: Use try/finally blocks to release stream readers
2. **Process chunks immediately**: Don't accumulate large amounts of data
3. **Use appropriate chunk sizes**: Balance between memory usage and processing efficiency
4. **Monitor backpressure**: Handle slow consumers appropriately

```javascript
const reader = stream.getReader();
try {
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        // Process immediately
        await processChunk(value);
    }
} finally {
    reader.releaseLock();
}
```

### Error Handling

1. **Handle stream errors**: Use try/catch around stream operations
2. **Implement proper cleanup**: Cancel streams when errors occur
3. **Propagate errors correctly**: Use controller.error() in transforms

```javascript
const safeTransform = new TransformStream({
    transform(chunk, controller) {
        try {
            const processed = processData(chunk);
            controller.enqueue(processed);
        } catch (error) {
            controller.error(error);
        }
    }
});
```

### Performance Optimization

1. **Use native types**: Prefer Uint8Array for binary data
2. **Minimize conversions**: Avoid unnecessary text encoding/decoding
3. **Batch operations**: Process multiple small chunks together when possible
4. **Cancel unused streams**: Prevent resource leaks

```javascript
// Efficient binary processing
const binaryProcessor = new TransformStream({
    transform(chunk, controller) {
        // Work directly with Uint8Array
        if (chunk instanceof Uint8Array) {
            // Process binary data efficiently
            const processed = processBuffer(chunk);
            controller.enqueue(processed);
        }
    }
});
```

### Stream Lifecycle Management

1. **Proper stream closure**: Always close streams when done
2. **Handle cancellation**: Implement cancel handlers for cleanup
3. **Timeout handling**: Set appropriate timeouts for stream operations

```javascript
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout

try {
    await fetch(url, { signal: controller.signal })
        .then(response => response.body)
        .then(stream => processStream(stream));
} catch (error) {
    if (error.name === 'AbortError') {
        console.log('Stream operation timed out');
    }
} finally {
    clearTimeout(timeoutId);
}
```

## Troubleshooting

### Common Issues

1. **Stream already locked**: Only one reader can be active at a time
2. **Backpressure problems**: Slow consumers can cause memory buildup
3. **Encoding issues**: Ensure proper text encoding/decoding
4. **Connection timeouts**: Set appropriate timeouts for long-running streams

### Debugging Streams

```javascript
// Add debugging to transform streams
const debugTransform = new TransformStream({
    transform(chunk, controller) {
        console.log('Processing chunk:', chunk.byteLength, 'bytes');
        controller.enqueue(chunk);
    }
});

// Monitor stream progress
let chunkCount = 0;
const monitoringTransform = new TransformStream({
    transform(chunk, controller) {
        chunkCount++;
        if (chunkCount % 100 === 0) {
            console.log(`Processed ${chunkCount} chunks`);
        }
        controller.enqueue(chunk);
    }
});
```

SwiftJS streaming support provides powerful, memory-efficient data processing capabilities that scale from small data sets to large-scale streaming applications, all while maintaining web standards compliance and native performance.
