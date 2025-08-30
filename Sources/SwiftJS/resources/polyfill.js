
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

  encode(string) {
    const utf8 = new Uint8Array(Buffer.byteLength(string, 'utf8'));
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

// XMLHttpRequest implementation
globalThis.XMLHttpRequest = class XMLHttpRequest extends EventTarget {
  static UNSENT = 0;
  static OPENED = 1;
  static HEADERS_RECEIVED = 2;
  static LOADING = 3;
  static DONE = 4;

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

    this._method = null;
    this._url = null;
    this._async = true;
    this._request = null;
    this._requestHeaders = {};
    this._response = null;
    this._aborted = false;

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
    this._method = method.toUpperCase();
    this._url = url;
    this._async = async;
    this._request = new __APPLE_SPEC__.URLRequest(url);
    this._request.httpMethod = this._method;
    this._setReadyState(XMLHttpRequest.OPENED);
  }

  setRequestHeader(name, value) {
    if (this.readyState !== XMLHttpRequest.OPENED) {
      throw new Error('InvalidStateError: The object is in an invalid state.');
    }
    this._requestHeaders[name] = value;
    this._request.setValueForHTTPHeaderField(value, name);
  }

  send(body = null) {
    if (this.readyState !== XMLHttpRequest.OPENED) {
      throw new Error('InvalidStateError: The object is in an invalid state.');
    }

    if (body !== null) {
      if (body instanceof FormData) {
        const multipart = body._toMultipartString();
        this._request.httpBody = multipart.body;
        if (!this._requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', `multipart/form-data; boundary=${multipart.boundary}`);
        }
      } else if (typeof body === 'string') {
        this._request.httpBody = body;
        if (!this._requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', 'text/plain;charset=UTF-8');
        }
      } else if (body instanceof ArrayBuffer || ArrayBuffer.isView(body)) {
        this._request.httpBody = new Uint8Array(body);
        if (!this._requestHeaders['Content-Type']) {
          this.setRequestHeader('Content-Type', 'application/octet-stream');
        }
      }
    }

    this._setReadyState(XMLHttpRequest.LOADING);
    this._dispatchEvent('loadstart');

    const session = __APPLE_SPEC__.URLSession.getShared();
    const promise = session.dataTaskWithRequestCompletionHandler(this._request, null);

    promise.then((result) => {
      if (this._aborted) return;

      this._response = result.response;
      this.status = result.response.statusCode;
      this.statusText = this._getStatusText(this.status);
      this.responseURL = result.response.url || this._url;

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

      this._setReadyState(XMLHttpRequest.DONE);
      this._dispatchEvent('load');
      this._dispatchEvent('loadend');
    }).catch((error) => {
      if (this._aborted) return;

      this._setReadyState(XMLHttpRequest.DONE);
      this._dispatchEvent('error');
      this._dispatchEvent('loadend');
    });
  }

  abort() {
    this._aborted = true;
    if (this.readyState !== XMLHttpRequest.DONE) {
      this._setReadyState(XMLHttpRequest.DONE);
      this._dispatchEvent('abort');
      this._dispatchEvent('loadend');
    }
  }

  getResponseHeader(name) {
    if (this.readyState < XMLHttpRequest.HEADERS_RECEIVED || !this._response) {
      return null;
    }
    return this._response.valueForHTTPHeaderField(name) || null;
  }

  getAllResponseHeaders() {
    if (this.readyState < XMLHttpRequest.HEADERS_RECEIVED || !this._response) {
      return '';
    }
    const headers = this._response.allHeaderFields;
    return Object.keys(headers).map(key => `${key}: ${headers[key]}`).join('\r\n') + '\r\n';
  }

  overrideMimeType(mime) {
    // Not implemented for now
  }

  _setReadyState(state) {
    this.readyState = state;
    this._dispatchEvent('readystatechange');
  }

  _dispatchEvent(type) {
    const event = new Event(type);
    this.dispatchEvent(event);

    const handler = this['on' + type];
    if (typeof handler === 'function') {
      handler.call(this, event);
    }
  }

  _getStatusText(status) {
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
    this._headers = new Map();
    if (init) {
      if (init instanceof Headers) {
        for (const [key, value] of init._headers) {
          this._headers.set(key.toLowerCase(), value);
        }
      } else if (Array.isArray(init)) {
        for (const [key, value] of init) {
          this._headers.set(key.toLowerCase(), String(value));
        }
      } else if (typeof init === 'object') {
        for (const [key, value] of Object.entries(init)) {
          this._headers.set(key.toLowerCase(), String(value));
        }
      }
    }
  }

  append(name, value) {
    const normalizedName = name.toLowerCase();
    const existing = this._headers.get(normalizedName);
    if (existing) {
      this._headers.set(normalizedName, `${existing}, ${value}`);
    } else {
      this._headers.set(normalizedName, String(value));
    }
  }

  delete(name) {
    this._headers.delete(name.toLowerCase());
  }

  entries() {
    return this._headers.entries();
  }

  forEach(callback, thisArg) {
    for (const [key, value] of this._headers) {
      callback.call(thisArg, value, key, this);
    }
  }

  get(name) {
    return this._headers.get(name.toLowerCase()) || null;
  }

  has(name) {
    return this._headers.has(name.toLowerCase());
  }

  keys() {
    return this._headers.keys();
  }

  set(name, value) {
    this._headers.set(name.toLowerCase(), String(value));
  }

  values() {
    return this._headers.values();
  }

  [Symbol.iterator]() {
    return this._headers[Symbol.iterator]();
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
    this._bodyText = null;
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
      const multipart = this.body._toMultipartString();
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
      const multipart = this.body._toMultipartString();
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
      const multipart = this.body._toMultipartString();
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
      const multipart = this.body._toMultipartString();
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
  if (request.body) {
    if (request.body instanceof FormData) {
      const multipart = request.body._toMultipartString();
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

// FormData implementation
globalThis.FormData = class FormData {
  constructor(form) {
    this._data = new Map();
    
    if (form && form.elements) {
      // If a form element is passed, extract its data
      for (const element of form.elements) {
        if (element.name && !element.disabled) {
          if (element.type === 'file') {
            if (element.files) {
              for (const file of element.files) {
                this.append(element.name, file);
              }
            }
          } else if (element.type === 'checkbox' || element.type === 'radio') {
            if (element.checked) {
              this.append(element.name, element.value);
            }
          } else if (element.type !== 'submit' && element.type !== 'button') {
            this.append(element.name, element.value);
          }
        }
      }
    }
  }

  append(name, value, filename) {
    const key = String(name);
    
    if (!this._data.has(key)) {
      this._data.set(key, []);
    }
    
    if (value && typeof value === 'object' && value.constructor && value.constructor.name === 'File') {
      // Handle File objects
      this._data.get(key).push({
        type: 'file',
        value: value,
        filename: filename || value.name || 'blob'
      });
    } else if (value && typeof value === 'object' && value.constructor && value.constructor.name === 'Blob') {
      // Handle Blob objects
      this._data.get(key).push({
        type: 'blob',
        value: value,
        filename: filename || 'blob'
      });
    } else {
      // Handle string values
      this._data.get(key).push({
        type: 'string',
        value: String(value),
        filename: null
      });
    }
  }

  delete(name) {
    this._data.delete(String(name));
  }

  entries() {
    const entries = [];
    for (const [key, values] of this._data) {
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
    const values = this._data.get(String(name));
    if (!values || values.length === 0) {
      return null;
    }
    return values[0].value;
  }

  getAll(name) {
    const values = this._data.get(String(name));
    if (!values) {
      return [];
    }
    return values.map(item => item.value);
  }

  has(name) {
    return this._data.has(String(name));
  }

  keys() {
    const keys = [];
    for (const [key, values] of this._data) {
      for (let i = 0; i < values.length; i++) {
        keys.push(key);
      }
    }
    return keys[Symbol.iterator]();
  }

  set(name, value, filename) {
    const key = String(name);
    this._data.delete(key);
    this.append(key, value, filename);
  }

  values() {
    const values = [];
    for (const [key, items] of this._data) {
      for (const item of items) {
        values.push(item.value);
      }
    }
    return values[Symbol.iterator]();
  }

  [Symbol.iterator]() {
    return this.entries();
  }

  // Convert FormData to multipart/form-data string
  _toMultipartString() {
    const boundary = '----formdata-swiftjs-' + Math.random().toString(36).substr(2, 16);
    let result = '';

    for (const [key, values] of this._data) {
      for (const item of values) {
        result += `--${boundary}\r\n`;
        
        if (item.type === 'file' || item.type === 'blob') {
          const filename = item.filename || 'blob';
          const contentType = item.value.type || 'application/octet-stream';
          result += `Content-Disposition: form-data; name="${key}"; filename="${filename}"\r\n`;
          result += `Content-Type: ${contentType}\r\n\r\n`;
          
          // For now, we'll convert blob/file to string representation
          // In a real implementation, this would handle binary data properly
          if (item.value.arrayBuffer) {
            // This is a simplified approach for demo purposes
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
    
    return {
      boundary: boundary,
      body: result
    };
  }

  // Convert FormData to URL-encoded string
  _toURLEncoded() {
    const params = [];
    
    for (const [key, values] of this._data) {
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
};