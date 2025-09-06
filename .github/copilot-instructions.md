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

## Project Conventions

### Code Style and Naming
- **No underscore prefixes**: Never use underscore prefixes (like `_originalBody`) for internal fields or methods
- **Use symbols for internal APIs**: For polyfill internal fields that need cross-class access, use symbols defined in the `SYMBOLS` object
- **Use `#` for class private fields**: For true private fields within a single class, use JavaScript private field syntax with `#`
- **Example pattern**:
  ```javascript
  // ❌ WRONG - underscore prefix
  get _originalBody() { return this.#originalBody; }
  
  // ✅ CORRECT - use symbol for cross-class access
  this[SYMBOLS.requestOriginalBody] = init.body;
  
  // ✅ CORRECT - use # for true private fields
  #body = null;
  ```

### Web Standards Compliance
- When implementing APIs, prioritize web standards and specifications (W3C, WHATWG, ECMAScript) over Node.js-specific behaviors
- Follow MDN Web Docs for API signatures, behavior, and error handling patterns
- Implement standard web APIs (Fetch, Crypto, Streams, etc.) according to their specifications
- Only deviate from web standards when necessary for Swift/Apple platform integration
- Document any deviations from standards with clear reasoning

**IMPORTANT: No DOM-Specific APIs**
- SwiftJS is a server-side runtime and does not implement DOM-specific APIs
- Use standard `Error` objects instead of DOM-specific errors like `DOMException`
- Avoid DOM-related concepts like `window`, `document`, `HTMLElement`, etc.
- Focus on web standard APIs that work in non-DOM environments (workers, Node.js-like runtime)
- When web specs reference DOM concepts, implement the non-DOM portions or provide appropriate alternatives

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
- **CRITICAL: Never start a new task before the previous one has completely finished**
  - Wait for explicit confirmation that the previous task has completed successfully or failed
  - Do not assume a task is finished just because you don't see output for a while
  - Multiple concurrent tasks can cause conflicts, resource contention, and unpredictable behavior
- **Monitor task status** carefully and don't make assumptions about completion

### Test Execution Guidelines
- **Always use the provided tools** when available instead of running commands manually:
  - Use `runTests` tool for running Swift test cases instead of `swift test` command
  - Use `run_notebook_cell` tool for executing Jupyter cells instead of terminal commands
  - Use `SwiftJSRunner` via `run_in_terminal` for JavaScript file execution
- **Test-specific best practices:**
  - When running test suites, use the `runTests` tool with specific file paths to avoid unnecessarily long test runs
  - For JavaScript testing, create test files in `.temp/` directory and use `SwiftJSRunner`
  - Never run `swift test` manually when the `runTests` tool is available
  - Always wait for test completion before analyzing results or running additional tests

### Task Status Verification
- If you cannot see the output or the task appears to be still running, you are **required** to ask the user to confirm the task has completed or is stuck
- If the task is stuck or hanging, ask the user to terminate the task and try again
- **Never assume** a task has completed successfully without explicit confirmation
- Always ask the user to confirm task completion or termination if the status is unclear
- **Sequential execution is mandatory:** Do not queue or pipeline tasks - complete one fully before starting the next
- **Never try to get the terminal output using a different approach or alternative method** always wait for the result using the provided tools and instructions. Do not attempt workarounds or alternate output retrieval.

### Error Handling
- If a command fails, read the error output completely before suggesting fixes
- Don't retry failed commands without understanding and addressing the root cause
- Ask for user confirmation before attempting alternative approaches
- **Never run alternative commands while a failed task is still running or in an unknown state**

## Streaming Architecture Guidelines

### **CRITICAL:** Streaming Implementation Principles
When implementing or modifying Blob, File, and HTTP operations, follow these principles to maintain memory-efficient streaming:

1. **NEVER call blob.arrayBuffer() in streaming contexts**
   - Always use blob.stream() and process chunks individually
   - Large files (GB+) will cause memory exhaustion otherwise

2. **File objects with filePath use Swift FileSystem streaming APIs**
   - createFileHandle() + readFileHandleChunk() for true disk streaming
   - Never load entire file into memory before streaming

3. **HTTP uploads use streaming body, not buffered body**
   - Pass ReadableStream directly to URLRequest
   - Avoid await body.arrayBuffer() for uploads

4. **TextDecoder streaming for text operations**
   - Use { stream: true } to handle encoding boundaries across chunks
   - Accumulate text progressively, not all-at-once

5. **Response body streaming pipes blob.stream() directly**
   - No intermediate arrayBuffer() materialization
   - Preserve memory-efficient chunk processing

