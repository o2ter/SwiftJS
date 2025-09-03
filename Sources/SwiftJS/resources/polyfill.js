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
    abortSignalMarkAborted: Symbol('AbortSignal._markAborted')
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

    addEventListener(type, listener) {
      if (!this.#listeners[type]) {
        this.#listeners[type] = [];
      }
      this.#listeners[type].push(listener);
    }

    removeEventListener(type, listener) {
      if (!this.#listeners[type]) return;
      this.#listeners[type] = this.#listeners[type].filter(l => l !== listener);
    }

    dispatchEvent(event) {
      if (!this.#listeners[event.type]) return;
      for (const listener of this.#listeners[event.type]) {
        listener(event);
      }
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
  };

  // File - extends Blob with file metadata
  globalThis.File = class File extends Blob {
    #name;
    #lastModified;

    constructor(parts, name, options = {}) {
      super(parts, options);
      this.#name = String(name || '');
      this.#lastModified = options.lastModified || Date.now();
      this[Symbol.toStringTag] = 'File';
    }

    get name() { return this.#name; }
    get lastModified() { return this.#lastModified; }
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
      const promise = session.dataTaskWithRequestCompletionHandler(this.#request, null);

      promise
        .then(result => this.#handleResponse(result))
        .catch(error => this.#handleError(error));
    }

    #setRequestBody(body) {
      if (!body) return;

      if (body instanceof FormData) {
        const multipart = body[SYMBOLS.formDataToMultipart]();
        this.#request.httpBody = multipart.body;
        if (!this.#requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', `multipart/form-data; boundary=${multipart.boundary}`);
        }
      } else if (typeof body === 'string') {
        this.#request.httpBody = body;
        if (!this.#requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', 'text/plain;charset=UTF-8');
        }
      } else if (body instanceof ArrayBuffer || ArrayBuffer.isView(body)) {
        this.#request.httpBody = new Uint8Array(body);
        if (!this.#requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', 'application/octet-stream');
        }
      }
    }

    #handleResponse(result) {
      if (this.#aborted) return;

      this.#response = result.response;
      this.#status = result.response.statusCode;
      this.#statusText = this.#getStatusText(this.#status);
      this.#responseURL = result.response.url || this.#url;

      this.#setResponseData(result.data);
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

    #initializeHeaders(init) {
      if (init instanceof Headers) {
        for (const [key, value] of init[SYMBOLS.headersMap]) {
          this[SYMBOLS.headersMap].set(key.toLowerCase(), value);
        }
      } else if (Array.isArray(init)) {
        for (const [key, value] of init) {
          this[SYMBOLS.headersMap].set(key.toLowerCase(), String(value));
        }
      } else if (typeof init === 'object') {
        for (const [key, value] of Object.entries(init)) {
          this[SYMBOLS.headersMap].set(key.toLowerCase(), String(value));
        }
      }
    }

    append(name, value) {
      const normalizedName = name.toLowerCase();
      const existing = this[SYMBOLS.headersMap].get(normalizedName);
      const newValue = existing ? `${existing}, ${value}` : String(value);
      this[SYMBOLS.headersMap].set(normalizedName, newValue);
    }

    delete(name) {
      this[SYMBOLS.headersMap].delete(name.toLowerCase());
    }

    get(name) {
      return this[SYMBOLS.headersMap].get(name.toLowerCase()) || null;
    }

    has(name) {
      return this[SYMBOLS.headersMap].has(name.toLowerCase());
    }

    set(name, value) {
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
      this.#statusText = init.statusText || '';
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

  // fetch - HTTP request function
  globalThis.fetch = async function fetch(input, init = {}) {
    const request = new Request(input, init);
    const urlRequest = new __APPLE_SPEC__.URLRequest(request.url);
    urlRequest.httpMethod = request.method;

    // Set headers
    for (const [key, value] of request.headers) {
      urlRequest.setValueForHTTPHeaderField(value, key);
    }

    // Set body
    if (request.body) {
      if (request.body instanceof FormData) {
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
      } else if (request.body instanceof ReadableStream) {
        // Handle streaming request body
        const reader = request.body.getReader();
        const chunks = [];
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            chunks.push(value);
          }
          // Concatenate all chunks
          let totalLength = 0;
          chunks.forEach(chunk => totalLength += chunk.byteLength);
          const combined = new Uint8Array(totalLength);
          let offset = 0;
          chunks.forEach(chunk => {
            combined.set(chunk, offset);
            offset += chunk.byteLength;
          });
          urlRequest.httpBody = combined;
        } finally {
          reader.releaseLock();
        }
      }
    }

    const session = __APPLE_SPEC__.URLSession.shared();
    const result = await session.dataTaskWithRequestCompletionHandler(urlRequest, null);

    // Create response with the raw data, not a stream
    // The Response constructor will create the appropriate stream internally
    const response = new Response(result.data, {
      status: result.response.statusCode,
      statusText: '',
      headers: result.response.allHeaderFields,
      url: result.response.url || request.url
    });

    return response;
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