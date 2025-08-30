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

@objc protocol JSURLSessionExport: JSExport {
    static func getShared() -> JSURLSession
    init(configuration: JSURLSessionConfiguration)
    var configuration: JSURLSessionConfiguration { get }
    
    func dataTaskWithRequestCompletionHandler(
        _ request: JSURLRequest, _ completionHandler: JSValue?
    ) -> JSValue?
    func dataTaskWithURL(_ url: String, completionHandler: JSValue?) -> JSValue?
}

@objc final class JSURLSession: NSObject, JSURLSessionExport {
    
    nonisolated(unsafe) 
        private static let _shared: JSURLSession = JSURLSession(session: .shared)

    @objc static func getShared() -> JSURLSession {
        return _shared
    }
    
    let session: URLSession
    
    init(session: URLSession) {
        self.session = session
    }
    
    init(configuration: JSURLSessionConfiguration) {
        self.session = URLSession(configuration: configuration.configuration)
    }

    var configuration: JSURLSessionConfiguration {
        return JSURLSessionConfiguration(configuration: self.session.configuration)
    }
    
    func dataTaskWithRequestCompletionHandler(
        _ request: JSURLRequest, _ completionHandler: JSValue?
    ) -> JSValue? {
        guard let context = JSContext.current() else { return nil }

        return JSValue(newPromiseIn: context) { resolve, reject in
            let task = self.session.dataTask(with: request.urlRequest) { data, response, error in
                if let error = error {
                    reject?.call(withArguments: [
                        JSValue(newErrorFromMessage: error.localizedDescription, in: context)!
                    ])
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    reject?.call(withArguments: [
                        JSValue(newErrorFromMessage: "Invalid response", in: context)!
                    ])
                    return
                }

                let jsResponse = JSURLResponse(response: httpResponse)
                let dataValue: JSValue

                if let data = data {
                    dataValue = JSValue.uint8Array(count: data.count, in: context) { buffer in
                        data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
                    }
                } else {
                    dataValue = JSValue.uint8Array(count: 0, in: context)
                }

                let result = JSValue(
                    object: [
                        "data": dataValue,
                        "response": JSValue(object: jsResponse, in: context)!,
                    ], in: context)!

                if let handler = completionHandler {
                    let nullValue = JSValue(nullIn: context)!
                    let responseValue = JSValue(object: jsResponse, in: context)!
                    handler.call(withArguments: [nullValue, dataValue, responseValue])
                }

                resolve?.call(withArguments: [result])
            }
            task.resume()
        }
    }

    func dataTaskWithURL(_ url: String, completionHandler: JSValue?) -> JSValue? {
        let request = JSURLRequest(url: url)
        return dataTaskWithRequestCompletionHandler(request, completionHandler)
    }
}
