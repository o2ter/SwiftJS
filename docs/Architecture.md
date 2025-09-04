# SwiftJS Architecture Guide

This document explains the internal architecture of SwiftJS, how it bridges Swift and JavaScript, and the design principles that guide its implementation.

## Table of Contents

- [Overview](#overview)
- [Core Architecture](#core-architecture)
- [Component Layers](#component-layers)
- [Value Marshaling](#value-marshaling)
- [JavaScript Context Management](#javascript-context-management)
- [Native API Exposure](#native-api-exposure)
- [Async Integration](#async-integration)
- [Memory Management](#memory-management)
- [Error Handling](#error-handling)
- [Extension Points](#extension-points)

## Overview

SwiftJS follows a layered architecture that bridges Apple's JavaScriptCore with modern web APIs and native Swift capabilities. The design prioritizes:

- **Web Standards Compliance**: Following W3C, WHATWG, and ECMAScript specifications
- **Performance**: Efficient value marshaling and minimal overhead
- **Safety**: Memory-safe operations with proper cleanup
- **Extensibility**: Clean patterns for adding new native APIs

```
┌─────────────────────────────────────────┐
│             JavaScript Layer            │
│  (Web APIs, Polyfills, User Scripts)    │
├─────────────────────────────────────────┤
│            Bridge Layer                 │
│  (Value Marshaling, API Exposure)       │
├─────────────────────────────────────────┤
│            Swift Library Layer          │
│  (Native Implementations, URLSession)   │
├─────────────────────────────────────────┤
│            JavaScriptCore              │
│        (Apple's JS Engine)             │
└─────────────────────────────────────────┘
```

## Core Architecture

### Main Components

1. **SwiftJS Struct**: Entry point that creates and manages the JavaScript context
2. **VirtualMachine**: Wraps JSVirtualMachine with RunLoop integration
3. **Context**: Manages timers, loggers, and context-specific state
4. **Value System**: Handles conversion between Swift and JavaScript values
5. **Native APIs**: Swift implementations of web and system APIs

### Directory Structure

```
Sources/SwiftJS/
├── core/                   # Core JavaScript engine management
│   ├── core.swift         # Main SwiftJS struct
│   ├── vm.swift           # VirtualMachine wrapper
│   ├── value.swift        # Value marshaling system
│   ├── polyfill.swift     # Polyfill injection
│   └── logger.swift       # Logging infrastructure
├── lib/                   # Native API implementations
│   ├── crypto.swift       # Cryptographic functions
│   ├── processInfo.swift  # Process information
│   ├── deviceInfo.swift   # Device information
│   ├── fileSystem.swift   # File system operations
│   └── http/              # HTTP client implementation
└── resources/
    └── polyfill.js        # JavaScript polyfills
```

## Component Layers

### 1. Core Layer (`Sources/SwiftJS/core/`)

The core layer manages the JavaScript execution environment and provides the foundation for all other functionality.

#### SwiftJS Struct
```swift
public struct SwiftJS {
    public let virtualMachine: VirtualMachine
    let base: JSContext
    let context = Context()
    
    public init(_ virtualMachine: VirtualMachine = VirtualMachine()) {
        self.virtualMachine = virtualMachine
        self.base = JSContext(virtualMachine: virtualMachine.base)
        self.base.exceptionHandler = { context, exception in
            guard let message = exception?.toString() else { return }
            print(message)
        }
        self.polyfill()
    }
}
```

**Key Responsibilities:**
- Creates and configures JSContext
- Automatically injects polyfills
- Sets up exception handling
- Manages the virtual machine

#### VirtualMachine
```swift
public final class VirtualMachine {
    let base: JSVirtualMachine
    let runloop: RunLoop
    
    public init() {
        self.runloop = RunLoop.current
        self.base = JSVirtualMachine()
    }
}
```

**Key Responsibilities:**
- Wraps JSVirtualMachine for timer integration
- Manages RunLoop association for async operations
- Provides isolated execution contexts

#### Context Class
```swift
class Context {
    var timerId: Int = 0
    var timer: [Int: Timer] = [:]
    var logger: @Sendable (LogLevel, [SwiftJS.Value]) -> Void
    
    init() {
        self.logger = { level, message in
            print("[\(level.name.uppercased())] \(message.map { $0.toString() }.joined(separator: " "))")
        }
    }
}
```

**Key Responsibilities:**
- Manages timer state
- Provides logging infrastructure
- Maintains context-specific data
- Handles cleanup on deinitialization

### 2. Library Layer (`Sources/SwiftJS/lib/`)

The library layer provides native Swift implementations of web APIs that are exposed to JavaScript.

#### JSExport Protocol Pattern
All native APIs follow the JSExport protocol pattern:

```swift
@objc protocol JSCryptoExport: JSExport {
    func randomUUID() -> String
    func getRandomValues(_ buffer: JSValue) -> JSValue
    func randomBytes(_ length: Int) -> JSValue
}

@objc final class JSCrypto: NSObject, JSCryptoExport, @unchecked Sendable {
    func randomUUID() -> String {
        return UUID().uuidString
    }
    // ... implementation
}
```

**Design Principles:**
- Use `@objc` protocols for JSExport compatibility
- Final classes for performance and safety
- `@unchecked Sendable` for Swift 6 concurrency compliance
- Clear separation between interface and implementation

#### HTTP Integration
The HTTP layer uses AsyncHTTPClient for modern streaming capabilities:

```swift
@objc protocol JSURLSessionExport: JSExport {
    static var shared: JSURLSession { get }
    func httpRequestWithRequest(
        _ request: JSURLRequest,
        _ bodyStream: JSValue?,
        _ progressHandler: JSValue?,
        _ completionHandler: JSValue?
    ) -> JSValue?
}
```

### 3. Polyfill Layer (`Sources/SwiftJS/resources/polyfill.js`)

The polyfill layer implements web APIs in JavaScript that either:
1. Delegate to native Swift implementations
2. Provide pure JavaScript implementations
3. Bridge between the two approaches

#### Polyfill Structure
```javascript
// Global API implementations
globalThis.console = { /* enhanced console */ };
globalThis.fetch = async function(input, init) { /* fetch implementation */ };
globalThis.setTimeout = function(callback, ms) { /* timer implementation */ };

// Text encoding/decoding
globalThis.TextEncoder = class TextEncoder { /* implementation */ };
globalThis.TextDecoder = class TextDecoder { /* implementation */ };

// Crypto API
globalThis.crypto = new class Crypto {
    randomUUID() { return __APPLE_SPEC__.crypto.randomUUID(); }
    // ... other methods
};
```

## Value Marshaling

The value marshaling system handles conversion between Swift and JavaScript values seamlessly.

### SwiftJS.Value System

```swift
public struct Value {
    private let base: JSValue
    
    public init(_ value: String, in context: SwiftJS) {
        self.base = JSValue(object: value, in: context.base)
    }
    
    public init(_ value: [Any], in context: SwiftJS) {
        self.base = JSValue(object: value, in: context.base)
    }
    
    // Automatic bridging for common types
    public init(_ value: SwiftJS.Export, in context: SwiftJS) {
        self.base = JSValue(object: value, in: context.base)
    }
}
```

### Automatic Type Conversion

SwiftJS automatically converts between Swift and JavaScript types:

| Swift Type | JavaScript Type | Notes |
|-----------|-----------------|-------|
| `String` | `string` | Direct conversion |
| `Int`, `Double` | `number` | Numeric types |
| `Bool` | `boolean` | Boolean values |
| `Array` | `Array` | Array conversion |
| `Dictionary` | `Object` | Object conversion |
| `Data`, `[UInt8]` | `Uint8Array` | Binary data |
| Custom objects | JSExport | Protocol-based |

### Custom Value Bridging

For complex types, SwiftJS uses the JSExport protocol:

```swift
// Swift side
@objc final class CustomObject: NSObject, JSExport {
    @objc func method() -> String { return "result" }
}

// Usage
let obj = CustomObject()
context.globalObject["myObject"] = SwiftJS.Value(obj, in: context)

// JavaScript side
console.log(myObject.method()); // "result"
```

## JavaScript Context Management

### Context Lifecycle

1. **Initialization**: SwiftJS creates JSContext and VirtualMachine
2. **Polyfill Injection**: Automatic loading of web APIs
3. **Native API Exposure**: __APPLE_SPEC__ object setup
4. **Script Execution**: User code evaluation
5. **Cleanup**: Timer invalidation and resource cleanup

### Exception Handling

```swift
self.base.exceptionHandler = { context, exception in
    guard let message = exception?.toString() else { return }
    print(message)
}
```

JavaScript exceptions are captured and can be handled in Swift:

```swift
let result = context.evaluateScript("throw new Error('test')")
let exception = context.exception
if !exception.isUndefined {
    print("JavaScript error: \(exception.toString())")
}
```

### Global Object Management

The global object is automatically configured with:

```swift
extension SwiftJS {
    func polyfill() {
        self.globalObject["__APPLE_SPEC__"] = .init([
            "crypto": .init(JSCrypto(), in: self),
            "processInfo": .init(JSProcessInfo(), in: self),
            "deviceInfo": .init(JSDeviceInfo(), in: self),
            "FileSystem": .init(JSFileSystem.self, in: self),
            "URLSession": .init(JSURLSession.self, in: self)
        ], in: self)
        
        // Load JavaScript polyfills
        if let polyfillJs = String(data: Data(PackageResources.polyfill_js), encoding: .utf8) {
            self.evaluateScript(polyfillJs)
        }
    }
}
```

## Native API Exposure

### The __APPLE_SPEC__ Pattern

Native Swift APIs are exposed through the global `__APPLE_SPEC__` object, providing a clear namespace for platform-specific functionality.

#### Design Principles:
1. **Namespace Isolation**: Prevent conflicts with web standards
2. **Discoverability**: Clear naming for native capabilities
3. **Type Safety**: Proper Swift type bridging
4. **Documentation**: Self-documenting API structure

#### Implementation Pattern:
```swift
// 1. Define JSExport protocol
@objc protocol JSMyAPIExport: JSExport {
    func myMethod() -> String
}

// 2. Implement the protocol
@objc final class JSMyAPI: NSObject, JSMyAPIExport {
    func myMethod() -> String { return "result" }
}

// 3. Expose in __APPLE_SPEC__
self.globalObject["__APPLE_SPEC__"]["myAPI"] = .init(JSMyAPI(), in: self)
```

### Static vs Instance APIs

The exposure pattern supports both static class methods and instance methods:

```swift
// Static API (class methods)
"FileSystem": .init(JSFileSystem.self, in: self)  // Exposes class methods

// Instance API (singleton pattern)
"crypto": .init(JSCrypto(), in: self)  // Exposes instance methods

// Factory pattern (shared instances)
"URLSession": .init(JSURLSession.self, in: self)  // Supports .shared() pattern
```

## Async Integration

### Promise Support

Swift async functions are automatically bridged to JavaScript Promises:

```swift
// Swift async function
func asyncOperation() async -> String {
    await Task.sleep(nanoseconds: 1_000_000_000)
    return "completed"
}

// Exposed to JavaScript
context.globalObject["asyncOp"] = SwiftJS.Value(in: context) { args, this in
    return await asyncOperation()
}

// JavaScript usage
const result = await asyncOp(); // Returns Promise
```

### Timer Integration

Timers are integrated with the RunLoop system:

```swift
fileprivate func createTimer(
    callback: SwiftJS.Value, ms: Double, repeats: Bool, arguments: [SwiftJS.Value]
) -> Int {
    let id = self.context.timerId
    self.context.timer[id] = Timer.scheduledTimer(
        withTimeInterval: ms / 1000,
        repeats: repeats,
        block: { _ in
            _ = callback.call(withArguments: arguments)
        }
    )
    self.context.timerId += 1
    return id
}
```

### RunLoop Management

The VirtualMachine integrates with RunLoop for proper async operation handling:

```swift
public var runloop: RunLoop {
    return self.virtualMachine.runloop
}

// Usage in SwiftJSRunner
while hasActiveWork {
    let ranWork = runLoop.run(mode: .default, before: Date().addingTimeInterval(0.1))
    // Check for completion conditions
}
```

## Memory Management

### Automatic Cleanup

SwiftJS uses Swift's automatic reference counting (ARC) for memory management:

```swift
deinit {
    for (_, timer) in self.timer {
        timer.invalidate()
    }
    timer = [:]
}
```

### Resource Management

- **Timers**: Automatically invalidated on context destruction
- **Network Connections**: Connection pooling through AsyncHTTPClient
- **File Handles**: Proper cleanup in native implementations
- **JavaScript Objects**: Managed by JavaScriptCore's garbage collector

### Sendable Compliance

All types are marked for Swift 6 concurrency compliance:

```swift
extension SwiftJS: @unchecked Sendable {}
extension VirtualMachine: @unchecked Sendable {}
extension Context: @unchecked Sendable {}
```

## Error Handling

### Multi-Layer Error Handling

1. **Swift Layer**: Standard Swift error handling with throws/try/catch
2. **Bridge Layer**: Conversion of Swift errors to JavaScript exceptions
3. **JavaScript Layer**: Standard JavaScript try/catch mechanisms

### Error Propagation

```swift
// Swift function that can throw
func riskyOperation() throws -> String {
    throw MyError.something
}

// Exposed to JavaScript with error handling
context.globalObject["risky"] = SwiftJS.Value(in: context) { args, this in
    do {
        return try riskyOperation()
    } catch {
        throw SwiftJS.Value(newErrorFromMessage: error.localizedDescription, in: context)
    }
}

// JavaScript usage
try {
    const result = risky();
} catch (error) {
    console.error('Operation failed:', error.message);
}
```

### Exception Handler

Global exception handling provides debugging information:

```swift
self.base.exceptionHandler = { context, exception in
    guard let message = exception?.toString() else { return }
    print(message)
    
    // Optionally log stack trace
    if let stack = exception?["stack"] {
        print("Stack trace:", stack.toString())
    }
}
```

## Extension Points

### Adding New Native APIs

To add a new native API to SwiftJS:

1. **Create JSExport Protocol**:
```swift
@objc protocol JSMyServiceExport: JSExport {
    func performAction(_ param: String) -> JSValue
}
```

2. **Implement the Service**:
```swift
@objc final class JSMyService: NSObject, JSMyServiceExport, @unchecked Sendable {
    func performAction(_ param: String) -> JSValue {
        // Implementation here
        return JSValue(object: "result", in: JSContext.current())
    }
}
```

3. **Expose in __APPLE_SPEC__**:
```swift
// In polyfill() method
self.globalObject["__APPLE_SPEC__"]["myService"] = .init(JSMyService(), in: self)
```

4. **Optional JavaScript Wrapper**:
```javascript
// In polyfill.js
globalThis.myService = {
    action(param) {
        return __APPLE_SPEC__.myService.performAction(param);
    }
};
```

### Extending JavaScript APIs

JavaScript APIs can be extended by modifying the polyfill.js file:

```javascript
// Add new global API
globalThis.myAPI = {
    method() {
        // Pure JavaScript implementation
        return 'result';
    },
    
    nativeMethod() {
        // Delegate to native Swift
        return __APPLE_SPEC__.myService.performAction('data');
    }
};
```

### Custom Value Types

For complex data types, implement custom value bridging:

```swift
extension SwiftJS.Value {
    init(_ customObject: MyCustomType, in context: SwiftJS) {
        // Convert to JavaScript-compatible representation
        let jsObject = [
            "property1": customObject.property1,
            "property2": customObject.property2
        ]
        self.init(jsObject, in: context)
    }
}
```

## Performance Considerations

### Value Marshaling Optimization

- **Lazy Conversion**: Values are converted only when accessed
- **Type Caching**: Common type conversions are optimized
- **Direct Access**: JSValue.isTypedArray for efficient binary data

### Memory Optimization

- **Object Pooling**: Reuse of common objects where possible
- **Weak References**: Prevent retain cycles in callbacks
- **Batch Operations**: Minimize bridge crossings for bulk operations

### Execution Optimization

- **Polyfill Caching**: Polyfills are loaded once per context
- **Native Delegation**: Performance-critical operations use native implementations
- **Connection Pooling**: HTTP connections are reused efficiently

This architecture provides a solid foundation for bridging Swift and JavaScript while maintaining performance, safety, and extensibility.
