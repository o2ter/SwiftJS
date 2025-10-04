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

@objc protocol JSFileSystemExport: JSExport {
    func homeDirectory() -> String
    func temporaryDirectory() -> String
    func currentDirectoryPath() -> String
    func changeCurrentDirectoryPath(_ path: String) -> Bool
    func removeItem(_ path: String) -> Bool
    func readFile(_ path: String, _ binary: Bool) -> JSValue?
    func writeFile(_ path: String, _ data: JSValue, _ flags: Int) -> Bool
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

    /// - createReadFileHandle returns a Promise<number> resolving to handle id or -1 on failure
    func createReadFileHandle(_ path: String) -> JSValue
    /// - readFileHandleChunk returns a Promise<Uint8Array|null> resolving with chunk or null at EOF
    func readFileHandleChunk(_ handle: Int, _ length: Int) -> JSValue
    /// - closeFileHandle returns a Promise<void>
    func closeFileHandle(_ handle: Int) -> JSValue
    
    // Write streaming methods for memory-efficient file writing
    /// - createWriteFileHandle returns a Promise<number> resolving to handle id or -1 on failure
    /// - Parameters:
    ///   - path: File path
    ///   - flags: File open flags (bit flags: 1=append, 2=exclusive)
    func createWriteFileHandle(_ path: String, _ flags: Int) -> JSValue
    /// - writeFileHandleChunk returns a Promise<boolean> resolving with success status
    func writeFileHandleChunk(_ handle: Int, _ data: JSValue) -> JSValue
}

@objc final class JSFileSystem: NSObject, JSFileSystemExport, @unchecked Sendable {
    
    // File operation flags (bit flags)
    // Bit 0 (value 1): Append mode
    // Bit 1 (value 2): Exclusive mode (O_EXCL - atomic create, fail if exists)
    // Examples: 0 = truncate, 1 = append, 2 = exclusive, 3 = append+exclusive

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
    
    func removeItem(_ path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            let context = JSContext.current()!
            if let error = error as? JSValue {
                context.exception = error
            } else {
                context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            }
            return false
        }
    }
    
    func readFile(_ path: String, _ binary: Bool) -> JSValue? {
        let context = JSContext.current()!
        
        do {
            if binary {
                // Return Uint8Array for binary data
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                let uint8Array = JSValue.uint8Array(count: data.count, in: context) { buffer in
                    data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
                }
                return uint8Array
            } else {
                // Return string for text data
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return JSValue(object: content, in: context)
            }
        } catch {
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func writeFile(_ path: String, _ data: JSValue, _ flags: Int) -> Bool {
        let context = JSContext.current()!
        
        // Decode flags: bit 0 = append, bit 1 = exclusive
        let append = (flags & 1) != 0
        let exclusive = (flags & 2) != 0

        // Convert JS data to Swift Data
        let swiftData: Data

        if data.isTypedArray {
            let bytes = data.typedArrayBytes
            swiftData = Data(bytes.bindMemory(to: UInt8.self))
        } else if data.isString {
            swiftData = data.toString().data(using: .utf8) ?? Data()
        } else {
            context.exception = JSValue(
                newErrorFromMessage: "Unsupported data type for writeFile", in: context)
            return false
        }

        // Build POSIX open flags (same pattern as createWriteFileHandle)
        var openFlags = O_WRONLY | O_CREAT
        if exclusive {
            openFlags |= O_EXCL
        }
        if append {
            openFlags |= O_APPEND  // Use O_APPEND for atomic append operations
        } else {
            openFlags |= O_TRUNC
        }

        // Open file using POSIX (atomic for exclusive mode)
        let fd = open(path, openFlags, 0o644)

        if fd == -1 {
            let errorNum = errno
            let error = String(cString: strerror(errorNum))
            let message =
                errorNum == EEXIST
                ? "File already exists: \(path)"
                : "Failed to open file: \(error)"
            context.exception = JSValue(newErrorFromMessage: message, in: context)
            return false
        }

        defer { close(fd) }

        // Write data (O_APPEND flag ensures atomic append to end of file)
        let written = swiftData.withUnsafeBytes { buffer in
            write(fd, buffer.baseAddress, buffer.count)
        }

        if written != swiftData.count {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to write all data to file", in: context)
            return false
        }

        return true
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

    func createReadFileHandle(_ path: String) -> JSValue {
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

    // Write streaming methods for memory-efficient file writing
    func createWriteFileHandle(_ path: String, _ flags: Int) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, reject in
            DispatchQueue.global().async {
                // Decode flags: bit 0 = append, bit 1 = exclusive
                let append = (flags & 1) != 0
                let exclusive = (flags & 2) != 0

                // Build POSIX open flags
                var openFlags = O_WRONLY | O_CREAT
                if exclusive {
                    openFlags |= O_EXCL
                }
                if append {
                    openFlags |= O_APPEND  // Use O_APPEND for atomic append operations
                } else {
                    openFlags |= O_TRUNC
                }

                // Open file using POSIX (atomic for exclusive mode)
                let fd = open(path, openFlags, 0o644)

                if fd == -1 {
                    let errorNum = errno
                    let error = String(cString: strerror(errorNum))
                    self.runloop.perform {
                        let message =
                            errorNum == EEXIST
                            ? "File already exists: \(path)"
                            : "Failed to open file: \(error)"
                        reject?.call(withArguments: [
                            JSValue(newErrorFromMessage: message, in: jsContext)!
                        ])
                    }
                    return
                }

                let fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)

                // Note: No need to seek - O_APPEND flag ensures atomic append to end of file

                // Register the write handle
                self.context.handleLock.lock()
                self.context.handleCounter += 1
                let handleId = self.context.handleCounter
                self.context.openFileHandles[handleId] = fileHandle
                self.context.handleLock.unlock()

                self.runloop.perform {
                    resolve?.call(withArguments: [
                        JSValue(double: Double(handleId), in: jsContext)!
                    ])
                }
            }
        }
    }

    func writeFileHandleChunk(_ handle: Int, _ data: JSValue) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, reject in
            self.context.handleLock.lock()
            let fileHandle = self.context.openFileHandles[handle]
            self.context.handleLock.unlock()

            guard let fileHandle = fileHandle else {
                self.runloop.perform {
                    reject?.call(withArguments: [
                        JSValue(newErrorFromMessage: "Invalid file handle", in: jsContext)!
                    ])
                }
                return
            }

            // Convert JS data to Swift Data
            DispatchQueue.global().async {
                do {
                    let swiftData: Data

                    if data.isTypedArray {
                        let bytes = data.typedArrayBytes
                        swiftData = Data(bytes.bindMemory(to: UInt8.self))
                    } else if data.isString {
                        swiftData = data.toString().data(using: .utf8) ?? Data()
                    } else {
                        self.runloop.perform {
                            reject?.call(withArguments: [
                                JSValue(
                                    newErrorFromMessage: "Unsupported data type for write",
                                    in: jsContext)!
                            ])
                        }
                        return
                    }

                    // Write chunk to file
                    try fileHandle.write(contentsOf: swiftData)

                    self.runloop.perform {
                        resolve?.call(withArguments: [JSValue(bool: true, in: jsContext)!])
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
}
