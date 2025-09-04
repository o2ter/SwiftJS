# SwiftJS - JavaScript Runtime for Swift

## Architecture Overview

SwiftJS is a JavaScript runtime built on Apple's JavaScriptCore, providing a bridge between Swift and JavaScript with Node.js-like APIs. The architecture follows a layered approach:

- **Core Layer** (`Sources/SwiftJS/core/`): JavaScript execution engine and value marshaling
- **Library Layer** (`Sources/SwiftJS/lib/`): Native Swift implementations of JS APIs
- **Polyfill Layer** (`Sources/SwiftJS/resources/polyfill.js`): JavaScript polyfills for missing APIs

## Key Components

### JavaScript Context Management
- `SwiftJS` struct is the main entry point - creates a JS context with automatic polyfill injection
- `VirtualMachine` wraps JSVirtualMachine with RunLoop integration for timer support
- Always use `SwiftJS()` constructor which automatically calls `polyfill()` for full API setup

### Value Bridging Pattern
The `SwiftJS.Value` system provides seamless Swift ↔ JavaScript value conversion:
```swift
// JavaScript values are automatically bridged
let jsValue: SwiftJS.Value = "hello"  // String literal
let jsArray: SwiftJS.Value = [1, 2, 3]  // Array literal
let jsObject: SwiftJS.Value = ["key": "value"]  // Dictionary literal
```

**Important Method Binding Behavior:** When accessing JavaScript methods via subscript, the `this` context is lost:
```swift
// ❌ WRONG - loses 'this' context, causes TypeError
let method = object["methodName"]
let result = method.call(withArguments: [])

// ✅ CORRECT - preserves 'this' context
let result = object.invokeMethod("methodName", withArguments: [])
```

This is standard JavaScript behavior where extracting a method from an object unbinds it from its original context. Always use `invokeMethod` for calling object methods to ensure proper `this` binding.

### Native API Exposure via `__APPLE_SPEC__`
Native Swift APIs are exposed to JavaScript through the global `__APPLE_SPEC__` object:
- `crypto`: Cryptographic functions (randomUUID, randomBytes, hashing)
- `processInfo`: Process information (PID, arguments, environment)
- `deviceInfo`: Device identification
- `FileSystem`: File operations
- `URLSession`: HTTP requests

## Critical Patterns

### JSExport Protocol Implementation
All native objects exposed to JavaScript must conform to `JSExport`:
```swift
@objc protocol JSMyAPIExport: JSExport {
    func myMethod() -> String
}

@objc final class JSMyAPI: NSObject, JSMyAPIExport {
    func myMethod() -> String { return "result" }
}
```

**Important:** Swift static properties (including computed properties with getters) are automatically exposed as JavaScript functions, not properties. This means:
- Swift `static var myProperty: String { get }` becomes JavaScript `myObject.myProperty()` (callable function)
- Swift `static func myMethod() -> String` also becomes JavaScript `myObject.myMethod()` (callable function)
- Tests should expect and call these as functions: `typeof myObject.myProperty === 'function'` and `myObject.myProperty()`

**JavaScriptCore Property Enumeration Limitation:** Swift-exposed objects cannot be enumerated using standard JavaScript methods:
- `Object.getOwnPropertyNames(swiftObject)` returns an empty array `[]`
- `for...in` loops do not iterate over Swift-exposed properties/methods
- `Object.keys(swiftObject)` returns an empty array `[]`
- However, direct property access works: `swiftObject.myMethod()` and `typeof swiftObject.myMethod === 'function'`
- Tests should verify functionality directly rather than relying on property enumeration

### Async/Promise Integration
Swift async functions are automatically bridged to JavaScript Promises:
```swift
// This creates a JavaScript function that returns a Promise
SwiftJS.Value(newFunctionIn: context) { args, this in
    // Swift async code here
    return someAsyncResult
}
```

### Timer Management
Timers are managed through the `SwiftJS.Context` class and automatically cleaned up. The polyfill provides `setTimeout`/`setInterval` that work with the RunLoop.

