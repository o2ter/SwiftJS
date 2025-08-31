; (function () {
  // Module-scoped symbols for internal, non-public APIs
  const formDataData = Symbol('FormData._data');
  const formDataToMultipart = Symbol('FormData._toMultipartString');
  const formDataToURLEncoded = Symbol('FormData._toURLEncoded');
  const blobParts = Symbol('Blob._parts');
  const blobType = Symbol('Blob._type');
  const blobPlaceholderPromise = Symbol('Blob._placeholderPromise');
  const headersMap = Symbol('Headers._headers');
  const requestBodyText = Symbol('Request._bodyText');

  globalThis.process = new class Process {

    #env = { ...__APPLE_SPEC__.processInfo.environment };
    #argv = [...__APPLE_SPEC__.processInfo.arguments];

    get env() {
      return this.#env;
    }

    get argv() {
      return this.#argv;
    }

    get pid() {
      return __APPLE_SPEC__.processInfo.processIdentifier;
    }

    cwd() {
      return __APPLE_SPEC__.FileSystem.currentDirectoryPath();
    }

    chdir(directory) {
      return __APPLE_SPEC__.FileSystem.changeCurrentDirectoryPath(directory);
    }
  }

  globalThis.Event = class Event {
    constructor(type, options) {
      this.type = type;
      this.target = null;
      this.currentTarget = null;
      this.eventPhase = 0;
      this.bubbles = options?.bubbles || false;
      this.cancelable = options?.cancelable || false;
    }
    stopPropagation() {
      this.eventPhase = 1;
    }
    preventDefault() {
      if (this.cancelable) {
        this.defaultPrevented = true;
      }
    }
  }

  globalThis.EventTarget = class EventTarget {
    #listeners;
    constructor() {
      this.#listeners = {};
    }
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
  }

  globalThis.AbortSignal = class AbortSignal extends EventTarget {
    #aborted;
    #onabort;
    constructor() {
      super();
      this.#aborted = false;
    }
    get aborted() {
      return this.#aborted;
    }
    get onabort() {
      return this.#onabort;
    }
    set onabort(listener) {
      const existing = this.#onabort;
      if (existing) {
        this.removeEventListener("abort", existing);
      }
      this.#onabort = callback;
      this.addEventListener("abort", callback);
    }
  }

  globalThis.AbortController = class AbortController {
    #signal;
    constructor() {
      this.#signal = new AbortSignal();
    }
    get signal() {
      return this.#signal;
    }
    abort() {
      const signal = this.signal;
      if (!signal.aborted) {
        signal._aborted = true;
        signal.dispatchEvent(new Event("abort"));
      }
    }
  }

  globalThis.crypto = new class Crypto {
    randomUUID() {
      return __APPLE_SPEC__.crypto.randomUUID();
    }
    randomBytes(length) {
      if (!Number.isSafeInteger(length) || length < 0) {
        throw Error('Invalid length');
      }
      return __APPLE_SPEC__.crypto.randomBytes(length);
    }
    getRandomValues(b) {
      if (!ArrayBuffer.isView(b)) {
        throw Error('Invalid type of buffer');
      }
      const bytes = b instanceof Uint8Array ? b : new Uint8Array(b.buffer, b.byteOffset, b.byteLength);
      __APPLE_SPEC__.crypto.getRandomValues(bytes);
      return b;
    }
  }

  // TextEncoder and TextDecoder implementation
  globalThis.TextEncoder = class TextEncoder {
    constructor(encoding = 'utf-8') {
      this.encoding = encoding;
    }

    static #byteLength(string) {
      if (string == null) return 0;
      if (typeof string !== 'string') string = String(string);
      let len = 0;
      for (let i = 0; i < string.length; i++) {
        let c = string.charCodeAt(i);
        if (c < 0x80) {
          len += 1;
        } else if (c < 0x800) {
          len += 2;
        } else if ((c & 0xFC00) === 0xD800 && i + 1 < string.length && (string.charCodeAt(i + 1) & 0xFC00) === 0xDC00) {
          // surrogate pair
          i++;
          len += 4;
        } else {
          len += 3;
        }
      }
      return len;
    }

    encode(string) {
      const utf8 = new Uint8Array(TextEncoder.#byteLength(string));
      let i = 0;
      for (let ci = 0; ci !== string.length; ci++) {
        let c = string.charCodeAt(ci);
        if (c < 128) {
          utf8[i++] = c;
          continue;
        }
        if (c < 2048) {
          utf8[i++] = c >> 6 | 192;
        } else {
          if ((c & 0xFC00) === 0xD800 && ci + 1 < string.length && (string.charCodeAt(ci + 1) & 0xFC00) === 0xDC00) {
            c = 0x10000 + ((c & 0x03FF) << 10) + (string.charCodeAt(++ci) & 0x03FF);
            utf8[i++] = c >> 18 | 240;
            utf8[i++] = c >> 12 & 63 | 128;
          } else {
            utf8[i++] = c >> 12 | 224;
          }
          utf8[i++] = c >> 6 & 63 | 128;
        }
        utf8[i++] = c & 63 | 128;
      }
      return utf8.subarray(0, i);
    }
  };

  globalThis.TextDecoder = class TextDecoder {
    constructor(encoding = 'utf-8') {
      this.encoding = encoding;
    }

    decode(uint8Array) {
      if (!uint8Array) return '';
      const bytes = uint8Array instanceof Uint8Array ? uint8Array : new Uint8Array(uint8Array);
      let result = '';
      let i = 0;

      while (i < bytes.length) {
        let byte1 = bytes[i++];

        if (byte1 < 128) {
          result += String.fromCharCode(byte1);
        } else if ((byte1 >> 5) === 6) {
          let byte2 = bytes[i++];
          result += String.fromCharCode(((byte1 & 31) << 6) | (byte2 & 63));
        } else if ((byte1 >> 4) === 14) {
          let byte2 = bytes[i++];
          let byte3 = bytes[i++];
          result += String.fromCharCode(((byte1 & 15) << 12) | ((byte2 & 63) << 6) | (byte3 & 63));
        } else if ((byte1 >> 3) === 30) {
          let byte2 = bytes[i++];
          let byte3 = bytes[i++];
          let byte4 = bytes[i++];
          let codePoint = ((byte1 & 7) << 18) | ((byte2 & 63) << 12) | ((byte3 & 63) << 6) | (byte4 & 63);
          codePoint -= 0x10000;
          result += String.fromCharCode(0xD800 + (codePoint >> 10), 0xDC00 + (codePoint & 1023));
        }
      }
      return result;
    }
  };

  // Minimal Blob / File implementation
  // Supports parts made of: string, ArrayBuffer, TypedArray, Blob
  globalThis.Blob = class Blob {
    constructor(parts = [], options = {}) {
      this[blobParts] = Array.isArray(parts) ? parts.slice() : [parts];
      this.type = (options && options.type) ? String(options.type).toLowerCase() : '';
      this.size = 0;
      const encoder = new TextEncoder();
      for (const part of this[blobParts]) {
        if (typeof part === 'string') {
          this.size += encoder.encode(part).length;
        } else if (part instanceof ArrayBuffer) {
          this.size += part.byteLength;
        } else if (ArrayBuffer.isView(part)) {
          this.size += part.byteLength;
        } else if (part && typeof part === 'object' && part.constructor && part.constructor.name === 'Blob') {
          this.size += part.size || 0;
        } else if (part == null) {
          // ignore
        } else {
          // fallback to string conversion
          const s = String(part);
          this.size += encoder.encode(s).length;
        }
      }
      // Common web API fields
      this[blobType] = this.type;
      this[Symbol.toStringTag] = 'Blob';
    }

    async arrayBuffer() {
      const encoder = new TextEncoder();
      const chunks = [];
      let total = 0;

      for (const part of this[blobParts]) {
        if (typeof part === 'string') {
          const u = encoder.encode(part);
          chunks.push(u);
          total += u.length;
        } else if (part instanceof ArrayBuffer) {
          const u = new Uint8Array(part);
          chunks.push(u);
          total += u.byteLength;
        } else if (ArrayBuffer.isView(part)) {
          const view = new Uint8Array(part.buffer, part.byteOffset, part.byteLength);
          chunks.push(view);
          total += view.byteLength;
        } else if (part && typeof part === 'object' && part.constructor && part.constructor.name === 'Blob') {
          const buff = await part.arrayBuffer();
          const u = new Uint8Array(buff);
          chunks.push(u);
          total += u.byteLength;
        } else if (part == null) {
          // skip
        } else {
          const u = encoder.encode(String(part));
          chunks.push(u);
          total += u.length;
        }
      }

      const result = new Uint8Array(total);
      let offset = 0;
      for (const c of chunks) {
        result.set(c, offset);
        offset += c.byteLength;
      }

      return result.buffer;
    }

    async text() {
      const buffer = await this.arrayBuffer();
      return new TextDecoder().decode(new Uint8Array(buffer));
    }

    slice(start = 0, end = undefined, contentType = '') {
      // Normalize bounds
      const size = this.size || 0;
      let relativeStart = start < 0 ? Math.max(size + start, 0) : Math.min(start, size);
      let relativeEnd = end === undefined ? size : (end < 0 ? Math.max(size + end, 0) : Math.min(end, size));
      const span = Math.max(relativeEnd - relativeStart, 0);

      if (span === 0) return new Blob([], { type: contentType });

      // Create a single-arrayBuffer and slice it
      const self = this;
      const sliced = (async function () {
        const buffer = await self.arrayBuffer();
        const u = new Uint8Array(buffer, relativeStart, span);
        return new Blob([u], { type: contentType });
      })();

      // Return a Blob that will resolve its data when asked.
      // For simplicity, return a Blob whose parts include an async placeholder Blob.
      // The returned Blob should behave synchronously for size/type but arrayBuffer() will work.
      const placeholder = new Blob([], { type: contentType });
      // store the async part so placeholder.arrayBuffer() will use it
      placeholder[blobParts] = [{
        __asyncBlob: true,
        [blobPlaceholderPromise]: sliced
      }];
      placeholder.size = span;
      return placeholder;
    }
  };

  // Adjust Blob.arrayBuffer to handle async placeholder parts created by slice
  const _originalBlobArrayBuffer = globalThis.Blob.prototype.arrayBuffer;
  globalThis.Blob.prototype.arrayBuffer = async function () {
    // If parts include async placeholders, await them
    if (this[blobParts] && this[blobParts].some(p => p && p.__asyncBlob)) {
      const resolved = [];
      for (const p of this[blobParts]) {
        if (p && p.__asyncBlob) {
          const b = await p[blobPlaceholderPromise];
          // b is a Blob
          const buff = await b.arrayBuffer();
          resolved.push(new Uint8Array(buff));
        } else {
          resolved.push(p);
        }
      }
      // temporarily replace parts and call original
      const old = this[blobParts];
      this[blobParts] = resolved;
      try {
        return await _originalBlobArrayBuffer.call(this);
      } finally {
        this[blobParts] = old;
      }
    }

    return await _originalBlobArrayBuffer.call(this);
  };

  // File extends Blob
  globalThis.File = class File extends Blob {
    constructor(parts, name, options = {}) {
      super(parts, options);
      this.name = String(name || '');
      this.lastModified = options.lastModified || Date.now();
      this[Symbol.toStringTag] = 'File';
    }
  };

  // XMLHttpRequest implementation
  globalThis.XMLHttpRequest = class XMLHttpRequest extends EventTarget {
    static UNSENT = 0;
    static OPENED = 1;
    static HEADERS_RECEIVED = 2;
    static LOADING = 3;
    static DONE = 4;
    #method = null;
    #url = null;
    #async = true;
    #request = null;
    #requestHeaders = {};
    #response = null;
    #aborted = false;

    constructor() {
      super();
      this.readyState = XMLHttpRequest.UNSENT;
      this.status = 0;
      this.statusText = '';
      this.response = null;
      this.responseText = '';
      this.responseType = '';
      this.responseURL = '';
      this.responseXML = null;
      this.timeout = 0;
      this.upload = new EventTarget();
      this.withCredentials = false;

      this.#method = null;
      this.#url = null;
      this.#async = true;
      this.#request = null;
      this.#requestHeaders = {};
      this.#response = null;
      this.#aborted = false;

      this.onreadystatechange = null;
      this.onabort = null;
      this.onerror = null;
      this.onload = null;
      this.onloadend = null;
      this.onloadstart = null;
      this.onprogress = null;
      this.ontimeout = null;
    }

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

      if (body !== null) {
        if (body instanceof FormData) {
          const multipart = body[formDataToMultipart]();
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

      this.#setReadyState(XMLHttpRequest.LOADING);
      this.#dispatchEvent('loadstart');

      const session = __APPLE_SPEC__.URLSession.getShared();
      const promise = session.dataTaskWithRequestCompletionHandler(this.#request, null);

      promise.then((result) => {
        if (this.#aborted) return;

        this.#response = result.response;
        this.status = result.response.statusCode;
        this.statusText = this.#getStatusText(this.status);
        this.responseURL = result.response.url || this.#url;

        // Set response based on responseType
        const data = result.data;
        if (this.responseType === '' || this.responseType === 'text') {
          this.responseText = new TextDecoder().decode(data);
          this.response = this.responseText;
        } else if (this.responseType === 'arraybuffer') {
          this.response = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
          this.responseText = '';
        } else if (this.responseType === 'blob') {
          this.response = new Blob([data]);
          this.responseText = '';
        } else if (this.responseType === 'json') {
          try {
            const text = new TextDecoder().decode(data);
            this.response = JSON.parse(text);
            this.responseText = '';
          } catch (e) {
            this.response = null;
            this.responseText = '';
          }
        }

        this.#setReadyState(XMLHttpRequest.DONE);
        this.#dispatchEvent('load');
        this.#dispatchEvent('loadend');
      }).catch((error) => {
        if (this.#aborted) return;

        this.#setReadyState(XMLHttpRequest.DONE);
        this.#dispatchEvent('error');
        this.#dispatchEvent('loadend');
      });
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
      return Object.keys(headers).map(key => `${key}: ${headers[key]}`).join('\r\n') + '\r\n';
    }

    overrideMimeType(mime) {
      // Not implemented for now
    }

    #setReadyState(state) {
      this.readyState = state;
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

  // Headers implementation
  globalThis.Headers = class Headers {
    constructor(init) {
      this[headersMap] = new Map();
      if (init) {
        if (init instanceof Headers) {
          for (const [key, value] of init[headersMap]) {
            this[headersMap].set(key.toLowerCase(), value);
          }
        } else if (Array.isArray(init)) {
          for (const [key, value] of init) {
            this[headersMap].set(key.toLowerCase(), String(value));
          }
        } else if (typeof init === 'object') {
          for (const [key, value] of Object.entries(init)) {
            this[headersMap].set(key.toLowerCase(), String(value));
          }
        }
      }
    }

    append(name, value) {
      const normalizedName = name.toLowerCase();
      const existing = this[headersMap].get(normalizedName);
      if (existing) {
        this[headersMap].set(normalizedName, `${existing}, ${value}`);
      } else {
        this[headersMap].set(normalizedName, String(value));
      }
    }

    delete(name) {
      this[headersMap].delete(name.toLowerCase());
    }

    entries() {
      return this[headersMap].entries();
    }

    forEach(callback, thisArg) {
      for (const [key, value] of this[headersMap]) {
        callback.call(thisArg, value, key, this);
      }
    }

    get(name) {
      return this[headersMap].get(name.toLowerCase()) || null;
    }

    has(name) {
      return this[headersMap].has(name.toLowerCase());
    }

    keys() {
      return this[headersMap].keys();
    }

    set(name, value) {
      this[headersMap].set(name.toLowerCase(), String(value));
    }

    values() {
      return this[headersMap].values();
    }

    [Symbol.iterator]() {
      return this[headersMap][Symbol.iterator]();
    }
  };

  // Request implementation  
  globalThis.Request = class Request {
    constructor(input, init = {}) {
      if (input instanceof Request) {
        this.url = input.url;
        this.method = input.method;
        this.headers = new Headers(input.headers);
        this.body = input.body;
        this.mode = input.mode;
        this.credentials = input.credentials;
        this.cache = input.cache;
        this.redirect = input.redirect;
        this.referrer = input.referrer;
        this.integrity = input.integrity;
      } else {
        this.url = String(input);
        this.method = (init.method || 'GET').toUpperCase();
        this.headers = new Headers(init.headers);
        this.body = init.body || null;
        this.mode = init.mode || 'cors';
        this.credentials = init.credentials || 'same-origin';
        this.cache = init.cache || 'default';
        this.redirect = init.redirect || 'follow';
        this.referrer = init.referrer || 'about:client';
        this.integrity = init.integrity || '';
      }

      this.bodyUsed = false;
      this[requestBodyText] = null;
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
      this.bodyUsed = true;

      if (!this.body) return new ArrayBuffer(0);
      if (this.body instanceof ArrayBuffer) return this.body;
      if (this.body instanceof FormData) {
        const multipart = this.body[formDataToMultipart]();
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
      this.bodyUsed = true;

      if (!this.body) return '';
      if (typeof this.body === 'string') return this.body;
      if (this.body instanceof FormData) {
        const multipart = this.body[formDataToMultipart]();
        return multipart.body;
      }

      const buffer = await this.arrayBuffer();
      return new TextDecoder().decode(buffer);
    }
  };

  // Response implementation
  globalThis.Response = class Response {
    constructor(body, init = {}) {
      this.body = body || null;
      this.status = init.status || 200;
      this.statusText = init.statusText || '';
      this.headers = new Headers(init.headers);
      this.url = init.url || '';
      this.redirected = init.redirected || false;
      this.type = init.type || 'default';
      this.ok = this.status >= 200 && this.status < 300;
      this.bodyUsed = false;
    }

    static error() {
      const response = new Response(null, { status: 0, statusText: '' });
      response.type = 'error';
      return response;
    }

    static redirect(url, status = 302) {
      const response = new Response(null, { status, headers: { Location: url } });
      response.type = 'opaqueredirect';
      return response;
    }

    clone() {
      if (this.bodyUsed) {
        throw new TypeError('Cannot clone a Response whose body has already been read');
      }
      return new Response(this.body, {
        status: this.status,
        statusText: this.statusText,
        headers: this.headers,
        url: this.url,
        redirected: this.redirected,
        type: this.type
      });
    }

    async arrayBuffer() {
      if (this.bodyUsed) {
        throw new TypeError('Body has already been read');
      }
      this.bodyUsed = true;

      if (!this.body) return new ArrayBuffer(0);
      if (this.body instanceof ArrayBuffer) return this.body;
      if (this.body instanceof Uint8Array) {
        return this.body.buffer.slice(this.body.byteOffset, this.body.byteOffset + this.body.byteLength);
      }
      if (this.body instanceof FormData) {
        const multipart = this.body[formDataToMultipart]();
        return new TextEncoder().encode(multipart.body).buffer;
      }
      if (typeof this.body === 'string') {
        return new TextEncoder().encode(this.body).buffer;
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
      this.bodyUsed = true;

      if (!this.body) return '';
      if (typeof this.body === 'string') return this.body;
      if (this.body instanceof Uint8Array) {
        return new TextDecoder().decode(this.body);
      }
      if (this.body instanceof FormData) {
        const multipart = this.body[formDataToMultipart]();
        return multipart.body;
      }

      const buffer = await this.arrayBuffer();
      return new TextDecoder().decode(buffer);
    }
  };

  // fetch implementation
  globalThis.fetch = async function fetch(input, init = {}) {
    const request = new Request(input, init);

    const urlRequest = new __APPLE_SPEC__.URLRequest(request.url);
    urlRequest.httpMethod = request.method;

    // Set headers
    for (const [key, value] of request.headers) {
      urlRequest.setValueForHTTPHeaderField(value, key);
    }

    // Set body
    // Set body
    if (request.body) {
      if (request.body instanceof FormData) {
        const multipart = request.body[formDataToMultipart]();
        urlRequest.httpBody = multipart.body;
        urlRequest.setValueForHTTPHeaderField(`multipart/form-data; boundary=${multipart.boundary}`, 'Content-Type');
      } else if (typeof request.body === 'string') {
        urlRequest.httpBody = request.body;
      } else if (request.body instanceof ArrayBuffer || ArrayBuffer.isView(request.body)) {
        urlRequest.httpBody = new Uint8Array(request.body);
      }
    }

    const session = __APPLE_SPEC__.URLSession.getShared();
    const result = await session.dataTaskWithRequestCompletionHandler(urlRequest, null);

    const response = new Response(result.data, {
      status: result.response.statusCode,
      statusText: '',
      headers: result.response.allHeaderFields,
      url: result.response.url || request.url
    });

    return response;
  };

  // FormData implementation (internals hidden via module-scoped Symbols)
  globalThis.FormData = class FormData {
    constructor(form) {
      this[formDataData] = new Map();
    }

    append(name, value, filename) {
      const key = String(name);

      if (!this[formDataData].has(key)) {
        this[formDataData].set(key, []);
      }

      if (value && typeof value === 'object' && value.constructor && value.constructor.name === 'File') {
        // Handle File objects
        this[formDataData].get(key).push({
          type: 'file',
          value: value,
          filename: filename || value.name || 'blob'
        });
      } else if (value && typeof value === 'object' && value.constructor && value.constructor.name === 'Blob') {
        // Handle Blob objects
        this[formDataData].get(key).push({
          type: 'blob',
          value: value,
          filename: filename || 'blob'
        });
      } else {
        // Handle string values
        this[formDataData].get(key).push({
          type: 'string',
          value: String(value),
          filename: null
        });
      }
    }

    delete(name) {
      this[formDataData].delete(String(name));
    }

    entries() {
      const entries = [];
      for (const [key, values] of this[formDataData]) {
        for (const item of values) {
          if (item.type === 'file' || item.type === 'blob') {
            entries.push([key, item.value, item.filename]);
          } else {
            entries.push([key, item.value]);
          }
        }
      }
      return entries[Symbol.iterator]();
    }

    forEach(callback, thisArg) {
      for (const [key, value] of this.entries()) {
        callback.call(thisArg, value, key, this);
      }
    }

    get(name) {
      const values = this[formDataData].get(String(name));
      if (!values || values.length === 0) {
        return null;
      }
      return values[0].value;
    }

    getAll(name) {
      const values = this[formDataData].get(String(name));
      if (!values) {
        return [];
      }
      return values.map(item => item.value);
    }

    has(name) {
      return this[formDataData].has(String(name));
    }

    keys() {
      const keys = [];
      for (const [key, values] of this[formDataData]) {
        for (let i = 0; i < values.length; i++) {
          keys.push(key);
        }
      }
      return keys[Symbol.iterator]();
    }

    set(name, value, filename) {
      const key = String(name);
      this[formDataData].delete(key);
      this.append(key, value, filename);
    }

    values() {
      const values = [];
      for (const [key, items] of this[formDataData]) {
        for (const item of items) {
          values.push(item.value);
        }
      }
      return values[Symbol.iterator]();
    }

    [Symbol.iterator]() {
      return this.entries();
    }

    // (multipart helper implemented via symbol method below)

    // Convert FormData to URL-encoded string
    [formDataToURLEncoded]() {
      const params = [];
      for (const [key, values] of this[formDataData]) {
        for (const item of values) {
          if (item.type === 'string') {
            params.push(encodeURIComponent(key) + '=' + encodeURIComponent(item.value));
          } else {
            // Files and blobs are typically not supported in URL-encoded format
            params.push(encodeURIComponent(key) + '=' + encodeURIComponent('[Object]'));
          }
        }
      }

      return params.join('&');
    }

    // expose the multipart helper via symbol to keep module-local privacy
    [formDataToMultipart]() {
      const boundary = '----formdata-swiftjs-' + Math.random().toString(36).substr(2, 16);
      let result = '';

      for (const [key, values] of this[formDataData]) {
        for (const item of values) {
          result += `--${boundary}\r\n`;

          if (item.type === 'file' || item.type === 'blob') {
            const filename = item.filename || 'blob';
            const contentType = item.value.type || 'application/octet-stream';
            result += `Content-Disposition: form-data; name="${key}"; filename="${filename}"\r\n`;
            result += `Content-Type: ${contentType}\r\n\r\n`;

            if (item.value.arrayBuffer) {
              result += '[Binary Data]\r\n';
            } else {
              result += String(item.value) + '\r\n';
            }
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
    constructor(stream, underlyingSource) {
      this._stream = stream;
      this._underlyingSource = underlyingSource || {};
    }

    enqueue(chunk) {
      if (this._stream._state !== 'readable') return;
      this._stream._queue.push(chunk);
      while (this._stream._readRequests.length > 0 && this._stream._queue.length > 0) {
        const { resolve } = this._stream._readRequests.shift();
        const value = this._stream._queue.shift();
        resolve({ value, done: false });
      }
    }

    close() {
      if (this._stream._state !== 'readable') return;
      this._stream._state = 'closed';
      while (this._stream._readRequests.length > 0) {
        const { resolve } = this._stream._readRequests.shift();
        resolve({ value: undefined, done: true });
      }
    }

    error(err) {
      if (this._stream._state !== 'readable') return;
      this._stream._state = 'errored';
      this._stream._storedError = err;
      while (this._stream._readRequests.length > 0) {
        const { reject } = this._stream._readRequests.shift();
        reject(err);
      }
    }
  }

  globalThis.ReadableStream = class ReadableStream {
    constructor(underlyingSource = {}, strategy) {
      this._underlyingSource = underlyingSource;
      this._strategy = strategy || {};
      this._queue = [];
      this._readRequests = [];
      this._state = 'readable';
      this._storedError = undefined;

      this._controller = new ReadableStreamDefaultController(this, underlyingSource);

      if (underlyingSource.start) {
        try { underlyingSource.start(this._controller); } catch (e) { this._controller.error(e); }
      }
    }

    getReader() {
      const stream = this;
      return new (class ReadableStreamDefaultReader {
        constructor() { this._released = false; }

        read() {
          if (stream._state === 'errored') return Promise.reject(stream._storedError);
          if (stream._queue.length > 0) {
            const value = stream._queue.shift();
            return Promise.resolve({ value, done: false });
          }
          if (stream._state === 'closed') return Promise.resolve({ value: undefined, done: true });
          const deferred = createDeferred();
          stream._readRequests.push(deferred);
          return deferred.promise;
        }

        releaseLock() { this._released = true; }

        cancel(reason) {
          stream._readRequests.forEach(r => r.reject(reason));
          stream._readRequests = [];
          if (stream._underlyingSource.cancel) {
            try { return Promise.resolve(stream._underlyingSource.cancel(reason)); } catch (e) { return Promise.reject(e); }
          }
          return Promise.resolve();
        }
      })();
    }
  }

  class WritableStreamDefaultController {
    constructor(stream, underlyingSink) {
      this._stream = stream;
      this._underlyingSink = underlyingSink || {};
    }

    error(err) {
      this._stream._state = 'errored';
      this._stream._storedError = err;
    }
  }

  globalThis.WritableStream = class WritableStream {
    constructor(underlyingSink = {}, strategy) {
      this._underlyingSink = underlyingSink;
      this._strategy = strategy || {};
      this._state = 'writable';
      this._storedError = undefined;
      this._controller = new WritableStreamDefaultController(this, underlyingSink);
      this._writing = false;
      this._writeQueue = [];
    }

    getWriter() {
      const stream = this;
      return new (class WritableStreamDefaultWriter {
        write(chunk) {
          if (stream._state === 'errored') return Promise.reject(stream._storedError);
          if (stream._state === 'closed') return Promise.reject(new TypeError('Cannot write to closed stream'));
          const promise = new Promise((resolve, reject) => {
            stream._writeQueue.push({ chunk, resolve, reject });
            scheduleWrite();
          });
          function scheduleWrite() {
            if (stream._writing) return;
            const item = stream._writeQueue.shift();
            if (!item) return;
            stream._writing = true;
            try {
              const r = stream._underlyingSink.write ? stream._underlyingSink.write(item.chunk) : Promise.resolve();
              Promise.resolve(r).then(() => {
                stream._writing = false;
                item.resolve();
                scheduleWrite();
              }, (e) => {
                stream._writing = false;
                item.reject(e);
                stream._controller.error(e);
              });
            } catch (e) {
              stream._writing = false;
              item.reject(e);
              stream._controller.error(e);
            }
          }
          return promise;
        }

        close() {
          if (stream._state === 'errored') return Promise.reject(stream._storedError);
          if (stream._underlyingSink.close) {
            try { const r = stream._underlyingSink.close(); stream._state = 'closed'; return Promise.resolve(r); } catch (e) { stream._controller.error(e); return Promise.reject(e); }
          }
          stream._state = 'closed';
          return Promise.resolve();
        }

        abort(reason) {
          if (stream._underlyingSink.abort) {
            try { return Promise.resolve(stream._underlyingSink.abort(reason)); } catch (e) { return Promise.reject(e); }
          }
          stream._state = 'errored';
          stream._storedError = reason instanceof Error ? reason : new Error(String(reason));
          return Promise.resolve();
        }
      })();
    }
  }

  globalThis.TransformStream = class TransformStream {
    constructor(transformer = {}, writableStrategy, readableStrategy) {
      const ts = this;
      this._readable = new ReadableStream({ start(controller) { ts._readableController = controller; } }, readableStrategy);

      this._writable = new WritableStream({
        write(chunk) {
          try {
            if (transformer.transform) {
              const result = transformer.transform(chunk, ts._readableController);
              return Promise.resolve(result);
            }
            ts._readableController.enqueue(chunk);
            return Promise.resolve();
          } catch (e) { ts._readableController.error(e); return Promise.reject(e); }
        },
        close() { ts._readableController.close(); },
        abort(reason) { ts._readableController.error(reason); }
      }, writableStrategy);
    }

    get readable() { return this._readable; }
    get writable() { return this._writable; }
  }
})();