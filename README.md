# SwiftJS

SwiftJS is a JavaScript runtime built on Apple's JavaScriptCore, providing a bridge between Swift and JavaScript with Node.js-like APIs and modern web standards support.

## Features

### 🚀 JavaScript Runtime
- **JavaScriptCore-powered**: Built on Apple's high-performance JavaScript engine
- **Node.js-compatible APIs**: Familiar APIs for JavaScript developers
- **Modern ES6+ Support**: Promises, async/await, modules, and more
- **Web Standards Compliance**: Following W3C, WHATWG, and ECMAScript specifications

### 🌐 Web APIs
- **Fetch API**: HTTP requests with streaming support
- **Crypto API**: `crypto.randomUUID()`, `crypto.getRandomValues()`, hashing functions
- **Console API**: Full console implementation with timing, counting, and grouping
- **Timers**: `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval`
- **Text Encoding**: `TextEncoder` and `TextDecoder` for UTF-8 processing
- **Streams**: ReadableStream, WritableStream, TransformStream with pipe methods

### 🍎 Native Integration
- **File System Access**: Read/write files through native Swift APIs
- **Device Information**: Access device identifiers and system info
- **Process Information**: Environment variables, arguments, process ID
- **URLSession Integration**: Native macOS/iOS networking with streaming support
- **Swift-JavaScript Bridge**: Seamless value marshaling between Swift and JavaScript

### ⚡ Performance & Memory
- **Streaming Support**: Process large data without memory spikes
- **Connection Pooling**: Efficient HTTP connection management
- **Memory Management**: Automatic cleanup of resources and timers
- **Concurrent Operations**: Handle multiple async operations efficiently

## Quick Start

### Installation

Add SwiftJS to your Swift project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/o2ter/SwiftJS.git", from: "1.0.0")
]
```

### Basic Usage

```swift
import SwiftJS

// Create a SwiftJS context
let context = SwiftJS()

// Execute JavaScript code
let result = context.evaluateScript("""
    console.log('Hello from SwiftJS!');
    
    // Use modern JavaScript features
    const greet = async (name) => {
        return `Hello, ${name}!`;
    };
    
    greet('World');
""")

// Keep the run loop alive for async operations
RunLoop.current.run()
```

### Using SwiftJSRunner (Command Line)

```bash
# Run JavaScript files
swift run SwiftJSRunner script.js

# Execute JavaScript directly
swift run SwiftJSRunner -e "console.log('Hello, World!')"

# Pass arguments to scripts
swift run SwiftJSRunner script.js arg1 arg2
```

## API Examples

### HTTP Requests with Fetch

```javascript
// Modern fetch API with streaming
const response = await fetch('https://api.github.com/zen');
const text = await response.text();
console.log('GitHub Zen:', text);

// POST with JSON
const response = await fetch('https://postman-echo.com/data', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ key: 'value' })
});
```

### Cryptographic Functions

```javascript
// Generate UUIDs
const id = crypto.randomUUID();
console.log('UUID:', id);

// Generate random bytes
const bytes = new Uint8Array(16);
crypto.getRandomValues(bytes);
console.log('Random bytes:', bytes);
```

### File System Operations

```javascript
// Access native file system through SwiftJS bridge
const fs = __APPLE_SPEC__.FileSystem;

// Check if file exists
const exists = fs.fileExistsAtPath('/path/to/file.txt');

// Read file contents
if (exists) {
    const content = fs.contentsOfFileAtPath('/path/to/file.txt');
    console.log('File content:', content);
}
```

### Streaming Data Processing

```javascript
// Create a data processing pipeline
const transform = new TransformStream({
    transform(chunk, controller) {
        const text = new TextDecoder().decode(chunk);
        const upper = text.toUpperCase();
        controller.enqueue(new TextEncoder().encode(upper));
    }
});

// Pipe data through transformation
await readableStream
    .pipeThrough(transform)
    .pipeTo(writableStream);
```

### Timers and Async Operations

```javascript
// Timers work seamlessly with other APIs
setTimeout(async () => {
    const response = await fetch('https://postman-echo.com/data');
    const data = await response.json();
    console.log('Fetched data:', data);
}, 1000);

// Process data periodically
setInterval(() => {
    const id = crypto.randomUUID();
    console.log('Generated ID:', id);
}, 5000);
```

## Architecture

SwiftJS follows a layered architecture:

- **Core Layer**: JavaScript execution engine and value marshaling
- **Library Layer**: Native Swift implementations of JS APIs
- **Polyfill Layer**: JavaScript polyfills for missing web APIs

All JavaScript values are automatically bridged to Swift through the `SwiftJS.Value` system, providing seamless interoperability between the two languages.

## Platform Support

- **macOS**: 14.0+
- **iOS**: 17.0+
- **macCatalyst**: 17.0+

## Dependencies

- [swift-crypto](https://github.com/apple/swift-crypto): Cryptographic operations
- [swift-nio](https://github.com/apple/swift-nio): High-performance networking
- [async-http-client](https://github.com/swift-server/async-http-client): HTTP client with streaming support

## Documentation

- [API Reference](docs/API.md) - Comprehensive API documentation
- [Architecture Guide](docs/Architecture.md) - Internal architecture details
- [SwiftJSRunner](docs/SwiftJSRunner.md) - Command-line tool documentation
- [Streaming Guide](docs/STREAMING.md) - Data streaming capabilities
- [Examples](docs/Examples.md) - Practical usage examples

## Testing

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter WebAPIs
swift test --filter Networking
swift test --filter StreamingTests

# Build the project
swift build

# Run SwiftJSRunner
swift run SwiftJSRunner --help
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

The MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built on Apple's [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore)
- Inspired by Node.js and modern web standards
- Uses Swift Package Manager for dependency management
