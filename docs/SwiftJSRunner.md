# SwiftJSRunner

SwiftJSRunner is an executable target in the SwiftJS project that allows you to run JavaScript files using the SwiftJS runtime from the command line.

## Features

- Run JavaScript files with Node.js-like APIs
- Execute JavaScript code directly with eval mode
- Access to SwiftJS native APIs (crypto, file system, HTTP, etc.)
- Support for async/await, Promises, and timers
- Command line argument passing via `process.argv`
- Proper error handling with stack traces

## Usage

### Running JavaScript Files

```bash
# Run a JavaScript file
swift run SwiftJSRunner script.js

# Run a JavaScript file with arguments
swift run SwiftJSRunner script.js arg1 arg2
```

### Eval Mode

```bash
# Execute JavaScript code directly
swift run SwiftJSRunner -e "console.log('Hello, World!')"

# Execute JavaScript code with arguments
swift run SwiftJSRunner --eval "console.log(process.argv)" arg1 arg2
```

### Help

```bash
swift run SwiftJSRunner --help
```

## Available APIs

SwiftJSRunner provides access to all SwiftJS APIs including:

- **Console**: `console.log()`, `console.error()`, etc.
- **Timers**: `setTimeout()`, `setInterval()`, `clearTimeout()`, `clearInterval()`
- **Process**: `process.argv`, `process.pid`
- **Crypto**: `crypto.randomUUID()`, `crypto.randomBytes()`, hashing functions
- **Fetch**: HTTP requests with `fetch()`
- **File System**: Via `__APPLE_SPEC__.FileSystem`
- **Streams**: ReadableStream, WritableStream, TransformStream

## Examples

### Basic Script

```javascript
// hello.js
console.log("Hello from SwiftJS!");
console.log("Arguments:", process.argv);
```

```bash
swift run SwiftJSRunner hello.js world
```

### Async Example

```javascript
// async-example.js
async function main() {
    console.log("Starting async operation...");
    
    const result = await new Promise(resolve => {
        setTimeout(() => resolve("Done!"), 1000);
    });
    
    console.log("Result:", result);
}

main();
```

```bash
swift run SwiftJSRunner async-example.js
```

### HTTP Request Example

```javascript
// fetch-example.js
async function fetchData() {
    try {
        const response = await fetch('https://api.github.com/zen');
        const text = await response.text();
        console.log("GitHub Zen:", text);
    } catch (error) {
        console.error("Fetch error:", error.message);
    }
}

fetchData();
```

```bash
swift run SwiftJSRunner fetch-example.js
```

## Building

The SwiftJSRunner is built automatically when you build the SwiftJS project:

```bash
swift build
```

You can also build just the runner:

```bash
swift build --product SwiftJSRunner
```

## Error Handling

SwiftJSRunner provides proper error handling with JavaScript stack traces:

```bash
swift run SwiftJSRunner -e "throw new Error('Something went wrong!');"
# Output: Error: Something went wrong!
```

The runner will exit with code 1 on JavaScript errors and code 0 on success.
