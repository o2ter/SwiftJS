# SwiftJSRunner

SwiftJSRunner is a command-line tool that allows you to execute JavaScript files and code using the SwiftJS runtime. It provides a Node.js-like environment with access to all SwiftJS APIs and native Swift capabilities.

## Features

- **JavaScript File Execution**: Run JavaScript files with full SwiftJS API access
- **Eval Mode**: Execute JavaScript code directly from the command line
- **Node.js-like Environment**: Familiar APIs and global objects
- **Native Integration**: Access Swift APIs through `__APPLE_SPEC__` namespace
- **Async Support**: Full support for Promises, async/await, and timers
- **Process Integration**: Command-line arguments via `process.argv`
- **Error Handling**: Comprehensive error reporting with stack traces
- **Automatic Cleanup**: Intelligent lifecycle management for long-running scripts

## Installation

SwiftJSRunner is built automatically with the SwiftJS project:

```bash
# Build the entire project
swift build

# Build only SwiftJSRunner
swift build --product SwiftJSRunner
```

## Usage

### Command Syntax

```bash
swift run SwiftJSRunner [options] [script-file] [arguments...]
swift run SwiftJSRunner [options] -e <javascript-code> [arguments...]
```

### Options

- `-e, --eval <code>`: Execute JavaScript code directly
- `-h, --help`: Show help message and exit

### Running JavaScript Files

```bash
# Execute a JavaScript file
swift run SwiftJSRunner script.js

# Pass arguments to the script
swift run SwiftJSRunner script.js arg1 arg2 "arg with spaces"

# Arguments are available as process.argv in JavaScript
```

### Eval Mode

```bash
# Execute JavaScript code directly
swift run SwiftJSRunner -e "console.log('Hello, World!')"

# Use arguments in eval mode
swift run SwiftJSRunner -e "console.log('Args:', process.argv.slice(2))" arg1 arg2

# Multi-line JavaScript (use quotes)
swift run SwiftJSRunner -e "
const greet = (name) => console.log(`Hello, \${name}!`);
greet('SwiftJS');
"
```

## Available APIs

SwiftJSRunner provides access to the complete SwiftJS API surface:

### Web Standard APIs
- **Console**: `console.log()`, `console.error()`, `console.warn()`, `console.time()`, etc.
- **Timers**: `setTimeout()`, `setInterval()`, `clearTimeout()`, `clearInterval()`
- **Crypto**: `crypto.randomUUID()`, `crypto.getRandomValues()`, `crypto.randomBytes()`
- **Text Encoding**: `TextEncoder`, `TextDecoder`
- **Fetch API**: `fetch()`, `Request`, `Response`, `Headers`
- **Streams**: `ReadableStream`, `WritableStream`, `TransformStream`
- **Events**: `EventTarget`, `AbortController`, `AbortSignal`

### Process & Environment
- **Process Info**: `process.argv`, `process.pid`, `process.env`
- **Global Objects**: `globalThis`, `console`, standard constructors

### Native Swift APIs (via `__APPLE_SPEC__`)
- **File System**: `__APPLE_SPEC__.FileSystem` - File operations
- **Crypto**: `__APPLE_SPEC__.crypto` - Advanced cryptographic functions
- **Device Info**: `__APPLE_SPEC__.deviceInfo` - Device identification
- **Process Info**: `__APPLE_SPEC__.processInfo` - System process information
- **Networking**: `__APPLE_SPEC__.URLSession` - Native HTTP requests

## Examples

### Basic Script

Create a file `hello.js`:
```javascript
console.log("Hello from SwiftJS!");
console.log("Process ID:", process.pid);
console.log("Arguments:", process.argv);

// Modern JavaScript features work
const greet = async (name) => {
    return `Hello, ${name}!`;
};

greet("World").then(console.log);
```

Run it:
```bash
swift run SwiftJSRunner hello.js world
```

### HTTP Request Example

Create `fetch-example.js`:
```javascript
async function fetchData() {
    try {
        console.log("Fetching GitHub Zen...");
        const response = await fetch('https://api.github.com/zen');
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const text = await response.text();
        console.log("GitHub Zen:", text.trim());
        
    } catch (error) {
        console.error("Fetch error:", error.message);
        process.exit(1);
    }
}

fetchData();
```

Run it:
```bash
swift run SwiftJSRunner fetch-example.js
```

### File System Operations

Create `file-example.js`:
```javascript
const fs = __APPLE_SPEC__.FileSystem;

// Check if a file exists
const filePath = process.argv[2] || '/tmp/test.txt';
const exists = fs.fileExistsAtPath(filePath);

console.log(`File ${filePath} exists:`, exists);

if (exists) {
    // Read file contents
    const content = fs.contentsOfFileAtPath(filePath);
    console.log("File content:", new TextDecoder().decode(content));
} else {
    // Create a test file
    const testContent = new TextEncoder().encode("Hello from SwiftJS!");
    const success = fs.createFileAtPathWithContents(filePath, testContent);
    console.log("File created:", success);
}
```

