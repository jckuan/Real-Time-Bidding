// Stress Test Scenario 3: Update Spike
// Simulates exponential increase in bid updates as deadline approaches

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics
const bidUpdateRate = new Rate('bid_update_success');
const redisLatency = new Trend('redis_leaderboard_latency');
const conflictRate = new Counter('update_conflicts');

// Configuration
const API_BASE = __ENV.API_BASE || 'http://YOUR_ALB_DNS/api/v1';
const PRODUCT_ID = __ENV.PRODUCT_ID || '1';

export const options = {
  scenarios: {
    // Initial bidders establish baseline
    initial_bids: {
      executor: 'constant-vus',
      vus: 50,
      duration: '30s',
      exec: 'initialBid',
    },
    // Exponential update spike
    update_spike: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: 25 },   // 2.5x growth
        { duration: '1m', target: 60 },   // 2.4x growth
        { duration: '1m', target: 150 },  // 2.5x growth
        { duration: '1m', target: 400 },  // 2.67x growth (deadline approaching)
        { duration: '1m', target: 1000 }, // 2.5x growth (peak panic)
        { duration: '10s', target: 0 },    // Cutoff
      ],
      startTime: '35s', // Start after initial bids
      exec: 'updateBid',
    },
  },
  thresholds: {
    http_req_duration: ['p(99)<8000'],         // 99% under 8s even during spike
    bid_update_success: ['rate>0.5'],          // At least 50% updates succeed
    redis_leaderboard_latency: ['p(95)<1000'], // Redis stays fast
  },
};

// Store user tokens and current bids
const userState = {};

function getUserCredentials(vu) {
  const email = `spike_${vu}@test.com`;
  const password = 'Spike123!';
  const username = `spike_user_${vu}`;
  return { email, password, username };
}

function authenticate(user) {
  const registerPayload = JSON.stringify({
    email: user.email,
    password: user.password,
    username: user.username,
  });

  let authRes = http.post(`${API_BASE}/auth/register`, registerPayload, {
    headers: { 'Content-Type': 'application/json' },
  });

  if (authRes.status !== 200 && authRes.status !== 201) {
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
    return authData.data.token;
  }
  return null;
}

// Initial bid submission phase
export function initialBid() {
  const user = getUserCredentials(__VU);
  const token = authenticate(user);
  
  if (!token) return;

  group('Initial Bid Submission', function () {
    const bidPrice = Math.floor(Math.random() * 500) + 1000; // $1000-$1500

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
      'initial bid successful': (r) => r.status === 200 || r.status === 201,
    });

    if (success) {
      userState[__VU] = { token, currentBid: bidPrice };
      const data = JSON.parse(bidRes.body);
      console.log(`Initial bid: $${bidPrice}, Rank: ${data.data.rank}`);
    }
  });

  sleep(1);
}

// Update spike phase
export function updateBid() {
  const user = getUserCredentials(__VU);
  let token = userState[__VU]?.token;
  let currentBid = userState[__VU]?.currentBid || 1000;

  // Authenticate if not already
  if (!token) {
    token = authenticate(user);
    if (!token) return;
  }

  group('Bid Update Spike', function () {
    // Increasingly aggressive price increases (simulating panic)
    const increment = Math.floor(Math.random() * 200) + 100; // $100-$300 increase
    const newBidPrice = currentBid + increment;

    const updatePayload = JSON.stringify({
      bidPrice: newBidPrice,
    });

    const updateRes = http.put(`${API_BASE}/bids/${PRODUCT_ID}`, updatePayload, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
    });

    const success = check(updateRes, {
      'update successful': (r) => r.status === 200,
      'no server errors': (r) => r.status < 500,
    });

    bidUpdateRate.add(success);

    if (success) {
      userState[__VU] = { token, currentBid: newBidPrice };
      const data = JSON.parse(updateRes.body);
      console.log(`Updated to $${newBidPrice}, Rank: ${data.data.rank}`);
    } else if (updateRes.status === 409) {
      // Conflict (e.g., price decrease attempt)
      conflictRate.add(1);
    }

    // Check leaderboard (Redis stress test)
    const leaderboardStart = Date.now();
    const leaderboardRes = http.get(`${API_BASE}/bids/leaderboard/${PRODUCT_ID}?limit=50`, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    redisLatency.add(Date.now() - leaderboardStart);

    check(leaderboardRes, {
      'leaderboard available': (r) => r.status === 200,
    });
  });

  // Very short sleep during spike (simulating frantic updates)
  sleep(Math.random() * 0.5 + 0.2); // 0.2-0.7 seconds
}

export function setup() {
  console.log('===========================================');
  console.log('Stress Test: Update Spike Scenario');
  console.log(`API Endpoint: ${API_BASE}`);
  console.log(`Product ID: ${PRODUCT_ID}`);
  console.log('Phase 1: 50 users submit initial bids (30s)');
  console.log('Phase 2: Exponential update spike (2.5 min)');
  console.log('Peak: 1000 concurrent updates');
  console.log('===========================================');
}

export function teardown() {
  console.log('===========================================');
  console.log('Update Spike Test Complete');
  console.log('Check conflict rate and Redis performance');
  console.log('===========================================');
}
