// Stress Test Scenario 2: Sustained Load
// Tests system stability under continuous bidding load over extended period

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics
const bidUpdateSuccessRate = new Rate('bid_update_success_rate');
const newBidSuccessRate = new Rate('new_bid_success_rate');
const leaderboardLatency = new Trend('leaderboard_latency');
const bidUpdateLatency = new Trend('bid_update_latency');

// Configuration
const API_BASE = __ENV.API_BASE || 'http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1';
const PRODUCT_ID = __ENV.PRODUCT_ID || '1';

export const options = {
  stages: [
    { duration: '30s', target: 100 },   // Warm up to 100 users
    { duration: '1m', target: 500 },    // Ramp to 500 concurrent users
    { duration: '5m', target: 500 },    // Sustain 500 users for 5 minutes
    { duration: '1m', target: 200 },    // Cool down to 200
    { duration: '30s', target: 0 },     // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],           // 95% under 3s
    http_req_failed: ['rate<0.1'],               // Error rate under 10%
    new_bid_success_rate: ['rate>0.7'],          // 70% new bid success
    bid_update_success_rate: ['rate>0.8'],       // 80% update success
    leaderboard_latency: ['p(90)<1000'],         // 90% leaderboard queries under 1s
  },
};

// Shared state for users who have already bid
const userBids = new Map();

function getUserCredentials(vu) {
  const email = `sustained_${vu}@test.com`;
  const password = 'Sustained123!';
  const username = `sustained_user_${vu}`;
  return { email, password, username };
}

export default function () {
  const user = getUserCredentials(__VU);
  let token = '';
  
  // Authentication (register or login)
  group('Authentication', function () {
    const registerPayload = JSON.stringify({
      email: user.email,
      password: user.password,
      username: user.username,
    });

    let authRes = http.post(`${API_BASE}/auth/register`, registerPayload, {
      headers: { 'Content-Type': 'application/json' },
    });

    if (authRes.status !== 200 && authRes.status !== 201) {
      // User exists, login instead
      const loginPayload = JSON.stringify({
        email: user.email,
        password: user.password,
      });
      authRes = http.post(`${API_BASE}/auth/login`, loginPayload, {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (authRes.status === 200 || authRes.status === 201) {
      const authData = JSON.parse(authRes.body);
      token = authData.data.token;
    }
  });

  if (!token) return;

  // 70% chance of new bid, 30% chance of update
  const shouldUpdate = userBids.has(__VU) && Math.random() > 0.7;

  if (shouldUpdate) {
    // Update existing bid
    group('Update Bid', function () {
      const currentBid = userBids.get(__VU);
      const newBidPrice = currentBid + Math.floor(Math.random() * 100) + 50; // Increase by $50-$150

      const updatePayload = JSON.stringify({
        bidPrice: newBidPrice,
      });

      const updateStart = Date.now();
      const updateRes = http.put(`${API_BASE}/bids/${PRODUCT_ID}`, updatePayload, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      bidUpdateLatency.add(Date.now() - updateStart);

      const success = check(updateRes, {
        'bid update successful': (r) => r.status === 200,
      });

      bidUpdateSuccessRate.add(success);

      if (success) {
        userBids.set(__VU, newBidPrice);
        const data = JSON.parse(updateRes.body);
        console.log(`Updated bid to $${newBidPrice}, New rank: ${data.data.rank}`);
      }
    });
  } else {
    // Submit new bid
    group('Submit New Bid', function () {
      const bidPrice = Math.floor(Math.random() * 1500) + 1000; // $1000-$2500

      const bidPayload = JSON.stringify({
        productId: parseInt(PRODUCT_ID),
        bidPrice: bidPrice,
      });

      const bidRes = http.post(`${API_BASE}/bids`, bidPayload, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      const success = check(bidRes, {
        'new bid successful': (r) => r.status === 200 || r.status === 201,
      });

      newBidSuccessRate.add(success);

      if (success) {
        userBids.set(__VU, bidPrice);
        const data = JSON.parse(bidRes.body);
        console.log(`New bid $${bidPrice}, Rank: ${data.data.rank}`);
      }
    });
  }

  // Periodically check leaderboard (every 3rd iteration)
  if (__ITER % 3 === 0) {
    group('Check Leaderboard', function () {
      const start = Date.now();
      const leaderboardRes = http.get(`${API_BASE}/bids/leaderboard/${PRODUCT_ID}?limit=20`, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      leaderboardLatency.add(Date.now() - start);

      check(leaderboardRes, {
        'leaderboard retrieved': (r) => r.status === 200,
      });
    });
  }

  // Check own bid status (every 5th iteration)
  if (__ITER % 5 === 0) {
    group('Check My Status', function () {
      const statusRes = http.get(`${API_BASE}/bids/my-status/${PRODUCT_ID}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      check(statusRes, {
        'status retrieved': (r) => r.status === 200,
      });
    });
  }

  // Random think time (1-3 seconds)
  sleep(Math.random() * 2 + 1);
}

export function setup() {
  console.log('===========================================');
  console.log('Stress Test: Sustained Load Scenario');
  console.log(`API Endpoint: ${API_BASE}`);
  console.log(`Product ID: ${PRODUCT_ID}`);
  console.log('Duration: 7.5 minutes');
  console.log('Peak Load: 500 concurrent users');
  console.log('===========================================');
}

export function teardown() {
  console.log('===========================================');
  console.log('Sustained Load Test Complete');
  console.log('===========================================');
}