Run it:
```bash
swift run SwiftJSRunner file-example.js /path/to/your/file.txt
```

### Crypto Operations

```bash
swift run SwiftJSRunner -e "
// Generate UUID
console.log('UUID:', crypto.randomUUID());

// Generate random bytes
const bytes = new Uint8Array(16);
crypto.getRandomValues(bytes);
console.log('Random bytes:', Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join(''));

// Use native crypto for advanced operations
const hash = __APPLE_SPEC__.crypto.createHash('sha256');
hash.update(new TextEncoder().encode('Hello, World!'));
console.log('SHA256 hash:', hash.digest('hex'));
"
```

### Timer and Async Example

Create `timer-example.js`:
```javascript
console.log("Starting timer demo...");

let count = 0;
const interval = setInterval(() => {
    count++;
    console.log(`Tick ${count}`);
    
    if (count >= 5) {
        clearInterval(interval);
        console.log("Timer demo complete!");
    }
}, 1000);

// Async operation
setTimeout(async () => {
    console.log("Running async operation...");
    const uuid = crypto.randomUUID();
    console.log("Generated UUID:", uuid);
}, 2500);
```

Run it:
```bash
swift run SwiftJSRunner timer-example.js
```

## Script Lifecycle

SwiftJSRunner intelligently manages script execution:

1. **Initialization**: Creates SwiftJS context and loads polyfills
2. **Argument Processing**: Makes command-line arguments available via `process.argv`
3. **Script Execution**: Evaluates the JavaScript code or file
4. **RunLoop Management**: Keeps the process alive for async operations
5. **Automatic Termination**: Exits when no more async work is scheduled
6. **Timeout Protection**: Prevents infinite execution (5 minutes for files, 30 seconds for eval)

## Error Handling

SwiftJSRunner provides comprehensive error handling:

### JavaScript Errors
```bash
swift run SwiftJSRunner -e "throw new Error('Oops!');"
# Output:
# JavaScript Error:
# Error: Oops!
#     at eval (eval:1:1)
```

### File Not Found
```bash
swift run SwiftJSRunner nonexistent.js
# Output: Error: JavaScript file not found: nonexistent.js
```

### Syntax Errors
```bash
swift run SwiftJSRunner -e "const x = ;"
# Output: JavaScript Error: SyntaxError: Unexpected token ';'
```

### Exit Codes
- `0`: Success
- `1`: JavaScript error, file not found, or syntax error

## Best Practices

### For Scripts
- Use `async/await` for cleaner asynchronous code
- Handle errors appropriately with try/catch blocks
- Use `process.exit(code)` to explicitly control exit codes
- Leverage modern JavaScript features (ES6+)

### For Development
- Create test scripts in `.temp/` directory to keep workspace clean
- Use `console.time()`/`console.timeEnd()` for performance measurement
- Take advantage of native APIs for better performance

### Performance Tips
- Use native APIs (`__APPLE_SPEC__`) for file operations when possible
- Leverage streaming for large data processing
- Minimize timer usage in short-lived scripts

## Debugging

### Verbose Output
Use console methods for debugging:
```javascript
console.time('operation');
console.log('Debug info:', { key: 'value' });
console.timeEnd('operation');
```

### Stack Traces
SwiftJSRunner preserves JavaScript stack traces:
```javascript
function problematic() {
    throw new Error('Something went wrong');
}

function caller() {
    problematic();
}

caller(); // Will show full call stack
```

## Troubleshooting

### Script Hangs
- Check for unclosed timers (`setInterval` without `clearInterval`)
- Ensure async operations complete or timeout appropriately
- Use timeouts to prevent infinite waiting

### Permission Errors
- File system operations require appropriate permissions
- Network requests may be blocked by firewall/security settings

### Memory Issues
- Use streaming APIs for large data processing
- Clear timers and clean up resources explicitly

## Integration Examples

### Shell Script Integration
```bash
#!/bin/bash
# run-js-tests.sh

echo "Running JavaScript tests..."
swift run SwiftJSRunner test-suite.js
result=$?

if [ $result -eq 0 ]; then
    echo "Tests passed!"
else
    echo "Tests failed with code $result"
    exit $result
fi
```

### CI/CD Usage
```yaml
# .github/workflows/test.yml
- name: Run JavaScript Tests
  run: |
    swift build
    swift run SwiftJSRunner tests/integration-test.js
```

SwiftJSRunner provides a powerful and flexible way to execute JavaScript code with full access to Swift's native capabilities, making it ideal for scripting, testing, and integration scenarios.
