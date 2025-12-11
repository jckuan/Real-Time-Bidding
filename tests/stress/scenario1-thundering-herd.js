// Stress Test Scenario 1: Thundering Herd
// Simulates 1000+ concurrent users bidding simultaneously when product goes live

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// Custom metrics
const bidSuccessRate = new Counter('bid_success_rate');
const bidFailureRate = new Counter('bid_failure_rate');
const bidLatency = new Trend('bid_latency');
const loginLatency = new Trend('login_latency');

// Configuration
const API_BASE = __ENV.API_BASE || 'http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1';
const PRODUCT_ID = __ENV.PRODUCT_ID || '1'; // Set this after creating test product

export const options = {
  stages: [
    { duration: '30s', target: 100 },   // Gradual warm-up
    { duration: '1m', target: 500 },    // Build to 500
    { duration: '1m', target: 1000 },   // Reach 1000 (demo requirement)
    { duration: '2m', target: 1000 },   // Sustain 1000 concurrent users
    { duration: '30s', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'],  // More realistic: 95% under 5s
    http_req_failed: ['rate<0.1'],      // Allow 10% error rate (more realistic)
    bid_success_rate: ['count>800'],    // At least 800 successful bids
  },
};

// Generate unique test user credentials
function getUserCredentials(vu, iter) {
  const timestamp = Date.now();
  const email = `loadtest_${vu}_${iter}_${timestamp}@test.com`;
  const password = 'LoadTest123!';
  const username = `loaduser_${vu}_${iter}`;
  return { email, password, username };
}

export default function () {
  const user = getUserCredentials(__VU, __ITER);
  let token = '';
  
  // Group 1: User Registration & Login
  group('User Authentication', function () {
    // Register
    const registerPayload = JSON.stringify({
      email: user.email,
      password: user.password,
      username: user.username,
    });

    const registerRes = http.post(`${API_BASE}/auth/register`, registerPayload, {
      headers: { 'Content-Type': 'application/json' },
    });

    check(registerRes, {
      'registration successful': (r) => r.status === 201 || r.status === 200,
    });

    if (registerRes.status === 200 || registerRes.status === 201) {
      const registerData = JSON.parse(registerRes.body);
      token = registerData.data.token;
      loginLatency.add(registerRes.timings.duration);
    } else {
      // If user exists, try login
      const loginPayload = JSON.stringify({
        email: user.email,
        password: user.password,
      });

      const loginRes = http.post(`${API_BASE}/auth/login`, loginPayload, {
        headers: { 'Content-Type': 'application/json' },
      });

      check(loginRes, {
        'login successful': (r) => r.status === 200,
      });

      if (loginRes.status === 200) {
        const loginData = JSON.parse(loginRes.body);
        token = loginData.data.token;
        loginLatency.add(loginRes.timings.duration);
      }
    }
  });

  if (!token) {
    console.error('Failed to authenticate user');
    return;
  }

  // Group 2: Submit Bid (The Thundering Herd Moment)
  group('Submit Bid', function () {
    // Random bid price between $1000-$2000
    const bidPrice = Math.floor(Math.random() * 1000) + 1000;
    
    const bidPayload = JSON.stringify({
      productId: parseInt(PRODUCT_ID),
      bidPrice: bidPrice,
    });

    const bidStart = Date.now();
    const bidRes = http.post(`${API_BASE}/bids`, bidPayload, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
    });

    const bidDuration = Date.now() - bidStart;
    bidLatency.add(bidDuration);

    const bidSuccess = check(bidRes, {
      'bid submitted successfully': (r) => r.status === 201 || r.status === 200,
      'bid returns rank': (r) => {
        try {
          const data = JSON.parse(r.body);
          return data.data && data.data.rank !== undefined;
        } catch {
          return false;
        }
      },
    });

    if (bidSuccess) {
      bidSuccessRate.add(1);
      const bidData = JSON.parse(bidRes.body);
      console.log(`Bid submitted: $${bidPrice}, Rank: ${bidData.data.rank}, Score: ${bidData.data.score}`);
    } else {
      bidFailureRate.add(1);
      console.error(`Bid failed: ${bidRes.status} - ${bidRes.body}`);
    }
  });

  // Group 3: Check Leaderboard
  group('View Leaderboard', function () {
    const leaderboardRes = http.get(`${API_BASE}/bids/leaderboard/${PRODUCT_ID}?limit=10`, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    check(leaderboardRes, {
      'leaderboard retrieved': (r) => r.status === 200,
      'leaderboard has data': (r) => {
        try {
          const data = JSON.parse(r.body);
          return data.data && data.data.leaderboard && data.data.leaderboard.length > 0;
        } catch {
          return false;
        }
      },
    });
  });

  sleep(1); // Brief pause between iterations
}

// Setup function (runs once before test)
export function setup() {
  console.log('===========================================');
  console.log('Stress Test: Thundering Herd Scenario');
  console.log(`API Endpoint: ${API_BASE}`);
  console.log(`Product ID: ${PRODUCT_ID}`);
  console.log('Target: 1000 concurrent bidders');
  console.log('===========================================');
}

// Teardown function (runs once after test)
export function teardown(data) {
  console.log('===========================================');
  console.log('Test Complete - Check metrics above');
  console.log('===========================================');
}
