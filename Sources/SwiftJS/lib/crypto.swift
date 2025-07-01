//
//  crypto.swift
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

@objc protocol JSCryptoExport: JSExport {

  func randomUUID() -> String

  func getRandomValues(_ buffer: JSValue) -> JSValue

  func randomBytes(_ length: Int) -> JSValue

  func createHash(_ algorithm: String) -> JSHash?

  func createHamc(_ algorithm: String, _ secret: JSValue) -> JSHash?
}

extension JSCrypto {

  func randomUUID() -> String {
    let uuid = UUID()
    return .init(uuid.uuidString)
  }

  func getRandomValues(_ buffer: JSValue) -> JSValue {
    guard buffer.isTypedArray else { return buffer }
    let bytes = buffer.typedArrayMutableBytes
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
    return buffer
  }

  func randomBytes(_ length: Int) -> JSValue {
    return .uint8Array(count: length, in: JSContext.current()) { bytes in
      _ = SecRandomCopyBytes(kSecRandomDefault, length, bytes.baseAddress!)
    }
  }
}

@objc final class JSCrypto: NSObject, JSCryptoExport {

}

extension JSCrypto {

  func createHash(_ algorithm: String) -> JSHash? {
    switch algorithm {
    case "md5": return JSHash(Insecure.MD5())
    case "sha1": return JSHash(Insecure.SHA1())
    case "sha256": return JSHash(SHA256())
    case "sha384": return JSHash(SHA384())
    case "sha512": return JSHash(SHA512())
    default: return nil
    }
  }
}

extension JSCrypto {

  func createHamc(_ algorithm: String, _ secret: JSValue) -> JSHash? {
    guard secret.isTypedArray else { return nil }
    let key = SymmetricKey(data: secret.typedArrayBytes)
    switch algorithm {
    case "md5": return JSHash(HMAC<Insecure.MD5>(key: key))
    case "sha1": return JSHash(HMAC<Insecure.SHA1>(key: key))
    case "sha256": return JSHash(HMAC<SHA256>(key: key))
    case "sha384": return JSHash(HMAC<SHA384>(key: key))
    case "sha512": return JSHash(HMAC<SHA512>(key: key))
    default: return nil
    }
  }
}
