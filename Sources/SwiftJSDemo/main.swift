//
//  main.swift
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

import Foundation
import SwiftJS

let context = SwiftJS()

// Load existing demo resources
let corejsURL = Bundle.module.url(forResource: "corejs", withExtension: "js")
let corejs = try String(contentsOf: corejsURL!)

let script1URL = Bundle.module.url(forResource: "script_1", withExtension: "js")
let script1 = try String(contentsOf: script1URL!)

let script2URL = Bundle.module.url(forResource: "script_2", withExtension: "js")
let script2 = try String(contentsOf: script2URL!)

context.evaluateScript(script1)
context.evaluateScript(corejs)
context.evaluateScript(script2)

// Test streaming functionality
print("Testing SwiftJS Streaming Support...")

// Test 1: Basic ReadableStream functionality
print("\n1. Testing ReadableStream creation and reading...")
let streamingTest = """
  const stream = new ReadableStream({
      start(controller) {
          controller.enqueue(new TextEncoder().encode('Hello '));
          controller.enqueue(new TextEncoder().encode('Streaming '));
          controller.enqueue(new TextEncoder().encode('World!'));
          controller.close();
      }
  });

  const reader = stream.getReader();
  const chunks = [];

  async function readAll() {
      while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
      }
      
      let totalLength = 0;
      chunks.forEach(chunk => totalLength += chunk.byteLength);
      const combined = new Uint8Array(totalLength);
      let offset = 0;
      chunks.forEach(chunk => {
          combined.set(chunk, offset);
          offset += chunk.byteLength;
      });
      
      return new TextDecoder().decode(combined);
  }

  readAll().then(text => {
      console.log('Stream result:', text);
  }).catch(error => {
      console.error('Stream error:', error.message);
  });
  """

context.evaluateScript(streamingTest)

// Test 2: Response body streaming
print("\n2. Testing Response body streaming...")
let responseStreamTest = """
  const response = new Response('Hello from Response body stream!');
  console.log('Response body is ReadableStream:', response.body instanceof ReadableStream);

  response.text().then(text => {
      console.log('Response text:', text);
  }).catch(error => {
      console.error('Response error:', error.message);
  });
  """

context.evaluateScript(responseStreamTest)

// Test 3: Stream tee functionality
print("\n3. Testing stream tee functionality...")
let teeStreamTest = """
  const source = new ReadableStream({
      start(controller) {
          controller.enqueue(new TextEncoder().encode('Tee test'));
          controller.close();
      }
  });

  const [stream1, stream2] = source.tee();

  Promise.all([
      stream1.getReader().read(),
      stream2.getReader().read()
  ]).then(([result1, result2]) => {
      const text1 = new TextDecoder().decode(result1.value);
      const text2 = new TextDecoder().decode(result2.value);
      console.log('Tee result 1:', text1);
      console.log('Tee result 2:', text2);
      console.log('Tee results equal:', text1 === text2);
  }).catch(error => {
      console.error('Tee error:', error.message);
  });
  """

context.evaluateScript(teeStreamTest)

// Test 4: Request with streaming body
print("\n4. Testing Request with streaming body...")
let requestStreamTest = """
  try {
      const stream = new ReadableStream({
          start(controller) {
              controller.enqueue(new TextEncoder().encode('Streaming request body'));
              controller.close();
          }
      });
      
      const request = new Request('https://example.com', {
          method: 'POST',
          body: stream
      });
      
      console.log('Request body is stream:', request.body instanceof ReadableStream);
      console.log('Request method:', request.method);
  } catch (error) {
      console.error('Request stream error:', error.message);
  }
  """

context.evaluateScript(requestStreamTest)

// Test 5: Fetch with streaming response
print("\n5. Testing fetch streaming response...")
let fetchStreamTest = """
  // Simple test - create a response and check if body is a stream
  const testResponse = new Response('Test streaming response');
  console.log('Fetch response body is stream:', testResponse.body instanceof ReadableStream);

  // Test reading from the stream
  testResponse.body.getReader().read().then(({ done, value }) => {
      if (!done) {
          const text = new TextDecoder().decode(value);
          console.log('Streamed response chunk:', text);
      }
  }).catch(error => {
      console.error('Stream read error:', error.message);
  });
  """

context.evaluateScript(fetchStreamTest)

print("\n6. Running event loop to process async operations...")

RunLoop.main.run()
