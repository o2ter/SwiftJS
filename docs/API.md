# SwiftJS API Reference

This document provides a comprehensive reference for all JavaScript APIs available in SwiftJS, including web standard APIs and native Swift integrations.

## Table of Contents

- [Global Objects](#global-objects)
- [Console API](#console-api)
- [Timer API](#timer-api)
- [Crypto API](#crypto-api)
- [Text Encoding API](#text-encoding-api)
- [Fetch API](#fetch-api)
- [Streams API](#streams-api)
- [Events API](#events-api)
- [Process API](#process-api)
- [Native Swift APIs](#native-swift-apis)

## Global Objects

### `globalThis`
The global object that serves as the root of the global scope.

```javascript
console.log(globalThis === this); // true (in global scope)
```

### Standard Constructors
All standard JavaScript constructors are available:
- `Object`, `Array`, `Function`, `String`, `Number`, `Boolean`
- `Date`, `RegExp`, `Error`, `Promise`
- `Map`, `Set`, `WeakMap`, `WeakSet`
- `ArrayBuffer`, `Uint8Array`, `Int32Array`, etc.

## Console API

SwiftJS provides a comprehensive console implementation with all standard methods.

### Basic Logging

#### `console.log(...args)`
Outputs a message to the console.

```javascript
console.log('Hello, World!');
console.log('Multiple', 'arguments', 123);
console.log({ key: 'value', nested: { data: true } });
```

#### `console.error(...args)`
Outputs an error message to the console.

```javascript
console.error('Something went wrong!');
console.error('Error code:', 500);
```

#### `console.warn(...args)`
Outputs a warning message to the console.

```javascript
console.warn('This is deprecated');
```

#### `console.info(...args)`
Outputs an informational message to the console.

```javascript
console.info('Process started');
```

### Timing Methods

#### `console.time(label?)`
Starts a timer with an optional label.

```javascript
console.time('operation');
// ... some code ...
console.timeEnd('operation');
// Output: operation: 42ms
```

#### `console.timeEnd(label?)`
Stops a timer and outputs the elapsed time.

#### `console.timeLog(label?, ...args)`
Logs the current elapsed time without stopping the timer.

```javascript
console.time('long-operation');
setTimeout(() => {
    console.timeLog('long-operation', 'checkpoint 1');
}, 1000);
```

### Counting Methods

#### `console.count(label?)`
Logs the number of times this line has been called with the given label.

```javascript
for (let i = 0; i < 3; i++) {
    console.count('loop');
}
// Output:
// loop: 1
// loop: 2
// loop: 3
```

#### `console.countReset(label?)`
Resets the count for the given label.

### Grouping Methods

#### `console.group(label?)`
Creates a new inline group with an optional label.

```javascript
console.group('User Details');
console.log('Name: John Doe');
console.log('Age: 30');
console.groupEnd();
```

#### `console.groupCollapsed(label?)`
Creates a new collapsed inline group.

#### `console.groupEnd()`
Closes the current inline group.

### Utility Methods

#### `console.table(data, columns?)`
Displays tabular data as a table.

```javascript
const users = [
    { name: 'John', age: 30 },
    { name: 'Jane', age: 25 }
];
console.table(users);
```

#### `console.assert(condition, ...args)`
Writes an error message if the assertion is false.

```javascript
console.assert(1 === 2, 'Math is broken!');
```

#### `console.clear()`
Clears the console (outputs a visual separator).

#### `console.dir(obj)`
Displays an interactive listing of the properties of a JavaScript object.

## Timer API

### `setTimeout(callback, delay?, ...args)`
Executes a function after a specified delay in milliseconds.

```javascript
const timeoutId = setTimeout(() => {
    console.log('Executed after 1 second');
}, 1000);

// With arguments
setTimeout((name, age) => {
    console.log(`Hello ${name}, you are ${age} years old`);
}, 500, 'John', 30);
```

**Returns:** A unique identifier that can be used with `clearTimeout()`.

### `clearTimeout(timeoutId)`
Cancels a timeout previously established by calling `setTimeout()`.

```javascript
const id = setTimeout(() => console.log('This will not run'), 1000);
clearTimeout(id);
```

### `setInterval(callback, delay?, ...args)`
Repeatedly executes a function with a fixed time delay between each call.

```javascript
const intervalId = setInterval(() => {
    console.log('Tick every 2 seconds');
}, 2000);

// Stop after 10 seconds
setTimeout(() => clearInterval(intervalId), 10000);
```

**Returns:** A unique identifier that can be used with `clearInterval()`.

### `clearInterval(intervalId)`
Cancels a repeating action which was set up using `setInterval()`.

## Crypto API

### `crypto.randomUUID()`
Generates a random UUID string.

```javascript
const id = crypto.randomUUID();
console.log(id); // e.g., "550e8400-e29b-41d4-a716-446655440000"
```

**Returns:** A string containing a randomly generated UUID.

### `crypto.getRandomValues(buffer)`
Fills the provided buffer with cryptographically strong random values.

```javascript
const array = new Uint8Array(16);
crypto.getRandomValues(array);
console.log(array); // Uint8Array with random values
```

**Parameters:**
- `buffer`: A typed array (Uint8Array, Uint16Array, etc.)

**Returns:** The same array passed as `buffer`, filled with random values.

### `crypto.randomBytes(length)`
Generates a specified number of random bytes.

```javascript
const bytes = crypto.randomBytes(16);
console.log(bytes); // Uint8Array with 16 random bytes
```

**Parameters:**
- `length`: Number of bytes to generate

**Returns:** Uint8Array containing random bytes.

## Text Encoding API

### `TextEncoder`
Encodes strings into UTF-8 byte sequences.

#### Constructor
```javascript
const encoder = new TextEncoder();
console.log(encoder.encoding); // "utf-8"
```

#### `encode(string)`
Encodes a string into a UTF-8 Uint8Array.

```javascript
const encoder = new TextEncoder();
const encoded = encoder.encode('Hello, 世界!');
console.log(encoded); // Uint8Array
```

### `TextDecoder`
Decodes byte sequences into strings.

#### Constructor
```javascript
const decoder = new TextDecoder(); // defaults to 'utf-8'
console.log(decoder.encoding); // "utf-8"
```

#### `decode(buffer)`
Decodes a buffer into a string.

```javascript
const decoder = new TextDecoder();
const bytes = new Uint8Array([72, 101, 108, 108, 111]);
const text = decoder.decode(bytes);
console.log(text); // "Hello"
```

## Fetch API

### `fetch(input, init?)`
Performs HTTP requests and returns a Promise that resolves to a Response.

```javascript
// GET request
const response = await fetch('https://postman-echo.com/data');
const data = await response.json();

// POST request
const response = await fetch('https://postman-echo.com/data', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({ key: 'value' })
});
```

**Parameters:**
- `input`: URL string or Request object
- `init`: Optional configuration object

**Returns:** Promise that resolves to a Response object.

### `Headers`
Represents HTTP headers.

#### Constructor
```javascript
const headers = new Headers();
headers.set('Content-Type', 'application/json');
headers.append('Authorization', 'Bearer token');

// From object
const headers2 = new Headers({
    'Content-Type': 'application/json',
    'Accept': 'application/json'
});
```

#### Methods
- `append(name, value)`: Appends a header value
- `delete(name)`: Deletes a header
- `get(name)`: Gets a header value
- `has(name)`: Checks if header exists
- `set(name, value)`: Sets a header value

### `Request`
Represents an HTTP request.

```javascript
const request = new Request('https://postman-echo.com/data', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ data: 'value' })
});

const response = await fetch(request);
```

### `Response`
Represents an HTTP response.

#### Properties
- `status`: HTTP status code
- `statusText`: HTTP status message
- `ok`: Boolean indicating success (status 200-299)
- `headers`: Headers object
- `body`: ReadableStream of the response body

#### Methods
- `text()`: Returns Promise resolving to response body as text
- `json()`: Returns Promise resolving to parsed JSON
- `arrayBuffer()`: Returns Promise resolving to ArrayBuffer
- `clone()`: Creates a clone of the response

```javascript
const response = await fetch('https://postman-echo.com/data');

console.log(response.status); // 200
console.log(response.ok); // true

const text = await response.text();
// or
const data = await response.json();
```

## Streams API

### `ReadableStream`
Represents a readable stream of data.

#### Constructor
```javascript
const stream = new ReadableStream({
    start(controller) {
        controller.enqueue('chunk 1');
        controller.enqueue('chunk 2');
        controller.close();
    }
});
```

#### Methods
- `getReader()`: Gets a reader for the stream
- `tee()`: Creates two identical streams
- `pipeTo(writable)`: Pipes to a WritableStream
- `pipeThrough(transform)`: Pipes through a TransformStream

```javascript
const reader = stream.getReader();
while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    console.log('Chunk:', value);
}
```

### `WritableStream`
Represents a writable stream of data.

```javascript
const stream = new WritableStream({
    write(chunk) {
        console.log('Received:', chunk);
    },
    close() {
        console.log('Stream closed');
    }
});

const writer = stream.getWriter();
await writer.write('Hello');
await writer.close();
```

### `TransformStream`
Represents a transform stream that can modify data as it passes through.

```javascript
const transform = new TransformStream({
    transform(chunk, controller) {
        const upperCase = chunk.toString().toUpperCase();
        controller.enqueue(upperCase);
    }
});

// Use readable and writable sides
const readable = transform.readable;
const writable = transform.writable;
```

## Events API

### `EventTarget`
Base class for objects that can receive events.

```javascript
class MyEmitter extends EventTarget {
    emit(type, data) {
        this.dispatchEvent(new CustomEvent(type, { detail: data }));
    }
}

const emitter = new MyEmitter();
emitter.addEventListener('test', (event) => {
    console.log('Received:', event.detail);
});
emitter.emit('test', { message: 'Hello!' });
```

### `AbortController`
Provides the ability to abort operations.

```javascript
const controller = new AbortController();
const signal = controller.signal;

// Use with fetch
fetch('https://postman-echo.com/data', { signal })
    .then(response => response.json())
    .catch(error => {
        if (error.name === 'AbortError') {
            console.log('Fetch aborted');
        }
    });

// Abort after 5 seconds
setTimeout(() => controller.abort(), 5000);
```

### `AbortSignal`
Represents a signal object that allows communication with an operation and abort it.

```javascript
// Check if aborted
if (signal.aborted) {
    throw new Error('Operation was aborted');
}

// Listen for abort event
signal.addEventListener('abort', () => {
    console.log('Operation aborted');
});
```

## Process API

### `process.argv`
Array containing command-line arguments.

```javascript
// For: swift run SwiftJSRunner script.js arg1 arg2
console.log(process.argv);
// Output: ['SwiftJSRunner', 'script.js', 'arg1', 'arg2']
```

### `process.pid`
Process identifier of the current process.

```javascript
console.log('Process ID:', process.pid);
```

### `process.env`
Object containing environment variables.

```javascript
console.log('HOME:', process.env.HOME);
console.log('PATH:', process.env.PATH);
```

## Native Swift APIs

Native Swift APIs are exposed through the global `__APPLE_SPEC__` object, providing direct access to iOS/macOS capabilities.

### `__APPLE_SPEC__.crypto`

#### `randomUUID()`
```javascript
const uuid = __APPLE_SPEC__.crypto.randomUUID();
```

#### `randomBytes(length)`
```javascript
const bytes = __APPLE_SPEC__.crypto.randomBytes(32);
```

#### `createHash(algorithm)`
Creates a hash object for the specified algorithm.

```javascript
const hash = __APPLE_SPEC__.crypto.createHash('sha256');
hash.update(new TextEncoder().encode('Hello, World!'));
const digest = hash.digest('hex');
console.log('SHA256:', digest);
```

**Supported algorithms:** 'md5', 'sha1', 'sha256', 'sha384', 'sha512'

#### `createHmac(algorithm, secret)`
Creates an HMAC object.

```javascript
const secret = new TextEncoder().encode('secret-key');
const hmac = __APPLE_SPEC__.crypto.createHmac('sha256', secret);
hmac.update(new TextEncoder().encode('data'));
const signature = hmac.digest('hex');
```

### `__APPLE_SPEC__.FileSystem`

#### `fileExistsAtPath(path)`
Checks if a file exists at the specified path.

```javascript
const exists = __APPLE_SPEC__.FileSystem.fileExistsAtPath('/tmp/test.txt');
```

#### `contentsOfFileAtPath(path)`
Reads the contents of a file.

```javascript
const content = __APPLE_SPEC__.FileSystem.contentsOfFileAtPath('/tmp/test.txt');
const text = new TextDecoder().decode(content);
```

#### `createFileAtPathWithContents(path, contents)`
Creates a file with the specified contents.

```javascript
const data = new TextEncoder().encode('Hello, World!');
const success = __APPLE_SPEC__.FileSystem.createFileAtPathWithContents('/tmp/test.txt', data);
```

#### `removeItemAtPath(path)`
Removes a file or directory.

```javascript
const success = __APPLE_SPEC__.FileSystem.removeItemAtPath('/tmp/test.txt');
```

### `__APPLE_SPEC__.processInfo`

#### `processIdentifier`
Current process ID.

```javascript
const pid = __APPLE_SPEC__.processInfo.processIdentifier;
```

#### `arguments`
Process arguments array.

```javascript
const args = __APPLE_SPEC__.processInfo.arguments;
```

#### `environment`
Environment variables dictionary.

```javascript
const env = __APPLE_SPEC__.processInfo.environment;
const home = env['HOME'];
```

### `__APPLE_SPEC__.deviceInfo`

#### `identifierForVendor()`
Gets the device identifier for vendor.

```javascript
const deviceId = __APPLE_SPEC__.deviceInfo.identifierForVendor();
```

#### `name`
Device name.

```javascript
const name = __APPLE_SPEC__.deviceInfo.name;
```

#### `systemName`
System name (iOS, macOS, etc.).

```javascript
const system = __APPLE_SPEC__.deviceInfo.systemName;
```

#### `systemVersion`
System version.

```javascript
const version = __APPLE_SPEC__.deviceInfo.systemVersion;
```

### `__APPLE_SPEC__.URLSession`

#### `shared()`
Gets the shared URLSession instance.

```javascript
const session = __APPLE_SPEC__.URLSession.shared();
```

#### HTTP Request Methods
Perform HTTP requests using native URLSession.

```javascript
// Create a request
const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com/data');
request.httpMethod = 'POST';
request.setValueForHTTPHeaderField('application/json', 'Content-Type');

// Perform request
const result = await session.httpRequestWithRequest(request, null, null, null);
console.log('Status:', result.response.statusCode);
console.log('Data:', new TextDecoder().decode(result.data));
```

### `__APPLE_SPEC__.URLRequest`

#### Constructor
```javascript
const request = new __APPLE_SPEC__.URLRequest('https://postman-echo.com');
```

#### Properties
- `url`: Request URL
- `httpMethod`: HTTP method ('GET', 'POST', etc.)
- `allHTTPHeaderFields`: All headers object

#### Methods
- `setValueForHTTPHeaderField(value, field)`: Set header value
- `valueForHTTPHeaderField(field)`: Get header value

### `__APPLE_SPEC__.URLResponse`

Represents an HTTP response from URLSession.

#### Properties
- `url`: Response URL
- `statusCode`: HTTP status code
- `allHeaderFields`: Response headers

## Error Handling

All APIs properly propagate JavaScript errors. Use try/catch blocks for error handling:

```javascript
try {
    const response = await fetch('invalid-url');
} catch (error) {
    console.error('Fetch failed:', error.message);
}

try {
    const content = __APPLE_SPEC__.FileSystem.contentsOfFileAtPath('/nonexistent');
} catch (error) {
    console.error('File read failed:', error.message);
}
```

## TypeScript Support

SwiftJS APIs are compatible with TypeScript. You can create type definitions for better development experience:

```typescript
declare global {
    const __APPLE_SPEC__: {
        crypto: {
            randomUUID(): string;
            randomBytes(length: number): Uint8Array;
            createHash(algorithm: string): CryptoHash;
        };
        FileSystem: {
            fileExistsAtPath(path: string): boolean;
            contentsOfFileAtPath(path: string): Uint8Array;
            createFileAtPathWithContents(path: string, contents: Uint8Array): boolean;
        };
        // ... other APIs
    };
}
```

This comprehensive API reference covers all the major functionality available in SwiftJS, providing both web-standard APIs and native Swift integration for powerful cross-platform development.
