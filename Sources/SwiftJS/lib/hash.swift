//
//  hash.swift
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

import Crypto
import JavaScriptCore

protocol HashProtocol {

  associatedtype Digest: ContiguousBytes

  mutating func update(bufferPointer: UnsafeRawBufferPointer)

  func finalize() -> Self.Digest
}

extension Insecure.MD5: HashProtocol {

}

extension Insecure.SHA1: HashProtocol {

}

extension SHA256: HashProtocol {

}

extension SHA384: HashProtocol {

}

extension SHA512: HashProtocol {

}

extension HMAC: HashProtocol {

  typealias Digest = Self.MAC

  mutating func update(bufferPointer: UnsafeRawBufferPointer) {
    self.update(data: bufferPointer)
  }
}

@objc protocol JSHashExport: JSExport {

  func update(_ data: JSValue)

  func digest() -> JSValue

  func clone() -> Self
}

@objc final class JSHash: NSObject, JSHashExport {

  var base: any HashProtocol

  init(_ hash: any HashProtocol) {
    self.base = hash
  }

  func update(_ data: JSValue) {
    guard data.isTypedArray else { return }
    base.update(bufferPointer: data.typedArrayBytes)
  }

  func digest() -> JSValue {
    let digest = base.finalize()
    return digest.withUnsafeBytes { bytes in
      .uint8Array(count: bytes.count, in: JSContext.current()) { buffer in
        buffer.copyBytes(from: bytes)
      }
    }
  }

  func clone() -> JSHash {
    return JSHash(base)
  }
}
