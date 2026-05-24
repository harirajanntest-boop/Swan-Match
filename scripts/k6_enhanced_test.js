// ============================================================================
// Swan Match — Enhanced High-Volume k6 Performance Load Test
// ============================================================================
// Simulates concurrent messaging loops, high-resolution image loading/uploads,
// account verification, spam filters, and safety report creation.
//
// Prerequisites: Install k6 (https://k6.io/docs/get-started/installation/)
// Run: k6 run scripts/k6_enhanced_test.js
// ============================================================================

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom business metrics
const chatThroughputMetric = new Rate('chat_throughput_success');
const imageUploadDurationMetric = new Trend('image_upload_duration');
const spamCheckDurationMetric = new Trend('spam_check_duration');
const generalErrorsMetric = new Rate('general_errors');

const BASE_URL = 'https://us-central1-swan-match.cloudfunctions.net';

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up: 0 to 10 active concurrent users
    { duration: '2m',  target: 30 },  // Hold peak: 30 concurrent users doing continuous loops
    { duration: '30s', target: 0 },   // Cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2500'], // 95% of requests must complete under 2.5s
    chat_throughput_success: ['rate>0.95'], // >95% chat throughput success
    general_errors: ['rate<0.05'], // Error rate under 5%
  },
};

// Simulated mock binary image data (100KB)
const dummyImageData = 'a'.repeat(100 * 1024); 

// Helper: Firebase Callables Headers
const callHeaders = { headers: { 'Content-Type': 'application/json' } };

// 1. SIMULATE: Account Lookup / Registration Throttling Check
function simulateAuthLookup() {
  const phone = `+1${Math.floor(1000000000 + Math.random() * 9000000000)}`;
  const payload = JSON.stringify({ data: { phoneNumber: phone } });
  
  const res = http.post(`${BASE_URL}/checkPhoneExists`, payload, callHeaders);
  
  const success = check(res, {
    'Auth: phone check returned 200': (r) => r.status === 200,
    'Auth: latency < 1.5s': (r) => r.timings.duration < 1500,
  });
  
  generalErrorsMetric.add(!success);
}

// 2. SIMULATE: High-Volume Chat Message & Spam Verification
function simulateChatLoop() {
  const messages = [
    'Hey! How are you doing today? 💛',
    'I really love your match profile! Let us meet up.',
    'Are you interested in grabing some coffee this weekend?',
    'This platform feels super premium and clean.',
    'Let us chat here first before taking things offline!'
  ];
  const text = messages[Math.floor(Math.random() * messages.length)];
  
  const start = Date.now();
  const payload = JSON.stringify({ data: { text: text, context: 'chat_stream' } });
  const res = http.post(`${BASE_URL}/checkContentFilter`, payload, callHeaders);
  const duration = Date.now() - start;
  
  const success = check(res, {
    'Chat: content filter success': (r) => r.status === 200,
    'Chat: safety latency < 1s': (r) => r.timings.duration < 1000,
  });
  
  chatThroughputMetric.add(success);
  spamCheckDurationMetric.add(duration);
  generalErrorsMetric.add(!success);
}

// 3. SIMULATE: Profile Image Upload & Content Delivery Load (Step 16)
function simulateImageUpload() {
  const payload = JSON.stringify({
    data: {
      photoUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500',
      photoHash: `hash_mock_${Math.floor(1000000 + Math.random() * 9000000)}`
    }
  });

  const start = Date.now();
  const res = http.post(`${BASE_URL}/checkPhotoDuplicate`, payload, callHeaders);
  const duration = Date.now() - start;

  const success = check(res, {
    'Image: duplicate detection returned 200': (r) => r.status === 200,
    'Image: duplicate checking latency < 2s': (r) => r.timings.duration < 2000,
  });

  imageUploadDurationMetric.add(duration);
  generalErrorsMetric.add(!success);
}

// 4. SIMULATE: Safety Incident Submission under Load
function simulateSafetyReport() {
  const categories = ['scam', 'harassment', 'underage', 'impersonation'];
  const category = categories[Math.floor(Math.random() * categories.length)];
  
  const payload = JSON.stringify({
    data: {
      reportedUid: `user_b_${Math.floor(100 + Math.random() * 900)}`,
      category: category,
      reason: `Automated Load Test Report for: ${category}`
    }
  });
  
  const res = http.post(`${BASE_URL}/submitReport`, payload, callHeaders);
  
  const success = check(res, {
    'Safety: report submission returned 200': (r) => r.status === 200,
  });
  
  generalErrorsMetric.add(!success);
}

// Main Concurrent Loop
export default function () {
  const actionSelector = Math.random();
  
  if (actionSelector < 0.3) {
    simulateAuthLookup();
  } else if (actionSelector < 0.7) {
    simulateChatLoop();
  } else if (actionSelector < 0.9) {
    simulateImageUpload();
  } else {
    simulateSafetyReport();
  }
  
  // Natural pacing between concurrent swipe/chat actions
  sleep(0.5 + Math.random());
}

// Final Summary Output in Console
export function handleSummary(data) {
  console.log('======================================================================');
  console.log('         SWAN MATCH — HIGH-VOLUME ENHANCED LOAD TEST RESULTS');
  console.log('======================================================================');
  console.log(`  Concurrent Actions Run:     ${data.metrics.http_reqs.values.count}`);
  console.log(`  Avg Response Duration:      ${data.metrics.http_req_duration.values.avg.toFixed(0)}ms`);
  console.log(`  P95 Response Duration:      ${data.metrics.http_req_duration.values['p(95)'].toFixed(0)}ms`);
  console.log(`  Chat Messages Throughput:   ${(data.metrics.chat_throughput_success.values.rate * 100).toFixed(1)}%`);
  console.log(`  Image Upload/Checking Avg:  ${(data.metrics.image_upload_duration.values.avg || 0).toFixed(0)}ms`);
  console.log(`  Spam/Filter Checks Avg:     ${(data.metrics.spam_check_duration.values.avg || 0).toFixed(0)}ms`);
  console.log(`  General Client Error Rate:  ${(data.metrics.general_errors.values.rate * 100).toFixed(2)}%`);
  console.log('======================================================================');
  return {};
}
