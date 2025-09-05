(function () {
  'use strict';

  // Private symbols for internal APIs
  const SYMBOLS = {
    formDataData: Symbol('FormData._data'),
    formDataToMultipart: Symbol('FormData._toMultipartString'),
    formDataToURLEncoded: Symbol('FormData._toURLEncoded'),
    blobParts: Symbol('Blob._parts'),
    blobType: Symbol('Blob._type'),
    blobPlaceholderPromise: Symbol('Blob._placeholderPromise'),
    headersMap: Symbol('Headers._headers'),
    requestBodyText: Symbol('Request._bodyText'),
    streamInternal: Symbol('Stream._internal'),
    abortSignalMarkAborted: Symbol('AbortSignal._markAborted'),
    filePath: Symbol('File._filePath')
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
      return __APPLE_SPEC__.FileSystem.changeCurrentDirectoryPath(directory);
    }

    // Standard Node.js process.exit() - sets global flag and throws uncatchable error
    exit(code = 0) {
      // Set global exit flag that Swift can check
      globalThis.__SWIFTJS_EXIT_CODE__ = code;
      // Throw an error that cannot be caught by user code
      const exitError = new Error('PROCESS_EXIT');
      exitError.name = 'ProcessExit';
      exitError.code = code;

      // Use setTimeout to throw the error async, making it uncatchable
      setTimeout(() => {
        throw exitError;
      }, 0);
    }
  };

  // Path - Path manipulation utilities
  globalThis.Path = class Path {
    static sep = '/';  // Path separator (Unix-style for consistency)

    static join(...segments) {
      if (segments.length === 0) return '.';

      // Filter out empty segments and join with separator
      const parts = segments
        .filter(segment => segment && typeof segment === 'string')
        .join(this.sep)
        .split(this.sep)
        .filter(part => part !== '');

      // Handle absolute paths
      const isAbsolute = segments[0] && segments[0].startsWith('/');
      const result = parts.join(this.sep);

      return isAbsolute ? '/' + result : result || '.';
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
        resolvedPath = __APPLE_SPEC__.FileSystem.currentDirectoryPath + '/' + resolvedPath;
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
        } else if (part !== '.') {
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

      if (lastDot === -1 || lastDot === 0) return '';
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
          let totalLength = 0;
          chunks.forEach(chunk => totalLength += chunk.byteLength);

          const combined = new Uint8Array(totalLength);
          let offset = 0;
          chunks.forEach(chunk => {
            combined.set(chunk, offset);
            offset += chunk.byteLength;
          });

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

    static watch(path, options = {}) {
      // Basic file watching - in a real implementation this would use platform-specific APIs
      console.warn('FileSystem.watch() is not implemented - polling not supported in this environment');

      // Return a basic EventTarget for API compatibility
      return new class FileWatcher extends EventTarget {
        close() {
          // No-op
        }
      };
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
      wrappedListener._originalListener = listener;

      this.#listeners[type].push(wrappedListener);
    }

    removeEventListener(type, listener) {
      if (!this.#listeners[type]) return;
      this.#listeners[type] = this.#listeners[type].filter(l =>
        l !== listener && l._originalListener !== listener
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
          console.error('Error in event listener:', error);
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
  globalThis.btoa = function (str) {
    if (typeof str !== 'string') {
      throw new TypeError('Failed to execute \'btoa\': 1 argument required, but only 0 present.');
    }

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

  globalThis.atob = function (base64) {
    if (typeof base64 !== 'string') {
      throw new TypeError('Failed to execute \'atob\': 1 argument required, but only 0 present.');
    }

    // Remove whitespace and validate base64 characters
    base64 = base64.replace(/\s/g, '');
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
  };

  // Enhanced Console implementation
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

    constructor(parts = [], options = {}) {
      this[SYMBOLS.blobParts] = Array.isArray(parts) ? parts.slice() : [parts];
      this.#type = String(options.type || '').toLowerCase();
      this.#calculateSize();
      this[SYMBOLS.blobType] = this.#type;
      this[Symbol.toStringTag] = 'Blob';
    }

    get size() { return this.#size; }
    get type() { return this.#type; }

    #calculateSize() {
      const encoder = new TextEncoder();
      for (const part of this[SYMBOLS.blobParts]) {
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
      let partsToProcess = this[SYMBOLS.blobParts];

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

      return result.buffer;
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
      placeholder[SYMBOLS.blobParts] = [{
        __asyncBlob: true,
        [SYMBOLS.blobPlaceholderPromise]: slicePromise
      }];
      placeholder.#setSize(span);
      return placeholder;
    }

    stream() {
      // Return a ReadableStream that streams the blob data in chunks
      const blob = this;

      return new ReadableStream({
        async start(controller) {
          try {
            // For now, we'll read the entire blob and stream it in chunks
            // This could be optimized to stream parts individually for very large blobs
            const buffer = await blob.arrayBuffer();
            const uint8Array = new Uint8Array(buffer);

            // Stream in 64KB chunks for better performance
            const chunkSize = 64 * 1024;
            let offset = 0;

            while (offset < uint8Array.length) {
              const chunk = uint8Array.slice(offset, Math.min(offset + chunkSize, uint8Array.length));
              controller.enqueue(chunk);
              offset += chunkSize;
            }

            controller.close();
          } catch (error) {
            controller.error(error);
          }
        }
      });
    }
  };

  // File - extends Blob with file metadata
  globalThis.File = class File extends Blob {
    #name;
    #lastModified;
    #filePath; // For files created from FileSystemFileHandle

    constructor(parts, name, options = {}) {
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
      if (filePath && __APPLE_SPEC__.FileSystem.exists(filePath)) {
        return new ReadableStream({
          start(controller) {
            // Create a file handle for efficient streaming through Swift
            const handle = __APPLE_SPEC__.FileSystem.createFileHandle(filePath);
            if (!handle) {
              controller.error(new Error(`Failed to open file: ${filePath}`));
              return;
            }

            const chunkSize = 64 * 1024; // 64KB chunks

            const readNextChunk = () => {
              try {
                // Read chunk directly from Swift file handle
                const chunk = __APPLE_SPEC__.FileSystem.readFileHandleChunk(handle, chunkSize);

                if (!chunk) {
                  // EOF reached
                  __APPLE_SPEC__.FileSystem.closeFileHandle(handle);
                  controller.close();
                  return;
                }

                // Convert JSValue to Uint8Array
                const bytes = chunk.typedArrayBytes;
                controller.enqueue(new Uint8Array(bytes));

                // Continue reading asynchronously
                setTimeout(readNextChunk, 0);
              } catch (error) {
                __APPLE_SPEC__.FileSystem.closeFileHandle(handle);
                controller.error(error);
              }
            };

            readNextChunk();
          }
        });
      }

      // For in-memory File objects, use the parent Blob stream() method
      return super.stream();
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
      return new File([], name, {
        type: getMimeType(ext),
        lastModified: stats.lastModified ? stats.lastModified.getTime() : Date.now(),
        [SYMBOLS.filePath]: path
      });
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
      this.#startReading(blob, 'arraybuffer');
    }

    readAsBinaryString(blob) {
      this.#startReading(blob, 'binarystring');
    }

    readAsDataURL(blob) {
      this.#startReading(blob, 'dataurl');
    }

    readAsText(blob, encoding = 'utf-8') {
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
      if (this.#readyState === FileReader.LOADING) {
        throw new Error('InvalidStateError: FileReader is already reading');
      }

      this.#setReadyState(FileReader.LOADING);
      this.#result = null;
      this.#error = null;

      // Fire loadstart event
      this.#fireEvent('loadstart');

      try {
        let blob = blobOrFile;
        let useStreaming = blob.size > 1024 * 1024; // Use streaming for files > 1MB

        const total = blob.size || 0;
        let loaded = 0;

        // Fire initial progress event
        this.#fireEvent('progress', { loaded: 0, total, lengthComputable: total > 0 });

        let result;

        if (useStreaming && (format === 'arraybuffer' || format === 'text')) {
          // Use streaming for large files
          result = await this.#streamingRead(blob, format, encoding, (progressLoaded) => {
            loaded = progressLoaded;
            this.#fireEvent('progress', { loaded, total, lengthComputable: true });
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
        if (this.#readyState !== FileReader.LOADING) {
          return; // Aborted
        }

        this.#result = result;
        this.#setReadyState(FileReader.DONE);

        // Fire final progress event
        this.#fireEvent('progress', { loaded: total, total, lengthComputable: true });

        // Fire load event
        this.#fireEvent('load');

        // Fire loadend event
        this.#fireEvent('loadend');

      } catch (error) {
        this.#error = error;
        this.#setReadyState(FileReader.DONE);

        // Fire error event
        this.#fireEvent('error');

        // Fire loadend event
        this.#fireEvent('loadend');
      }
    }

    async #streamingRead(blob, format, encoding, onProgress) {
      const stream = blob.stream();
      const reader = stream.getReader();
      const chunks = [];
      let totalLoaded = 0;

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          chunks.push(value);
          totalLoaded += value.byteLength;

          if (onProgress) {
            onProgress(totalLoaded);
          }

          // Check if aborted during streaming
          if (this.#readyState !== FileReader.LOADING) {
            return null;
          }
        }

        // Combine chunks
        const totalLength = chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0);
        const combined = new Uint8Array(totalLength);
        let offset = 0;
        for (const chunk of chunks) {
          combined.set(chunk, offset);
          offset += chunk.byteLength;
        }

        if (format === 'arraybuffer') {
          return combined.buffer;
        } else if (format === 'text') {
          return new TextDecoder(encoding).decode(combined);
        }

        throw new Error(`Streaming not supported for format: ${format}`);
      } finally {
        reader.releaseLock();
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
    #responseXML = null;
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
      this.withCredentials = false;
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
    get responseXML() { return this.#responseXML; }
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

      const progressHandler = (chunk, isComplete) => {
        if (this.#aborted) return;

        if (chunk && chunk.length > 0) {
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
        }

        if (isComplete && !this.#aborted) {
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
        progressHandler,   // progressHandler for streaming updates
        null               // completionHandler
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

    #handleResponse(result, accumulatedData) {
      if (this.#aborted || this.readyState === XMLHttpRequest.DONE) return;

      // If we have accumulated data from progress, use it; otherwise use result.data
      const finalData = accumulatedData || result.data;
      this.#setResponseData(finalData);
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

    overrideMimeType(mime) {
      // Not implemented
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
      const statusTexts = {
        100: 'Continue', 101: 'Switching Protocols',
        200: 'OK', 201: 'Created', 202: 'Accepted', 204: 'No Content',
        300: 'Multiple Choices', 301: 'Moved Permanently', 302: 'Found', 304: 'Not Modified',
        400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden', 404: 'Not Found',
        500: 'Internal Server Error', 502: 'Bad Gateway', 503: 'Service Unavailable'
      };
      return statusTexts[status] || '';
    }
  };

  // Headers - HTTP headers implementation
  globalThis.Headers = class Headers {
    constructor(init) {
      this[SYMBOLS.headersMap] = new Map();

      if (init) {
        this.#initializeHeaders(init);
      }
    }

    // Validate header name according to HTTP specification
    #validateHeaderName(name) {
      if (typeof name !== 'string' || name === '') {
        throw new TypeError('Invalid header name: must be a non-empty string');
      }

      // Check for invalid characters
      // HTTP header names cannot contain spaces, tabs, newlines, or other control characters
      if (/[\s\x00-\x1F\x7F]/.test(name)) {
        throw new TypeError('Invalid header name: contains invalid characters');
      }
    }

    #initializeHeaders(init) {
      if (init instanceof Headers) {
        for (const [key, value] of init[SYMBOLS.headersMap]) {
          this[SYMBOLS.headersMap].set(key.toLowerCase(), value);
        }
      } else if (Array.isArray(init)) {
        for (const [key, value] of init) {
          this.#validateHeaderName(key);
          this[SYMBOLS.headersMap].set(key.toLowerCase(), String(value));
        }
      } else if (typeof init === 'object') {
        for (const [key, value] of Object.entries(init)) {
          this.#validateHeaderName(key);
          this[SYMBOLS.headersMap].set(key.toLowerCase(), String(value));
        }
      }
    }

    append(name, value) {
      this.#validateHeaderName(name);
      const normalizedName = name.toLowerCase();
      const existing = this[SYMBOLS.headersMap].get(normalizedName);
      const newValue = existing ? `${existing}, ${value}` : String(value);
      this[SYMBOLS.headersMap].set(normalizedName, newValue);
    }

    delete(name) {
      this.#validateHeaderName(name);
      this[SYMBOLS.headersMap].delete(name.toLowerCase());
    }

    get(name) {
      this.#validateHeaderName(name);
      return this[SYMBOLS.headersMap].get(name.toLowerCase()) || null;
    }

    has(name) {
      this.#validateHeaderName(name);
      return this[SYMBOLS.headersMap].has(name.toLowerCase());
    }

    set(name, value) {
      this.#validateHeaderName(name);
      this[SYMBOLS.headersMap].set(name.toLowerCase(), String(value));
    }

    entries() {
      return this[SYMBOLS.headersMap].entries();
    }

    keys() {
      return this[SYMBOLS.headersMap].keys();
    }

    values() {
      return this[SYMBOLS.headersMap].values();
    }

    forEach(callback, thisArg) {
      for (const [key, value] of this[SYMBOLS.headersMap]) {
        callback.call(thisArg, value, key, this);
      }
    }

    [Symbol.iterator]() {
      return this[SYMBOLS.headersMap][Symbol.iterator]();
    }
  };

  // Request - HTTP request representation
  globalThis.Request = class Request {
    #url;
    #method;
    #headers;
    #body;
    #mode;
    #credentials;
    #cache;
    #redirect;
    #referrer;
    #integrity;
    #signal;
    #bodyUsed = false;

    constructor(input, init = {}) {
      if (input instanceof Request) {
        this.#copyFromRequest(input);
      } else {
        this.#initializeFromUrl(String(input), init);
      }
      this[SYMBOLS.requestBodyText] = null;
    }

    #copyFromRequest(request) {
      this.#url = request.url;
      this.#method = request.method;
      this.#headers = new Headers(request.headers);
      this.#body = request.body;
      this.#mode = request.mode;
      this.#credentials = request.credentials;
      this.#cache = request.cache;
      this.#redirect = request.redirect;
      this.#referrer = request.referrer;
      this.#integrity = request.integrity;
      this.#signal = request.signal;
    }

    #initializeFromUrl(url, init) {
      this.#url = url;
      this.#method = (init.method || 'GET').toUpperCase();
      this.#headers = new Headers(init.headers);
      this.#body = init.body || null;
      this.#mode = init.mode || 'cors';
      this.#credentials = init.credentials || 'same-origin';
      this.#cache = init.cache || 'default';
      this.#redirect = init.redirect || 'follow';
      this.#referrer = init.referrer || 'about:client';
      this.#integrity = init.integrity || '';
      this.#signal = init.signal || null;
    }

    // Getters
    get url() { return this.#url; }
    get method() { return this.#method; }
    get headers() { return this.#headers; }
    get body() { return this.#body; }
    get mode() { return this.#mode; }
    get credentials() { return this.#credentials; }
    get cache() { return this.#cache; }
    get redirect() { return this.#redirect; }
    get referrer() { return this.#referrer; }
    get integrity() { return this.#integrity; }
    get signal() { return this.#signal; }
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
      if (this.body instanceof FormData) {
        const multipart = this.body[SYMBOLS.formDataToMultipart]();
        return new TextEncoder().encode(multipart.body).buffer;
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
      this.#originalBody = body || null;
      this.#status = init.status || 200;
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
        start(controller) {
          try {
            if (typeof body === 'string') {
              const encoder = new TextEncoder();
              const bytes = encoder.encode(body);
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

      // Read from stream
      const reader = this.#bodyStream.getReader();
      const chunks = [];
      let totalLength = 0;

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
          totalLength += value.byteLength;
        }

        const result = new Uint8Array(totalLength);
        let offset = 0;
        for (const chunk of chunks) {
          result.set(chunk, offset);
          offset += chunk.byteLength;
        }

        return result.buffer;
      } finally {
        reader.releaseLock();
      }
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

      // Read from stream manually instead of calling arrayBuffer() which would check bodyUsed again
      const reader = this.#bodyStream.getReader();
      const chunks = [];
      let totalLength = 0;

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
          totalLength += value.byteLength;
        }

        const result = new Uint8Array(totalLength);
        let offset = 0;
        for (const chunk of chunks) {
          result.set(chunk, offset);
          offset += chunk.byteLength;
        }

        return new TextDecoder().decode(result);
      } finally {
        reader.releaseLock();
      }
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
    const progressHandler = function (chunk, isComplete) {
      if (aborted || !responseBodyController) return;

      if (chunk && chunk.length > 0) {
        responseBodyController.enqueue(chunk);
      }
      if (isComplete) {
        responseBodyController.close();
        responseBodyController = null;
      }
    };

    try {
      // Race the HTTP request with the abort signal
      const requestPromise = session.httpRequestWithRequest(
        urlRequest,
        bodyStream,       // bodyStream parameter
        progressHandler,  // progressHandler for streaming response
        null              // completionHandler parameter
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

  // FormData - form data representation
  globalThis.FormData = class FormData {
    constructor(form) {
      this[SYMBOLS.formDataData] = new Map();
    }

    append(name, value, filename) {
      const key = String(name);
      if (!this[SYMBOLS.formDataData].has(key)) {
        this[SYMBOLS.formDataData].set(key, []);
      }

      const item = this.#createFormDataItem(value, filename);
      this[SYMBOLS.formDataData].get(key).push(item);
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
      this[SYMBOLS.formDataData].delete(String(name));
    }

    get(name) {
      const values = this[SYMBOLS.formDataData].get(String(name));
      return values?.length > 0 ? values[0].value : null;
    }

    getAll(name) {
      const values = this[SYMBOLS.formDataData].get(String(name));
      return values ? values.map(item => item.value) : [];
    }

    has(name) {
      return this[SYMBOLS.formDataData].has(String(name));
    }

    set(name, value, filename) {
      const key = String(name);
      this[SYMBOLS.formDataData].delete(key);
      this.append(key, value, filename);
    }

    entries() {
      const entries = [];
      for (const [key, values] of this[SYMBOLS.formDataData]) {
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
      for (const [key, values] of this[SYMBOLS.formDataData]) {
        keys.push(...Array(values.length).fill(key));
      }
      return keys[Symbol.iterator]();
    }

    values() {
      const values = [];
      for (const [, items] of this[SYMBOLS.formDataData]) {
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

    [SYMBOLS.formDataToURLEncoded]() {
      const params = [];
      for (const [key, values] of this[SYMBOLS.formDataData]) {
        for (const item of values) {
          const paramValue = item.type === 'string' ? item.value : '[Object]';
          params.push(`${encodeURIComponent(key)}=${encodeURIComponent(paramValue)}`);
        }
      }
      return params.join('&');
    }

    [SYMBOLS.formDataToMultipart]() {
      const boundary = '----SwiftJSFormBoundary-' + crypto.randomUUID();
      let result = '';

      for (const [key, values] of this[SYMBOLS.formDataData]) {
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

  class ReadableStreamDefaultController {
    #stream;
    #internal;
    constructor(stream, underlyingSource) {
      this.#stream = stream;
      // ensure per-stream internal storage exists
      if (!stream[SYMBOLS.streamInternal]) stream[SYMBOLS.streamInternal] = {};
      this.#internal = stream[SYMBOLS.streamInternal];
      this.#internal.underlyingSource = underlyingSource || {};
    }

    enqueue(chunk) {
      if (this.#internal.state !== 'readable') return;
      this.#internal.queue.push(chunk);
      while (this.#internal.readRequests.length > 0 && this.#internal.queue.length > 0) {
        const { resolve } = this.#internal.readRequests.shift();
        const value = this.#internal.queue.shift();
        resolve({ value, done: false });
      }
    }

    close() {
      if (this.#internal.state !== 'readable') return;
      this.#internal.state = 'closed';
      while (this.#internal.readRequests.length > 0) {
        const { resolve } = this.#internal.readRequests.shift();
        resolve({ value: undefined, done: true });
      }
    }

    error(err) {
      if (this.#internal.state !== 'readable') return;
      this.#internal.state = 'errored';
      this.#internal.storedError = err;
      while (this.#internal.readRequests.length > 0) {
        const { reject } = this.#internal.readRequests.shift();
        reject(err);
      }
    }
  }

  globalThis.ReadableStream = class ReadableStream {
    constructor(underlyingSource = {}, strategy) {
      // Per-instance internal storage
      this[SYMBOLS.streamInternal] = {
        underlyingSource: underlyingSource,
        strategy: strategy || {},
        queue: [],
        readRequests: [],
        state: 'readable',
        storedError: undefined,
        controller: null,
        pulling: false
      };

      // create controller and store reference
      const controller = new ReadableStreamDefaultController(this, underlyingSource);
      this[SYMBOLS.streamInternal].controller = controller;

      if (underlyingSource.start) {
        try { underlyingSource.start(controller); } catch (e) { controller.error(e); }
      }
    }

    getReader() {
      const stream = this;
      return new (class ReadableStreamDefaultReader {
        #released = false;
        constructor() { this.#released = false; }

        read() {
          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'errored') return Promise.reject(s.storedError);
          if (s.queue.length > 0) {
            const value = s.queue.shift();
            return Promise.resolve({ value, done: false });
          }
          if (s.state === 'closed') return Promise.resolve({ value: undefined, done: true });
          
          const deferred = createDeferred();
          s.readRequests.push(deferred);
          
          // CRITICAL FIX: Call the pull method if available to generate more data
          if (s.underlyingSource && s.underlyingSource.pull && !s.pulling) {
            s.pulling = true;
            try {
              const pullResult = s.underlyingSource.pull(s.controller);
              if (pullResult && typeof pullResult.then === 'function') {
                pullResult.then(() => { s.pulling = false; }).catch(e => { s.pulling = false; s.controller.error(e); });
              } else {
                s.pulling = false;
              }
            } catch (e) {
              s.pulling = false;
              s.controller.error(e);
            }
          }
          
          return deferred.promise;
        }

        releaseLock() { this.#released = true; }

        cancel(reason) {
          const s = stream[SYMBOLS.streamInternal];
          s.readRequests.forEach(r => r.reject(reason));
          s.readRequests = [];
          if (s.underlyingSource && s.underlyingSource.cancel) {
            try { return Promise.resolve(s.underlyingSource.cancel(reason)); } catch (e) { return Promise.reject(e); }
          }
          return Promise.resolve();
        }
      })();
    }

    tee() {
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
          cleanup();

          // Handle different error scenarios
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

          throw error;
        }
      }

      return pipeLoop();
    }
  }

  class WritableStreamDefaultController {
    #stream;
    #internal;
    constructor(stream, underlyingSink) {
      this.#stream = stream;
      if (!stream[SYMBOLS.streamInternal]) stream[SYMBOLS.streamInternal] = {};
      this.#internal = stream[SYMBOLS.streamInternal];
      this.#internal.underlyingSink = underlyingSink || {};
    }

    error(err) {
      this.#internal.state = 'errored';
      this.#internal.storedError = err;
    }
  }

  globalThis.WritableStream = class WritableStream {
    constructor(underlyingSink = {}, strategy) {
      // per-instance internal storage
      this[SYMBOLS.streamInternal] = {
        underlyingSink: underlyingSink,
        strategy: strategy || {},
        state: 'writable',
        storedError: undefined,
        controller: null,
        writing: false,
        writeQueue: []
      };

      const controller = new WritableStreamDefaultController(this, underlyingSink);
      this[SYMBOLS.streamInternal].controller = controller;
    }

    getWriter() {
      const stream = this;
      return new (class WritableStreamDefaultWriter {
        write(chunk) {
          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'errored') return Promise.reject(s.storedError);
          if (s.state === 'closed') return Promise.reject(new TypeError('Cannot write to closed stream'));
          const promise = new Promise((resolve, reject) => {
            s.writeQueue.push({ chunk, resolve, reject });
            scheduleWrite();
          });
          function scheduleWrite() {
            if (s.writing) return;
            const item = s.writeQueue.shift();
            if (!item) return;
            s.writing = true;
            try {
              const underlying = s.underlyingSink;
              const r = underlying && underlying.write ? underlying.write(item.chunk) : Promise.resolve();
              Promise.resolve(r).then(() => {
                s.writing = false;
                item.resolve();
                scheduleWrite();
              }, (e) => {
                s.writing = false;
                item.reject(e);
                s.controller.error(e);
              });
            } catch (e) {
              s.writing = false;
              item.reject(e);
              s.controller.error(e);
            }
          }
          return promise;
        }

        close() {
          const s = stream[SYMBOLS.streamInternal];
          if (s.state === 'errored') return Promise.reject(s.storedError);
          if (s.underlyingSink && s.underlyingSink.close) {
            try { const r = s.underlyingSink.close(); s.state = 'closed'; return Promise.resolve(r); } catch (e) { s.controller.error(e); return Promise.reject(e); }
          }
          s.state = 'closed';
          return Promise.resolve();
        }

        abort(reason) {
          const s = stream[SYMBOLS.streamInternal];
          if (s.underlyingSink && s.underlyingSink.abort) {
            try { return Promise.resolve(s.underlyingSink.abort(reason)); } catch (e) { return Promise.reject(e); }
          }
          s.state = 'errored';
          s.storedError = reason instanceof Error ? reason : new Error(String(reason));
          return Promise.resolve();
        }

        releaseLock() {
          // Method to release the writer lock, allowing other writers to be obtained
        }
      })();
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
        writableController: null
      };

      const ts = this;

      const readable = new ReadableStream({
        start(controller) {
          ts[SYMBOLS.streamInternal].readableController = controller;
        },
        transform(chunk, controller) {
          try {
            if (transformer.transform) {
              const result = transformer.transform(chunk, ts[SYMBOLS.streamInternal].readableController);
              return Promise.resolve(result);
            }
            ts[SYMBOLS.streamInternal].readableController.enqueue(chunk);
            return Promise.resolve();
          } catch (e) {
            ts[SYMBOLS.streamInternal].readableController.error(e);
            return Promise.reject(e);
          }
        },
        flush(controller) {
          if (transformer.flush) {
            return transformer.flush(ts[SYMBOLS.streamInternal].readableController);
          }
        }
      }, readableStrategy);

      const writable = new WritableStream({
        start(controller) {
          ts[SYMBOLS.streamInternal].writableController = controller;
        },
        write(chunk) {
          try {
            if (transformer.transform) {
              const result = transformer.transform(chunk, ts[SYMBOLS.streamInternal].readableController);
              return Promise.resolve(result);
            }
            ts[SYMBOLS.streamInternal].readableController.enqueue(chunk);
            return Promise.resolve();
          } catch (e) {
            ts[SYMBOLS.streamInternal].readableController.error(e);
            return Promise.reject(e);
          }
        },
        close() { ts[SYMBOLS.streamInternal].readableController.close(); },
        abort(reason) { ts[SYMBOLS.streamInternal].readableController.error(reason); }
      }, writableStrategy);

      this[SYMBOLS.streamInternal].readable = readable;
      this[SYMBOLS.streamInternal].writable = writable;
    }

    get readable() { return this[SYMBOLS.streamInternal].readable; }
    get writable() { return this[SYMBOLS.streamInternal].writable; }
  }
})();