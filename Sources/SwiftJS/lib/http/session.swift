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

// Reference-type accumulator used by stream controllers
final class DataAccumulator: @unchecked Sendable {
    var data: Data = Data()
}

@objc protocol JSURLSessionExport: JSExport {
    
    func shared() -> JSURLSession
    
    func httpRequestWithRequest(
        _ request: JSURLRequest,
        _ bodyStream: JSValue,
        _ progressHandler: JSValue,
        _ completionHandler: JSValue?
    ) -> JSValue?
}

@objc final class JSURLSession: NSObject, JSURLSessionExport, @unchecked Sendable {
    
    // Store reference to SwiftJS context for network tracking
    private let context: SwiftJS.Context

    init(context: SwiftJS.Context) {
        self.context = context
        super.init()
    }

    func shared() -> JSURLSession {
        return self
    }

    /// Unified HTTP request method using JSURLRequest
    func httpRequestWithRequest(
        _ request: JSURLRequest,
        _ bodyStream: JSValue,
        _ progressHandler: JSValue,
        _ completionHandler: JSValue?
    ) -> JSValue? {
        guard let context = JSContext.current() else { return nil }

        return JSValue(newPromiseIn: context) { resolve, reject in
            Task {
                // Start network request tracking
                let networkId = self.context.startNetworkRequest()

                defer {
                    // End network request tracking
                    self.context.endNetworkRequest(networkId)
                }

                do {
                    // Use a reference-type accumulator so controllers can safely append data
                    let accumulator = DataAccumulator()

                    let streamController = StreamController(
                        context: context,
                        progressHandler: progressHandler,
                        accumulator: accumulator
                    )

                    let responseHead: HTTPResponseHead

                    if !bodyStream.isNull && !bodyStream.isUndefined {
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

                    // Build data JSValue from accumulator
                    let dataValue: JSValue
                    if !accumulator.data.isEmpty {
                        dataValue = JSValue.uint8Array(count: accumulator.data.count, in: context) {
                            buffer in
                            accumulator.data.copyBytes(
                                to: buffer.bindMemory(to: UInt8.self), count: accumulator.data.count
                            )
                        }
                    } else {
                        dataValue = JSValue.uint8Array(count: 0, in: context)
                    }

                    // For streaming mode (progress handler provided), resolve with JSURLResponse directly
                    if progressHandler != nil {
                        resolve?.call(withArguments: [JSValue(object: jsResponse, in: context)!])
                    } else {
                        // Non-streaming mode - resolve with a consistent result object containing `data` and `response`
                        let responseValue = JSValue(object: jsResponse, in: context)!
                        let result = JSValue(newObjectIn: context)!
                        result.setValue(dataValue, forProperty: "data")
                        result.setValue(responseValue, forProperty: "response")

                        // Call legacy completion handler if provided
                        if let handler = completionHandler {
                            let nullValue = JSValue(nullIn: context)!
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
