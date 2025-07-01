//
//  fileSystem.swift
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

import JavaScriptCore

@objc protocol JSFileSystemExport: JSExport {
    static var homeDirectory: String { get }
    static var temporaryDirectory: String { get }
    static var currentDirectoryPath: String { get }
    static func changeCurrentDirectoryPath(_ path: String) -> Bool
    static func removeItem(_ path: String)
}

@objc final class JSFileSystem: NSObject, JSFileSystemExport {
    
    static var homeDirectory: String {
        return NSHomeDirectory()
    }
    
    static var temporaryDirectory: String {
        return NSTemporaryDirectory()
    }
    
    static var currentDirectoryPath: String {
        return FileManager.default.currentDirectoryPath
    }
    
    static func changeCurrentDirectoryPath(_ path: String) -> Bool {
        return FileManager.default.changeCurrentDirectoryPath(path)
    }
    
    static func removeItem(_ path: String) {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            let context = JSContext.current()!
            if let error = error as? JSValue {
                context.exception = error
            } else {
                context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            }
        }
    }
}
