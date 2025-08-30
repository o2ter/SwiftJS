// Simple demonstration of XMLHttpRequest and fetch APIs
console.log("🚀 SwiftJS XMLHttpRequest and fetch API Demo");

// Test 1: Simple XMLHttpRequest
console.log("\n📡 Testing XMLHttpRequest...");
const xhr = new XMLHttpRequest();
xhr.open('GET', 'https://httpbin.org/json');
xhr.onload = function() {
  if (xhr.status === 200) {
    console.log("✅ XMLHttpRequest SUCCESS!");
    console.log(`Status: ${xhr.status}`);
    console.log(`Response: ${xhr.responseText.substring(0, 100)}...`);
  }
};
xhr.onerror = function() {
  console.log("❌ XMLHttpRequest ERROR");
};
xhr.send();

// Test 2: fetch API
console.log("\n🌐 Testing fetch API...");
setTimeout(async () => {
  try {
    const response = await fetch('https://httpbin.org/json');
    if (response.ok) {
      console.log("✅ fetch SUCCESS!");
      console.log(`Status: ${response.status}`);
      const json = await response.json();
      console.log("JSON data received:", Object.keys(json));
    }
  } catch (error) {
    console.log("❌ fetch ERROR:", error.message);
  }
}, 1000);

// Test 3: POST request with XMLHttpRequest
console.log("\n📤 Testing POST with XMLHttpRequest...");
setTimeout(() => {
  const xhr2 = new XMLHttpRequest();
  xhr2.open('POST', 'https://httpbin.org/post');
  xhr2.setRequestHeader('Content-Type', 'application/json');
  xhr2.onload = function() {
    if (xhr2.status === 200) {
      console.log("✅ POST XMLHttpRequest SUCCESS!");
      console.log(`Status: ${xhr2.status}`);
    }
  };
  xhr2.send(JSON.stringify({ message: "Hello from SwiftJS!" }));
}, 2000);

// Test 4: POST request with fetch
console.log("\n🚀 Testing POST with fetch...");
setTimeout(async () => {
  try {
    const response = await fetch('https://httpbin.org/post', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ framework: "SwiftJS", test: "fetch API" })
    });
    
    if (response.ok) {
      console.log("✅ POST fetch SUCCESS!");
      console.log(`Status: ${response.status}`);
      const result = await response.json();
      console.log("Posted data received back:", result.json);
    }
  } catch (error) {
    console.log("❌ POST fetch ERROR:", error.message);
  }
}, 3000);

console.log("\n🔄 All tests initiated... waiting for results...");
