//
//  main.swift
//  SwiftJSRunner
//
//  The MIT License
//  Copyright (c) 2021 - 2025 O2ter Limited. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import SwiftJS

// MARK: - Command Line Argument Parsing

func printUsage() {
    print("SwiftJSRunner - JavaScript Runtime for Swift")
    print("")
    print("Usage:")
    print("  SwiftJSRunner <javascript-file> [arguments...]")
    print("  SwiftJSRunner -e <javascript-code> [arguments...]")
    print("  SwiftJSRunner --eval <javascript-code> [arguments...]")
    print("  SwiftJSRunner -h | --help")
    print("")
    print("Options:")
    print("  -e, --eval <code>    Execute JavaScript code directly")
    print("  -h, --help           Show this help message")
    print("")
    print("Arguments:")
    print("  Any additional arguments will be available in JavaScript as process.argv")
    print("")
    print("Examples:")
    print("  SwiftJSRunner script.js")
    print("  SwiftJSRunner script.js arg1 arg2")
    print("  SwiftJSRunner -e \"console.log('Hello, World!')\"")
    print("  SwiftJSRunner --eval \"console.log(process.argv)\" arg1 arg2")
}

func exitWithError(_ message: String, code: Int32 = 1) -> Never {
    fputs("Error: \(message)\n", stderr)
    exit(code)
}

// MARK: - Main Execution

func main() {
    let arguments = CommandLine.arguments
    let programName = (arguments.first! as NSString).lastPathComponent
    let args = Array(arguments.dropFirst())
    
    // Handle help option
    if args.isEmpty || args.contains("-h") || args.contains("--help") {
        printUsage()
        exit(args.isEmpty ? 1 : 0)
    }
    
    // Create SwiftJS context
    let context = SwiftJS()
    
    // Set up process.argv with proper arguments
    var jsArgs: [String] = []
    var sourceCode: String = ""
    var isEvalMode = false
    
    if args[0] == "-e" || args[0] == "--eval" {
        // Eval mode
        if args.count < 2 {
            exitWithError("Option \(args[0]) requires JavaScript code")
        }
        isEvalMode = true
        sourceCode = args[1]
        jsArgs = [programName, args[0]] + Array(args.dropFirst(2))
    } else {
        // File mode
        let scriptPath = args[0]
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            exitWithError("JavaScript file not found: \(scriptPath)")
        }
        
        // Read the JavaScript file
        do {
            sourceCode = try String(contentsOfFile: scriptPath, encoding: .utf8)
        } catch {
            exitWithError("Failed to read JavaScript file: \(error.localizedDescription)")
        }
        
        jsArgs = [programName, scriptPath] + Array(args.dropFirst())
    }
    
    // Set up process.argv in JavaScript context
    let jsArgsArray = SwiftJS.Value(jsArgs.map { SwiftJS.Value($0) })
    
    // Set argv on global object directly and set up process
    context.globalObject["__argv__"] = jsArgsArray
    context.evaluateScript("if (typeof process !== 'undefined') { process.argv = __argv__; } else { globalThis.process = { argv: __argv__ }; }")
    
    // Execute the JavaScript code
    let result = context.evaluateScript(sourceCode)
    
    // Check if there was an exception
    let exception = context.exception
    if !exception.isUndefined {
        // Try to get stack trace
        let stack = exception["stack"]
        if !stack.isUndefined {
            fputs("JavaScript Error:\n\(stack.toString())\n", stderr)
        } else {
            fputs("JavaScript Error: \(exception.toString())\n", stderr)
        }
        exit(1)
    }
    
    // If the result is defined and not null, print it (like Node.js REPL)
    if isEvalMode && !result.isUndefined && !result.isNull {
        print(result.toString())
    }
    
    // Keep the run loop running to handle any async operations (timers, promises, etc.)
    // But with a reasonable timeout to prevent hanging
    let runLoop = RunLoop.current
    let startTime = Date()
    let timeoutDuration: TimeInterval = 10.0 // 10 seconds timeout
    
    while runLoop.run(mode: .default, before: Date().addingTimeInterval(0.1)) {
        // Check for timeout
        if Date().timeIntervalSince(startTime) > timeoutDuration {
            break
        }
        
        // Check if we have any pending timers or other work
        // This is a simple heuristic - in practice, we might want more sophisticated detection
        Thread.sleep(forTimeInterval: 0.01)
    }
}

// Run the main function
main()
