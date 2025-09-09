(function () {
  'use strict';

  // Private symbols for internal APIs
  const SYMBOLS = {
    formDataToMultipart: Symbol('FormData._toMultipartString'),
    blobPlaceholderPromise: Symbol('Blob._placeholderPromise'),
    requestOriginalBody: Symbol('Request._originalBody'),
    streamInternal: Symbol('Stream._internal'),
    abortSignalMarkAborted: Symbol('AbortSignal._markAborted'),
    abortSignalTimeoutMs: Symbol('AbortSignal._timeoutMs'),
    filePath: Symbol('File._filePath'),
    eventTargetOriginalListener: Symbol('EventTarget._originalListener')
  };

  // Process API - provides Node.js-like process object
  globalThis.process = new class Process {
    #env = { ...__APPLE_SPEC__.processInfo.environment };
    #argv = [...__APPLE_SPEC__.processInfo.arguments];

    get env() { return this.#env; }
    get argv() { return this.#argv; }
    get pid() { return __APPLE_SPEC__.processInfo.processIdentifier; }

    cwd() {
      return __APPLE_SPEC__.FileSystem.currentDirectoryPath();
    }

    chdir(directory) {
      if (arguments.length === 0) {
        throw new TypeError("process.chdir() requires a directory argument");
      }
      if (directory == null) {
        throw new TypeError("process.chdir() path must be a string");
      }

      const path = String(directory);
      const success = __APPLE_SPEC__.FileSystem.changeCurrentDirectoryPath(path);
      if (!success) {
        throw new Error(`chdir: ENOENT: no such file or directory, chdir '${path}'`);
      }
      return success;
    }

    // Standard Node.js process.exit() - calls native Swift implementation
    exit(code = 0) {
      // Validate exit code
      const exitCode = parseInt(code, 10);
      if (isNaN(exitCode)) {
        throw new TypeError('Exit code must be a number');
      }

      // Call the native Swift implementation directly
      // This will terminate the process cleanly without exceptions or global pollution
      __APPLE_SPEC__.processControl.exit(exitCode);
    }
  };

  // Path - Path manipulation utilities
  globalThis.Path = class Path {
    static sep = '/';  // Path separator (Unix-style for consistency)

    static join(...segments) {
      if (segments.length === 0) return '.';

      // Check if the first valid segment is absolute
      let isAbsolute = false;
      let resultParts = [];

      for (const segment of segments) {
        if (!segment || typeof segment !== 'string') continue;

        // If this is the first segment and it starts with '/', it's absolute
        if (resultParts.length === 0 && segment.startsWith('/')) {
          isAbsolute = true;
        }

        // Split segment and filter out empty parts
        const parts = segment.split(this.sep).filter(part => part !== '' && part !== '.');
        resultParts.push(...parts);
      }

      const result = resultParts.join(this.sep);

      if (isAbsolute) {
        return this.sep + result;
      }
      return result || '.';
    }

    static resolve(...segments) {
      let resolvedPath = '';
      let resolvedAbsolute = false;

      for (let i = segments.length - 1; i >= 0 && !resolvedAbsolute; i--) {
        const path = segments[i];
        if (path && typeof path === 'string') {
          resolvedPath = path + '/' + resolvedPath;
          resolvedAbsolute = path.startsWith('/');
        }
      }

      if (!resolvedAbsolute) {
        resolvedPath = __APPLE_SPEC__.FileSystem.currentDirectoryPath() + '/' + resolvedPath;
      }

      // Normalize the path
      return this.normalize(resolvedPath);
    }

    static normalize(path) {
      if (!path || typeof path !== 'string') return '.';

      const isAbsolute = path.startsWith('/');
      const parts = path.split('/').filter(part => part !== '');
      const normalizedParts = [];

      for (const part of parts) {
        if (part === '..') {
          if (normalizedParts.length > 0 && normalizedParts[normalizedParts.length - 1] !== '..') {
            normalizedParts.pop();
          } else if (!isAbsolute) {
            normalizedParts.push('..');
          }
        } else if (part !== '.' && part !== '') {
          normalizedParts.push(part);
        }
      }

      const result = normalizedParts.join('/');
      if (isAbsolute) {
        return '/' + result;
      }
      return result || '.';
    }

    static dirname(path) {
      if (!path || typeof path !== 'string') return '.';
      const normalized = this.normalize(path);
      const lastSlash = normalized.lastIndexOf('/');

      if (lastSlash === -1) return '.';
      if (lastSlash === 0) return '/';

      return normalized.substring(0, lastSlash);
    }

    static basename(path, ext = '') {
      if (!path || typeof path !== 'string') return '';
      const normalized = this.normalize(path);
      const lastSlash = normalized.lastIndexOf('/');
      const basename = lastSlash === -1 ? normalized : normalized.substring(lastSlash + 1);

      if (ext && basename.endsWith(ext)) {
        return basename.substring(0, basename.length - ext.length);
      }

      return basename;
    }

    static extname(path) {
      if (!path || typeof path !== 'string') return '';
      const basename = this.basename(path);
      const lastDot = basename.lastIndexOf('.');

      // Return empty string for:
      // - No dot found
      // - Dot at the start of filename (hidden files like .gitignore)
      // - Dot at the end of filename (like "file.")
      if (lastDot === -1 || lastDot === 0 || lastDot === basename.length - 1) return '';
      return basename.substring(lastDot);
    }

    static isAbsolute(path) {
      return typeof path === 'string' && path.startsWith('/');
    }
  };

  // FileSystem - Direct file system operations (non-web standard)
  globalThis.FileSystem = class FileSystem {
    // Directory utilities
    static get home() { return __APPLE_SPEC__.FileSystem.homeDirectory(); }
    static get temp() { return __APPLE_SPEC__.FileSystem.temporaryDirectory(); }
    static get cwd() { return __APPLE_SPEC__.FileSystem.currentDirectoryPath(); }

    static chdir(path) {
      return __APPLE_SPEC__.FileSystem.changeCurrentDirectoryPath(path);
    }

    // Basic file operations
    static exists(path) {
      return __APPLE_SPEC__.FileSystem.exists(path);
    }

    static isFile(path) {
      return __APPLE_SPEC__.FileSystem.isFile(path);
    }

    static isDirectory(path) {
      return __APPLE_SPEC__.FileSystem.isDirectory(path);
    }

    static stat(path) {
      return __APPLE_SPEC__.FileSystem.stat(path);
    }

    // Reading operations
    static readText(path, encoding = 'utf-8') {
      return __APPLE_SPEC__.FileSystem.readFile(path);
    }

    static readBytes(path) {
      return __APPLE_SPEC__.FileSystem.readFileData(path);
    }

    static async readFile(path, options = {}) {
      const { encoding = 'utf-8', flag = 'r' } = options;

      if (!this.exists(path)) {
        throw new Error(`File not found: ${path}`);
      }

      if (!this.isFile(path)) {
        throw new Error(`Not a file: ${path}`);
      }

      if (encoding === null || encoding === 'binary') {
        // Return Uint8Array for binary data
        const data = this.readBytes(path);
        return data ? data.typedArrayBytes : new Uint8Array(0);
      } else {
        // Return string for text data
        return this.readText(path) || '';
      }
    }

    static readDir(path) {
      return __APPLE_SPEC__.FileSystem.readDirectory(path) || [];
    }

    // Writing operations
    static writeText(path, content, options = {}) {
      const { flag = 'w' } = options;
      return __APPLE_SPEC__.FileSystem.writeFile(path, String(content));
    }

    static writeBytes(path, data) {
      return __APPLE_SPEC__.FileSystem.writeFileData(path, data);
    }

    static async writeFile(path, data, options = {}) {
      const { encoding = 'utf-8', flag = 'w' } = options;

      if (typeof data === 'string') {
        return this.writeText(path, data, options);
      } else if (data instanceof Uint8Array || data instanceof ArrayBuffer || ArrayBuffer.isView(data)) {
        return this.writeBytes(path, data);
      } else if (data instanceof Blob) {
        const bytes = new Uint8Array(await data.arrayBuffer());
        return this.writeBytes(path, bytes);
      } else {
        // Convert to string
        return this.writeText(path, String(data), options);
      }
    }

    // Directory operations
    static mkdir(path, options = {}) {
      const { recursive = true } = options;
      return __APPLE_SPEC__.FileSystem.createDirectory(path);
    }

    static rmdir(path, options = {}) {
      const { recursive = false } = options;

      if (!this.exists(path)) {
        throw new Error(`Directory not found: ${path}`);
      }

      if (!this.isDirectory(path)) {
        throw new Error(`Not a directory: ${path}`);
      }

      if (!recursive) {
        const contents = this.readDir(path);
        if (contents.length > 0) {
          throw new Error(`Directory not empty: ${path}`);
        }
      }

      __APPLE_SPEC__.FileSystem.removeItem(path);
      return true;
    }

    // File/directory manipulation
    static remove(path) {
      if (!this.exists(path)) {
        throw new Error(`Path not found: ${path}`);
      }
      __APPLE_SPEC__.FileSystem.removeItem(path);
      return true;
    }

    static copy(src, dest, options = {}) {
      const { overwrite = false } = options;

      if (!this.exists(src)) {
        throw new Error(`Source not found: ${src}`);
      }

      if (this.exists(dest) && !overwrite) {
        throw new Error(`Destination already exists: ${dest}`);
      }

      return __APPLE_SPEC__.FileSystem.copyItem(src, dest);
    }

    static move(src, dest, options = {}) {
      const { overwrite = false } = options;

      if (!this.exists(src)) {
        throw new Error(`Source not found: ${src}`);
      }

      if (this.exists(dest) && !overwrite) {
        throw new Error(`Destination already exists: ${dest}`);
      }

      return __APPLE_SPEC__.FileSystem.moveItem(src, dest);
    }

    // Stream operations for large files
    static createReadStream(path, options = {}) {
      const { encoding = null, start = 0, end = undefined } = options;

      if (!this.exists(path)) {
        throw new Error(`File not found: ${path}`);
      }

      if (!this.isFile(path)) {
        throw new Error(`Not a file: ${path}`);
      }

      return new ReadableStream({
        start(controller) {
          try {
            const data = __APPLE_SPEC__.FileSystem.readFileData(path);
            if (!data) {
              controller.error(new Error(`Failed to read file: ${path}`));
              return;
            }

            const bytes = data.typedArrayBytes;
            const startByte = Math.max(0, start);
            const endByte = end !== undefined ? Math.min(bytes.byteLength, end + 1) : bytes.byteLength;

            if (startByte >= endByte) {
              controller.close();
              return;
            }

            // Stream in chunks
            const chunkSize = 64 * 1024; // 64KB chunks
            let offset = startByte;

            while (offset < endByte) {
              const chunkEnd = Math.min(offset + chunkSize, endByte);
              const chunk = bytes.slice(offset, chunkEnd);

              if (encoding === null) {
                controller.enqueue(new Uint8Array(chunk));
              } else {
                const text = new TextDecoder(encoding).decode(new Uint8Array(chunk));
                controller.enqueue(text);
              }

              offset = chunkEnd;
            }

            controller.close();
          } catch (error) {
            controller.error(error);
          }
        }
      });
    }

    static createWriteStream(path, options = {}) {
      const { encoding = 'utf-8', flags = 'w' } = options;
      let chunks = [];

      return new WritableStream({
        write(chunk) {
          if (typeof chunk === 'string') {
            chunks.push(new TextEncoder().encode(chunk));
          } else if (chunk instanceof Uint8Array) {
            chunks.push(chunk);
          } else if (chunk instanceof ArrayBuffer) {
            chunks.push(new Uint8Array(chunk));
          } else if (ArrayBuffer.isView(chunk)) {
            chunks.push(new Uint8Array(chunk.buffer, chunk.byteOffset, chunk.byteLength));
          } else {
            chunks.push(new TextEncoder().encode(String(chunk)));
          }
        },

        close() {
          // Combine all chunks and write to file
          const combined = combineChunksToUint8Array(chunks);

          if (!__APPLE_SPEC__.FileSystem.writeFileData(path, combined)) {
            throw new Error(`Failed to write file: ${path}`);
          }
          chunks = [];
        },

        abort() {
          chunks = [];
        }
      });
    }

    // Utility methods
    static async glob(pattern, options = {}) {
      // Simple glob implementation - could be enhanced
      const { cwd = this.cwd, absolute = false } = options;
      const results = [];

      const searchDir = (dir, pat) => {
        try {
          const entries = this.readDir(dir);
          for (const entry of entries) {
            const fullPath = Path.join(dir, entry);

            if (pat.includes('*')) {
              const regex = new RegExp(pat.replace(/\*/g, '.*'));
              if (regex.test(entry)) {
                results.push(absolute ? fullPath : Path.join('.', entry));
              }
            } else if (entry === pat) {
              results.push(absolute ? fullPath : Path.join('.', entry));
            }

            if (this.isDirectory(fullPath) && pat.includes('/')) {
              searchDir(fullPath, pat);
            }
          }
        } catch (e) {
          // Ignore directories we can't read
        }
      };

      searchDir(cwd, pattern);
      return results;
    }

    // Path utilities
    static join(...parts) {
      return parts.join('/').replace(/\/+/g, '/');
    }

    static dirname(path) {
      return path.substring(0, path.lastIndexOf('/')) || '/';
    }

    static basename(path) {
      return path.substring(path.lastIndexOf('/') + 1);
    }

    static extname(path) {
      const name = this.basename(path);
      const lastDot = name.lastIndexOf('.');
      return lastDot > 0 ? name.substring(lastDot) : '';
    }

    // Efficient file operations that go through Swift
    static async streamCopy(source, destination, options = {}) {
      const { onProgress } = options;

      if (!this.exists(source)) {
        throw new Error(`Source file not found: ${source}`);
      }

      // For files under 10MB, use direct copy for better performance
      const sourceSize = this.stat(source).size;
      if (sourceSize <= 10 * 1024 * 1024) {
        const result = this.copy(source, destination, { overwrite: true });
        if (onProgress) {
          onProgress({ loaded: sourceSize, total: sourceSize, percent: 100 });
        }
        return result;
      }

      // For larger files, could implement chunked copying in Swift
      // For now, fall back to standard copy
      return this.copy(source, destination, { overwrite: true });
    }
  };



  // Event API - basic DOM-like event system
  globalThis.Event = class Event {
    constructor(type, options = {}) {
      this.type = type;
      this.target = null;
      this.currentTarget = null;
      this.eventPhase = 0;
      this.bubbles = options.bubbles || false;
      this.cancelable = options.cancelable || false;
      this.defaultPrevented = false;
    }

    stopPropagation() {
      this.eventPhase = 1;
    }

    preventDefault() {
      if (this.cancelable) {
        this.defaultPrevented = true;
      }
    }
  };

  globalThis.EventTarget = class EventTarget {
    #listeners = {};

    addEventListener(type, listener, options = {}) {
      if (!this.#listeners[type]) {
        this.#listeners[type] = [];
      }

      // Handle options
      const once = typeof options === 'object' ? options.once : false;

      const wrappedListener = once ?
        (event) => {
          try {
            listener(event);
          } finally {
            this.removeEventListener(type, wrappedListener);
          }
        } :
        listener;

      // Store original listener reference for removal
      wrappedListener[SYMBOLS.eventTargetOriginalListener] = listener;

      this.#listeners[type].push(wrappedListener);
    }

    removeEventListener(type, listener) {
      if (!this.#listeners[type]) return;
      this.#listeners[type] = this.#listeners[type].filter(l =>
        l !== listener && l[SYMBOLS.eventTargetOriginalListener] !== listener
      );
    }

    dispatchEvent(event) {
      if (!this.#listeners[event.type]) return true;

      // Set event target properties
      event.target = this;
      event.currentTarget = this;

      // Copy listeners array to avoid issues with modifications during dispatch
      const listeners = [...this.#listeners[event.type]];

      for (const listener of listeners) {
        try {
          listener(event);
        } catch (error) {
          // In browsers, listener errors don't stop other listeners from executing
          // and don't propagate - they're usually logged to console
          console.error(error);
        }
      }

      return !event.defaultPrevented;
    }
  };

  // AbortSignal and AbortController - for cancellation
  globalThis.AbortSignal = class AbortSignal extends EventTarget {
    #aborted = false;
    #onabort = null;

    get aborted() { return this.#aborted; }
    get onabort() { return this.#onabort; }

    set onabort(listener) {
      if (this.#onabort) {
        this.removeEventListener('abort', this.#onabort);
      }
      this.#onabort = listener;
      if (listener) {
        this.addEventListener('abort', listener);
      }
    }

    [SYMBOLS.abortSignalMarkAborted]() {
      this.#aborted = true;
    }

    // Static factory method for timeout-based AbortSignal
    static timeout(milliseconds) {
      const controller = new AbortController();
      // Set timeout hint on the signal using symbol
      controller.signal[SYMBOLS.abortSignalTimeoutMs] = milliseconds;
      setTimeout(() => {
        controller.abort();
      }, milliseconds);
      return controller.signal;
    }
  };

  globalThis.AbortController = class AbortController {
    #signal = new AbortSignal();

    get signal() { return this.#signal; }

    abort() {
      if (!this.#signal.aborted) {
        this.#signal[SYMBOLS.abortSignalMarkAborted]();
        this.#signal.dispatchEvent(new Event('abort'));
      }
    }
  };

  // Crypto API - cryptographic functions
  globalThis.crypto = new class Crypto {
    randomUUID() {
      return __APPLE_SPEC__.crypto.randomUUID();
    }

    randomBytes(length) {
      if (!Number.isSafeInteger(length) || length < 0) {
        throw new Error('Invalid length');
      }
      return __APPLE_SPEC__.crypto.randomBytes(length);
    }

    getRandomValues(buffer) {
      if (!ArrayBuffer.isView(buffer)) {
        throw new Error('Invalid type of buffer');
      }
      const bytes = buffer instanceof Uint8Array
        ? buffer
        : new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength);
      __APPLE_SPEC__.crypto.getRandomValues(bytes);
      return buffer;
    }
  };

  // TextEncoder - encode strings to UTF-8
  globalThis.TextEncoder = class TextEncoder {
    encoding = 'utf-8';

    static #getByteLength(string) {
      if (string == null) return 0;
      if (typeof string !== 'string') string = String(string);

      let length = 0;
      for (let i = 0; i < string.length; i++) {
        const code = string.charCodeAt(i);
        if (code < 0x80) {
          length += 1;
        } else if (code < 0x800) {
          length += 2;
        } else if ((code & 0xFC00) === 0xD800 && i + 1 < string.length &&
          (string.charCodeAt(i + 1) & 0xFC00) === 0xDC00) {
          // Surrogate pair
          i++;
          length += 4;
        } else {
          length += 3;
        }
      }
      return length;
    }

    encode(string = '') {
      // Convert non-string inputs to strings like browsers do
      if (typeof string !== 'string') {
        string = String(string);
      }

      const utf8 = new Uint8Array(TextEncoder.#getByteLength(string));
      let byteIndex = 0;

      for (let charIndex = 0; charIndex < string.length; charIndex++) {
        let code = string.charCodeAt(charIndex);

        if (code < 128) {
          utf8[byteIndex++] = code;
          continue;
        }

        if (code < 2048) {
          utf8[byteIndex++] = code >> 6 | 192;
        } else {
          // Handle surrogate pairs
          if ((code & 0xFC00) === 0xD800 && charIndex + 1 < string.length &&
            (string.charCodeAt(charIndex + 1) & 0xFC00) === 0xDC00) {
            code = 0x10000 + ((code & 0x03FF) << 10) + (string.charCodeAt(++charIndex) & 0x03FF);
            utf8[byteIndex++] = code >> 18 | 240;
            utf8[byteIndex++] = code >> 12 & 63 | 128;
          } else {
            utf8[byteIndex++] = code >> 12 | 224;
          }
          utf8[byteIndex++] = code >> 6 & 63 | 128;
        }
        utf8[byteIndex++] = code & 63 | 128;
      }

      return utf8.subarray(0, byteIndex);
    }
  };

  // TextDecoder - decode UTF-8 to strings
  globalThis.TextDecoder = class TextDecoder {
    encoding = 'utf-8';

    decode(input) {
      if (!input) return '';

      const bytes = input instanceof Uint8Array
        ? input
        : new Uint8Array(input);

      let result = '';
      let i = 0;

      while (i < bytes.length) {
        const byte1 = bytes[i++];

        if (byte1 < 128) {
          result += String.fromCharCode(byte1);
        } else if ((byte1 >> 5) === 6) {
          const byte2 = bytes[i++];
          result += String.fromCharCode(((byte1 & 31) << 6) | (byte2 & 63));
        } else if ((byte1 >> 4) === 14) {
          const byte2 = bytes[i++];
          const byte3 = bytes[i++];
          result += String.fromCharCode(
            ((byte1 & 15) << 12) | ((byte2 & 63) << 6) | (byte3 & 63)
          );
        } else if ((byte1 >> 3) === 30) {
          const byte2 = bytes[i++];
          const byte3 = bytes[i++];
          const byte4 = bytes[i++];
          let codePoint = ((byte1 & 7) << 18) | ((byte2 & 63) << 12) |
            ((byte3 & 63) << 6) | (byte4 & 63);
          codePoint -= 0x10000;
          result += String.fromCharCode(
            0xD800 + (codePoint >> 10),
            0xDC00 + (codePoint & 1023)
          );
        }
      }
      return result;
    }
  };

  // Base64 encoding/decoding functions for Data URLs and binary data
  globalThis.btoa = function (data) {
    // Web standard: btoa should accept any value and convert to string
    if (arguments.length === 0) {
      throw new TypeError('Failed to execute \'btoa\': 1 argument required, but only 0 present.');
    }

    // Convert to string following web standard ToString operation
    const str = String(data);

    // Convert string to UTF-8 bytes first
    const utf8Bytes = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code > 255) {
        throw new Error('Failed to execute \'btoa\': The string to be encoded contains characters outside of the Latin1 range.');
      }
      utf8Bytes.push(code);
    }

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';

    for (let i = 0; i < utf8Bytes.length; i += 3) {
      const a = utf8Bytes[i];
      const b = i + 1 < utf8Bytes.length ? utf8Bytes[i + 1] : 0;
      const c = i + 2 < utf8Bytes.length ? utf8Bytes[i + 2] : 0;

      const bitmap = (a << 16) | (b << 8) | c;

      result += chars.charAt((bitmap >> 18) & 63);
      result += chars.charAt((bitmap >> 12) & 63);
      result += i + 1 < utf8Bytes.length ? chars.charAt((bitmap >> 6) & 63) : '=';
      result += i + 2 < utf8Bytes.length ? chars.charAt(bitmap & 63) : '=';
    }

    return result;
  };

  globalThis.atob = function (data) {
    // Web standard: atob should accept any value and convert to string
    if (arguments.length === 0) {
      throw new TypeError('Failed to execute \'atob\': 1 argument required, but only 0 present.');
    }

    // Convert to string following web standard ToString operation
    let base64 = String(data);

    // Remove whitespace and validate base64 characters
    base64 = base64.replace(/\s/g, '');

    // Handle missing padding by adding it
    const paddingNeeded = 4 - (base64.length % 4);
    if (paddingNeeded < 4) {
      base64 += '='.repeat(paddingNeeded);
    }

    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(base64)) {
      throw new Error('Failed to execute \'atob\': The string to be decoded is not correctly encoded.');
    }

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';

    for (let i = 0; i < base64.length; i += 4) {
      const char1 = base64.charAt(i);
      const char2 = base64.charAt(i + 1);
      const char3 = base64.charAt(i + 2);
      const char4 = base64.charAt(i + 3);

      const encoded1 = chars.indexOf(char1);
      const encoded2 = chars.indexOf(char2);
      const encoded3 = char3 === '=' ? 0 : chars.indexOf(char3);
      const encoded4 = char4 === '=' ? 0 : chars.indexOf(char4);

      if (encoded1 === -1 || encoded2 === -1 || (char3 !== '=' && encoded3 === -1) || (char4 !== '=' && encoded4 === -1)) {
        throw new Error('Failed to execute \'atob\': The string to be decoded is not correctly encoded.');
      }

      const bitmap = (encoded1 << 18) | (encoded2 << 12) | (encoded3 << 6) | encoded4;

      // Always decode the first byte
      result += String.fromCharCode((bitmap >> 16) & 255);

      // Decode second byte unless we have double padding
      if (char3 !== '=') {
        result += String.fromCharCode((bitmap >> 8) & 255);
      }

      // Decode third byte unless we have any padding
      if (char4 !== '=') {
        result += String.fromCharCode(bitmap & 255);
      }
    }

    return result;
  };  // Enhanced Console implementation
  globalThis.console = globalThis.console || {};

  // Console state tracking
  const consoleState = {
    timers: new Map(),
    counters: new Map(),
    groupStack: [],
    groupDepth: 0
  };

  // Utility functions for better formatting
  function formatValue(value, depth = 0, maxDepth = 3, seen = new WeakSet()) {
    if (depth > maxDepth) return '[Max Depth Reached]';

    if (value === null) return 'null';
    if (value === undefined) return 'undefined';

    const type = typeof value;

    if (type === 'string') return `"${value}"`;
    if (type === 'number' || type === 'boolean' || type === 'bigint') return String(value);
    if (type === 'symbol') return value.toString();

    if (type === 'function') {
      const funcStr = value.toString();
      const name = value.name || 'anonymous';
      // Show just the function signature for better readability
      const match = funcStr.match(/^(?:async\s+)?(?:function\s*)?([^(]*)\([^)]*\)/);
      return match ? `[Function: ${name}]` : `[Function: ${name}]`;
    }

    if (type === 'object') {
      if (seen.has(value)) return '[Circular Reference]';
      seen.add(value);

      try {
        if (Array.isArray(value)) {
          if (value.length === 0) return '[]';
          if (depth >= maxDepth) return `[Array(${value.length})]`;

          const items = value.slice(0, 10).map(item => formatValue(item, depth + 1, maxDepth, seen));
          const result = items.length < value.length
            ? `[ ${items.join(', ')}, ... ${value.length - items.length} more ]`
            : `[ ${items.join(', ')} ]`;
          seen.delete(value);
          return result;
        }

        if (value instanceof Date) {
          seen.delete(value);
          return value.toISOString();
        }

        if (value instanceof Error) {
          seen.delete(value);
          return `${value.name}: ${value.message}${value.stack ? '\n' + value.stack : ''}`;
        }

        if (value instanceof RegExp) {
          seen.delete(value);
          return value.toString();
        }

        // Handle DOM-like objects or objects with custom toString
        if (value.toString && value.toString !== Object.prototype.toString) {
          const str = value.toString();
          if (str !== '[object Object]') {
            seen.delete(value);
            return str;
          }
        }

        // Format plain objects
        if (depth >= maxDepth) {
          seen.delete(value);
          return '[Object]';
        }

        const keys = Object.keys(value);
        if (keys.length === 0) {
          seen.delete(value);
          return '{}';
        }

        const pairs = keys.slice(0, 10).map(key => {
          try {
            return `${key}: ${formatValue(value[key], depth + 1, maxDepth, seen)}`;
          } catch (e) {
            return `${key}: [Error getting value]`;
          }
        });

        const result = keys.length > 10
          ? `{ ${pairs.join(', ')}, ... ${keys.length - 10} more }`
          : `{ ${pairs.join(', ')} }`;

        seen.delete(value);
        return result;
      } catch (e) {
        seen.delete(value);
        return '[Error formatting object]';
      }
    }

    return String(value);
  }

  function formatArguments(args) {
    return args.map(arg => formatValue(arg)).join(' ');
  }

  function getGroupPrefix() {
    return '  '.repeat(consoleState.groupDepth);
  }

  // Enhanced console methods that work with the existing Swift logger
  const originalConsole = globalThis.console;

  // Basic logging methods - these will be overridden by Swift but we provide fallbacks
  ['log', 'error', 'warn', 'info', 'debug', 'trace'].forEach(method => {
    if (!originalConsole[method]) {
      originalConsole[method] = function (...args) {
        // Fallback implementation if Swift doesn't override
        const formatted = formatArguments(args);
        const prefix = getGroupPrefix();
        console._nativeLog?.(method.toUpperCase(), `${prefix}${formatted}`) ||
          console._print?.(`[${method.toUpperCase()}] ${prefix}${formatted}`);
      };
    }
  });

  // Enhanced console methods
  Object.assign(globalThis.console, {
    // Timing methods
    time(label = 'default') {
      consoleState.timers.set(label, Date.now());
    },

    timeEnd(label = 'default') {
      const startTime = consoleState.timers.get(label);
      if (startTime !== undefined) {
        const duration = Date.now() - startTime;
        consoleState.timers.delete(label);
        const message = `${label}: ${duration}ms`;
        const prefix = getGroupPrefix();

        // Use existing log method (which Swift will override)
        console.log(`${prefix}⏱️  ${message}`);
      } else {
        console.warn(`Timer '${label}' does not exist`);
      }
    },

    timeLog(label = 'default', ...args) {
      const startTime = consoleState.timers.get(label);
      if (startTime !== undefined) {
        const duration = Date.now() - startTime;
        const extraArgs = args.length > 0 ? ' ' + formatArguments(args) : '';
        const message = `${label}: ${duration}ms${extraArgs}`;
        const prefix = getGroupPrefix();
        console.log(`${prefix}⏱️  ${message}`);
      } else {
        console.warn(`Timer '${label}' does not exist`);
      }
    },

    // Counting methods
    count(label = 'default') {
      const current = consoleState.counters.get(label) || 0;
      const newCount = current + 1;
      consoleState.counters.set(label, newCount);
      const prefix = getGroupPrefix();
      console.log(`${prefix}🔢 ${label}: ${newCount}`);
    },

    countReset(label = 'default') {
      if (consoleState.counters.has(label)) {
        consoleState.counters.delete(label);
      } else {
        console.warn(`Count for '${label}' does not exist`);
      }
    },

    // Grouping methods
    group(label = '') {
      const prefix = getGroupPrefix();
      if (label) {
        console.log(`${prefix}📁 ${label}`);
      }
      consoleState.groupDepth++;
    },

    groupCollapsed(label = '') {
      // Same as group for text-based console
      this.group(label);
    },

    groupEnd() {
      if (consoleState.groupDepth > 0) {
        consoleState.groupDepth--;
      }
    },

    // Table method (basic implementation)
    table(data, columns) {
      const prefix = getGroupPrefix();

      if (!data || typeof data !== 'object') {
        console.log(`${prefix}${formatValue(data)}`);
        return;
      }

      if (Array.isArray(data)) {
        console.log(`${prefix}📊 Table:`);
        data.forEach((row, index) => {
          if (typeof row === 'object' && row !== null) {
            const rowData = columns ?
              columns.reduce((acc, col) => ({ ...acc, [col]: row[col] }), {}) :
              row;
            console.log(`${prefix}  ${index}: ${formatValue(rowData)}`);
          } else {
            console.log(`${prefix}  ${index}: ${formatValue(row)}`);
          }
        });
      } else {
        console.log(`${prefix}📊 Table:`);
        Object.entries(data).forEach(([key, value]) => {
          console.log(`${prefix}  ${key}: ${formatValue(value)}`);
        });
      }
    },

    // Assertion method
    assert(condition, ...args) {
      if (!condition) {
        const message = args.length > 0 ? formatArguments(args) : 'Assertion failed';
        const prefix = getGroupPrefix();
        console.error(`${prefix}❌ Assertion failed: ${message}`);
      }
    },

    // Clear method (visual separator)
    clear() {
      console.log('\n'.repeat(3) + '🧹 Console cleared' + '\n'.repeat(2));
    },

    // Directory listing (basic object inspection)
    dir(obj) {
      const prefix = getGroupPrefix();
      console.log(`${prefix}📋 ${formatValue(obj, 0, 5)}`);
    },

    dirxml(obj) {
      // Alias for dir in non-DOM environment
      this.dir(obj);
    }
  });

  // Blob - binary data container
  globalThis.Blob = class Blob {
    #size = 0;
    #type = '';
    #parts = [];

    constructor(parts = [], options = {}) {
      this.#parts = Array.isArray(parts) ? parts.slice() : [parts];
      this.#type = String(options.type || '').toLowerCase();
      this.#calculateSize();
      this[Symbol.toStringTag] = 'Blob';
    }

    get size() { return this.#size; }
    get type() { return this.#type; }

    #calculateSize() {
      const encoder = new TextEncoder();
      for (const part of this.#parts) {
        if (typeof part === 'string') {
          this.#size += encoder.encode(part).length;
        } else if (part instanceof ArrayBuffer) {
          this.#size += part.byteLength;
        } else if (ArrayBuffer.isView(part)) {
          this.#size += part.byteLength;
        } else if (part instanceof Blob) {
          this.#size += part.size || 0;
        } else if (part != null) {
          // Fallback to string conversion
          this.#size += encoder.encode(String(part)).length;
        }
      }
    }

    #setSize(size) {
      this.#size = size;
    }

    async #processAsyncParts(parts) {
      const resolved = [];
      for (const part of parts) {
        if (part?.__asyncBlob) {
          const blob = await part[SYMBOLS.blobPlaceholderPromise];
          const buffer = await blob.arrayBuffer();
          resolved.push(new Uint8Array(buffer));
        } else {
          resolved.push(part);
        }
      }
      return resolved;
    }

    async arrayBuffer() {
      let partsToProcess = this.#parts;

      // Handle async placeholders
      if (partsToProcess?.some(p => p?.__asyncBlob)) {
        partsToProcess = await this.#processAsyncParts(partsToProcess);
      }

      const encoder = new TextEncoder();
      const chunks = [];
      let totalSize = 0;

      for (const part of partsToProcess) {
        let chunk;

        if (typeof part === 'string') {
          chunk = encoder.encode(part);
        } else if (part instanceof ArrayBuffer) {
          chunk = new Uint8Array(part);
        } else if (ArrayBuffer.isView(part)) {
          chunk = new Uint8Array(part.buffer, part.byteOffset, part.byteLength);
        } else if (part instanceof Blob) {
          const buffer = await part.arrayBuffer();
          chunk = new Uint8Array(buffer);
        } else if (part != null) {
          chunk = encoder.encode(String(part));
        } else {
          continue;
        }

        chunks.push(chunk);
        totalSize += chunk.byteLength;
      }

      const result = new Uint8Array(totalSize);
      let offset = 0;
      for (const chunk of chunks) {
        result.set(chunk, offset);
        offset += chunk.byteLength;
      }

      // Use helper to combine chunks
      const combined = combineChunksToUint8Array(chunks);
      return combined.buffer;
    }

    async text() {
      const buffer = await this.arrayBuffer();
      return new TextDecoder().decode(new Uint8Array(buffer));
    }

    slice(start = 0, end = undefined, contentType = '') {
      const size = this.size || 0;
      const relativeStart = start < 0 ? Math.max(size + start, 0) : Math.min(start, size);
      const relativeEnd = end === undefined ? size : (end < 0 ? Math.max(size + end, 0) : Math.min(end, size));
      const span = Math.max(relativeEnd - relativeStart, 0);

      if (span === 0) {
        return new Blob([], { type: contentType });
      }

      const slicePromise = this.arrayBuffer().then(buffer => {
        const slicedBuffer = new Uint8Array(buffer, relativeStart, span);
        return new Blob([slicedBuffer], { type: contentType });
      });

      // Return placeholder blob
      const placeholder = new Blob([], { type: contentType });
      placeholder.#parts = [{
        __asyncBlob: true,
        [SYMBOLS.blobPlaceholderPromise]: slicePromise
      }];
      placeholder.#setSize(span);
      return placeholder;
    }

    stream() {
      // Return a ReadableStream that properly streams the blob data
      const blob = this;
      const chunkSize = 64 * 1024; // 64KB chunks

      return new ReadableStream({
        async start(controller) {
          try {
            // Stream each part individually without loading everything into memory
            await streamParts(blob.#parts, controller, chunkSize);
            controller.close();
          } catch (error) {
            controller.error(error);
          }
        }
      });

      // Helper function to stream blob parts
      async function streamParts(parts, controller, chunkSize) {
        const encoder = new TextEncoder();

        for (const part of parts) {
          // Handle async placeholders (from sliced blobs)
          if (part?.__asyncBlob) {
            const resolvedBlob = await part[SYMBOLS.blobPlaceholderPromise];
            await streamParts(resolvedBlob.#parts, controller, chunkSize);
            continue;
          }

          if (typeof part === 'string') {
            // Stream string data in chunks
            const encoded = encoder.encode(part);
            await streamBuffer(encoded, controller, chunkSize);
          } else if (part instanceof ArrayBuffer) {
            await streamBuffer(new Uint8Array(part), controller, chunkSize);
          } else if (ArrayBuffer.isView(part)) {
            await streamBuffer(new Uint8Array(part.buffer, part.byteOffset, part.byteLength), controller, chunkSize);
          } else if (part instanceof Blob) {
            // Recursively stream nested blob without loading into memory
            const nestedStream = part.stream();
            const reader = nestedStream.getReader();
            try {
              while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                controller.enqueue(value);
              }
            } finally {
              reader.releaseLock();
            }
          } else if (part != null) {
            // Fallback to string conversion for unknown types
            const encoded = encoder.encode(String(part));
            await streamBuffer(encoded, controller, chunkSize);
          }
        }
      }

      // Helper function to stream buffer in chunks
      async function streamBuffer(buffer, controller, chunkSize) {
        for (let offset = 0; offset < buffer.length; offset += chunkSize) {
          const chunk = buffer.slice(offset, Math.min(offset + chunkSize, buffer.length));
          controller.enqueue(chunk);
          // Yield control to allow other operations
          await new Promise(resolve => setTimeout(resolve, 0));
        }
      }
    }
  };

  // Reusable helper: create a ReadableStream that streams a file from the native
  // FileSystem using the Swift file handle APIs. This centralizes the
  // createFileHandle/readFileHandleChunk/closeFileHandle pattern used in several
  // places in the polyfill.
  function createFileReadableStream(filePath, chunkSize = 64 * 1024) {
    let handle = null;

    return new ReadableStream({
      start(controller) {
        try {
          handle = __APPLE_SPEC__.FileSystem.createFileHandle(filePath);
          if (!handle) {
            controller.error(new Error(`Failed to open file: ${filePath}`));
            return;
          }

          const readNext = () => {
            try {
              const chunk = __APPLE_SPEC__.FileSystem.readFileHandleChunk(handle, chunkSize);

              // Interpret chunk shape: prefer existing Uint8Array, fall back to typedArrayBytes
              const bytes = chunk instanceof Uint8Array
                ? chunk
                : (chunk && chunk.typedArrayBytes ? new Uint8Array(chunk.typedArrayBytes) : new Uint8Array(chunk));

              if (!bytes || bytes.length === 0) {
                if (handle) {
                  __APPLE_SPEC__.FileSystem.closeFileHandle(handle);
                  handle = null;
                }
                controller.close();
                return;
              }

              controller.enqueue(bytes);
              // Continue asynchronously to avoid blocking
              setTimeout(readNext, 0);
            } catch (err) {
              if (handle) {
                try { __APPLE_SPEC__.FileSystem.closeFileHandle(handle); } catch (e) { }
                handle = null;
              }
              controller.error(err);
            }
          };

          readNext();
        } catch (err) {
          if (handle) {
            try { __APPLE_SPEC__.FileSystem.closeFileHandle(handle); } catch (e) { }
            handle = null;
          }
          controller.error(err);
        }
      },

      cancel() {
        if (handle) {
          try { __APPLE_SPEC__.FileSystem.closeFileHandle(handle); } catch (e) { }
          handle = null;
        }
      }
    });
  }

  // Helper: combine an array of Uint8Array chunks into a single Uint8Array
  function combineChunksToUint8Array(chunks) {
    const totalLength = chunks.reduce((sum, c) => sum + (c ? c.byteLength : 0), 0);
    const combined = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of chunks) {
      if (!chunk) continue;
      combined.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return combined;
  }

  // Helper: consume a ReadableStreamDefaultReader and return an ArrayBuffer
  // options: { onProgress: (loaded)=>void, shouldAbort: ()=>boolean }
  async function readAllArrayBufferFromReader(reader, options = {}) {
    const { onProgress, shouldAbort } = options;
    const chunks = [];
    let totalLength = 0;

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
        chunks.push(bytes);
        totalLength += bytes.byteLength;
        if (onProgress) onProgress(totalLength);
        if (shouldAbort && shouldAbort()) {
          return null;
        }
      }
      const combined = combineChunksToUint8Array(chunks);
      return combined.buffer;
    } finally {
      try { reader.releaseLock(); } catch (e) { }
    }
  }

  // Helper: consume a ReadableStreamDefaultReader and return a decoded string
  // options: { encoding: 'utf-8', onProgress: (loaded)=>void, shouldAbort: ()=>boolean }
  async function readAllTextFromReader(reader, options = {}) {
    const { encoding = 'utf-8', onProgress, shouldAbort } = options;
    const decoder = new TextDecoder(encoding, { stream: true });
    let result = '';

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
        result += decoder.decode(bytes, { stream: true });
        if (onProgress) onProgress(bytes.byteLength);
        if (shouldAbort && shouldAbort()) {
          return null;
        }
      }
      result += decoder.decode();
      return result;
    } finally {
      try { reader.releaseLock(); } catch (e) { }
    }
  }

  // File - extends Blob with file metadata
  globalThis.File = class File extends Blob {
    #name;
    #lastModified;
    #filePath; // For files created from FileSystemFileHandle

    constructor(parts, name, options = {}) {
      if (arguments.length < 2) {
        throw new TypeError(`Failed to construct 'File': 2 arguments required, but only ${arguments.length} present.`);
      }
      if (typeof name !== 'string') {
        throw new TypeError("Failed to construct 'File': parameter 2 is not of type 'string'.");
      }

      super(parts, options);
      this.#name = String(name || '');
      this.#lastModified = options.lastModified || Date.now();
      this.#filePath = options[SYMBOLS.filePath] || null; // Internal option for file system files
      this[Symbol.toStringTag] = 'File';
    }

    get name() { return this.#name; }
    get lastModified() { return this.#lastModified; }

    stream() {
      // If this File was created from a file system path, stream directly from disk using Swift
      const filePath = this.#filePath;
      if (filePath && __APPLE_SPEC__.FileSystem.exists(filePath) && __APPLE_SPEC__.FileSystem.isFile(filePath)) {
        return createFileReadableStream(filePath);
      }

      // For in-memory File objects, use the parent Blob stream() method
      return super.stream();
    }

    async text() {
      // If this File was created from a file system path, read directly from disk
      const filePath = this.#filePath;
      if (filePath && __APPLE_SPEC__.FileSystem.exists(filePath) && __APPLE_SPEC__.FileSystem.isFile(filePath)) {
        const content = __APPLE_SPEC__.FileSystem.readFile(filePath);
        if (content === null) {
          throw new Error(`Failed to read file: ${filePath}`);
        }
        return content;
      }

      // For in-memory File objects, use the parent Blob text() method
      return super.text();
    }

    async arrayBuffer() {
      // If this File was created from a file system path, read directly from disk
      const filePath = this.#filePath;
      if (filePath && __APPLE_SPEC__.FileSystem.exists(filePath) && __APPLE_SPEC__.FileSystem.isFile(filePath)) {
        const data = __APPLE_SPEC__.FileSystem.readFileData(filePath);
        if (!data) {
          throw new Error(`Failed to read file: ${filePath}`);
        }
        return data.buffer;
      }

      // For in-memory File objects, use the parent Blob arrayBuffer() method
      return super.arrayBuffer();
    }

    // Static method to create File from file system path
    static fromPath(path) {
      if (!__APPLE_SPEC__.FileSystem.exists(path) || !__APPLE_SPEC__.FileSystem.isFile(path)) {
        throw new Error(`File not found: ${path}`);
      }

      const stats = __APPLE_SPEC__.FileSystem.stat(path);

      // Extract filename and extension using JavaScript
      const name = path.split('/').pop() || '';
      const ext = name.includes('.') ? '.' + name.split('.').pop() : '';

      // Helper function for MIME types
      function getMimeType(ext) {
        const mimes = {
          '.txt': 'text/plain',
          '.html': 'text/html',
          '.json': 'application/json',
          '.js': 'application/javascript',
          '.css': 'text/css',
          '.png': 'image/png',
          '.jpg': 'image/jpeg',
          '.jpeg': 'image/jpeg',
          '.gif': 'image/gif',
          '.pdf': 'application/pdf'
        };
        return mimes[ext.toLowerCase()] || 'application/octet-stream';
      }

      // Create File object that references the path for efficient operations
      const file = new File([], name, {
        type: getMimeType(ext),
        lastModified: stats.mtime || Date.now(),
        [SYMBOLS.filePath]: path
      });

      // Override the size property to reflect the actual file size
      Object.defineProperty(file, 'size', {
        value: stats.size || 0,
        writable: false,
        enumerable: true,
        configurable: false
      });

      return file;
    }
  };

  // FileReader - asynchronous file reading with events
  globalThis.FileReader = class FileReader extends EventTarget {
    static EMPTY = 0;
    static LOADING = 1;
    static DONE = 2;

    #readyState = FileReader.EMPTY;
    #result = null;
    #error = null;

    constructor() {
      super();
      this.EMPTY = FileReader.EMPTY;
      this.LOADING = FileReader.LOADING;
      this.DONE = FileReader.DONE;

      // Event handler properties
      this.onloadstart = null;
      this.onprogress = null;
      this.onload = null;
      this.onabort = null;
      this.onerror = null;
      this.onloadend = null;
    }

    get readyState() { return this.#readyState; }
    get result() { return this.#result; }
    get error() { return this.#error; }

    #setReadyState(state) {
      this.#readyState = state;
    }

    #fireEvent(type, data = {}) {
      const event = new Event(type);
      Object.assign(event, data);

      this.dispatchEvent(event);

      // Also call the onX handler if it exists
      const handler = this['on' + type];
      if (typeof handler === 'function') {
        // Ensure target is set correctly for onX handlers
        if (!event.target) {
          event.target = this;
        }
        handler.call(this, event);
      }
    }

    abort() {
      if (this.#readyState === FileReader.LOADING) {
        this.#setReadyState(FileReader.DONE);
        this.#result = null;
        this.#fireEvent('abort');
        this.#fireEvent('loadend');
      }
    }

    readAsArrayBuffer(blob) {
      if (this.#readyState === FileReader.LOADING) {
        throw new Error('InvalidStateError: FileReader is already reading');
      }
      this.#startReading(blob, 'arraybuffer');
    }

    readAsBinaryString(blob) {
      if (this.#readyState === FileReader.LOADING) {
        throw new Error('InvalidStateError: FileReader is already reading');
      }
      this.#startReading(blob, 'binarystring');
    }

    readAsDataURL(blob) {
      if (this.#readyState === FileReader.LOADING) {
        throw new Error('InvalidStateError: FileReader is already reading');
      }
      this.#startReading(blob, 'dataurl');
    }

    readAsText(blob, encoding = 'utf-8') {
      if (this.#readyState === FileReader.LOADING) {
        throw new Error('InvalidStateError: FileReader is already reading');
      }
      this.#startReading(blob, 'text', encoding);
    }

    // Enhanced method to read files directly from filesystem paths
    readAsArrayBufferFromPath(filePath) {
      const file = File.fromPath(filePath);
      this.readAsArrayBuffer(file);
    }

    readAsTextFromPath(filePath, encoding = 'utf-8') {
      const file = File.fromPath(filePath);
      this.readAsText(file);
    }

    readAsDataURLFromPath(filePath) {
      const file = File.fromPath(filePath);
      this.readAsDataURL(file);
    }

    async #startReading(blobOrFile, format, encoding = 'utf-8') {
      // State should already be checked by the caller, but double-check
      if (this.#readyState === FileReader.LOADING) {
        throw new Error('InvalidStateError: FileReader is already reading');
      }

      // Capture 'this' reference to preserve context across async boundaries
      const self = this;

      self.#setReadyState(FileReader.LOADING);
      self.#result = null;
      self.#error = null;

      // Fire loadstart event
      self.#fireEvent('loadstart');

      try {
        let blob = blobOrFile;
        let useStreaming = blob.size > 1024 * 1024; // Use streaming for files > 1MB

        const total = blob.size || 0;
        let loaded = 0;

        // Fire initial progress event
        self.#fireEvent('progress', { loaded: 0, total, lengthComputable: total > 0 });

        let result;

        if (useStreaming && (format === 'arraybuffer' || format === 'text')) {
          // Use proper streaming that processes chunks as they arrive
          result = await self.#streamingRead(blob, format, encoding, (progressLoaded) => {
            loaded = progressLoaded;
            self.#fireEvent('progress', { loaded, total, lengthComputable: true });
          });
        } else {
          // Standard reading for smaller files
          switch (format) {
            case 'arraybuffer':
              result = await blob.arrayBuffer();
              break;

            case 'text':
              result = await blob.text();
              break;

            case 'dataurl':
              const buffer = await blob.arrayBuffer();
              const bytes = new Uint8Array(buffer);
              const base64 = btoa(String.fromCharCode(...bytes));
              result = `data:${blob.type || 'application/octet-stream'};base64,${base64}`;
              break;

            case 'binarystring':
              const binaryBuffer = await blob.arrayBuffer();
              const binaryBytes = new Uint8Array(binaryBuffer);
              result = String.fromCharCode(...binaryBytes);
              break;

            default:
              throw new Error(`Unknown format: ${format}`);
          }
        }

        // Check if reading was aborted
        if (self.#readyState !== FileReader.LOADING) {
          return; // Aborted
        }

        self.#result = result;
        self.#setReadyState(FileReader.DONE);

        // Fire final progress event
        self.#fireEvent('progress', { loaded: total, total, lengthComputable: true });

        // Fire load event
        self.#fireEvent('load');

        // Fire loadend event
        self.#fireEvent('loadend');

      } catch (error) {
        // Check if reading was aborted
        if (self.#readyState !== FileReader.LOADING) {
          return; // Aborted
        }

        self.#error = error;
        self.#setReadyState(FileReader.DONE);

        // Fire error event
        self.#fireEvent('error');

        // Fire loadend event
        self.#fireEvent('loadend');
      }
    }

    async #streamingRead(blob, format, encoding, onProgress) {
      // Check if this is a file with path-based streaming
      if (blob[SYMBOLS.filePath] && blob.size > 0) {
        return this.#streamFromFilePath(blob[SYMBOLS.filePath], format, encoding, onProgress);
      }

      // Standard streaming for in-memory blobs
      const stream = blob.stream();
      const reader = stream.getReader();
      try {
        if (format === 'arraybuffer') {
          const buffer = await readAllArrayBufferFromReader(reader, {
            onProgress: (loaded) => { if (onProgress) onProgress(loaded); },
            shouldAbort: () => this.#readyState !== FileReader.LOADING
          });
          return buffer;
        } else if (format === 'text') {
          const text = await readAllTextFromReader(reader, {
            encoding,
            onProgress: (loaded) => { if (onProgress) onProgress(loaded); },
            shouldAbort: () => this.#readyState !== FileReader.LOADING
          });
          return text;
        }

        throw new Error(`Streaming not supported for format: ${format}`);
      } finally {
        try { reader.releaseLock(); } catch (e) { }
      }
    }

    async #streamFromFilePath(filePath, format, encoding, onProgress) {
      try {
        // Create a file-backed readable stream and consume it according to format
        const stream = createFileReadableStream(filePath);
        const reader = stream.getReader();
        let totalLoaded = 0;

        try {
          if (format === 'arraybuffer') {
            const buffer = await readAllArrayBufferFromReader(reader, {
              onProgress: (loaded) => { if (onProgress) onProgress(loaded); },
              shouldAbort: () => this.#readyState !== FileReader.LOADING
            });
            return buffer;
          } else if (format === 'text') {
            const text = await readAllTextFromReader(reader, {
              encoding,
              onProgress: (loaded) => { if (onProgress) onProgress(loaded); },
              shouldAbort: () => this.#readyState !== FileReader.LOADING
            });
            return text;
          }

          throw new Error(`Path streaming not supported for format: ${format}`);
        } finally {
          try { reader.releaseLock(); } catch (e) { }
        }

      } catch (error) {
        throw error;
      }
    }
  };

  // XMLHttpRequest - HTTP request implementation
  globalThis.XMLHttpRequest = class XMLHttpRequest extends EventTarget {
    // State constants
    static UNSENT = 0;
    static OPENED = 1;
    static HEADERS_RECEIVED = 2;
    static LOADING = 3;
    static DONE = 4;

    // Private fields
    #method = null;
    #url = null;
    #async = true;
    #request = null;
    #requestHeaders = {};
    #response = null;
    #aborted = false;
    #status = 0;
    #statusText = '';
    #responseURL = '';
    #readyState = XMLHttpRequest.UNSENT;
    #responseData = null;
    #responseText = '';
    #upload = new EventTarget();

    constructor() {
      super();
      // Copy static constants to instance for compatibility
      this.UNSENT = XMLHttpRequest.UNSENT;
      this.OPENED = XMLHttpRequest.OPENED;
      this.HEADERS_RECEIVED = XMLHttpRequest.HEADERS_RECEIVED;
      this.LOADING = XMLHttpRequest.LOADING;
      this.DONE = XMLHttpRequest.DONE;

      // Public properties
      this.responseType = '';
      this.timeout = 0;
      // Event handlers
      this.onreadystatechange = null;
      this.onabort = null;
      this.onerror = null;
      this.onload = null;
      this.onloadend = null;
      this.onloadstart = null;
      this.onprogress = null;
      this.ontimeout = null;
    }

    // Getters
    get status() { return this.#status; }
    get statusText() { return this.#statusText; }
    get responseURL() { return this.#responseURL; }
    get readyState() { return this.#readyState; }
    get response() { return this.#responseData; }
    get responseText() { return this.#responseText; }
    get upload() { return this.#upload; }

    open(method, url, async = true, user = null, password = null) {
      this.#method = method.toUpperCase();
      this.#url = url;
      this.#async = async;
      this.#request = new __APPLE_SPEC__.URLRequest(url);
      this.#request.httpMethod = this.#method;
      this.#setReadyState(XMLHttpRequest.OPENED);
    }

    setRequestHeader(name, value) {
      if (this.readyState !== XMLHttpRequest.OPENED) {
        throw new Error('InvalidStateError: The object is in an invalid state.');
      }
      this.#requestHeaders[name] = value;
      this.#request.setValueForHTTPHeaderField(value, name);
    }

    send(body = null) {
      if (this.readyState !== XMLHttpRequest.OPENED) {
        throw new Error('InvalidStateError: The object is in an invalid state.');
      }

      this.#setRequestBody(body);
      this.#setReadyState(XMLHttpRequest.LOADING);
      this.#dispatchEvent('loadstart');

      const session = __APPLE_SPEC__.URLSession.shared();

      // Set timeout on the URLRequest if specified
      if (this.timeout > 0) {
        this.#request.timeoutInterval = this.timeout / 1000; // Convert ms to seconds
      }

      // Implement progressive loading with onprogress events
      let accumulatedData = new Uint8Array(0);
      let timeoutId = null;

      // Set up timeout if specified
      if (this.timeout > 0) {
        timeoutId = setTimeout(() => {
          if (!this.#aborted && this.readyState !== XMLHttpRequest.DONE) {
            this.#aborted = true;
            this.#setReadyState(XMLHttpRequest.DONE);
            this.#dispatchEvent('timeout');
            this.#dispatchEvent('loadend');
          }
        }, this.timeout);
      }

      const progressHandler = (chunk, error) => {
        if (this.#aborted) return;

        if (error) {
          // Clear timeout on error
          if (timeoutId) {
            clearTimeout(timeoutId);
            timeoutId = null;
          }
          this.#handleError(error);
        } else if (chunk.length > 0) {
          // Accumulate chunks for partial response access
          const newData = new Uint8Array(accumulatedData.length + chunk.length);
          newData.set(accumulatedData);
          newData.set(chunk, accumulatedData.length);
          accumulatedData = newData;

          // Update partial response text for readyState = 3 (LOADING)
          if (this.responseType === '' || this.responseType === 'text') {
            this.#responseText = new TextDecoder().decode(accumulatedData);
            this.#responseData = this.#responseText;
          }

          // Fire progress event
          const progressEvent = new Event('progress');
          progressEvent.loaded = accumulatedData.length;
          progressEvent.lengthComputable = false; // We don't know total yet
          this.dispatchEvent(progressEvent);
          if (this.onprogress) {
            this.onprogress.call(this, progressEvent);
          }
        } else {
          // Clear timeout on completion
          if (timeoutId) {
            clearTimeout(timeoutId);
            timeoutId = null;
          }
          // Final response data is already accumulated
          this.#finalizeResponse(accumulatedData);
        }
      };

      const promise = session.httpRequestWithRequest(
        this.#request,
        null,              // bodyStream 
        progressHandler   // progressHandler for streaming updates
      );

      promise
        .then(result => {
          if (!this.#aborted) {
            // Clear timeout on success
            if (timeoutId) {
              clearTimeout(timeoutId);
              timeoutId = null;
            }

            // Set response headers when we get the result
            // XMLHttpRequest uses progressHandler, so result is the JSURLResponse directly
            this.#response = result;
            this.#status = result.statusCode;
            this.#statusText = this.#getStatusText(this.#status);
            this.#responseURL = result.url || this.#url;
            if (this.readyState < XMLHttpRequest.HEADERS_RECEIVED) {
              this.#setReadyState(XMLHttpRequest.HEADERS_RECEIVED);
            }

            // Don't call #handleResponse since we're using progress handler
            // The progress handler will call #finalizeResponse when complete
          }
        })
        .catch(error => {
          // Clear timeout on error
          if (timeoutId) {
            clearTimeout(timeoutId);
            timeoutId = null;
          }
          this.#handleError(error);
        });
    }

    #setRequestBody(body) {
      if (!body) return;

      // Fire upload events for non-empty bodies
      let hasUploadBody = false;

      if (body instanceof FormData) {
        const multipart = body[SYMBOLS.formDataToMultipart]();
        this.#request.httpBody = multipart.body;
        if (!this.#requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', `multipart/form-data; boundary=${multipart.boundary}`);
        }
        hasUploadBody = true;
      } else if (typeof body === 'string') {
        this.#request.httpBody = body;
        if (!this.#requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', 'text/plain;charset=UTF-8');
        }
        hasUploadBody = body.length > 0;
      } else if (body instanceof ArrayBuffer || ArrayBuffer.isView(body)) {
        this.#request.httpBody = new Uint8Array(body);
        if (!this.#requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', 'application/octet-stream');
        }
        hasUploadBody = true;
      }

      // Fire upload events if we have a body to upload
      if (hasUploadBody) {
        // Fire upload start
        const uploadStartEvent = new Event('loadstart');
        this.#upload.dispatchEvent(uploadStartEvent);

        // Simulate upload progress (since we don't have real upload progress from Swift yet)
        setTimeout(() => {
          const uploadProgressEvent = new Event('progress');
          uploadProgressEvent.loaded = this.#request.httpBody ? this.#request.httpBody.length : 0;
          uploadProgressEvent.total = uploadProgressEvent.loaded;
          uploadProgressEvent.lengthComputable = true;
          this.#upload.dispatchEvent(uploadProgressEvent);

          const uploadLoadEvent = new Event('load');
          this.#upload.dispatchEvent(uploadLoadEvent);

          const uploadLoadEndEvent = new Event('loadend');
          this.#upload.dispatchEvent(uploadLoadEndEvent);
        }, 0);
      }
    }

    #finalizeResponse(accumulatedData) {
      if (this.#aborted) return;

      // Set final response data based on responseType
      this.#setResponseData(accumulatedData);
      this.#setReadyState(XMLHttpRequest.DONE);
      this.#dispatchEvent('load');
      this.#dispatchEvent('loadend');
    }

    #handleError(error) {
      if (this.#aborted) return;

      this.#setReadyState(XMLHttpRequest.DONE);
      this.#dispatchEvent('error');
      this.#dispatchEvent('loadend');
    }

    #setResponseData(data) {
      switch (this.responseType) {
        case '':
        case 'text':
          this.#responseText = new TextDecoder().decode(data);
          this.#responseData = this.#responseText;
          break;
        case 'arraybuffer':
          this.#responseData = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
          this.#responseText = '';
          break;
        case 'blob':
          this.#responseData = new Blob([data]);
          this.#responseText = '';
          break;
        case 'json':
          try {
            const text = new TextDecoder().decode(data);
            this.#responseData = JSON.parse(text);
          } catch (e) {
            this.#responseData = null;
          }
          this.#responseText = '';
          break;
      }
    }

    abort() {
      this.#aborted = true;
      if (this.readyState !== XMLHttpRequest.DONE) {
        this.#setReadyState(XMLHttpRequest.DONE);
        this.#dispatchEvent('abort');
        this.#dispatchEvent('loadend');
      }
      // Note: We can't easily cancel the ongoing Swift request, but we mark it as aborted
    }

    getResponseHeader(name) {
      if (this.readyState < XMLHttpRequest.HEADERS_RECEIVED || !this.#response) {
        return null;
      }
      return this.#response.valueForHTTPHeaderField(name) || null;
    }

    getAllResponseHeaders() {
      if (this.readyState < XMLHttpRequest.HEADERS_RECEIVED || !this.#response) {
        return '';
      }
      const headers = this.#response.allHeaderFields;
      return Object.keys(headers)
        .map(key => `${key}: ${headers[key]}`)
        .join('\r\n') + '\r\n';
    }

    #setReadyState(state) {
      this.#readyState = state;
      this.#dispatchEvent('readystatechange');
    }

    #dispatchEvent(type) {
      const event = new Event(type);
      this.dispatchEvent(event);

      const handler = this['on' + type];
      if (typeof handler === 'function') {
        handler.call(this, event);
      }
    }

    #getStatusText(status) {
      return getStatusText(status);
    }
  };

  // Headers - HTTP headers implementation
  globalThis.Headers = class Headers {
    #headers = new Map();

    constructor(init) {
      if (init) {
        this.#initializeHeaders(init);
      }
    }

    // Validate header name according to HTTP specification
    #validateHeaderName(name) {
      if (typeof name !== 'string' || name === '') {
        throw new TypeError('Invalid header name: must be a non-empty string');
      }

      // Check for invalid characters according to RFC 7230
      // Header names must be tokens: 1*( ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" )
      if (/[^\x21\x23-\x27\x2A\x2B\x2D\x2E\x30-\x39\x41-\x5A\x5E-\x7A\x7C\x7E]/.test(name)) {
        throw new TypeError('Invalid header name: contains invalid characters');
      }
    }

    // Validate header value according to HTTP specification  
    #validateHeaderValue(value) {
      const valueStr = String(value);
      // Header values cannot contain control characters except tabs
      if (/[\x00-\x08\x0A-\x1F\x7F]/.test(valueStr)) {
        throw new TypeError('Invalid header value: contains invalid characters');
      }
    }

    #initializeHeaders(init) {
      if (init instanceof Headers) {
        for (const [key, value] of init.#headers) {
          this.#headers.set(key.toLowerCase(), value);
        }
      } else if (Array.isArray(init)) {
        for (const [key, value] of init) {
          this.#validateHeaderName(key);
          this.#validateHeaderValue(value);
          this.#headers.set(key.toLowerCase(), String(value));
        }
      } else if (typeof init === 'object') {
        for (const [key, value] of Object.entries(init)) {
          this.#validateHeaderName(key);
          this.#validateHeaderValue(value);
          this.#headers.set(key.toLowerCase(), String(value));
        }
      }
    }

    append(name, value) {
      this.#validateHeaderName(name);
      this.#validateHeaderValue(value);
      const normalizedName = name.toLowerCase();
      const existing = this.#headers.get(normalizedName);
      const newValue = existing ? `${existing}, ${value}` : String(value);
      this.#headers.set(normalizedName, newValue);
    }

    delete(name) {
      this.#validateHeaderName(name);
      this.#headers.delete(name.toLowerCase());
    }

    get(name) {
      this.#validateHeaderName(name);
      return this.#headers.get(name.toLowerCase()) || null;
    }

    has(name) {
      this.#validateHeaderName(name);
      return this.#headers.has(name.toLowerCase());
    }

    set(name, value) {
      this.#validateHeaderName(name);
      this.#validateHeaderValue(value);
      this.#headers.set(name.toLowerCase(), String(value));
    }

    entries() {
      return this.#headers.entries();
    }

    keys() {
      return this.#headers.keys();
    }

    values() {
      return this.#headers.values();
    }

    forEach(callback, thisArg) {
      for (const [key, value] of this.#headers) {
        callback.call(thisArg, value, key, this);
      }
    }

    [Symbol.iterator]() {
      return this.#headers[Symbol.iterator]();
    }
  };

  // Request - HTTP request representation
  globalThis.Request = class Request {
    #url;
    #method;
    #headers;
    #body;
    #signal;
    #redirect;
    #bodyUsed = false;

    constructor(input, init = {}) {
      // Validate required URL argument
      if (arguments.length === 0) {
        throw new TypeError("Failed to construct 'Request': 1 argument required, but only 0 present.");
      }

      if (input instanceof Request) {
        this.#copyFromRequest(input);
      } else {
        this.#initializeFromUrl(String(input), init);
      }
    }

    #copyFromRequest(request) {
      this.#url = request.url;
      this.#method = request.method;
      this.#headers = new Headers(request.headers);
      this.#body = request.body;
      this.#signal = request.signal;
      this.#redirect = request.redirect;
      this[SYMBOLS.requestOriginalBody] = request[SYMBOLS.requestOriginalBody]; // Copy the original body
    }

    #initializeFromUrl(url, init) {
      this.#url = url;

      // Validate method
      const method = (init.method || 'GET').toUpperCase();

      // Check for forbidden methods (case-insensitive)
      const forbiddenMethods = ['CONNECT', 'TRACE', 'TRACK'];
      if (forbiddenMethods.includes(method)) {
        throw new TypeError(`'${init.method}' HTTP method is forbidden.`);
      }

      // Validate that method is a valid HTTP token
      // HTTP token chars: A-Z, a-z, 0-9, !, #, $, %, &, ', *, +, -, ., ^, _, `, |, ~
      if (!/^[A-Za-z0-9!#$%&'*+\-.^_`|~]+$/.test(method)) {
        throw new TypeError(`'${init.method}' is not a valid HTTP method.`);
      }

      // Validate that GET/HEAD requests don't have body
      if ((method === 'GET' || method === 'HEAD') && init.body) {
        throw new TypeError(`Request with GET/HEAD method cannot have body.`);
      }

      this.#method = method;
      this.#headers = new Headers(init.headers);
      this.#body = init.body || null;
      this[SYMBOLS.requestOriginalBody] = init.body || null; // Store original body
      this.#signal = init.signal || null;
      this.#redirect = init.redirect || 'follow';

      // Validate redirect option
      if (!['follow', 'error', 'manual'].includes(this.#redirect)) {
        throw new TypeError(`Invalid redirect option: ${this.#redirect}`);
      }
    }

    // Getters
    get url() { return this.#url; }
    get method() { return this.#method; }
    get headers() { return this.#headers; }
    get body() { return this.#body; }
    get signal() { return this.#signal; }
    get redirect() { return this.#redirect; }
    get bodyUsed() { return this.#bodyUsed; }

    #setBodyUsed() {
      this.#bodyUsed = true;
    }

    clone() {
      if (this.bodyUsed) {
        throw new TypeError('Cannot clone a Request whose body has already been read');
      }
      return new Request(this);
    }

    async arrayBuffer() {
      if (this.bodyUsed) {
        throw new TypeError('Body has already been read');
      }
      this.#setBodyUsed();

      if (!this.body) return new ArrayBuffer(0);
      if (this.body instanceof ArrayBuffer) return this.body;
      if (this.body instanceof Blob) {
        return await this.body.arrayBuffer();
      }
      if (this.body instanceof FormData) {
        const multipart = this.body[SYMBOLS.formDataToMultipart]();
        return new TextEncoder().encode(multipart.body).buffer;
      }
      if (this.body instanceof URLSearchParams) {
        return new TextEncoder().encode(this.body.toString()).buffer;
      }
      if (typeof this.body === 'string') {
        return new TextEncoder().encode(this.body).buffer;
      }
      if (ArrayBuffer.isView(this.body)) {
        return this.body.buffer.slice(this.body.byteOffset, this.body.byteOffset + this.body.byteLength);
      }
      throw new TypeError('Unsupported body type');
    }

    async blob() {
      const buffer = await this.arrayBuffer();
      return new Blob([buffer]);
    }

    async json() {
      const text = await this.text();
      return JSON.parse(text);
    }

    async text() {
      if (this.bodyUsed) {
        throw new TypeError('Body has already been read');
      }
      this.#setBodyUsed();

      if (!this.body) return '';
      if (typeof this.body === 'string') return this.body;
      if (this.body instanceof URLSearchParams) {
        return this.body.toString();
      }
      if (this.body instanceof Blob) {
        return await this.body.text();
      }
      if (this.body instanceof FormData) {
        const multipart = this.body[SYMBOLS.formDataToMultipart]();
        return multipart.body;
      }

      const buffer = await this.arrayBuffer();
      return new TextDecoder().decode(buffer);
    }
  };

  // Response implementation
  globalThis.Response = class Response {
    #bodyStream;
    #originalBody;
    #status;
    #statusText;
    #headers;
    #url;
    #redirected;
    #type;
    #ok;
    #bodyUsed;

    constructor(body, init = {}) {
      // Validate status code
      const status = init.status !== undefined ? init.status : 200;
      if (!Number.isInteger(status) || status < 100 || status > 599) {
        throw new RangeError(`Invalid status code: ${status}`);
      }

      this.#originalBody = body || null;
      this.#status = status;
      this.#statusText = init.statusText !== undefined ? init.statusText : getStatusText(this.#status);
      this.#headers = new Headers(init.headers);
      this.#url = init.url || '';
      this.#redirected = init.redirected || false;
      this.#type = init.type || 'default';
      this.#ok = this.#status >= 200 && this.#status < 300;
      this.#bodyUsed = false;
      this.#bodyStream = this.#createBodyStream(body);
    }

    get body() {
      return this.#bodyStream;
    }

    #createBodyStream(body) {
      if (!body) {
        return null;
      }

      // If body is already a ReadableStream, return it
      if (body instanceof ReadableStream) {
        return body;
      }

      // Create a ReadableStream from the body data
      return new ReadableStream({
        async start(controller) {
          try {
            if (typeof body === 'string') {
              const encoder = new TextEncoder();
              const bytes = encoder.encode(body);
              controller.enqueue(bytes);
            } else if (body instanceof Blob) {
              // Use proper streaming from blob without loading everything into memory
              const blobStream = body.stream();
              const reader = blobStream.getReader();
              try {
                while (true) {
                  const { done, value } = await reader.read();
                  if (done) break;
                  controller.enqueue(value);
                }
              } finally {
                reader.releaseLock();
              }
            } else if (body instanceof URLSearchParams) {
              const encoder = new TextEncoder();
              const bytes = encoder.encode(body.toString());
              controller.enqueue(bytes);
            } else if (body instanceof Uint8Array) {
              controller.enqueue(body);
            } else if (body instanceof ArrayBuffer) {
              controller.enqueue(new Uint8Array(body));
            } else if (ArrayBuffer.isView(body)) {
              controller.enqueue(new Uint8Array(body.buffer, body.byteOffset, body.byteLength));
            } else if (body instanceof FormData) {
              const multipart = body[SYMBOLS.formDataToMultipart]();
              const encoder = new TextEncoder();
              const bytes = encoder.encode(multipart.body);
              controller.enqueue(bytes);
            } else {
              // Convert to string and encode
              const encoder = new TextEncoder();
              const bytes = encoder.encode(String(body));
              controller.enqueue(bytes);
            }
            controller.close();
          } catch (error) {
            controller.error(error);
          }
        }
      });
    }

    get status() {
      return this.#status;
    }

    get statusText() {
      return this.#statusText;
    }

    get headers() {
      return this.#headers;
    }

    get url() {
      return this.#url;
    }

    get redirected() {
      return this.#redirected;
    }

    get type() {
      return this.#type;
    }

    get ok() {
      return this.#ok;
    }

    get bodyUsed() {
      return this.#bodyUsed;
    }

    // Internal method to set bodyUsed (used by body reading methods)
    #setBodyUsed() {
      this.#bodyUsed = true;
    }

    // Internal method to set type (used by static methods)
    #setType(type) {
      this.#type = type;
    }

    static error() {
      const response = new Response(null, { status: 0, statusText: '' });
      response.#setType('error');
      return response;
    }

    static redirect(url, status = 302) {
      const response = new Response(null, { status, headers: { Location: url } });
      response.#setType('opaqueredirect');
      return response;
    }

    clone() {
      if (this.bodyUsed) {
        throw new TypeError('Cannot clone a Response whose body has already been read');
      }

      // For responses with streams, we need to tee the stream
      let clonedBody = this.#originalBody;
      let clonedStream = null;

      if (this.#bodyStream && !this.#originalBody) {
        // If we only have a stream, we need to tee it
        const [stream1, stream2] = this.#bodyStream.tee ? this.#bodyStream.tee() : [this.#bodyStream, this.#bodyStream];
        this.#bodyStream = stream1;
        clonedStream = stream2;
      }

      const cloned = new Response(clonedBody, {
        status: this.status,
        statusText: this.statusText,
        headers: this.headers,
        url: this.url,
        redirected: this.redirected,
        type: this.type
      });

      // If we teed a stream, set it directly
      if (clonedStream) {
        cloned.#bodyStream = clonedStream;
      }

      return cloned;
    }

    async arrayBuffer() {
      if (this.bodyUsed) {
        throw new TypeError('Body has already been read');
      }
      this.#setBodyUsed();

      if (!this.#bodyStream) {
        return new ArrayBuffer(0);
      }

      // If we have original body data, use it directly for better performance
      if (this.#originalBody instanceof ArrayBuffer) {
        return this.#originalBody;
      } else if (this.#originalBody instanceof Uint8Array) {
        return this.#originalBody.buffer.slice(this.#originalBody.byteOffset, this.#originalBody.byteOffset + this.#originalBody.byteLength);
      } else if (this.#originalBody && typeof this.#originalBody === 'string') {
        return new TextEncoder().encode(this.#originalBody).buffer;
      } else if (this.#originalBody instanceof FormData) {
        const multipart = this.#originalBody[SYMBOLS.formDataToMultipart]();
        return new TextEncoder().encode(multipart.body).buffer;
      }

      // Read from stream using helper
      const reader = this.#bodyStream.getReader();
      const buffer = await readAllArrayBufferFromReader(reader, { onProgress: null });
      return buffer || new ArrayBuffer(0);
    }

    async blob() {
      const buffer = await this.arrayBuffer();
      return new Blob([buffer]);
    }

    async json() {
      const text = await this.text();
      return JSON.parse(text);
    }

    async text() {
      if (this.bodyUsed) {
        throw new TypeError('Body has already been read');
      }
      this.#setBodyUsed();

      if (!this.#bodyStream) {
        return '';
      }

      // If we have original string data, use it directly
      if (typeof this.#originalBody === 'string') {
        return this.#originalBody;
      } else if (this.#originalBody instanceof FormData) {
        const multipart = this.#originalBody[SYMBOLS.formDataToMultipart]();
        return multipart.body;
      }

      // Read from stream using helper for text decoding
      const reader = this.#bodyStream.getReader();
      const text = await readAllTextFromReader(reader, { encoding: 'utf-8' });
      return text || '';
    }
  };

  // Helper function to get status text from status code
  function getStatusText(status) {
    const statusTexts = {
      100: 'Continue',
      101: 'Switching Protocols',
      200: 'OK',
      201: 'Created',
      202: 'Accepted',
      204: 'No Content',
      301: 'Moved Permanently',
      302: 'Found',
      304: 'Not Modified',
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      405: 'Method Not Allowed',
      500: 'Internal Server Error',
      502: 'Bad Gateway',
      503: 'Service Unavailable'
    };
    return statusTexts[status] || '';
  }

  // fetch - HTTP request function
  globalThis.fetch = async function fetch(input, init = {}) {
    const request = new Request(input, init);

    // Check if the request is already aborted
    if (request.signal && request.signal.aborted) {
      const abortError = new Error('The operation was aborted');
      abortError.name = 'AbortError';
      throw abortError;
    }

    const urlRequest = new __APPLE_SPEC__.URLRequest(request.url);
    urlRequest.httpMethod = request.method;

    // Set timeout based on AbortSignal.timeout() or default
    if (request.signal && request.signal[SYMBOLS.abortSignalTimeoutMs]) {
      // Use timeout from AbortSignal.timeout()
      urlRequest.timeoutInterval = request.signal[SYMBOLS.abortSignalTimeoutMs] / 1000;
    } else {
      // Set default timeout (30 seconds)
      urlRequest.timeoutInterval = 30.0;
    }

    // Set headers
    for (const [key, value] of request.headers) {
      urlRequest.setValueForHTTPHeaderField(value, key);
    }

    // Set body and determine if we need streaming
    let bodyStream = null;

    if (request.body) {
      if (request.body instanceof ReadableStream) {
        // Pass the stream directly to SwiftNIO for true streaming
        bodyStream = request.body;
      } else if (request.body instanceof FormData) {
        const multipart = request.body[SYMBOLS.formDataToMultipart]();
        urlRequest.httpBody = multipart.body;
        urlRequest.setValueForHTTPHeaderField(
          `multipart/form-data; boundary=${multipart.boundary}`,
          'Content-Type'
        );
      } else if (request[SYMBOLS.requestOriginalBody] instanceof URLSearchParams) {
        urlRequest.httpBody = request[SYMBOLS.requestOriginalBody].toString();
        if (!request.headers.has('Content-Type')) {
          urlRequest.setValueForHTTPHeaderField(
            'application/x-www-form-urlencoded',
            'Content-Type'
          );
        }
      } else if (request.body instanceof URLSearchParams) {
        urlRequest.httpBody = request.body.toString();
        if (!request.headers.has('Content-Type')) {
          urlRequest.setValueForHTTPHeaderField(
            'application/x-www-form-urlencoded',
            'Content-Type'
          );
        }
      } else if (request.body instanceof Blob) {
        // Use streaming upload for Blob bodies
        bodyStream = request.body.stream();
        if (!request.headers.has('Content-Type') && request.body.type) {
          urlRequest.setValueForHTTPHeaderField(request.body.type, 'Content-Type');
        }
      } else if (typeof request.body === 'string') {
        urlRequest.httpBody = request.body;
      } else if (request.body instanceof ArrayBuffer || ArrayBuffer.isView(request.body)) {
        urlRequest.httpBody = new Uint8Array(request.body);
      }
    }

    const session = __APPLE_SPEC__.URLSession.shared();

    // Create a streaming response body using progress handler
    let responseBodyController = null;
    let aborted = false;
    const responseBody = new ReadableStream({
      start(controller) {
        responseBodyController = controller;
      }
    });

    // Set up abort handling
    let abortPromise = null;
    if (request.signal) {
      abortPromise = new Promise((_, reject) => {
        const abortHandler = () => {
          aborted = true;
          if (responseBodyController) {
            const abortError = new Error('The operation was aborted');
            abortError.name = 'AbortError';
            responseBodyController.error(abortError);
            responseBodyController = null;
          }
          const abortError = new Error('The operation was aborted');
          abortError.name = 'AbortError';
          reject(abortError);
        };

        if (request.signal.aborted) {
          // Already aborted
          setTimeout(abortHandler, 0);
        } else {
          request.signal.addEventListener('abort', abortHandler);
        }
      });
    }

    // Use progress handler to stream response data
    const progressHandler = function (chunk, error) {
      if (aborted || !responseBodyController) return;

      if (error) {
        responseBodyController.error(error);
        responseBodyController = null;
      } else if (chunk.length > 0) {
        responseBodyController.enqueue(chunk);
      } else {
        responseBodyController.close();
        responseBodyController = null;
      }
    };

    try {
      // Race the HTTP request with the abort signal
      const requestPromise = session.httpRequestWithRequest(
        urlRequest,
        bodyStream,       // bodyStream parameter
        progressHandler  // progressHandler for streaming response
      );

      const result = abortPromise ?
        await Promise.race([requestPromise, abortPromise]) :
        await requestPromise;

      // If we got here and the request was aborted, throw
      if (aborted) {
        const abortError = new Error('The operation was aborted');
        abortError.name = 'AbortError';
        throw abortError;
      }

      // Create response with streaming body
      const response = new Response(responseBody, {
        status: result.statusCode,
        statusText: getStatusText(result.statusCode),
        headers: result.allHeaderFields,
        url: result.url || request.url
      });

      // Handle redirect option
      if (response.status >= 300 && response.status < 400) {
        if (request.redirect === 'error') {
          const redirectError = new TypeError('Redirected');
          redirectError.name = 'TypeError';
          throw redirectError;
        } else if (request.redirect === 'manual') {
          // Return the redirect response without following it
          return response;
        } else if (request.redirect === 'follow') {
          // Follow the redirect
          const locationHeader = response.headers.get('Location') || response.headers.get('location');
          if (locationHeader) {
            // Resolve the redirect URL - simple implementation for absolute and relative URLs
            let redirectUrl;
            if (locationHeader.startsWith('http://') || locationHeader.startsWith('https://')) {
              // Absolute URL
              redirectUrl = locationHeader;
            } else {
              // For relative URLs, create a simple URL resolver
              // This handles the most common cases for redirects
              if (locationHeader.startsWith('/')) {
                // Absolute path - extract protocol and host from original URL
                const match = request.url.match(/^(https?:\/\/[^\/]+)/);
                redirectUrl = match ? match[1] + locationHeader : locationHeader;
              } else {
                // Relative path - this is less common for redirects, but handle it
                const baseUrl = request.url.replace(/\/[^\/]*$/, '/');
                redirectUrl = baseUrl + locationHeader;
              }
            }

            // Create a new request for the redirect
            // According to fetch spec, POST/PUT/PATCH redirects to GET for 301/302/303
            let redirectMethod = request.method;
            if ((response.status === 301 || response.status === 302 || response.status === 303) &&
              (request.method === 'POST' || request.method === 'PUT' || request.method === 'PATCH')) {
              redirectMethod = 'GET';
            }

            const redirectRequest = new Request(redirectUrl, {
              method: redirectMethod,
              headers: request.headers,
              redirect: 'follow',
              signal: request.signal,
              // Don't include body for GET redirects
              body: redirectMethod === 'GET' ? null : request.body
            });

            // Recursively fetch the redirect target
            const redirectResponse = await fetch(redirectRequest);

            // Create a new response with the redirected flag set
            return new Response(redirectResponse.body, {
              status: redirectResponse.status,
              statusText: redirectResponse.statusText,
              headers: redirectResponse.headers,
              url: redirectResponse.url,
              redirected: true
            });
          }
        }
      }

      return response;
    } catch (error) {
      // Make sure to close the stream on any error
      if (responseBodyController) {
        responseBodyController.error(error);
        responseBodyController = null;
      }
      throw error;
    }
  };

  // URLSearchParams - URL search parameters manipulation
  globalThis.URLSearchParams = class URLSearchParams {
    #entries = []; // Store as ordered list of [key, value] pairs

    constructor(init) {
      if (typeof init === 'string') {
        this.#parseString(init);
      } else if (init instanceof URLSearchParams) {
        this.#entries = [...init.#entries];
      } else if (Array.isArray(init)) {
        for (const [key, value] of init) {
          this.append(String(key), String(value));
        }
      } else if (init && typeof init === 'object') {
        for (const [key, value] of Object.entries(init)) {
          this.append(String(key), String(value));
        }
      }
    }

    #parseString(str) {
      const cleanStr = str.startsWith('?') ? str.slice(1) : str;
      if (!cleanStr) return;

      const pairs = cleanStr.split('&');
      for (const pair of pairs) {
        const [key, ...valueParts] = pair.split('=');
        const value = valueParts.join('=');
        this.append(
          decodeURIComponent(key.replace(/\+/g, ' ')),
          decodeURIComponent(value.replace(/\+/g, ' '))
        );
      }
    }

    append(name, value) {
      if (arguments.length < 2) {
        throw new TypeError(`Failed to execute 'append' on 'URLSearchParams': 2 arguments required, but only ${arguments.length} present.`);
      }

      const key = String(name);
      const val = String(value);
      this.#entries.push([key, val]);
    }

    delete(name) {
      if (arguments.length < 1) {
        throw new TypeError(`Failed to execute 'delete' on 'URLSearchParams': 1 argument required, but only ${arguments.length} present.`);
      }

      const key = String(name);
      this.#entries = this.#entries.filter(([k, v]) => k !== key);
    }

    get(name) {
      const key = String(name);
      const entry = this.#entries.find(([k, v]) => k === key);
      return entry ? entry[1] : null;
    }

    getAll(name) {
      const key = String(name);
      return this.#entries.filter(([k, v]) => k === key).map(([k, v]) => v);
    }

    has(name) {
      const key = String(name);
      return this.#entries.some(([k, v]) => k === key);
    }

    set(name, value) {
      if (arguments.length < 2) {
        throw new TypeError(`Failed to execute 'set' on 'URLSearchParams': 2 arguments required, but only ${arguments.length} present.`);
      }

      const key = String(name);
      const val = String(value);
      // Remove all existing entries with this key
      this.#entries = this.#entries.filter(([k, v]) => k !== key);
      // Add the new entry
      this.#entries.push([key, val]);
    }

    sort() {
      this.#entries.sort((a, b) => a[0].localeCompare(b[0]));
    }

    toString() {
      const parts = [];
      for (const [key, value] of this.#entries) {
        const encodedKey = encodeURIComponent(key).replace(/%20/g, '+');
        const encodedValue = encodeURIComponent(value).replace(/%20/g, '+');
        parts.push(`${encodedKey}=${encodedValue}`);
      }
      return parts.join('&');
    }

    *entries() {
      for (const entry of this.#entries) {
        yield entry;
      }
    }

    *keys() {
      for (const [key] of this.#entries) {
        yield key;
      }
    }

    *values() {
      for (const [, value] of this.#entries) {
        yield value;
      }
    }

    forEach(callback, thisArg) {
      for (const [key, value] of this.#entries) {
        callback.call(thisArg, value, key, this);
      }
    }

    [Symbol.iterator]() {
      return this.entries();
    }
  };

  // FormData - form data representation
  globalThis.FormData = class FormData {
    #data = new Map();

    append(name, value, filename) {
      if (arguments.length < 2) {
        throw new TypeError(`Failed to execute 'append' on 'FormData': 2 arguments required, but only ${arguments.length} present.`);
      }

      const key = String(name);
      if (!this.#data.has(key)) {
        this.#data.set(key, []);
      }

      const item = this.#createFormDataItem(value, filename);
      this.#data.get(key).push(item);
    }

    #createFormDataItem(value, filename) {
      if (value && typeof value === 'object') {
        if (value.constructor?.name === 'File') {
          return {
            type: 'file',
            value: value,
            filename: filename || value.name || 'blob'
          };
        } else if (value.constructor?.name === 'Blob') {
          return {
            type: 'blob',
            value: value,
            filename: filename || 'blob'
          };
        }
      }
      return {
        type: 'string',
        value: String(value),
        filename: null
      };
    }

    delete(name) {
      this.#data.delete(String(name));
    }

    get(name) {
      const values = this.#data.get(String(name));
      return values?.length > 0 ? values[0].value : null;
    }

    getAll(name) {
      const values = this.#data.get(String(name));
      return values ? values.map(item => item.value) : [];
    }

    has(name) {
      return this.#data.has(String(name));
    }

    set(name, value, filename) {
      if (arguments.length < 2) {
        throw new TypeError(`Failed to execute 'set' on 'FormData': 2 arguments required, but only ${arguments.length} present.`);
      }

      const key = String(name);
      this.#data.delete(key);
      this.append(key, value, filename);
    }

    entries() {
      const entries = [];
      for (const [key, values] of this.#data) {
        for (const item of values) {
          const entry = item.type === 'file' || item.type === 'blob'
            ? [key, item.value, item.filename]
            : [key, item.value];
          entries.push(entry);
        }
      }
      return entries[Symbol.iterator]();
    }

    keys() {
      const keys = [];
      for (const [key, values] of this.#data) {
        keys.push(...Array(values.length).fill(key));
      }
      return keys[Symbol.iterator]();
    }

    values() {
      const values = [];
      for (const [, items] of this.#data) {
        values.push(...items.map(item => item.value));
      }
      return values[Symbol.iterator]();
    }

    forEach(callback, thisArg) {
      for (const [key, value] of this.entries()) {
        callback.call(thisArg, value, key, this);
      }
    }

    [Symbol.iterator]() {
      return this.entries();
    }

    [SYMBOLS.formDataToMultipart]() {
      const boundary = '----SwiftJSFormBoundary-' + crypto.randomUUID();
      let result = '';

      for (const [key, values] of this.#data) {
        for (const item of values) {
          result += `--${boundary}\r\n`;

          if (item.type === 'file' || item.type === 'blob') {
            const filename = item.filename || 'blob';
            const contentType = item.value.type || 'application/octet-stream';
            result += `Content-Disposition: form-data; name="${key}"; filename="${filename}"\r\n`;
            result += `Content-Type: ${contentType}\r\n\r\n`;
            result += item.value.arrayBuffer ? '[Binary Data]\r\n' : String(item.value) + '\r\n';
          } else {
            result += `Content-Disposition: form-data; name="${key}"\r\n\r\n`;
            result += item.value + '\r\n';
          }
        }
      }

      result += `--${boundary}--\r\n`;
      return { boundary, body: result };
    }
  };

  function createDeferred() {
    let resolve, reject;
    const p = new Promise((res, rej) => { resolve = res; reject = rej; });
    return { promise: p, resolve, reject };
  }

  globalThis.ReadableStreamDefaultController = class ReadableStreamDefaultController {
    #stream;
    #internal;
    constructor(stream, underlyingSource) {
      this.#stream = stream;
      this.#internal = stream[SYMBOLS.streamInternal];
      this.#internal.underlyingSource = underlyingSource || {};
    }

    enqueue(chunk) {
      if (this.#internal.state !== 'readable') {
        // According to Web Streams spec, silently ignore enqueue after close/error
        return;
      }

      // Check if we're over the high water mark (backpressure)
      const chunkSize = this.#internal.sizeAlgorithm(chunk);
      this.#internal.queueTotalSize += chunkSize;

      this.#internal.queue.push(chunk);

      // Process pending read requests
      while (this.#internal.readRequests.length > 0 && this.#internal.queue.length > 0) {
        const { resolve } = this.#internal.readRequests.shift();
        const value = this.#internal.queue.shift();
        const valueSize = this.#internal.sizeAlgorithm(value);
        this.#internal.queueTotalSize = Math.max(0, this.#internal.queueTotalSize - valueSize);
        resolve({ value, done: false });
      }
    }

    close() {
      if (this.#internal.state !== 'readable') return;
      this.#internal.state = 'closed';

      // Resolve all pending read requests with done: true
      while (this.#internal.readRequests.length > 0) {
        const { resolve } = this.#internal.readRequests.shift();
        resolve({ value: undefined, done: true });
      }

      // Resolve close promise if it exists
      if (this.#internal.closePromise) {
        this.#internal.closePromise.resolve();
      }
    }

    error(err) {
      if (this.#internal.state !== 'readable') return;
      this.#internal.state = 'errored';
      this.#internal.storedError = err;

      // Reject all pending read requests
      while (this.#internal.readRequests.length > 0) {
        const { reject } = this.#internal.readRequests.shift();
        reject(err);
      }

      // Reject close promise if it exists
      if (this.#internal.closePromise) {
        this.#internal.closePromise.reject(err);
      }
    }

    get desiredSize() {
      if (this.#internal.state === 'closed' || this.#internal.state === 'errored') {
        return null;
      }
      return this.#internal.highWaterMark - this.#internal.queueTotalSize;
    }
  }

  globalThis.ReadableStream = class ReadableStream {
    constructor(underlyingSource = {}, strategy = {}) {
      // Validate and set up strategy
      const queuingStrategy = strategy || {};
      const highWaterMark = queuingStrategy.highWaterMark ?? 1;
      const sizeAlgorithm = queuingStrategy.size || (() => 1);

      // Per-instance internal storage with enhanced properties
      this[SYMBOLS.streamInternal] = {
        underlyingSource: underlyingSource,
        strategy: queuingStrategy,
        highWaterMark: highWaterMark,
        sizeAlgorithm: sizeAlgorithm,
        queue: [],
        queueTotalSize: 0,
        readRequests: [],
        state: 'readable',
        storedError: undefined,
        controller: null,
        pulling: false,
        pullAgain: false,
        reader: null,
        closePromise: null,
        mode: underlyingSource.type === 'bytes' ? 'byob' : 'default'
      };

      // create controller and store reference
      const controller = new ReadableStreamDefaultController(this, underlyingSource);
      this[SYMBOLS.streamInternal].controller = controller;

      if (underlyingSource.start) {
        try {
          const startResult = underlyingSource.start(controller);
          if (startResult && typeof startResult.then === 'function') {
            startResult.catch(e => controller.error(e));
          }
        } catch (e) {
          controller.error(e);
        }
      }
    }

    getReader(options = {}) {
      // Defensive check: ensure streamInternal is initialized
      if (!this[SYMBOLS.streamInternal]) {
        throw new TypeError('ReadableStream is in an invalid state');
      }

      if (this[SYMBOLS.streamInternal].reader) {
        throw new TypeError('ReadableStream is already locked to a reader');
      }

      const mode = options.mode;
      if (mode === 'byob') {
        if (this[SYMBOLS.streamInternal].mode !== 'byob') {
          throw new TypeError('Cannot get BYOB reader for non-byte stream');
        }
        const reader = new ReadableStreamBYOBReader(this);
        this[SYMBOLS.streamInternal].reader = reader;
        return reader;
      }

      const stream = this;
      const reader = new (class ReadableStreamDefaultReader {
        #released = false;
        constructor() { this.#released = false; }

        read() {
          if (this.#released) {
            return Promise.reject(new TypeError('Reader has been released'));
          }

          const s = stream[SYMBOLS.streamInternal];
          if (!s) {
            return Promise.reject(new TypeError('ReadableStream is in an invalid state'));
          }
          if (s.state === 'errored') return Promise.reject(s.storedError);

          if (s.queue.length > 0) {
            const chunk = s.queue.shift();
            const chunkSize = s.sizeAlgorithm(chunk);
            s.queueTotalSize = Math.max(0, s.queueTotalSize - chunkSize);

            // Check if we should pull more data (backpressure management)
            if (s.queueTotalSize < s.highWaterMark && !s.pulling) {
              this.#requestPull();
            }

            return Promise.resolve({ value: chunk, done: false });
          }

          if (s.state === 'closed') return Promise.resolve({ value: undefined, done: true });

          const deferred = createDeferred();
          s.readRequests.push(deferred);
          this.#requestPull();
          return deferred.promise;
        }

        #requestPull() {
          const s = stream[SYMBOLS.streamInternal];
          if (!s) return; // Guard against undefined streamInternal
          if (!s.underlyingSource?.pull || s.pulling) {
            if (s.pulling) s.pullAgain = true;
            return;
          }

          s.pulling = true;
          try {
            const pullResult = s.underlyingSource.pull(s.controller);
            if (pullResult && typeof pullResult.then === 'function') {
              pullResult.then(() => {
                s.pulling = false;
                if (s.pullAgain) {
                  s.pullAgain = false;
                  this.#requestPull();
                }
              }).catch(e => {
                s.pulling = false;
                s.controller.error(e);
              });
            } else {
              s.pulling = false;
              if (s.pullAgain) {
                s.pullAgain = false;
                this.#requestPull();
              }
            }
          } catch (e) {
            s.pulling = false;
            s.controller.error(e);
          }
        }

        releaseLock() {
          if (this.#released) return;
          this.#released = true;
          if (stream[SYMBOLS.streamInternal]) {
            stream[SYMBOLS.streamInternal].reader = null;
          }
        }

        get closed() {
          const s = stream[SYMBOLS.streamInternal];
          if (!s) return Promise.reject(new TypeError('ReadableStream is in an invalid state'));
          if (s.state === 'closed') return Promise.resolve();
          if (s.state === 'errored') return Promise.reject(s.storedError);

          if (!s.closePromise) {
            s.closePromise = createDeferred();
          }
          return s.closePromise.promise;
        }

        cancel(reason) {
          return stream.cancel(reason);
        }
      })();

      this[SYMBOLS.streamInternal].reader = reader;
      return reader;
    }

    cancel(reason) {
      if (!this[SYMBOLS.streamInternal]) {
        return Promise.reject(new TypeError('ReadableStream is in an invalid state'));
      }
      const s = this[SYMBOLS.streamInternal];
      if (s.state === 'closed') return Promise.resolve();
      if (s.state === 'errored') return Promise.reject(s.storedError);

      // Reject all pending read requests
      s.readRequests.forEach(r => r.reject(reason));
      s.readRequests = [];

      // Mark as closed
      s.state = 'closed';

      // Call underlying source cancel if available
      if (s.underlyingSource && s.underlyingSource.cancel) {
        try {
          const cancelResult = s.underlyingSource.cancel(reason);
          return Promise.resolve(cancelResult);
        } catch (e) {
          return Promise.reject(e);
        }
      }
      return Promise.resolve();
    }

    get locked() {
      return this[SYMBOLS.streamInternal] && this[SYMBOLS.streamInternal].reader !== null;
    }

    tee() {
      if (!this[SYMBOLS.streamInternal]) {
        throw new TypeError('ReadableStream is in an invalid state');
      }
      if (this[SYMBOLS.streamInternal].state === 'errored') {
        throw new TypeError('Cannot tee an errored stream');
      }

      const reader = this.getReader();

      const teeState = {
        reading: false,
        canceled1: false,
        canceled2: false,
        reason1: null,
        reason2: null
      };

      function pullAlgorithm() {
        if (teeState.reading) {
          return Promise.resolve();
        }

        teeState.reading = true;
        return reader.read().then(({ value, done }) => {
          teeState.reading = false;

          if (done) {
            if (!teeState.canceled1) {
              stream1[SYMBOLS.streamInternal].controller.close();
            }
            if (!teeState.canceled2) {
              stream2[SYMBOLS.streamInternal].controller.close();
            }
            return;
          }

          if (!teeState.canceled1) {
            stream1[SYMBOLS.streamInternal].controller.enqueue(value);
          }
          if (!teeState.canceled2) {
            stream2[SYMBOLS.streamInternal].controller.enqueue(value);
          }
        }).catch(error => {
          teeState.reading = false;
          if (!teeState.canceled1) {
            stream1[SYMBOLS.streamInternal].controller.error(error);
          }
          if (!teeState.canceled2) {
            stream2[SYMBOLS.streamInternal].controller.error(error);
          }
        });
      }

      // Create streams with proper underlying sources
      const stream1 = new ReadableStream({
        pull: pullAlgorithm,
        cancel: (reason) => {
          teeState.canceled1 = true;
          teeState.reason1 = reason;
          if (teeState.canceled2) {
            return reader.cancel(reason);
          }
          return Promise.resolve();
        }
      });

      const stream2 = new ReadableStream({
        pull: pullAlgorithm,
        cancel: (reason) => {
          teeState.canceled2 = true;
          teeState.reason2 = reason;
          if (teeState.canceled1) {
            return reader.cancel(reason);
          }
          return Promise.resolve();
        }
      });

      return [stream1, stream2];
    }

    pipeThrough(transform, options = {}) {
      if (!transform || typeof transform !== 'object') {
        throw new TypeError('transform must be an object');
      }

      if (!transform.writable || !transform.readable) {
        throw new TypeError('transform must have writable and readable properties');
      }

      if (!(transform.writable instanceof WritableStream)) {
        throw new TypeError('transform.writable must be a WritableStream');
      }

      if (!(transform.readable instanceof ReadableStream)) {
        throw new TypeError('transform.readable must be a ReadableStream');
      }

      // Start the pipe operation
      this.pipeTo(transform.writable, options).catch(() => {
        // Error handling is done in pipeTo
      });

      return transform.readable;
    }

    pipeTo(destination, options = {}) {
      if (!(destination instanceof WritableStream)) {
        throw new TypeError('destination must be a WritableStream');
      }

      const signal = options.signal;
      const preventClose = options.preventClose || false;
      const preventAbort = options.preventAbort || false;
      const preventCancel = options.preventCancel || false;

      if (signal && signal.aborted) {
        return Promise.reject(new Error('AbortError'));
      }

      const reader = this.getReader();
      const writer = destination.getWriter();

      let abortPromise = null;
      if (signal) {
        abortPromise = new Promise((_, reject) => {
          signal.addEventListener('abort', () => {
            reject(new Error('AbortError'));
          });
        });
      }

      function cleanup() {
        reader.releaseLock();
        writer.releaseLock();
      }

      async function pipeLoop() {
        try {
          while (true) {
            const readResult = await (abortPromise ?
              Promise.race([reader.read(), abortPromise]) :
              reader.read());

            if (readResult.done) {
              if (!preventClose) {
                await writer.close();
              }
              cleanup();
              return;
            }

            await (abortPromise ?
              Promise.race([writer.write(readResult.value), abortPromise]) :
              writer.write(readResult.value));
          }
        } catch (error) {
          // Handle different error scenarios BEFORE cleanup
          if (error.message === 'AbortError') {
            if (!preventCancel) {
              await reader.cancel().catch(() => { });
            }
            if (!preventAbort) {
              await writer.abort(error).catch(() => { });
            }
          } else {
            // Regular error
            if (!preventCancel) {
              await reader.cancel(error).catch(() => { });
            }
            if (!preventAbort) {
              await writer.abort(error).catch(() => { });
            }
          }

          cleanup();
          throw error;
        }
      }

      return pipeLoop();
    }
  }

  globalThis.WritableStreamDefaultController = class WritableStreamDefaultController {
    #stream;
    #internal;
    constructor(stream, underlyingSink) {
      this.#stream = stream;
      this.#internal = stream[SYMBOLS.streamInternal];
      this.#internal.underlyingSink = underlyingSink || {};
    }

    error(err) {
      if (this.#internal.state === 'errored') return;
      this.#internal.state = 'errored';
      this.#internal.storedError = err;

      // Reject all pending writes
      this.#internal.writeQueue.forEach(item => item.reject(err));
      this.#internal.writeQueue = [];

      // Reject close promise if it exists
      if (this.#internal.closePromise) {
        this.#internal.closePromise.reject(err);
      }
    }

    get signal() {
      // Return an AbortSignal that can be used to abort operations
      // This is a simplified implementation
      return null;
    }
  }

  globalThis.WritableStream = class WritableStream {
    constructor(underlyingSink = {}, strategy = {}) {
      // Validate and set up strategy
      const queuingStrategy = strategy || {};
      const highWaterMark = queuingStrategy.highWaterMark ?? 1;
      const sizeAlgorithm = queuingStrategy.size || (() => 1);

      // per-instance internal storage with enhanced properties
      this[SYMBOLS.streamInternal] = {
        underlyingSink: underlyingSink,
        strategy: queuingStrategy,
        highWaterMark: highWaterMark,
        sizeAlgorithm: sizeAlgorithm,
        state: 'writable',
        storedError: undefined,
        controller: null,
        writing: false,
        writeQueue: [],
        queueTotalSize: 0,
        writer: null,
        closePromise: null,
        abortPromise: null
      };

      const controller = new WritableStreamDefaultController(this, underlyingSink);
      this[SYMBOLS.streamInternal].controller = controller;

      if (underlyingSink.start) {
        try {
          const startResult = underlyingSink.start(controller);
          if (startResult && typeof startResult.then === 'function') {
            startResult.catch(e => controller.error(e));
          }
        } catch (e) {
          controller.error(e);
        }
      }
    }

    getWriter() {
      if (this[SYMBOLS.streamInternal].writer) {
        throw new TypeError('WritableStream is already locked to a writer');
      }

      const stream = this;
      const writer = new (class WritableStreamDefaultWriter {
        #released = false;

        write(chunk) {
          if (this.#released) {
            return Promise.reject(new TypeError('Writer has been released'));
          }

          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'errored') return Promise.reject(s.storedError);
          if (s.state === 'closed' || s.state === 'closing') {
            return Promise.reject(new TypeError('Cannot write to closed stream'));
          }

          const chunkSize = s.sizeAlgorithm(chunk);
          const promise = new Promise((resolve, reject) => {
            s.writeQueue.push({ chunk, chunkSize, resolve, reject });
            s.queueTotalSize += chunkSize;
            this.#scheduleWrite();
          });

          return promise;
        }

        #scheduleWrite() {
          const s = stream[SYMBOLS.streamInternal];
          if (s.writing || s.writeQueue.length === 0) return;

          const item = s.writeQueue.shift();
          if (!item) return;

          s.queueTotalSize = Math.max(0, s.queueTotalSize - item.chunkSize);
          s.writing = true;

          try {
            if (s.underlyingSink.write) {
              const writeResult = s.underlyingSink.write(item.chunk, s.controller);
              if (writeResult && typeof writeResult.then === 'function') {
                writeResult.then(() => {
                  s.writing = false;
                  item.resolve();
                  this.#scheduleWrite(); // Process next item
                }).catch(e => {
                  s.writing = false;
                  s.controller.error(e);
                  item.reject(e);
                });
              } else {
                s.writing = false;
                item.resolve();
                this.#scheduleWrite();
              }
            } else {
              s.writing = false;
              item.resolve();
              this.#scheduleWrite();
            }
          } catch (e) {
            s.writing = false;
            s.controller.error(e);
            item.reject(e);
          }
        }

        close() {
          if (this.#released) {
            return Promise.reject(new TypeError('Writer has been released'));
          }

          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'closed' || s.state === 'closing') {
            return Promise.reject(new TypeError('Stream is already closed or closing'));
          }

          s.state = 'closing';

          return new Promise((resolve, reject) => {
            // Wait for all writes to complete, then close
            const waitForWrites = () => {
              if (s.writing || s.writeQueue.length > 0) {
                setTimeout(waitForWrites, 0);
                return;
              }

              try {
                if (s.underlyingSink.close) {
                  const closeResult = s.underlyingSink.close();
                  if (closeResult && typeof closeResult.then === 'function') {
                    closeResult.then(() => {
                      s.state = 'closed';
                      resolve();
                    }).catch(reject);
                  } else {
                    s.state = 'closed';
                    resolve();
                  }
                } else {
                  s.state = 'closed';
                  resolve();
                }
              } catch (e) {
                reject(e);
              }
            };

            waitForWrites();
          });
        }

        abort(reason) {
          if (this.#released) {
            return Promise.reject(new TypeError('Writer has been released'));
          }

          return stream.abort(reason);
        }

        releaseLock() {
          if (this.#released) return;
          this.#released = true;
          stream[SYMBOLS.streamInternal].writer = null;
        }

        get closed() {
          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'closed') return Promise.resolve();
          if (s.state === 'errored') return Promise.reject(s.storedError);

          if (!s.closePromise) {
            s.closePromise = createDeferred();
          }
          return s.closePromise.promise;
        }

        get desiredSize() {
          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'closed' || s.state === 'errored') return null;
          return s.highWaterMark - s.queueTotalSize;
        }

        get ready() {
          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'errored') return Promise.reject(s.storedError);
          if (s.queueTotalSize < s.highWaterMark) return Promise.resolve();

          // Return a promise that resolves when backpressure is relieved
          return new Promise(resolve => {
            const checkBackpressure = () => {
              if (s.queueTotalSize < s.highWaterMark) {
                resolve();
              } else {
                setTimeout(checkBackpressure, 0);
              }
            };
            checkBackpressure();
          });
        }
      })();

      this[SYMBOLS.streamInternal].writer = writer;
      return writer;
    }

    abort(reason) {
      const s = this[SYMBOLS.streamInternal];
      if (s.state === 'closed') return Promise.resolve();
      if (s.state === 'errored') return Promise.reject(s.storedError);

      s.state = 'errored';
      s.storedError = reason instanceof Error ? reason : new Error(String(reason));

      // Reject all pending writes
      s.writeQueue.forEach(item => item.reject(s.storedError));
      s.writeQueue = [];

      if (s.underlyingSink && s.underlyingSink.abort) {
        try {
          return Promise.resolve(s.underlyingSink.abort(reason));
        } catch (e) {
          return Promise.reject(e);
        }
      }
      return Promise.resolve();
    }

    get locked() {
      return this[SYMBOLS.streamInternal].writer !== null;
    }
  }

  globalThis.TransformStream = class TransformStream {
    constructor(transformer = {}, writableStrategy, readableStrategy) {
      // per-instance internals
      this[SYMBOLS.streamInternal] = {
        transformer: transformer,
        writable: null,
        readable: null,
        readableController: null,
        writableController: null,
        transforming: false,
        backpressure: false,
        backpressurePromise: null
      };

      const ts = this;

      // Enhanced readable side with proper transform integration
      const readable = new ReadableStream({
        start(controller) {
          ts[SYMBOLS.streamInternal].readableController = controller;
          if (transformer.start) {
            try {
              const startResult = transformer.start(controller);
              if (startResult && typeof startResult.then === 'function') {
                return startResult;
              }
            } catch (e) {
              controller.error(e);
              throw e;
            }
          }
        },
        pull(controller) {
          // Handle backpressure from readable side
          if (ts[SYMBOLS.streamInternal].backpressure) {
            ts[SYMBOLS.streamInternal].backpressure = false;
            if (ts[SYMBOLS.streamInternal].backpressurePromise) {
              ts[SYMBOLS.streamInternal].backpressurePromise.resolve();
              ts[SYMBOLS.streamInternal].backpressurePromise = null;
            }
          }
        },
        cancel(reason) {
          if (transformer.cancel) {
            return transformer.cancel(reason);
          }
          return Promise.resolve();
        }
      }, readableStrategy);

      // Enhanced writable side with proper transform integration
      const writable = new WritableStream({
        start(controller) {
          ts[SYMBOLS.streamInternal].writableController = controller;
        },
        write(chunk, controller) {
          return new Promise((resolve, reject) => {
            try {
              const readableController = ts[SYMBOLS.streamInternal].readableController;

              if (transformer.transform) {
                const transformResult = transformer.transform(chunk, readableController);

                if (transformResult && typeof transformResult.then === 'function') {
                  transformResult.then(() => resolve()).catch(e => {
                    readableController.error(e);
                    reject(e);
                  });
                } else {
                  resolve();
                }
              } else {
                // Default transform: pass through
                readableController.enqueue(chunk);
                resolve();
              }
            } catch (e) {
              ts[SYMBOLS.streamInternal].readableController.error(e);
              reject(e);
            }
          });
        },
        close() {
          return new Promise((resolve, reject) => {
            try {
              const readableController = ts[SYMBOLS.streamInternal].readableController;

              if (transformer.flush) {
                const flushResult = transformer.flush(readableController);

                if (flushResult && typeof flushResult.then === 'function') {
                  flushResult.then(() => {
                    readableController.close();
                    resolve();
                  }).catch(e => {
                    readableController.error(e);
                    reject(e);
                  });
                } else {
                  readableController.close();
                  resolve();
                }
              } else {
                readableController.close();
                resolve();
              }
            } catch (e) {
              ts[SYMBOLS.streamInternal].readableController.error(e);
              reject(e);
            }
          });
        },
        abort(reason) {
          const readableController = ts[SYMBOLS.streamInternal].readableController;
          readableController.error(reason);

          if (transformer.cancel) {
            return transformer.cancel(reason);
          }
          return Promise.resolve();
        }
      }, writableStrategy);

      this[SYMBOLS.streamInternal].readable = readable;
      this[SYMBOLS.streamInternal].writable = writable;
    }

    get readable() { return this[SYMBOLS.streamInternal].readable; }
    get writable() { return this[SYMBOLS.streamInternal].writable; }
  }

  // Queuing Strategies - Web Streams Standard
  globalThis.CountQueuingStrategy = class CountQueuingStrategy {
    constructor(options) {
      if (!options || typeof options.highWaterMark !== 'number') {
        throw new TypeError('CountQueuingStrategy expects options with highWaterMark');
      }
      this.highWaterMark = options.highWaterMark;
    }

    size(chunk) {
      return 1;
    }
  };

  globalThis.ByteLengthQueuingStrategy = class ByteLengthQueuingStrategy {
    constructor(options) {
      if (!options || typeof options.highWaterMark !== 'number') {
        throw new TypeError('ByteLengthQueuingStrategy expects options with highWaterMark');
      }
      this.highWaterMark = options.highWaterMark;
    }

    size(chunk) {
      if (chunk == null) return 0;
      if (typeof chunk === 'string') return new TextEncoder().encode(chunk).byteLength;
      if (chunk instanceof ArrayBuffer) return chunk.byteLength;
      if (ArrayBuffer.isView(chunk)) return chunk.byteLength;
      if (chunk instanceof Blob) return chunk.size;
      if (typeof chunk === 'object' && chunk.length !== undefined) return chunk.length;
      return 0;
    }
  };

  // Enhanced Readable Stream BYOB (Bring Your Own Buffer) Reader
  globalThis.ReadableStreamBYOBReader = class ReadableStreamBYOBReader {
    #stream;
    #released = false;

    constructor(stream) {
      this.#stream = stream;
    }

    read(view) {
      if (this.#released) {
        return Promise.reject(new TypeError('Reader has been released'));
      }

      if (!ArrayBuffer.isView(view)) {
        return Promise.reject(new TypeError('view must be an ArrayBuffer view'));
      }

      const s = this.#stream[SYMBOLS.streamInternal];
      if (s.state === 'errored') return Promise.reject(s.storedError);
      if (s.state === 'closed') return Promise.resolve({ value: view, done: true });

      // Simplified BYOB implementation - in a full implementation this would
      // interact with the underlying byte source more efficiently
      const deferred = createDeferred();
      s.readRequests.push({
        ...deferred,
        view: view,
        byob: true
      });

      this.#tryFillFromQueue();
      return deferred.promise;
    }

    #tryFillFromQueue() {
      const s = this.#stream[SYMBOLS.streamInternal];
      while (s.readRequests.length > 0 && s.queue.length > 0) {
        const request = s.readRequests[0];
        if (!request.byob) break; // Only handle BYOB requests here

        const chunk = s.queue.shift();
        s.readRequests.shift();

        if (chunk instanceof Uint8Array && request.view instanceof Uint8Array) {
          const bytesToCopy = Math.min(chunk.length, request.view.length);
          request.view.set(chunk.subarray(0, bytesToCopy));

          if (chunk.length > bytesToCopy) {
            // Put remaining bytes back in queue
            s.queue.unshift(chunk.subarray(bytesToCopy));
          }

          const filledView = request.view.subarray(0, bytesToCopy);
          request.resolve({ value: filledView, done: false });
        } else {
          // Fallback for non-byte data
          request.resolve({ value: request.view, done: false });
        }
      }
    }

    releaseLock() {
      this.#released = true;
    }

    get closed() {
      const s = this.#stream[SYMBOLS.streamInternal];
      if (s.state === 'closed') return Promise.resolve();
      if (s.state === 'errored') return Promise.reject(s.storedError);
      return new Promise((resolve, reject) => {
        if (!s.closePromise) {
          s.closePromise = { resolve, reject };
        }
      });
    }

    cancel(reason) {
      return this.#stream.cancel(reason);
    }
  };

})();