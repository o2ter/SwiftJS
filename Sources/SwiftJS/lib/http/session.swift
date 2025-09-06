//
//  session.swift
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
import NIOHTTP1

@objc protocol JSURLSessionExport: JSExport {
    
    func shared() -> JSURLSession
    
    func httpRequestWithRequest(
        _ request: JSURLRequest,
        _ bodyStream: JSValue?,
        _ progressHandler: JSValue?,
        _ completionHandler: JSValue?
    ) -> JSValue?
}

@objc final class JSURLSession: NSObject, JSURLSessionExport, @unchecked Sendable {
    
    // Store reference to SwiftJS context for network tracking
    private let swiftJSContext: SwiftJS.Context

    init(context: SwiftJS.Context) {
        self.swiftJSContext = context
        super.init()
    }

    func shared() -> JSURLSession {
        return self
    }

    /// Unified HTTP request method using JSURLRequest
    func httpRequestWithRequest(
        _ request: JSURLRequest,
        _ bodyStream: JSValue?,
        _ progressHandler: JSValue?,
        _ completionHandler: JSValue?
    ) -> JSValue? {
        guard let context = JSContext.current() else { return nil }

        return JSValue(newPromiseIn: context) { resolve, reject in
            Task {
                // Start network request tracking
                let networkId = self.swiftJSContext.startNetworkRequest()

                defer {
                    // End network request tracking
                    self.swiftJSContext.endNetworkRequest(networkId)
                }

                do {
                    var accumulatedData = Data()

                    // Choose stream controller based on whether we have a progress handler
                    let streamController: StreamControllerProtocol
                    if let progressHandler = progressHandler {
                        // Streaming mode - call progress handler for each chunk
                        streamController = ProgressStreamController(
                            context: context,
                            progressHandler: progressHandler,
                            accumulatedData: &accumulatedData
                        )
                    } else {
                        // Regular mode - just accumulate data
                        streamController = AccumulatingStreamController(
                            accumulatedData: &accumulatedData)
                    }

                    let responseHead: HTTPResponseHead

                    if let bodyStream = bodyStream, !bodyStream.isNull && !bodyStream.isUndefined {
                        // Upload with body stream
                        request.httpBody = bodyStream

                        // Create AsyncStream from JavaScript stream
                        let streamReader = JSStreamReader(stream: bodyStream, context: context)
                        let dataStream = streamReader.createAsyncStream()

                        responseHead = try await NIOHTTPClient.shared.executeStreamingUpload(
                            request,
                            bodyStream: dataStream,
                            streamController: streamController
                        )
                    } else {
                        // Regular request (GET/POST without streaming body)
                        responseHead = try await NIOHTTPClient.shared.executeStreamingRequest(
                            request,
                            streamController: streamController
                        )
                    }

                    // Create JSURLResponse from NIO response head
                    // Handle duplicate headers by combining values with commas (HTTP spec)
                    var headersDict: [String: String] = [:]
                    for header in responseHead.headers {
                        let key = header.name
                        let value = header.value
                        if let existing = headersDict[key] {
                            headersDict[key] = existing + ", " + value
                        } else {
                            headersDict[key] = value
                        }
                    }

                    let jsResponse = JSURLResponse(
                        statusCode: Int(responseHead.status.code),
                        headers: headersDict,
                        url: request.url
                    )

                    if progressHandler != nil {
                        // Streaming mode - resolve with response only (progress handler called completion in close())
                        resolve?.call(withArguments: [jsResponse])
                    } else {
                        // Regular mode - resolve with data and response
                        let dataValue: JSValue
                        if !accumulatedData.isEmpty {
                            dataValue = JSValue.uint8Array(
                                count: accumulatedData.count, in: context
                            ) { buffer in
                                accumulatedData.copyBytes(
                                    to: buffer.bindMemory(to: UInt8.self),
                                    count: accumulatedData.count)
                            }
                        } else {
                            dataValue = JSValue.uint8Array(count: 0, in: context)
                        }

                        let result = JSValue(
                            object: [
                                "data": dataValue,
                                "response": JSValue(object: jsResponse, in: context)!,
                            ], in: context)!

                        // Call legacy completion handler if provided
                        if let handler = completionHandler {
                            let nullValue = JSValue(nullIn: context)!
                            let responseValue = JSValue(object: jsResponse, in: context)!
                            handler.call(withArguments: [nullValue, dataValue, responseValue])
                        }

                        resolve?.call(withArguments: [result])
                    }
                } catch {
                    reject?.call(withArguments: [
                        JSValue(newErrorFromMessage: error.localizedDescription, in: context)!
                    ])
                }
            }
        }
    }
}

/// Stream controller that accumulates all data without calling progress handlers
/// Used for regular dataTask methods that need all data at once
final class AccumulatingStreamController: StreamControllerProtocol, @unchecked Sendable {
    private var accumulatedDataRef: UnsafeMutablePointer<Data>
    private let lock = NSLock()

    init(accumulatedData: inout Data) {
        self.accumulatedDataRef = withUnsafeMutablePointer(to: &accumulatedData) { $0 }
    }
    
    func enqueue(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        accumulatedDataRef.pointee.append(data)
    }

    func error(_ error: Error) {
        // Error handling is done at the task level
    }

    func close() {
        // No specific cleanup needed
    }
}

/// Stream controller that calls progress handler for each chunk
/// Used for streaming methods that need to report progress
final class ProgressStreamController: StreamControllerProtocol, @unchecked Sendable {
    private let context: JSContext
    private let progressHandler: JSValue?
    private var accumulatedDataRef: UnsafeMutablePointer<Data>
    private let lock = NSLock()

    init(context: JSContext, progressHandler: JSValue?, accumulatedData: inout Data) {
        self.context = context
        self.progressHandler = progressHandler
        self.accumulatedDataRef = withUnsafeMutablePointer(to: &accumulatedData) { $0 }
    }

    func enqueue(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        accumulatedDataRef.pointee.append(data)

        // Call progress handler if provided
        if let progressHandler = progressHandler, !data.isEmpty {
            let uint8Array = JSValue.uint8Array(count: data.count, in: context) { buffer in
                data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
            }

            // Call progress handler with data chunk and completion status (false = not complete)
            progressHandler.call(withArguments: [uint8Array, false])
        }
    }

    func error(_ error: Error) {
        // Error handling is done at the task level
    }

    func close() {
        // Call progress handler with completion signal
        if let progressHandler = progressHandler {
            // Call with empty data and completion = true
            let emptyArray = JSValue.uint8Array(count: 0, in: context) { _ in }
            progressHandler.call(withArguments: [emptyArray, true])
        }
    }
}
