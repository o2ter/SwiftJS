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

extension FileHandle: @unchecked Sendable {}

@objc protocol JSFileSystemExport: JSExport {
    static var homeDirectory: String { get }
    static var temporaryDirectory: String { get }
    static var currentDirectoryPath: String { get }
    static func changeCurrentDirectoryPath(_ path: String) -> Bool
    static func removeItem(_ path: String)
    static func readFile(_ path: String) -> String?
    static func readFileData(_ path: String) -> JSValue?
    static func writeFile(_ path: String, _ content: String) -> Bool
    static func writeFileData(_ path: String, _ data: JSValue) -> Bool
    static func readDirectory(_ path: String) -> [String]?
    static func createDirectory(_ path: String) -> Bool
    static func exists(_ path: String) -> Bool
    static func isDirectory(_ path: String) -> Bool
    static func isFile(_ path: String) -> Bool
    static func stat(_ path: String) -> JSValue?
    static func copyItem(_ sourcePath: String, _ destinationPath: String) -> Bool
    static func moveItem(_ sourcePath: String, _ destinationPath: String) -> Bool

    // Streaming methods for efficient file reading
    static func getFileSize(_ path: String) -> Int
    static func readFileChunk(_ path: String, _ offset: Int, _ length: Int) -> JSValue?
    static func createFileHandle(_ path: String) -> String?
    static func readFileHandleChunk(_ handle: String, _ length: Int) -> JSValue?
    static func closeFileHandle(_ handle: String)
}

@objc final class JSFileSystem: NSObject, JSFileSystemExport {
    
    static var homeDirectory: String {
        return NSHomeDirectory()
    }
    
    static var temporaryDirectory: String {
        let tempDir = NSTemporaryDirectory()
        // Remove trailing slash if present
        return tempDir.hasSuffix("/") ? String(tempDir.dropLast()) : tempDir
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
    
    static func readFile(_ path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    static func readFileData(_ path: String) -> JSValue? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
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

    static func writeFile(_ path: String, _ content: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    static func writeFileData(_ path: String, _ data: JSValue) -> Bool {
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

    static func readDirectory(_ path: String) -> [String]? {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: path)
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    static func createDirectory(_ path: String) -> Bool {
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

    static func exists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    static func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    static func isFile(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }

    static func stat(_ path: String) -> JSValue? {
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

    static func copyItem(_ sourcePath: String, _ destinationPath: String) -> Bool {
        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    static func moveItem(_ sourcePath: String, _ destinationPath: String) -> Bool {
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
    static func getFileSize(_ path: String) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return (attributes[.size] as? NSNumber)?.intValue ?? 0
        } catch {
            return 0
        }
    }

    static func readFileChunk(_ path: String, _ offset: Int, _ length: Int) -> JSValue? {
        guard let context = JSContext.current() else { return nil }

        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return nil
        }

        defer { fileHandle.closeFile() }

        do {
            let data: Data
            if #available(macOS 10.15, iOS 13.0, *) {
                try fileHandle.seek(toOffset: UInt64(offset))
                data = try fileHandle.read(upToCount: length) ?? Data()
            } else {
                fileHandle.seek(toFileOffset: UInt64(offset))
                data = fileHandle.readData(ofLength: length)
            }

            let uint8Array = JSValue.uint8Array(count: data.count, in: context) { buffer in
                data.copyBytes(to: buffer, count: data.count)
            }
            return uint8Array
        } catch {
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    // File handle management for continuous reading
    nonisolated(unsafe) private static var openFileHandles: [String: FileHandle] = [:]
    nonisolated(unsafe) private static var handleCounter = 0
    private static let handleLock = NSLock()

    static func createFileHandle(_ path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return nil
        }

        handleLock.lock()
        defer { handleLock.unlock() }

        handleCounter += 1
        let handleId = "handle_\(handleCounter)"
        openFileHandles[handleId] = fileHandle
        return handleId
    }

    static func readFileHandleChunk(_ handle: String, _ length: Int) -> JSValue? {
        guard let context = JSContext.current() else { return nil }

        handleLock.lock()
        let fileHandle = openFileHandles[handle]
        handleLock.unlock()

        guard let fileHandle = fileHandle else { return nil }

        do {
            let data: Data
            if #available(macOS 10.15, iOS 13.0, *) {
                data = try fileHandle.read(upToCount: length) ?? Data()
            } else {
                data = fileHandle.readData(ofLength: length)
            }

            if data.isEmpty {
                return nil  // EOF
            }

            let uint8Array = JSValue.uint8Array(count: data.count, in: context) { buffer in
                data.copyBytes(to: buffer, count: data.count)
            }
            return uint8Array
        } catch {
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    static func closeFileHandle(_ handle: String) {
        handleLock.lock()
        defer { handleLock.unlock() }

        if let fileHandle = openFileHandles.removeValue(forKey: handle) {
            fileHandle.closeFile()
        }
    }
}
