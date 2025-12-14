// Stress Test Scenario 0: Small Scale Validation
// Tests 100 concurrent users to verify system is working before full load

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// Custom metrics
const bidSuccessRate = new Counter('bid_success_rate');
const bidFailureRate = new Counter('bid_failure_rate');
const bidLatency = new Trend('bid_latency');
const loginLatency = new Trend('login_latency');

// Configuration
const API_BASE = __ENV.API_BASE || 'http://YOUR_ALB_DNS/api/v1';
const PRODUCT_ID = __ENV.PRODUCT_ID || '1';

export const options = {
  stages: [
    { duration: '30s', target: 20 },    // Warm up to 20 users
    { duration: '1m', target: 50 },     // Build to 50
    { duration: '1m', target: 100 },    // Reach 100 concurrent users
    { duration: '2m', target: 100 },    // Sustain 100 users
    { duration: '30s', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],  // 95% under 3s
    http_req_failed: ['rate<0.15'],     // Allow 15% error rate
    bid_success_rate: ['count>80'],     // At least 80 successful bids
  },
};

// Generate unique test user credentials
function getUserCredentials(vu, iter) {
  const timestamp = Date.now();
  const email = `validate_${vu}_${iter}_${timestamp}@test.com`;
  const password = 'Test123!';
  const username = `validate_${vu}_${iter}`;
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
      timeout: '30s', // Increased timeout
    });

    const registerSuccess = check(registerRes, {
      'registration successful': (r) => r.status === 201 || r.status === 200,
      'no server error': (r) => r.status < 500,
    });

    if (registerSuccess && (registerRes.status === 200 || registerRes.status === 201)) {
      const registerData = JSON.parse(registerRes.body);
      token = registerData.data.token;
      loginLatency.add(registerRes.timings.duration);
    } else {
      // Log error for debugging
      if (registerRes.status >= 500) {
        console.error(`Registration server error: ${registerRes.status} - ${registerRes.body.substring(0, 200)}`);
      } else if (registerRes.status >= 400) {
        // Try login if user already exists
        const loginPayload = JSON.stringify({
          email: user.email,
          password: user.password,
        });

        const loginRes = http.post(`${API_BASE}/auth/login`, loginPayload, {
          headers: { 'Content-Type': 'application/json' },
          timeout: '30s',
        });

        if (loginRes.status === 200) {
          const loginData = JSON.parse(loginRes.body);
          token = loginData.data.token;
          loginLatency.add(loginRes.timings.duration);
        }
      }
    }
  });

  if (!token) {
    console.error('Failed to authenticate user');
    sleep(2); // Back off before retry
    return;
  }

  // Group 2: Submit Bid
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
      timeout: '30s',
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
      'no server error on bid': (r) => r.status < 500,
    });

    if (bidSuccess) {
      bidSuccessRate.add(1);
      const bidData = JSON.parse(bidRes.body);
      console.log(`✓ Bid $${bidPrice}, Rank: ${bidData.data.rank}, Score: ${bidData.data.score.toFixed(2)}`);
    } else {
      bidFailureRate.add(1);
      if (bidRes.status >= 500) {
        console.error(`✗ Bid server error: ${bidRes.status} - ${bidRes.body.substring(0, 200)}`);
      } else if (bidRes.status >= 400) {
        console.warn(`⚠ Bid client error: ${bidRes.status} - ${bidRes.body.substring(0, 200)}`);
      }
    }
  });

  // Group 3: Check Leaderboard (only 30% of requests)
  if (Math.random() < 0.3) {
    group('View Leaderboard', function () {
      const leaderboardRes = http.get(`${API_BASE}/bids/leaderboard/${PRODUCT_ID}?limit=10`, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
        timeout: '30s',
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
  }

  sleep(Math.random() * 2 + 1); // Random think time 1-3s
}

export function setup() {
  console.log('===========================================');
  console.log('Validation Test: 100 Concurrent Users');
  console.log(`API Endpoint: ${API_BASE}`);
  console.log(`Product ID: ${PRODUCT_ID}`);
  console.log('Duration: 5 minutes');
  console.log('===========================================');
}

export function teardown(data) {
  console.log('===========================================');
  console.log('Validation Test Complete');
  console.log('Check results above for any issues');
  console.log('===========================================');
}
