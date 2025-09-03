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

### Stream Piping
Pipe streams together for efficient data processing:

```javascript
// pipeTo: Pipe a readable stream to a writable stream
const readable = new ReadableStream({
  start(controller) {
    controller.enqueue(new TextEncoder().encode('Hello World'));
    controller.close();
  }
});

const writable = new WritableStream({
  write(chunk) {
    console.log('Received:', new TextDecoder().decode(chunk));
  }
});

await readable.pipeTo(writable);

// pipeThrough: Pipe through a transform stream
const source = new ReadableStream({
  start(controller) {
    controller.enqueue(new TextEncoder().encode('hello world'));
    controller.close();
  }
});

const upperCaseTransform = new TransformStream({
  transform(chunk, controller) {
    const text = new TextDecoder().decode(chunk);
    controller.enqueue(new TextEncoder().encode(text.toUpperCase()));
  }
});

const destination = new WritableStream({
  write(chunk) {
    console.log('Result:', new TextDecoder().decode(chunk)); // "HELLO WORLD"
  }
});

// Chain operations
source
  .pipeThrough(upperCaseTransform)
  .pipeTo(destination);
```

### Pipe Options
Both `pipeTo` and `pipeThrough` support options for advanced control:

```javascript
const controller = new AbortController();

// pipeTo with abort signal
await readable.pipeTo(writable, {
  signal: controller.signal,
  preventClose: false,    // Don't close destination when source ends
  preventAbort: false,    // Don't abort destination on error
  preventCancel: false    // Don't cancel source on destination error
});

// Abort the operation
controller.abort();

// pipeThrough passes options to the internal pipeTo
const result = source.pipeThrough(transform, {
  signal: controller.signal
});
```

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

## Example: Data Processing Pipeline

```javascript
// Complex data processing pipeline using pipe methods
async function processDataPipeline(inputData) {
  // Source stream with raw data
  const source = new ReadableStream({
    start(controller) {
      inputData.forEach(item => {
        controller.enqueue(new TextEncoder().encode(JSON.stringify(item) + '\n'));
      });
      controller.close();
    }
  });

  // Parse JSON transform
  const jsonParser = new TransformStream({
    transform(chunk, controller) {
      const text = new TextDecoder().decode(chunk);
      const lines = text.split('\n').filter(line => line.trim());
      lines.forEach(line => {
        try {
          const data = JSON.parse(line);
          controller.enqueue(data);
        } catch (e) {
          console.error('Invalid JSON:', line);
        }
      });
    }
  });

  // Filter transform
  const filter = new TransformStream({
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
      controller.enqueue(new TextEncoder().encode(JSON.stringify(chunk) + '\n'));
    }
  });

  // Output collector
  const results = [];
  const collector = new WritableStream({
    write(chunk) {
      const text = new TextDecoder().decode(chunk);
      if (text.trim()) {
        results.push(JSON.parse(text.trim()));
      }
    },
    close() {
      console.log('Processing complete. Results:', results.length);
    }
  });

  // Chain the entire pipeline
  await source
    .pipeThrough(jsonParser)
    .pipeThrough(filter)
    .pipeThrough(enhancer)
    .pipeTo(collector);

  return results;
}

// Usage
const inputData = [
  { id: 1, name: 'Item 1', active: true },
  { id: 2, name: 'Item 2', active: false },
  { id: 3, name: 'Item 3', active: true }
];

processDataPipeline(inputData).then(results => {
  console.log('Final results:', results);
});
```

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
