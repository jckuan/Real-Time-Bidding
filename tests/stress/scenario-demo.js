import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const registrationSuccessRate = new Rate('registration_successful');
const loginSuccessRate = new Rate('login_successful');
const bidSuccessRate = new Rate('bid_submitted_successfully');
const leaderboardSuccessRate = new Rate('leaderboard_retrieved');
const loginLatency = new Trend('login_latency');
const bidLatency = new Trend('bid_latency');
const bidCount = new Counter('bid_success_count');

// Configuration
const BASE_URL = __ENV.API_BASE_URL || 'http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1';
const PRODUCT_ID = __ENV.PRODUCT_ID;

// Demo-friendly staged ramp for clean video recording
export const options = {
  stages: [
    { duration: '20s', target: 50 },      // Warm up to 50 users
    { duration: '40s', target: 200 },     // Ramp to 200
    { duration: '1m', target: 500 },      // Increase to 500
    { duration: '1m', target: 1000 },     // Peak at 1000 concurrent users
    { duration: '2m', target: 1000 },     // Sustain 1000 for 2 minutes (DEMO SHOWCASE)
    { duration: '30s', target: 100 },     // Cool down
    { duration: '20s', target: 0 },       // Finish
  ],
  thresholds: {
    'http_req_failed': ['rate<0.20'],           // Accept 20% errors at peak
    'http_req_duration': ['p(95)<20000'],       // 20s p95 acceptable for 1000 users
    'bid_success_count': ['count>800'],         // At least 800 successful bids
    'registration_successful': ['rate>0.85'],   // 85% registration success
    'login_successful': ['rate>0.85'],          // 85% login success
    'bid_submitted_successfully': ['rate>0.90'], // 90% bid success
  },
  noConnectionReuse: false,
  userAgent: 'K6StressTest/1.0-Demo',
  batch: 10,
  batchPerHost: 5,
};

export default function () {
  const vuId = __VU;
  const iterationId = __ITER;
  const timestamp = Date.now();
  const uniqueEmail = `user_${vuId}_${iterationId}_${timestamp}@test.com`;
  const password = 'Test123!';
  const userName = `User${vuId}`;

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '30s',
  };

  // Step 1: Register
  const registerStart = Date.now();
  const registerPayload = JSON.stringify({
    email: uniqueEmail,
    password: password,
    name: userName,
  });

  const registerRes = http.post(`${BASE_URL}/auth/register`, registerPayload, params);
  const registerSuccess = check(registerRes, {
    'registration status 201': (r) => r.status === 201,
    'registration has token': (r) => r.json('token') !== undefined,
  });
  
  registrationSuccessRate.add(registerSuccess);

  if (!registerSuccess) {
    console.error(`VU${vuId}: Registration failed - Status: ${registerRes.status}, Body: ${registerRes.body.substring(0, 200)}`);
    sleep(1);
    return;
  }

  sleep(0.5);

  // Step 2: Login
  const loginStart = Date.now();
  const loginPayload = JSON.stringify({
    email: uniqueEmail,
    password: password,
  });

  const loginRes = http.post(`${BASE_URL}/auth/login`, loginPayload, params);
  const loginSuccess = check(loginRes, {
    'login status 200': (r) => r.status === 200,
    'login has token': (r) => r.json('token') !== undefined,
  });

  loginSuccessRate.add(loginSuccess);
  loginLatency.add(Date.now() - loginStart);

  if (!loginSuccess) {
    console.error(`VU${vuId}: Login failed - Status: ${loginRes.status}, Body: ${loginRes.body.substring(0, 200)}`);
    sleep(1);
    return;
  }

  const token = loginRes.json('token');
  const authParams = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    timeout: '30s',
  };

  sleep(0.5);

  // Step 3: Submit Bid
  const bidStart = Date.now();
  const bidAmount = Math.floor(Math.random() * 5000) + 1000; // $1000-$6000
  const bidPayload = JSON.stringify({
    amount: bidAmount,
  });

  const bidRes = http.post(`${BASE_URL}/products/${PRODUCT_ID}/bid`, bidPayload, authParams);
  const bidSuccess = check(bidRes, {
    'bid status 201': (r) => r.status === 201,
    'bid has id': (r) => r.json('bid.id') !== undefined,
  });

  bidSuccessRate.add(bidSuccess);
  bidLatency.add(Date.now() - bidStart);

  if (bidSuccess) {
    bidCount.add(1);
  } else {
    console.error(`VU${vuId}: Bid failed - Status: ${bidRes.status}, Body: ${bidRes.body.substring(0, 200)}`);
  }

  sleep(0.5);

  // Step 4: Check Leaderboard (25% of users to reduce load)
  if (Math.random() < 0.25) {
    const leaderboardRes = http.get(`${BASE_URL}/products/${PRODUCT_ID}/leaderboard`, authParams);
    const leaderboardSuccess = check(leaderboardRes, {
      'leaderboard status 200': (r) => r.status === 200,
      'leaderboard has entries': (r) => {
        const body = r.json();
        return Array.isArray(body) || (body.leaderboard && Array.isArray(body.leaderboard));
      },
    });

    leaderboardSuccessRate.add(leaderboardSuccess);
  }

  // Random think time (1-3 seconds)
  sleep(Math.random() * 2 + 1);
}

export function handleSummary(data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  
  console.log('\n========================================');
  console.log('DEMO STRESS TEST SUMMARY');
  console.log('========================================');
  console.log(`Total VUs: ${data.metrics.vus_max.values.max}`);
  console.log(`Total Iterations: ${data.metrics.iterations.values.count}`);
  console.log(`Total Requests: ${data.metrics.http_reqs.values.count}`);
  console.log(`Success Rate: ${((1 - data.metrics.http_req_failed.values.rate) * 100).toFixed(2)}%`);
  console.log(`\nRegistrations: ${(data.metrics.registration_successful.values.rate * 100).toFixed(2)}% success`);
  console.log(`Logins: ${(data.metrics.login_successful.values.rate * 100).toFixed(2)}% success`);
  console.log(`Bids: ${(data.metrics.bid_submitted_successfully.values.rate * 100).toFixed(2)}% success`);
  console.log(`Total Successful Bids: ${data.metrics.bid_success_count.values.count}`);
  console.log(`\nP95 Latency: ${(data.metrics.http_req_duration.values['p(95)'] / 1000).toFixed(2)}s`);
  console.log(`Avg Request Duration: ${(data.metrics.http_req_duration.values.avg / 1000).toFixed(2)}s`);
  console.log('========================================\n');

  return {
    [`stress-results/demo-1000users-${timestamp}.json`]: JSON.stringify(data, null, 2),
    stdout: '\n✓ Demo stress test completed - Results saved\n',
  };
}
