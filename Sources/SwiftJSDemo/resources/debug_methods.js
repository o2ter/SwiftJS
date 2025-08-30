// Debug script to check available methods
console.log("=== URLSession shared object methods ===");
const session = __APPLE_SPEC__.URLSession.getShared();
console.log("URLSession.getShared():", session);
console.log("URLSession.shared methods:", Object.getOwnPropertyNames(session));
console.log("URLSession.shared prototype:", Object.getOwnPropertyNames(Object.getPrototypeOf(session)));

// Check if it has any dataTask methods
const methods = Object.getOwnPropertyNames(session).concat(Object.getOwnPropertyNames(Object.getPrototypeOf(session)));
const dataTaskMethods = methods.filter(name => name.includes('dataTask') || name.includes('DataTask'));
console.log("DataTask-related methods:", dataTaskMethods);

// Let's also try calling the method directly to see error
try {
  console.log("Trying session.dataTaskWithRequest...");
  const result = session.dataTaskWithRequest;
  console.log("dataTaskWithRequest result:", result);
} catch (e) {
  console.log("Error:", e.message);
}

try {
  console.log("Trying session.dataTaskWithURL...");
  const result = session.dataTaskWithURL;
  console.log("dataTaskWithURL result:", result);
} catch (e) {
  console.log("Error:", e.message);
}