### Resource Bundle Access
JavaScript resources are bundled and accessed via `Bundle.module`:
```swift
if let polyfillJs = Bundle.module.url(forResource: "polyfill", withExtension: "js"),
   let content = try? String(contentsOf: polyfillJs, encoding: .utf8) {
    self.evaluateScript(content, withSourceURL: polyfillJs)
}
```

## Build & Test Workflow

### Package Structure
- Library target: `SwiftJS` 
- Test executable: `SwiftJSTests`
- Uses Swift Package Manager with Swift 6.0 tools
- Platforms: macOS 14+, iOS 17+, macCatalyst 17+

### Running Tests
```bash
# Build library
swift build

# Run test executable (runs indefinitely with timers)
swift run SwiftJSTests

# Run test cases (preferred method for AI agents)
swift test
```

### Dependencies
- `swift-crypto`: For cryptographic operations
- Native `JavaScriptCore`: Core JavaScript engine

## Project Conventions

### Web Standards Compliance
- When implementing APIs, prioritize web standards and specifications (W3C, WHATWG, ECMAScript) over Node.js-specific behaviors
- Follow MDN Web Docs for API signatures, behavior, and error handling patterns
- Implement standard web APIs (Fetch, Crypto, Streams, etc.) according to their specifications
- Only deviate from web standards when necessary for Swift/Apple platform integration
- Document any deviations from standards with clear reasoning

### Error Handling
- JavaScript exceptions are captured via `JSContext.exceptionHandler`
- Swift functions exposed to JS should throw `SwiftJS.Value` errors for proper JS error handling
- Use `SwiftJS.Value(newErrorFromMessage:)` for creating JS-compatible errors

### Sendable Compliance
- All types are marked `@unchecked Sendable` for Swift 6 concurrency
- `JSValue` and `JSContext` are retroactively marked Sendable
- Async JavaScript functions use `@Sendable` closures

### Naming Conventions
- Native Swift APIs use `JS` prefix when exposed to JavaScript (e.g., `JSCrypto`, `JSURLSession`)
- JavaScript polyfill objects mirror Node.js/Web APIs (`process`, `crypto`, `console`)
- Swift types follow standard conventions (`SwiftJS.Value`, `SwiftJS.VirtualMachine`)

## Integration Points

### JavaScript ↔ Swift Value Marshaling
Values cross the boundary through `SwiftJS.ValueBase` enum that handles all JavaScript types. Use `toJSValue(inContext:)` for Swift→JS and direct `SwiftJS.Value` constructors for JS→Swift.

### RunLoop Integration
JavaScript timers integrate with the current RunLoop via `VirtualMachine.runloop`. Tests run `RunLoop.main.run()` to keep timers active.

### Resource Management
- JavaScript resources are copied (not processed) in Package.swift
- Swift resources use `.copy()` to preserve exact content
- Both library and test targets have separate resource bundles

## Temporary Files for Testing
- When creating temporary files to test code, place all test scripts under `<project_root>/.temp/` to keep the workspace organized and avoid conflicts with the main codebase.
- Use SwiftJSRunner to execute JavaScript test files: `swift run SwiftJSRunner <script.js>`
- SwiftJSRunner supports both file execution and eval mode: `swift run SwiftJSRunner -e "console.log('test')"`
- All SwiftJS APIs are available in SwiftJSRunner including crypto, fetch, file system, and timers

## AI Agent Test Execution Guidelines
When running tests as an AI agent:
- Wait for the test task to complete before proceeding
- If you cannot see the output or the task appears to be still running, the agent is required to ask the user to confirm the task has completed or stuck
- If the task is stuck, the agent should ask the user to terminate the task and try again
- Don't make assumptions about the task status
- Never use timeouts to run the test command
- Never repeat or re-run the test command while a test task is already running
- Only proceed with next steps after test completion confirmation
- Never assume a task has completed successfully without confirmation
- Always ask the user to confirm task completion or termination if the status is unclear