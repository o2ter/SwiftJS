
setInterval(() => {
  console.log('hello');
}, 1000);

console.log('log');
console.warn('warn');
console.info('info');
console.debug('debug');
console.error('error');
console.trace('trace');

const prototypes = (x) => {
  const prototype = Object.getPrototypeOf(x);
  if (prototype == undefined || prototype === Object.prototype) return [];
  return [prototype, ...prototypes(prototype)];
};

const props = (x) => [x, ...prototypes(x)].flatMap(x => Object.getOwnPropertyNames(x)).sort();

console.log(props(globalThis));

console.log(props(__APPLE_SPEC__));

console.log(JSON.stringify(process.env));
console.log(JSON.stringify(process.argv));
console.log(JSON.stringify(process.cwd()));

console.log(crypto.randomUUID());
console.log(crypto.randomBytes(16));

console.log(__APPLE_SPEC__.URLSessionConfiguration.default());
console.log(new __APPLE_SPEC__.URLSession(__APPLE_SPEC__.URLSessionConfiguration.default()));


console.log(__APPLE_SPEC__.processInfo.processName);
console.log(__APPLE_SPEC__.processInfo.processIdentifier);
console.log(__APPLE_SPEC__.processInfo.arguments);
console.log(__APPLE_SPEC__.processInfo.globallyUniqueString);
console.log(__APPLE_SPEC__.processInfo.hostName);

console.log(__APPLE_SPEC__.deviceInfo.identifierForVendor());

const hash = __APPLE_SPEC__.crypto.createHash('md5');
hash.update(new Uint8Array([1, 2, 3, 4, 5]));
hash.update(new Uint8Array([6, 7, 8, 9, 10]));
const clone = hash.clone();
console.log(hash.digest().toHex());
hash.update(new Uint8Array([6, 7, 8, 9, 10]));
console.log(hash.digest().toHex());
console.log(clone.digest().toHex());


const hamc = __APPLE_SPEC__.crypto.createHamc('md5', new Uint8Array([1, 2, 3, 4, 5]));
hamc.update(new Uint8Array([1, 2, 3, 4, 5]));
hamc.update(new Uint8Array([6, 7, 8, 9, 10]));
console.log(hamc.digest().toHex());


console.log(__APPLE_SPEC__.FileSystem.homeDirectory());
console.log(__APPLE_SPEC__.FileSystem.temporaryDirectory());