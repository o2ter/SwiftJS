// swift-tools-version: 6.0
//
//  Package.swift
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

import PackageDescription

let package = Package(
    name: "SwiftJS",
    platforms: [
        .macOS(.v14),
        .macCatalyst(.v17),
        .iOS(.v17),
    ],
    products: [
        .executable(name: "SwiftJSDemo", targets: ["SwiftJSDemo"]),
        .library(name: "SwiftJS", targets: ["SwiftJS"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.2"),
    ],
    targets: [
        .target(
            name: "SwiftJS",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            resources: [
                .copy("resources/polyfill.js")
            ]
        ),
        .testTarget(
            name: "SwiftJSTests",
            dependencies: ["SwiftJS"]
        ),
        .executableTarget(
            name: "SwiftJSDemo",
            dependencies: ["SwiftJS"],
            resources: [
                .copy("resources/corejs.js"),
                .copy("resources/script_1.js"),
                .copy("resources/script_2.js"),
                .copy("resources/http_test.js"),
                .copy("resources/debug_methods.js"),
                .copy("resources/demo.js")
            ]
        ),
    ]
)
