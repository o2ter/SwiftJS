# SwiftJS Examples

This document provides practical examples demonstrating various SwiftJS capabilities, from basic usage to advanced integration scenarios.

## Table of Contents

- [Getting Started](#getting-started)
- [Basic Examples](#basic-examples)
- [Web APIs](#web-apis)
- [File System Operations](#file-system-operations)
- [Network Programming](#network-programming)
- [Streaming and Data Processing](#streaming-and-data-processing)
- [Crypto and Security](#crypto-and-security)
- [Timer and Async Programming](#timer-and-async-programming)
- [Integration Examples](#integration-examples)
- [Performance Examples](#performance-examples)

## Getting Started

### Hello World

```swift
import SwiftJS

let context = SwiftJS()
let result = context.evaluateScript("console.log('Hello, SwiftJS!'); 'Success'")
print("Result:", result.toString())

// Keep RunLoop alive for async operations
RunLoop.current.run()
```

### Command Line Usage

```bash
# Create a simple script
echo "console.log('Hello from command line!');" > hello.js

# Run with SwiftJSRunner
swift run SwiftJSRunner hello.js
```

## Basic Examples

### Variable and Function Declaration

```javascript
// Modern JavaScript features work seamlessly
const greeting = 'Hello, World!';
let count = 0;

// Arrow functions
const increment = () => ++count;

// Async functions
const asyncGreet = async (name) => {
    await new Promise(resolve => setTimeout(resolve, 100));
    return `Hello, ${name}!`;
};

// Classes
class Counter {
    constructor(initial = 0) {
        this.value = initial;
    }
    
    increment() {
        return ++this.value;
    }
}

const counter = new Counter(5);
console.log('Counter value:', counter.increment());
```

### Error Handling

```javascript
// Try-catch with async operations
async function safeOperation() {
    try {
        const result = await someAsyncOperation();
        console.log('Success:', result);
    } catch (error) {
        console.error('Operation failed:', error.message);
        console.error('Stack trace:', error.stack);
    }
}

// Custom error types
class CustomError extends Error {
    constructor(message, code) {
        super(message);
        this.name = 'CustomError';
        this.code = code;
    }
}

try {
    throw new CustomError('Something went wrong', 'E001');
} catch (error) {
    if (error instanceof CustomError) {
        console.error(`Custom error ${error.code}: ${error.message}`);
    }
}
```

## Web APIs

### Console API Usage

```javascript
// Basic logging
console.log('Info message');
console.warn('Warning message');
console.error('Error message');

// Advanced console features
console.time('operation');
for (let i = 0; i < 1000; i++) {
    // Some operation
}
console.timeEnd('operation');

// Grouping
console.group('User Data');
console.log('Name: John Doe');
console.log('Age: 30');
console.groupEnd();

// Counting
for (let i = 0; i < 5; i++) {
    console.count('loop-iteration');
}

// Table output
const users = [
    { name: 'Alice', age: 25 },
    { name: 'Bob', age: 30 },
    { name: 'Charlie', age: 35 }
];
console.table(users);

// Assertions
console.assert(2 + 2 === 4, 'Math is working correctly');
console.assert(2 + 2 === 5, 'This will trigger an error');
```

### Text Encoding/Decoding

```javascript
// Text encoding
const encoder = new TextEncoder();
const data = encoder.encode('Hello, 世界! 🌍');
console.log('Encoded bytes:', data);

// Text decoding
const decoder = new TextDecoder();
const text = decoder.decode(data);
console.log('Decoded text:', text);

// Working with different data types
const message = 'JavaScript and Swift integration';
const encoded = encoder.encode(message);

// Process as bytes
const processedBytes = encoded.map(byte => byte ^ 0x5A); // Simple XOR

// Decode back
const processed = decoder.decode(new Uint8Array(processedBytes));
console.log('Processed text:', processed);
```

### Event Handling

```javascript
// Event emitter example
class SimpleEmitter extends EventTarget {
    emit(type, data) {
        this.dispatchEvent(new CustomEvent(type, { detail: data }));
    }
}

const emitter = new SimpleEmitter();

// Add event listeners
emitter.addEventListener('data', (event) => {
    console.log('Received data:', event.detail);
});

emitter.addEventListener('error', (event) => {
    console.error('Error occurred:', event.detail);
});

// Emit events
emitter.emit('data', { message: 'Hello from event!' });
emitter.emit('error', { code: 'E001', message: 'Something went wrong' });

// AbortController for cancellation
const controller = new AbortController();
const signal = controller.signal;

setTimeout(() => {
    console.log('Operation cancelled');
    controller.abort();
}, 2000);

// Use signal in operations
signal.addEventListener('abort', () => {
    console.log('Cleanup after abort');
});
```

## File System Operations

### Basic File Operations

```javascript
const fs = __APPLE_SPEC__.FileSystem;

// Check if file exists
const filePath = '/tmp/swiftjs-test.txt';
const exists = fs.fileExistsAtPath(filePath);
console.log(`File ${filePath} exists:`, exists);

// Create a file
const content = new TextEncoder().encode('Hello from SwiftJS!\nThis is a test file.');
const success = fs.createFileAtPathWithContents(filePath, content);
console.log('File created:', success);

// Read file content
if (fs.fileExistsAtPath(filePath)) {
    const fileContent = fs.contentsOfFileAtPath(filePath);
    const text = new TextDecoder().decode(fileContent);
    console.log('File content:', text);
}

// Remove file
const removed = fs.removeItemAtPath(filePath);
console.log('File removed:', removed);
```

### File Processing Pipeline

```javascript
async function processTextFile(inputPath, outputPath) {
    const fs = __APPLE_SPEC__.FileSystem;
    
    // Check if input file exists
    if (!fs.fileExistsAtPath(inputPath)) {
        throw new Error(`Input file not found: ${inputPath}`);
    }
    
    // Read input file
    const inputData = fs.contentsOfFileAtPath(inputPath);
    const inputText = new TextDecoder().decode(inputData);
    
    // Process the text (example: convert to uppercase and add line numbers)
    const lines = inputText.split('\n');
    const processedLines = lines.map((line, index) => {
        return `${index + 1}: ${line.toUpperCase()}`;
    });
    
    const processedText = processedLines.join('\n');
    
    // Write to output file
    const outputData = new TextEncoder().encode(processedText);
    const success = fs.createFileAtPathWithContents(outputPath, outputData);
    
    if (success) {
        console.log(`File processed successfully: ${outputPath}`);
    } else {
        throw new Error(`Failed to write output file: ${outputPath}`);
    }
}

// Usage
processTextFile('/tmp/input.txt', '/tmp/output.txt')
    .then(() => console.log('Processing complete'))
    .catch(error => console.error('Processing failed:', error.message));
```

### Directory Operations

```javascript
function listDirectoryContents(dirPath) {
    const fs = __APPLE_SPEC__.FileSystem;
    
    // Note: This is a conceptual example
    // Actual directory listing would require additional native methods
    try {
        const exists = fs.fileExistsAtPath(dirPath);
        if (!exists) {
            console.log(`Directory does not exist: ${dirPath}`);
            return;
        }
        
        console.log(`Checking directory: ${dirPath}`);
        // Implementation would depend on additional native methods
        
    } catch (error) {
        console.error('Error listing directory:', error.message);
    }
}

// Working with common paths
const homeDir = __APPLE_SPEC__.processInfo.environment['HOME'];
const tempDir = '/tmp';

console.log('Home directory:', homeDir);
console.log('Temp directory exists:', __APPLE_SPEC__.FileSystem.fileExistsAtPath(tempDir));
```

## Network Programming

### Basic HTTP Requests

```javascript
// Simple GET request
async function fetchExample() {
    try {
        const response = await fetch('https://api.github.com/zen');
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const text = await response.text();
        console.log('GitHub Zen:', text.trim());
        
    } catch (error) {
        console.error('Fetch error:', error.message);
    }
}

fetchExample();

// JSON API request
async function fetchUserData(username) {
    const url = `https://api.github.com/users/${username}`;
    
    try {
        const response = await fetch(url);
        
        if (response.status === 404) {
            console.log(`User '${username}' not found`);
            return null;
        }
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const userData = await response.json();
        console.log(`User: ${userData.name} (${userData.login})`);
        console.log(`Public repos: ${userData.public_repos}`);
        console.log(`Followers: ${userData.followers}`);
        
        return userData;
        
    } catch (error) {
        console.error('Failed to fetch user data:', error.message);
        return null;
    }
}

fetchUserData('octocat');
```

### POST Requests with Data

```javascript
// POST with JSON data
async function createUser(userData) {
    try {
        const response = await fetch('https://jsonplaceholder.typicode.com/users', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(userData)
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const result = await response.json();
        console.log('User created:', result);
        return result;
        
    } catch (error) {
        console.error('Failed to create user:', error.message);
        throw error;
    }
}

// Usage
const newUser = {
    name: 'John Doe',
    username: 'johndoe',
    email: 'john@example.com'
};

createUser(newUser);

// POST with form data
async function uploadForm(formData) {
    const response = await fetch('https://httpbin.org/post', {
        method: 'POST',
        body: formData
    });
    
    const result = await response.json();
    console.log('Form upload result:', result);
}

// Create FormData
const formData = new FormData();
formData.append('name', 'Test User');
formData.append('email', 'test@example.com');
formData.append('message', 'Hello from SwiftJS!');

uploadForm(formData);
```

### Headers and Authentication

```javascript
// Request with custom headers
async function authenticatedRequest(token) {
    const headers = new Headers();
    headers.set('Authorization', `Bearer ${token}`);
    headers.set('Accept', 'application/json');
    headers.set('User-Agent', 'SwiftJS/1.0');
    
    try {
        const response = await fetch('https://api.github.com/user', {
            headers: headers
        });
        
        if (response.status === 401) {
            console.error('Authentication failed');
            return null;
        }
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const user = await response.json();
        console.log('Authenticated user:', user.login);
        return user;
        
    } catch (error) {
        console.error('Request failed:', error.message);
        return null;
    }
}

// Working with response headers
async function inspectResponse() {
    const response = await fetch('https://httpbin.org/headers');
    
    console.log('Response status:', response.status);
    console.log('Response headers:');
    
    for (const [key, value] of response.headers) {
        console.log(`  ${key}: ${value}`);
    }
    
    const data = await response.json();
    console.log('Response data:', data);
}

inspectResponse();
```

## Streaming and Data Processing

### Basic Stream Operations

```javascript
// Create a simple readable stream
const sourceStream = new ReadableStream({
    start(controller) {
        const data = ['Hello', ' ', 'streaming', ' ', 'world', '!'];
        data.forEach(chunk => {
            controller.enqueue(new TextEncoder().encode(chunk));
        });
        controller.close();
    }
});

// Create a writable stream that processes data
const destinationStream = new WritableStream({
    write(chunk) {
        const text = new TextDecoder().decode(chunk);
        console.log('Received chunk:', text);
    },
    close() {
        console.log('Stream processing complete');
    }
});

// Pipe data from source to destination
sourceStream.pipeTo(destinationStream);
```

### Transform Streams for Data Processing

```javascript
// Create a transform stream that converts text to uppercase
const uppercaseTransform = new TransformStream({
    transform(chunk, controller) {
        const text = new TextDecoder().decode(chunk);
        const upperText = text.toUpperCase();
        controller.enqueue(new TextEncoder().encode(upperText));
    }
});

// Create a transform stream that adds line numbers
const lineNumberTransform = new TransformStream({
    start() {
        this.lineNumber = 1;
    },
    transform(chunk, controller) {
        const text = new TextDecoder().decode(chunk);
        const lines = text.split('\n');
        
        const numberedLines = lines.map(line => {
            if (line.trim()) {
                return `${this.lineNumber++}: ${line}`;
            }
            return line;
        });
        
        const result = numberedLines.join('\n');
        controller.enqueue(new TextEncoder().encode(result));
    }
});

// Complex processing pipeline
async function processTextStream(inputText) {
    // Create source stream from input text
    const source = new ReadableStream({
        start(controller) {
            controller.enqueue(new TextEncoder().encode(inputText));
            controller.close();
        }
    });
    
    // Create destination to collect results
    const results = [];
    const destination = new WritableStream({
        write(chunk) {
            results.push(new TextDecoder().decode(chunk));
        }
    });
    
    // Process through pipeline
    await source
        .pipeThrough(uppercaseTransform)
        .pipeThrough(lineNumberTransform)
        .pipeTo(destination);
    
    return results.join('');
}

// Usage
const inputText = `line one
line two
line three`;

processTextStream(inputText).then(result => {
    console.log('Processed text:');
    console.log(result);
});
```

### Streaming HTTP Responses

```javascript
// Stream processing of large HTTP response
async function processLargeDataStream(url) {
    try {
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let totalBytes = 0;
        let chunks = 0;
        
        console.log('Starting stream processing...');
        
        while (true) {
            const { done, value } = await reader.read();
            
            if (done) {
                console.log('Stream processing complete');
                break;
            }
            
            totalBytes += value.byteLength;
            chunks++;
            
            // Process chunk (example: count characters)
            const text = decoder.decode(value, { stream: true });
            const charCount = text.length;
            
            console.log(`Chunk ${chunks}: ${value.byteLength} bytes, ${charCount} characters`);
            
            // Optional: Process chunk data here
            // processChunk(text);
        }
        
        console.log(`Total: ${totalBytes} bytes in ${chunks} chunks`);
        
    } catch (error) {
        console.error('Stream processing failed:', error.message);
    }
}

// Usage with a test endpoint
processLargeDataStream('https://httpbin.org/stream/10');
```

## Crypto and Security

### Random Data Generation

```javascript
// Generate UUIDs
console.log('Random UUID:', crypto.randomUUID());

// Generate random bytes
const randomBytes = new Uint8Array(16);
crypto.getRandomValues(randomBytes);
console.log('Random bytes:', Array.from(randomBytes).map(b => b.toString(16).padStart(2, '0')).join(''));

// Generate random numbers
function randomInt(min, max) {
    const range = max - min;
    const bytes = new Uint32Array(1);
    crypto.getRandomValues(bytes);
    return min + (bytes[0] % range);
}

console.log('Random number between 1 and 100:', randomInt(1, 101));

// Generate secure password
function generatePassword(length = 12) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
    const bytes = new Uint8Array(length);
    crypto.getRandomValues(bytes);
    
    return Array.from(bytes).map(byte => chars[byte % chars.length]).join('');
}

console.log('Secure password:', generatePassword(16));
```

### Hashing with Native Crypto

```javascript
// Using native crypto for hashing
function hashData(data, algorithm = 'sha256') {
    const hash = __APPLE_SPEC__.crypto.createHash(algorithm);
    
    if (typeof data === 'string') {
        hash.update(new TextEncoder().encode(data));
    } else {
        hash.update(data);
    }
    
    return hash.digest('hex');
}

// Hash examples
const message = 'Hello, SwiftJS!';
console.log('SHA256:', hashData(message, 'sha256'));
console.log('SHA1:', hashData(message, 'sha1'));
console.log('MD5:', hashData(message, 'md5'));

// Hash binary data
const binaryData = new Uint8Array([1, 2, 3, 4, 5]);
console.log('Binary SHA256:', hashData(binaryData, 'sha256'));

// HMAC example
function createHMAC(data, secret, algorithm = 'sha256') {
    const secretBytes = typeof secret === 'string' 
        ? new TextEncoder().encode(secret) 
        : secret;
    
    const hmac = __APPLE_SPEC__.crypto.createHmac(algorithm, secretBytes);
    
    if (typeof data === 'string') {
        hmac.update(new TextEncoder().encode(data));
    } else {
        hmac.update(data);
    }
    
    return hmac.digest('hex');
}

const secret = 'my-secret-key';
const signature = createHMAC(message, secret);
console.log('HMAC signature:', signature);
```

### Data Integrity Verification

```javascript
// File integrity checker
function verifyFileIntegrity(filePath, expectedHash, algorithm = 'sha256') {
    const fs = __APPLE_SPEC__.FileSystem;
    
    if (!fs.fileExistsAtPath(filePath)) {
        throw new Error(`File not found: ${filePath}`);
    }
    
    const fileData = fs.contentsOfFileAtPath(filePath);
    const actualHash = hashData(fileData, algorithm);
    
    const isValid = actualHash === expectedHash;
    
    console.log(`File: ${filePath}`);
    console.log(`Expected ${algorithm.toUpperCase()}: ${expectedHash}`);
    console.log(`Actual ${algorithm.toUpperCase()}: ${actualHash}`);
    console.log(`Integrity check: ${isValid ? 'PASSED' : 'FAILED'}`);
    
    return isValid;
}

// Create test file and verify
const testData = new TextEncoder().encode('Test file content for integrity check');
const testPath = '/tmp/integrity-test.txt';

if (__APPLE_SPEC__.FileSystem.createFileAtPathWithContents(testPath, testData)) {
    const expectedHash = hashData(testData, 'sha256');
    verifyFileIntegrity(testPath, expectedHash, 'sha256');
    
    // Clean up
    __APPLE_SPEC__.FileSystem.removeItemAtPath(testPath);
}
```

## Timer and Async Programming

### Basic Timer Operations

```javascript
// Simple timeout
setTimeout(() => {
    console.log('This executes after 1 second');
}, 1000);

// Timeout with parameters
setTimeout((name, count) => {
    console.log(`Hello ${name}, count is ${count}`);
}, 500, 'Alice', 42);

// Interval example
let counter = 0;
const intervalId = setInterval(() => {
    counter++;
    console.log(`Interval tick: ${counter}`);
    
    if (counter >= 5) {
        clearInterval(intervalId);
        console.log('Interval stopped');
    }
}, 1000);

// Timeout cancellation
const timeoutId = setTimeout(() => {
    console.log('This will not execute');
}, 2000);

// Cancel the timeout after 1 second
setTimeout(() => {
    clearTimeout(timeoutId);
    console.log('Timeout cancelled');
}, 1000);
```

### Promise-based Delays

```javascript
// Promise-based delay function
function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Async function with delays
async function sequentialOperations() {
    console.log('Starting sequential operations...');
    
    await delay(1000);
    console.log('Step 1 complete');
    
    await delay(1500);
    console.log('Step 2 complete');
    
    await delay(500);
    console.log('All operations complete');
}

sequentialOperations();

// Timeout wrapper for promises
function withTimeout(promise, timeoutMs) {
    return Promise.race([
        promise,
        new Promise((_, reject) => {
            setTimeout(() => reject(new Error('Operation timed out')), timeoutMs);
        })
    ]);
}

// Usage with fetch
async function fetchWithTimeout(url, timeoutMs = 5000) {
    try {
        const response = await withTimeout(fetch(url), timeoutMs);
        return await response.text();
    } catch (error) {
        if (error.message === 'Operation timed out') {
            console.error(`Request to ${url} timed out after ${timeoutMs}ms`);
        } else {
            console.error('Request failed:', error.message);
        }
        throw error;
    }
}

fetchWithTimeout('https://httpbin.org/delay/3', 2000)
    .catch(error => console.log('Caught timeout:', error.message));
```

### Concurrent Operations

```javascript
// Parallel execution
async function parallelOperations() {
    console.log('Starting parallel operations...');
    
    const operations = [
        delay(1000).then(() => 'Operation 1'),
        delay(1500).then(() => 'Operation 2'),
        delay(800).then(() => 'Operation 3')
    ];
    
    const results = await Promise.all(operations);
    console.log('All operations complete:', results);
}

parallelOperations();

// Race condition example
async function raceExample() {
    console.log('Starting race...');
    
    const competitors = [
        delay(1000).then(() => 'Slow runner'),
        delay(500).then(() => 'Fast runner'),
        delay(750).then(() => 'Medium runner')
    ];
    
    const winner = await Promise.race(competitors);
    console.log('Winner:', winner);
}

raceExample();
```

### Task Scheduling

```javascript
// Simple task scheduler
class TaskScheduler {
    constructor() {
        this.tasks = [];
        this.running = false;
    }
    
    schedule(task, delay = 0) {
        const scheduledTime = Date.now() + delay;
        this.tasks.push({ task, scheduledTime });
        
        if (!this.running) {
            this.start();
        }
    }
    
    start() {
        this.running = true;
        this.processNext();
    }
    
    stop() {
        this.running = false;
    }
    
    processNext() {
        if (!this.running || this.tasks.length === 0) {
            this.running = false;
            return;
        }
        
        // Sort tasks by scheduled time
        this.tasks.sort((a, b) => a.scheduledTime - b.scheduledTime);
        
        const nextTask = this.tasks.shift();
        const now = Date.now();
        const delay = Math.max(0, nextTask.scheduledTime - now);
        
        setTimeout(() => {
            try {
                nextTask.task();
            } catch (error) {
                console.error('Task execution error:', error);
            }
            
            this.processNext();
        }, delay);
    }
}

// Usage
const scheduler = new TaskScheduler();

scheduler.schedule(() => console.log('Task 1 (immediate)'), 0);
scheduler.schedule(() => console.log('Task 2 (1 second)'), 1000);
scheduler.schedule(() => console.log('Task 3 (500ms)'), 500);
scheduler.schedule(() => console.log('Task 4 (2 seconds)'), 2000);
```

## Integration Examples

### Command Line Tool

```javascript
#!/usr/bin/env swift run SwiftJSRunner

// process-files.js - A file processing tool
const args = process.argv.slice(2);

if (args.length === 0) {
    console.error('Usage: process-files.js <input-file> [output-file]');
    process.exit(1);
}

const inputFile = args[0];
const outputFile = args[1] || inputFile + '.processed';

async function processFile() {
    const fs = __APPLE_SPEC__.FileSystem;
    
    try {
        // Check input file
        if (!fs.fileExistsAtPath(inputFile)) {
            throw new Error(`Input file not found: ${inputFile}`);
        }
        
        console.log(`Processing ${inputFile}...`);
        
        // Read and process content
        const inputData = fs.contentsOfFileAtPath(inputFile);
        const inputText = new TextDecoder().decode(inputData);
        
        // Example processing: word count and line count
        const lines = inputText.split('\n');
        const words = inputText.split(/\s+/).filter(word => word.length > 0);
        const chars = inputText.length;
        
        const stats = {
            file: inputFile,
            lines: lines.length,
            words: words.length,
            characters: chars,
            processedAt: new Date().toISOString()
        };
        
        // Create processed content
        const processedContent = `File Statistics
=================
File: ${stats.file}
Lines: ${stats.lines}
Words: ${stats.words}
Characters: ${stats.characters}
Processed: ${stats.processedAt}

Original Content:
================
${inputText}`;
        
        // Write output
        const outputData = new TextEncoder().encode(processedContent);
        const success = fs.createFileAtPathWithContents(outputFile, outputData);
        
        if (success) {
            console.log(`Processed file saved to: ${outputFile}`);
            console.log(`Statistics: ${stats.lines} lines, ${stats.words} words, ${stats.characters} characters`);
        } else {
            throw new Error(`Failed to write output file: ${outputFile}`);
        }
        
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

processFile();
```

### HTTP Server Simulation

```javascript
// http-client.js - A simple HTTP client tool
class HTTPClient {
    constructor() {
        this.defaultHeaders = {
            'User-Agent': 'SwiftJS-Client/1.0'
        };
    }
    
    async request(method, url, options = {}) {
        const config = {
            method: method.toUpperCase(),
            headers: { ...this.defaultHeaders, ...options.headers }
        };
        
        if (options.body) {
            config.body = options.body;
        }
        
        console.log(`${config.method} ${url}`);
        
        try {
            const response = await fetch(url, config);
            
            const result = {
                status: response.status,
                statusText: response.statusText,
                headers: Object.fromEntries(response.headers),
                body: null
            };
            
            // Parse response based on content type
            const contentType = response.headers.get('content-type') || '';
            
            if (contentType.includes('application/json')) {
                result.body = await response.json();
            } else {
                result.body = await response.text();
            }
            
            return result;
            
        } catch (error) {
            throw new Error(`Request failed: ${error.message}`);
        }
    }
    
    get(url, headers = {}) {
        return this.request('GET', url, { headers });
    }
    
    post(url, body, headers = {}) {
        return this.request('POST', url, { body, headers });
    }
    
    put(url, body, headers = {}) {
        return this.request('PUT', url, { body, headers });
    }
    
    delete(url, headers = {}) {
        return this.request('DELETE', url, { headers });
    }
}

// Usage example
async function testHTTPClient() {
    const client = new HTTPClient();
    
    try {
        // GET request
        console.log('Testing GET request...');
        const getResult = await client.get('https://httpbin.org/get');
        console.log('GET result:', getResult.status, getResult.statusText);
        
        // POST request
        console.log('\nTesting POST request...');
        const postData = JSON.stringify({ key: 'value', timestamp: Date.now() });
        const postResult = await client.post(
            'https://httpbin.org/post',
            postData,
            { 'Content-Type': 'application/json' }
        );
        console.log('POST result:', postResult.status, postResult.statusText);
        
        // Test error handling
        console.log('\nTesting error handling...');
        try {
            await client.get('https://httpbin.org/status/404');
        } catch (error) {
            console.log('Caught expected error:', error.message);
        }
        
    } catch (error) {
        console.error('HTTP client test failed:', error.message);
    }
}

testHTTPClient();
```

## Performance Examples

### Benchmarking

```javascript
// benchmark.js - Performance measurement utilities
class Benchmark {
    constructor(name) {
        this.name = name;
        this.start = 0;
        this.end = 0;
    }
    
    begin() {
        this.start = Date.now();
        console.log(`Starting benchmark: ${this.name}`);
    }
    
    finish() {
        this.end = Date.now();
        const duration = this.end - this.start;
        console.log(`Benchmark ${this.name} completed in ${duration}ms`);
        return duration;
    }
    
    static async measure(name, operation) {
        const benchmark = new Benchmark(name);
        benchmark.begin();
        
        try {
            const result = await operation();
            benchmark.finish();
            return { result, duration: benchmark.end - benchmark.start };
        } catch (error) {
            benchmark.finish();
            throw error;
        }
    }
}

// Benchmark various operations
async function runBenchmarks() {
    // String operations
    await Benchmark.measure('String concatenation', () => {
        let result = '';
        for (let i = 0; i < 10000; i++) {
            result += `Item ${i} `;
        }
        return result.length;
    });
    
    // Array operations
    await Benchmark.measure('Array operations', () => {
        const arr = [];
        for (let i = 0; i < 10000; i++) {
            arr.push(i);
        }
        return arr.filter(x => x % 2 === 0).map(x => x * 2).reduce((a, b) => a + b, 0);
    });
    
    // Crypto operations
    await Benchmark.measure('UUID generation', () => {
        const uuids = [];
        for (let i = 0; i < 1000; i++) {
            uuids.push(crypto.randomUUID());
        }
        return uuids.length;
    });
    
    // HTTP requests
    await Benchmark.measure('HTTP request', async () => {
        const response = await fetch('https://httpbin.org/json');
        return await response.json();
    });
    
    // File operations
    await Benchmark.measure('File I/O', () => {
        const fs = __APPLE_SPEC__.FileSystem;
        const testPath = '/tmp/benchmark-test.txt';
        const testData = new TextEncoder().encode('Benchmark test data');
        
        // Write
        fs.createFileAtPathWithContents(testPath, testData);
        
        // Read
        const readData = fs.contentsOfFileAtPath(testPath);
        
        // Clean up
        fs.removeItemAtPath(testPath);
        
        return readData.length;
    });
}

runBenchmarks().then(() => {
    console.log('All benchmarks completed');
});
```

### Memory Usage Monitoring

```javascript
// memory-monitor.js - Monitor memory usage patterns
class MemoryMonitor {
    constructor(interval = 1000) {
        this.interval = interval;
        this.monitoring = false;
        this.measurements = [];
    }
    
    start() {
        if (this.monitoring) return;
        
        this.monitoring = true;
        console.log('Starting memory monitoring...');
        
        const monitor = () => {
            if (!this.monitoring) return;
            
            // Note: Actual memory monitoring would require native implementation
            // This is a simulation
            const timestamp = Date.now();
            const measurement = {
                timestamp,
                allocatedObjects: Math.floor(Math.random() * 1000) + 500,
                activeTimers: 0 // Would count active timers
            };
            
            this.measurements.push(measurement);
            console.log(`Memory check: ${measurement.allocatedObjects} objects`);
            
            setTimeout(monitor, this.interval);
        };
        
        monitor();
    }
    
    stop() {
        this.monitoring = false;
        console.log('Memory monitoring stopped');
        return this.measurements;
    }
    
    report() {
        if (this.measurements.length === 0) return;
        
        const avgObjects = this.measurements.reduce((sum, m) => sum + m.allocatedObjects, 0) / this.measurements.length;
        const maxObjects = Math.max(...this.measurements.map(m => m.allocatedObjects));
        const minObjects = Math.min(...this.measurements.map(m => m.allocatedObjects));
        
        console.log('\nMemory Usage Report:');
        console.log(`Measurements: ${this.measurements.length}`);
        console.log(`Average objects: ${avgObjects.toFixed(2)}`);
        console.log(`Max objects: ${maxObjects}`);
        console.log(`Min objects: ${minObjects}`);
    }
}

// Test memory patterns
async function testMemoryPatterns() {
    const monitor = new MemoryMonitor(500);
    monitor.start();
    
    // Simulate various operations
    console.log('Creating many objects...');
    const objects = [];
    for (let i = 0; i < 1000; i++) {
        objects.push({ id: i, data: `Object ${i}` });
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    console.log('Creating and discarding objects...');
    for (let i = 0; i < 100; i++) {
        const temp = Array.from({ length: 100 }, (_, j) => ({ temp: j }));
        // Objects will be garbage collected
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    console.log('Cleaning up...');
    objects.length = 0; // Clear references
    
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const measurements = monitor.stop();
    monitor.report();
}

testMemoryPatterns();
```

These examples demonstrate the full range of SwiftJS capabilities, from basic JavaScript execution to advanced integration scenarios with native Swift APIs. Each example is designed to be practical and can serve as a starting point for real-world applications.
