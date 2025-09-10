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
import Foundation

extension Foundation.FileHandle: @unchecked Sendable {}

@objc protocol JSFileSystemExport: JSExport {
    func homeDirectory() -> String
    func temporaryDirectory() -> String
    func currentDirectoryPath() -> String
    func changeCurrentDirectoryPath(_ path: String) -> Bool
    func removeItem(_ path: String)
    func readFile(_ path: String) -> String?
    func readFileData(_ path: String) -> JSValue?
    func writeFile(_ path: String, _ content: String) -> Bool
    func writeFileData(_ path: String, _ data: JSValue) -> Bool
    func readDirectory(_ path: String) -> [String]?
    func createDirectory(_ path: String) -> Bool
    func exists(_ path: String) -> Bool
    func isDirectory(_ path: String) -> Bool
    func isFile(_ path: String) -> Bool
    func stat(_ path: String) -> JSValue?
    func copyItem(_ sourcePath: String, _ destinationPath: String) -> Bool
    func moveItem(_ sourcePath: String, _ destinationPath: String) -> Bool

    // Streaming methods for efficient file reading
    func getFileSize(_ path: String) -> Int
    // Promise-based streaming API (non-blocking)
    // - createFileHandle returns a Promise<number> resolving to handle id or -1 on failure
    // - readFileHandleChunk returns a Promise<Uint8Array|null> resolving with chunk or null at EOF
    // - closeFileHandle returns a Promise<void>
    func createFileHandle(_ path: String) -> JSValue
    func readFileHandleChunk(_ handle: Int, _ length: Int) -> JSValue
    func closeFileHandle(_ handle: Int) -> JSValue
}

@objc final class JSFileSystem: NSObject, JSFileSystemExport, @unchecked Sendable {
    
    private let context: SwiftJS.Context
    private let runloop: RunLoop

    init(context: SwiftJS.Context, runloop: RunLoop) {
        self.context = context
        self.runloop = runloop
        super.init()
    }

    func homeDirectory() -> String {
        return NSHomeDirectory()
    }
    
    func temporaryDirectory() -> String {
        let tempDir = NSTemporaryDirectory()
        // Remove trailing slash if present
        return tempDir.hasSuffix("/") ? String(tempDir.dropLast()) : tempDir
    }
    
    func currentDirectoryPath() -> String {
        return FileManager.default.currentDirectoryPath
    }
    
    func changeCurrentDirectoryPath(_ path: String) -> Bool {
        return FileManager.default.changeCurrentDirectoryPath(path)
    }
    
    func removeItem(_ path: String) {
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
    
    func readFile(_ path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func readFileData(_ path: String) -> JSValue? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
            let context = JSContext.current()!

            // Create a Uint8Array in JavaScript
            let uint8Array = JSValue.uint8Array(count: data.count, in: context) { buffer in
                data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
            }
            return uint8Array
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func writeFile(_ path: String, _ content: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func writeFileData(_ path: String, _ data: JSValue) -> Bool {
        do {
            let context = JSContext.current()!

            // Handle different types of data
            let swiftData: Data

            if data.isTypedArray {
                // Convert typed array to Data
                let bytes = data.typedArrayBytes
                swiftData = Data(bytes.bindMemory(to: UInt8.self))
            } else if data.isString {
                // Convert string to UTF-8 data
                swiftData = data.toString().data(using: .utf8) ?? Data()
            } else {
                context.exception = JSValue(
                    newErrorFromMessage: "Unsupported data type for writeFileData", in: context)
                return false
            }

            try swiftData.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func readDirectory(_ path: String) -> [String]? {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: path)
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func createDirectory(_ path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func exists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func isFile(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }

    func stat(_ path: String) -> JSValue? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let context = JSContext.current()!

            let stat = JSValue(newObjectIn: context)!

            // File size
            if let size = attributes[.size] as? NSNumber {
                stat.setObject(size, forKeyedSubscript: "size")
            }

            // Modification date
            if let modDate = attributes[.modificationDate] as? Date {
                stat.setObject(modDate.timeIntervalSince1970 * 1000, forKeyedSubscript: "mtime")
            }

            // Creation date
            if let createDate = attributes[.creationDate] as? Date {
                stat.setObject(
                    createDate.timeIntervalSince1970 * 1000, forKeyedSubscript: "birthtime")
            }

            // File type
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

            stat.setObject(isDirectory.boolValue, forKeyedSubscript: "isDirectory")
            stat.setObject(!isDirectory.boolValue, forKeyedSubscript: "isFile")

            // Permissions
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                stat.setObject(posixPermissions, forKeyedSubscript: "mode")
            }

            return stat
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func copyItem(_ sourcePath: String, _ destinationPath: String) -> Bool {
        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func moveItem(_ sourcePath: String, _ destinationPath: String) -> Bool {
        do {
            try FileManager.default.moveItem(atPath: sourcePath, toPath: destinationPath)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    // Streaming methods for efficient file reading
    func getFileSize(_ path: String) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return (attributes[.size] as? NSNumber)?.intValue ?? 0
        } catch {
            return 0
        }
    }

    func createFileHandle(_ path: String) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, _ in
            // Open file on a background queue to avoid blocking the JS thread
            DispatchQueue.global().async {
                if let fileHandle = FileHandle(forReadingAtPath: path) {
                    // Register the handle in a thread-safe way using the context lock
                    self.context.handleLock.lock()
                    self.context.handleCounter += 1
                    let handleId = self.context.handleCounter
                    self.context.openFileHandles[handleId] = fileHandle
                    self.context.handleLock.unlock()

                    resolve?.call(withArguments: [
                        JSValue(double: Double(handleId), in: jsContext)!
                    ])
                } else {
                    resolve?.call(withArguments: [JSValue(double: Double(-1), in: jsContext)!])
                }
            }
        }
    }

    func readFileHandleChunk(_ handle: Int, _ length: Int) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, reject in
            // Obtain the file handle in a thread-safe way
            self.context.handleLock.lock()
            let fileHandle = self.context.openFileHandles[handle]
            self.context.handleLock.unlock()

            guard let fileHandle = fileHandle else {
                // Must call resolve on JS thread
                resolve?.call(withArguments: [JSValue(nullIn: jsContext)!])
                return
            }

            // Read from file on a background queue
            DispatchQueue.global().async {
                do {
                    let data = try fileHandle.read(upToCount: length) ?? Data()

                    if data.isEmpty {
                        // EOF - resolve on JS thread
                        self.runloop.perform {
                            resolve?.call(withArguments: [JSValue(nullIn: jsContext)!])
                        }
                        return
                    }
                    // Create JS typed array and resolve on JS thread
                    let dataCopy = data  // capture
                    self.runloop.perform {
                        let uint8Array = JSValue.uint8Array(count: dataCopy.count, in: jsContext) {
                            buffer in
                            dataCopy.copyBytes(
                                to: buffer.bindMemory(to: UInt8.self), count: dataCopy.count)
                        }
                        resolve?.call(withArguments: [uint8Array])
                    }
                } catch {
                    self.runloop.perform {
                        reject?.call(withArguments: [
                            JSValue(newErrorFromMessage: "\(error)", in: jsContext)!
                        ])
                    }
                }
            }
        }
    }

    func closeFileHandle(_ handle: Int) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, _ in
            self.context.handleLock.lock()
            let fileHandle = self.context.openFileHandles.removeValue(forKey: handle)
            self.context.handleLock.unlock()

            if let fileHandle = fileHandle {
                DispatchQueue.global().async { fileHandle.closeFile() }
            }

            resolve?.call(withArguments: [JSValue(undefinedIn: jsContext)!])
        }
    }
}
