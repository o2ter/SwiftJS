// Test script for XMLHttpRequest and fetch APIs
console.log("Testing XMLHttpRequest and fetch APIs...");

// Test XMLHttpRequest
function testXMLHttpRequest() {
  console.log("\\n=== Testing XMLHttpRequest ===");
  
  const xhr = new XMLHttpRequest();
  
  xhr.onreadystatechange = function() {
    console.log(`ReadyState changed to: ${xhr.readyState}`);
    if (xhr.readyState === XMLHttpRequest.DONE) {
      console.log(`Status: ${xhr.status}`);
      console.log(`Response: ${xhr.responseText.substring(0, 100)}...`);
    }
  };
  
  xhr.onerror = function() {
    console.log("XHR Error occurred");
  };
  
  xhr.onload = function() {
    console.log("XHR Load completed");
  };
  
  try {
    xhr.open('GET', 'https://httpbin.org/json');
    xhr.send();
  } catch (error) {
    console.log("XHR Error:", error.message);
  }
}

// Test fetch API
async function testFetch() {
  console.log("\\n=== Testing fetch API ===");
  
  try {
    const response = await fetch('https://httpbin.org/json');
    console.log(`Fetch Status: ${response.status}`);
    console.log(`Fetch OK: ${response.ok}`);
    console.log(`Fetch URL: ${response.url}`);
    
    const data = await response.json();
    console.log("Fetch JSON data:", JSON.stringify(data, null, 2));
  } catch (error) {
    console.log("Fetch Error:", error.message);
  }
}

// Test Headers
function testHeaders() {
  console.log("\\n=== Testing Headers ===");
  
  const headers = new Headers();
  headers.set('Content-Type', 'application/json');
  headers.append('Authorization', 'Bearer token123');
  
  console.log("Headers:");
  for (const [key, value] of headers) {
    console.log(`  ${key}: ${value}`);
  }
  
  console.log(`Content-Type: ${headers.get('content-type')}`);
  console.log(`Has Authorization: ${headers.has('authorization')}`);
}

// Test Request and Response
function testRequestResponse() {
  console.log("\\n=== Testing Request and Response ===");
  
  const request = new Request('https://example.com', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ test: 'data' })
  });
  
  console.log(`Request URL: ${request.url}`);
  console.log(`Request Method: ${request.method}`);
  console.log(`Request Headers:`, Array.from(request.headers.entries()));
  
  const response = new Response('{"message": "Hello"}', {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
  
  console.log(`Response Status: ${response.status}`);
  console.log(`Response OK: ${response.ok}`);
}

// Run tests
testXMLHttpRequest();
setTimeout(testFetch, 1000);
setTimeout(testHeaders, 2000);
setTimeout(testRequestResponse, 3000);
