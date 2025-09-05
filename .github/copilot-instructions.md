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

### Native API Exposure via `__APPLE_SPEC__`
Native Swift APIs are exposed to JavaScript through the global `__APPLE_SPEC__` object:
- `crypto`: Cryptographic functions (randomUUID, randomBytes, hashing)
- `processInfo`: Process information (PID, arguments, environment)
- `deviceInfo`: Device identification
- `FileSystem`: File operations
- `URLSession`: HTTP requests

## Critical Patterns

### Method Binding and `this` Context
**CRITICAL:** When accessing JavaScript methods via subscript, the `this` context is lost, causing methods to fail:

```swift
// ❌ WRONG - loses 'this' context, causes TypeError
let method = object["methodName"]
let result = method.call(withArguments: [])  // TypeError: Type error

// ✅ CORRECT - preserves 'this' context  
let result = object.invokeMethod("methodName", withArguments: [])
```

**Why this happens:**
- JavaScript method extraction unbinds the method from its object
- Native methods like `Date.getFullYear()` require their original object as `this`
- `invokeMethod` calls the method directly on the object, preserving the binding
- This is standard JavaScript behavior, not a SwiftJS limitation

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
- When creating temporary files to test JavaScript code, place all test scripts under `<project_root>/.temp/` to keep the workspace organized and avoid conflicts with the main codebase.
- **Important:** The `.temp/` directory is only for JavaScript test files, not Swift code. Swift code must be run within proper test cases in the `Tests/` directory.
- Use SwiftJSRunner to execute JavaScript test files: `swift run SwiftJSRunner <script.js>`
- SwiftJSRunner supports both file execution and eval mode: `swift run SwiftJSRunner -e "console.log('test')"`
- All SwiftJS APIs are available in SwiftJSRunner including crypto, fetch, file system, and timers

## AI Agent Guidelines

### Implementation Verification
**CRITICAL:** Always verify implementation behavior before writing documentation or making assumptions:
- Test actual behavior in SwiftJS runtime before documenting APIs
- Run code examples to confirm they work as described
- Use SwiftJSRunner or test cases to validate functionality
- Don't rely on external documentation without verification - JavaScriptCore has unique behaviors
- Document any discrepancies between expected and actual behavior

### JavaScriptCore Behavior Documentation
When discovering important JavaScriptCore facts or behaviors during development:
- Add detailed notes to `.github/copilot-instructions.md` under relevant sections
- Include code examples demonstrating the behavior
- Explain why the behavior occurs and its implications
- Note any workarounds or special handling required
- Mark critical behaviors with **CRITICAL:** or **Important:** tags

## **Important:** Task Execution Guidelines
When running any command or task as an AI agent:

### Command Execution Best Practices
- **Always wait** for the task to complete before proceeding with any subsequent actions
- **Never use timeouts** to run commands - it's always failure-prone and unreliable
- **Never repeat or re-run** the same command while a task is already running
- **Monitor task status** carefully and don't make assumptions about completion

### Task Status Verification
- If you cannot see the output or the task appears to be still running, you are **required** to ask the user to confirm the task has completed or is stuck
- If the task is stuck or hanging, ask the user to terminate the task and try again
- **Never assume** a task has completed successfully without explicit confirmation
- Always ask the user to confirm task completion or termination if the status is unclear

### Error Handling
- If a command fails, read the error output completely before suggesting fixes
- Don't retry failed commands without understanding and addressing the root cause
- Ask for user confirmation before attempting alternative approaches

## Critical Testing Patterns

### Performance Testing with `measure` Blocks
When using XCTest `measure` blocks, scripts are executed multiple times for performance measurement. This creates important constraints:

```swift
// ❌ WRONG - const/let variables cause redeclaration errors on repeated runs
let script = """
    const data = [1, 2, 3];  // SyntaxError on second run
    data
"""

// ✅ CORRECT - use var for variables that may be redeclared
let script = """
    var data = [1, 2, 3];    // Works on repeated runs
    data
"""
```

**Key Points:**
- `measure` blocks execute the same code multiple times in the same JavaScript context
- `const` and `let` declarations cannot be redeclared, causing `SyntaxError` on subsequent runs
- Always use `var` for variables in scripts that will be executed multiple times
- This applies to performance tests and any code that may run repeatedly in the same context