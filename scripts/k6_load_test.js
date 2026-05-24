// ============================================================================
// Swan Match — k6 Load Test Script
// ============================================================================
// Prerequisites: Install k6 (https://k6.io/docs/get-started/installation/)
// Run: k6 run scripts/k6_load_test.js
// ============================================================================

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

// Test configuration
const BASE_URL = 'https://us-central1-swan-match.cloudfunctions.net';

export const options = {
  stages: [
    { duration: '30s', target: 5 },   // Ramp up to 5 users
    { duration: '1m',  target: 10 },   // Hold at 10 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'], // 95th percentile under 3s
    errors: ['rate<0.1'],              // Error rate under 10%
  },
};

// ─── TEST: Check Phone Exists ───────────────────────────────────────────────
function testCheckPhoneExists() {
  const payload = JSON.stringify({
    data: { phone: '+911234567890' },
  });
  const params = { headers: { 'Content-Type': 'application/json' } };
  const res = http.post(`${BASE_URL}/checkPhoneExists`, payload, params);

  const success = check(res, {
    'checkPhoneExists status 200': (r) => r.status === 200,
    'checkPhoneExists response time < 2s': (r) => r.timings.duration < 2000,
  });
  errorRate.add(!success);
  responseTime.add(res.timings.duration);
}

// ─── TEST: Check Content Filter ─────────────────────────────────────────────
function testContentFilter() {
  const payload = JSON.stringify({
    data: { text: 'Hello, I am looking for a partner' },
  });
  const params = { headers: { 'Content-Type': 'application/json' } };
  const res = http.post(`${BASE_URL}/checkContentFilter`, payload, params);

  const success = check(res, {
    'contentFilter status 200': (r) => r.status === 200,
    'contentFilter response time < 1s': (r) => r.timings.duration < 1000,
  });
  errorRate.add(!success);
  responseTime.add(res.timings.duration);
}

// ─── TEST: Health Check (Simple GET) ────────────────────────────────────────
function testHealthCheck() {
  // Firebase functions don't have a /health endpoint,
  // so we test the function URL availability
  const res = http.get(`${BASE_URL}/checkPhoneExists`);

  const success = check(res, {
    'health check responds': (r) => r.status !== 0,
  });
  errorRate.add(!success);
}

// ─── MAIN TEST FUNCTION ─────────────────────────────────────────────────────
export default function () {
  testCheckPhoneExists();
  sleep(1);

  testContentFilter();
  sleep(1);

  testHealthCheck();
  sleep(0.5);
}

// ─── SUMMARY ────────────────────────────────────────────────────────────────
export function handleSummary(data) {
  console.log('═══════════════════════════════════════');
  console.log('  Swan Match Load Test Results');
  console.log('═══════════════════════════════════════');
  console.log(`  Total requests: ${data.metrics.http_reqs.values.count}`);
  console.log(`  Avg response:   ${data.metrics.http_req_duration.values.avg.toFixed(0)}ms`);
  console.log(`  P95 response:   ${data.metrics.http_req_duration.values['p(95)'].toFixed(0)}ms`);
  console.log(`  Error rate:     ${(data.metrics.errors?.values?.rate * 100 || 0).toFixed(1)}%`);
  console.log('═══════════════════════════════════════');
  return {};
}