**FUTURE DEVELOPERS:** If you find yourself calling .arrayBuffer() in streaming code, you're probably doing it wrong. Use .stream() and process chunks.

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

### **CRITICAL:** Object Literal vs Block Statement Ambiguity
**A fundamental JavaScript parsing rule that frequently causes test failures:**

```swift
// ❌ WRONG - bare object literal parsed as block statement
let script = """
    {
        original: original,
        encoded: encoded,
        decoded: decoded
    }
"""
// Returns: undefined (parsed as labeled statements in a block)

// ✅ CORRECT - parentheses force object literal parsing
let script = """
    ({
        original: original,
        encoded: encoded,
        decoded: decoded
    })
"""
// Returns: object with properties
```

**Why this happens:**
- JavaScript parser interprets `{` at start of statement as beginning of block statement
- `original:`, `encoded:`, etc. become statement labels, not object properties
- Expressions after labels are evaluated but the block returns `undefined`
- Wrapping in parentheses `({ ... })` forces expression context, creating object literal
- This is standard JavaScript behavior, not a SwiftJS limitation

**IMPORTANT - Debugging Philosophy:**
When encountering mysterious "undefined" returns or unexpected behavior in JavaScript code, always consider fundamental JavaScript parsing and evaluation rules first:
- Is the code being parsed as intended? (statement vs expression context)
- Are there implicit type conversions happening?
- Is the execution context (this binding, scope) what you expect?
- Many "SwiftJS bugs" are actually standard JavaScript behaviors that need deeper understanding

**Comparing Success vs Failure Cases:**
Understanding why some tests pass while others fail reveals the parsing issue:

```swift
// ✅ SUCCESS - Simple expressions work fine
"typeof btoa"           // Returns: "function"
"btoa('hello')"         // Returns: "aGVsbG8="
"atob('aGVsbG8=')"      // Returns: "hello"

// ❌ FAILURE - Bare object literals return undefined
"{original: 'test'}"    // Returns: undefined (block statement)

// ✅ SUCCESS - Parentheses fix the parsing
"({original: 'test'})"  // Returns: {original: 'test'} (object literal)
```

**Key insight:** The difference is not in the function implementation (btoa/atob work perfectly), but in how JavaScript parses the return value structure. Simple expressions work, but object returns need parentheses to force correct parsing context.

**Common symptoms:**
- Test assertions fail with "undefined" when expecting object properties
- `result["property"]` returns undefined even though script logic appears correct
- Functions like `btoa`/`atob` work individually but fail in object return contexts

**Testing implications:**
- Always wrap object literals in parentheses when they're the main return value
- Particularly important in test scripts that return result objects for assertion
- Use `({ ... })` pattern consistently in all test object returns

### **CRITICAL:** Test Timeout Requirements
**All asynchronous tests MUST have timeout parameters to prevent hanging:**

```swift
// ❌ WRONG - missing timeout can cause indefinite hanging
wait(for: [expectation])

// ✅ CORRECT - always include appropriate timeout
wait(for: [expectation], timeout: 10.0)
```

**Timeout Guidelines by Test Type:**
- **5 seconds**: Quick data parsing, simple operations, basic API calls
- **10 seconds**: Standard network requests, stream operations, most async tests
- **15 seconds**: Complex stream processing, error recovery, multi-step operations
- **30 seconds**: Concurrent connections, resource-intensive operations
- **60 seconds**: Large file uploads, performance-critical operations

**Why timeouts are essential:**
- JavaScript async operations can hang indefinitely due to network issues
- Tests without timeouts block the entire test suite
- Debugging becomes impossible when tests hang without feedback
- CI/CD systems may timeout at the process level, giving less useful error information

**Common timeout scenarios:**
- Network requests to unreachable endpoints
- Stream operations waiting for data that never arrives
- Timer-based operations with incorrect JavaScript logic
- Promise chains with unhandled rejections
- Event listeners that are never triggered

**Timeout detection patterns:**
Use grep to find missing timeouts:
```bash
# Find all wait calls without timeout
grep -r "wait(for: \[expectation\])$" Tests/

# Verify all have timeouts
grep -r "wait(for:.*timeout:" Tests/
```

**Bulk timeout fixes:**
For files with many missing timeouts, use sed for bulk replacement:
```bash
sed -i '' 's/wait(for: \[expectation\])$/wait(for: [expectation], timeout: 10.0)/g' filename.swift
```

**Testing best practices:**
- Always add timeouts when creating new async tests
- Review existing tests for missing timeouts during refactoring
- Use appropriate timeout values based on operation complexity
- Consider network conditions and CI environment performance
- Prefer shorter timeouts for faster feedback, but ensure reliability