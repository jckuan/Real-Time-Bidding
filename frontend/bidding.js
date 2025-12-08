// Check authentication
const token = localStorage.getItem('token');
const user = JSON.parse(localStorage.getItem('user') || '{}');

if (!token) {
  window.location.href = 'login.html';
}

// Get product ID from URL
const urlParams = new URLSearchParams(window.location.search);
const productId = parseInt(urlParams.get('productId'));

if (!productId) {
  alert('Invalid product ID');
  window.location.href = 'dashboard.html';
}

// Display user info
document.getElementById('userEmail').textContent = user.email || '';
document.getElementById('memberWeight').textContent = `Weight: ${parseFloat(user.member_weight || user.memberWeight || 1.0).toFixed(2)}`;

// State
let product = null;
let myBidStatus = null;
let socket = null;

// Initialize
async function init() {
  await loadProductDetails();
  await loadMyBidStatus();
  
  // Update form after both product and bid status are loaded
  updateBiddingForm();
  
  // Only connect to WebSocket if sale is active or upcoming
  const now = new Date();
  const endTime = new Date(product.sale_end_time);
  
  if (now <= endTime) {
    initWebSocket();
  } else {
    // Sale ended, load final leaderboard via API
    await loadFinalLeaderboard();
    updateConnectionStatus(false, true); // false = not connected, true = ended
  }
  
  setupEventListeners();
}

// Load product details
async function loadProductDetails() {
  try {
    const response = await fetch(`${API_BASE_URL}/products/${productId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const data = await response.json();

    if (data.success) {
      product = data.data;
      displayProductInfo();
      updateBiddingForm();
    } else {
      document.getElementById('productInfo').innerHTML = 
        '<div class="error-message">Failed to load product details</div>';
    }
  } catch (error) {
    console.error('Failed to load product:', error);
    document.getElementById('productInfo').innerHTML = 
      '<div class="error-message">Failed to load product details</div>';
  }
}

// Load my bid status
async function loadMyBidStatus() {
  try {
    const response = await fetch(`${API_BASE_URL}/bids/my-status/${productId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const data = await response.json();
    console.log('My bid status response:', data);

    if (data.success && data.data.hasBid) {
      myBidStatus = data.data.bid;
      console.log('Setting myBidStatus:', myBidStatus);
      displayMyBidStatus();
    } else {
      console.log('No existing bid found');
    }
  } catch (error) {
    console.error('Failed to load bid status:', error);
  }
}

// Display product info
function displayProductInfo() {
  const now = new Date();
  const startTime = new Date(product.sale_start_time);
  const endTime = new Date(product.sale_end_time);

  let statusText = 'Pending';
  let statusClass = 'status-pending';

  if (now >= startTime && now <= endTime) {
    statusText = 'Live Now';
    statusClass = 'status-active';
  } else if (now > endTime) {
    statusText = 'Ended';
    statusClass = 'status-completed';
  }

  document.getElementById('productInfo').innerHTML = `
    <span class="product-status ${statusClass}">${statusText}</span>
    <h2 class="product-name">${product.name}</h2>
    <div class="product-details">
      <p>${product.description || ''}</p>
      <p><strong>Base Price:</strong> $${parseFloat(product.base_price).toFixed(2)}</p>
      <p><strong>Max Winners:</strong> ${product.max_winners}</p>
      <p><strong>Current Inventory:</strong> ${product.current_inventory}</p>
      <p><strong>Sale Start:</strong> ${new Date(product.sale_start_time).toLocaleString()}</p>
      <p><strong>Sale End:</strong> ${new Date(product.sale_end_time).toLocaleString()}</p>
    </div>
  `;
}

// Display my bid status
function displayMyBidStatus() {
  const statusEl = document.getElementById('myBidStatus');
  
  if (!myBidStatus) {
    statusEl.style.display = 'none';
    return;
  }

  statusEl.style.display = 'block';
  statusEl.innerHTML = `
    <div class="my-bid-status">
      <h3>Your Current Bid</h3>
      <div class="status-grid">
        <div class="status-item">
          <div class="status-label">Bid Price</div>
          <div class="status-value">$${parseFloat(myBidStatus.bidPrice).toFixed(2)}</div>
        </div>
        <div class="status-item">
          <div class="status-label">Score</div>
          <div class="status-value">${parseFloat(myBidStatus.score).toFixed(2)}</div>
        </div>
        <div class="status-item">
          <div class="status-label">Rank</div>
          <div class="status-value">#${myBidStatus.rank || '?'}</div>
        </div>
        <div class="status-item">
          <div class="status-label">Timestamp</div>
          <div class="status-value" style="font-size: 14px;">${new Date(myBidStatus.timestamp).toLocaleTimeString()}</div>
        </div>
      </div>
    </div>
  `;
}

// Update bidding form
function updateBiddingForm() {
  const now = new Date();
  const startTime = new Date(product.sale_start_time);
  const endTime = new Date(product.sale_end_time);
  const saleActive = now >= startTime && now <= endTime;

  const formEl = document.getElementById('biddingForm');
  const submitBtn = document.getElementById('submitBidBtn');
  const updateBtn = document.getElementById('updateBidBtn');
  const priceInput = document.getElementById('bidPrice');
  const priceHint = document.getElementById('priceHint');

  console.log('updateBiddingForm called - myBidStatus:', myBidStatus, 'saleActive:', saleActive);

  if (!saleActive) {
    formEl.style.display = 'none';
    return;
  }

  formEl.style.display = 'block';
  priceInput.min = product.base_price;

  if (myBidStatus) {
    console.log('Has bid - showing update button');
    submitBtn.style.display = 'none';
    updateBtn.style.display = 'block';
    priceHint.textContent = `Minimum: $${(parseFloat(myBidStatus.bidPrice) + 0.01).toFixed(2)} (must be higher than current bid)`;
  } else {
    console.log('No bid - showing submit button');
    submitBtn.style.display = 'block';
    updateBtn.style.display = 'none';
    priceHint.textContent = `Minimum: $${parseFloat(product.base_price).toFixed(2)}`;
  }
}

// Event listeners
function setupEventListeners() {
  document.getElementById('submitBidBtn').addEventListener('click', submitBid);
  document.getElementById('updateBidBtn').addEventListener('click', updateBid);
  document.getElementById('backBtn').addEventListener('click', goBack);
}

// Submit bid
async function submitBid() {
  const bidPrice = parseFloat(document.getElementById('bidPrice').value);
  
  if (!bidPrice || bidPrice < parseFloat(product.base_price)) {
    showError('Bid price must be at least the base price');
    return;
  }

  clearMessages();
  setLoading(true);

  try {
    const response = await fetch(`${API_BASE_URL}/bids`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        productId,
        bidPrice
      })
    });

    const data = await response.json();

    if (data.success) {
      showSuccess('Bid submitted successfully!');
      // API returns bid data directly in data, not data.bid
      myBidStatus = {
        bidId: data.data.bidId,
        bidPrice: data.data.bidPrice,
        score: data.data.score,
        rank: data.data.rank,
        timestamp: data.data.timestamp
      };
      console.log('After submit - myBidStatus:', myBidStatus);
      displayMyBidStatus();
      updateBiddingForm();
      document.getElementById('bidPrice').value = '';
    } else {
      showError(data.error?.message || 'Failed to submit bid');
    }
  } catch (error) {
    console.error('Submit bid error:', error);
    showError('Failed to submit bid. Please try again.');
  } finally {
    setLoading(false);
  }
}

// Update bid
async function updateBid() {
  const newBidPrice = parseFloat(document.getElementById('bidPrice').value);
  
  if (!newBidPrice || newBidPrice <= parseFloat(myBidStatus.bidPrice)) {
    showError('New bid price must be higher than your current bid');
    return;
  }

  clearMessages();
  setLoading(true);

  try {
    const response = await fetch(`${API_BASE_URL}/bids/${productId}`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        bidPrice: newBidPrice
      })
    });

    const data = await response.json();

    if (data.success) {
      showSuccess('Bid updated successfully!');
      myBidStatus = {
        bidId: data.data.bidId,
        bidPrice: data.data.bidPrice,
        score: data.data.score,
        rank: data.data.rank,
        timestamp: data.data.timestamp
      };
      displayMyBidStatus();
      updateBiddingForm();
      document.getElementById('bidPrice').value = '';
    } else {
      showError(data.error?.message || 'Failed to update bid');
    }
  } catch (error) {
    console.error('Update bid error:', error);
    showError('Failed to update bid. Please try again.');
  } finally {
    setLoading(false);
  }
}

// WebSocket initialization
function initWebSocket() {
  socket = io(WS_URL, {
    transports: ['websocket']
  });

  socket.on('connect', () => {
    console.log('WebSocket connected');
    updateConnectionStatus(true);
    socket.emit('subscribe_leaderboard', productId);
  });

  socket.on('disconnect', () => {
    console.log('WebSocket disconnected');
    updateConnectionStatus(false);
  });

  socket.on('subscribed', (data) => {
    console.log('Subscribed to leaderboard:', data);
  });

  socket.on('leaderboard_broadcast', (data) => {
    console.log('Leaderboard update:', data);
    updateLeaderboard(data);
  });

  socket.on('leaderboard_update', (data) => {
    console.log('Individual bid update:', data);
    // Refresh my status if it's my bid
    if (data.userId === user.id) {
      loadMyBidStatus();
    }
  });

  socket.on('sale_ended', async (data) => {
    updateConnectionStatus(false, true);
    // Load final leaderboard
    await loadFinalLeaderboard();
    // Disable bidding forms
    const bidForm = document.getElementById('bidForm');
    const updateForm = document.getElementById('updateBidForm');
    if (bidForm) bidForm.style.display = 'none';
    if (updateForm) updateForm.style.display = 'none';
  });
}

// Load final leaderboard via API (for ended sales)
async function loadFinalLeaderboard() {
  try {
    const response = await fetch(`${API_BASE_URL}/bids/leaderboard/${productId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const data = await response.json();

    if (data.success) {
      console.log('Leaderboard API response:', data.data);
      
      // Transform API response to match WebSocket broadcast format
      const leaderboard = data.data.leaderboard || [];
      const leaderboardData = {
        productId,
        maxWinners: product?.max_winners || 3,
        leaderboard: leaderboard,
        highestScore: leaderboard.length > 0 && leaderboard[0].score 
          ? parseFloat(leaderboard[0].score)
          : 0,
        entryThreshold: data.data.entryThreshold 
          ? parseFloat(data.data.entryThreshold)
          : 0,
        totalBidders: leaderboard.length,
        timestamp: new Date()
      };
      updateLeaderboard(leaderboardData);
    }
  } catch (error) {
    console.error('Failed to load final leaderboard:', error);
  }
}

// Update leaderboard display
function updateLeaderboard(data) {
  document.getElementById('leaderboardStats').style.display = 'grid';
  document.getElementById('totalBidders').textContent = data.totalBidders || 0;
  document.getElementById('highestScore').textContent = (data.highestScore || 0).toFixed(2);
  document.getElementById('entryThreshold').textContent = (data.entryThreshold || 0).toFixed(2);

  const content = document.getElementById('leaderboardContent');

  if (!data.leaderboard || data.leaderboard.length === 0) {
    content.innerHTML = '<div class="empty-state"><h3>No bids yet</h3><p>Be the first to bid!</p></div>';
    return;
  }

  const maxWinners = data.maxWinners || product?.max_winners || 3;

  content.innerHTML = `
    <table class="leaderboard-table">
      <thead>
        <tr>
          <th>Rank</th>
          <th>Email</th>
          <th>Score</th>
          <th>Weight</th>
        </tr>
      </thead>
      <tbody>
        ${data.leaderboard.map((bidder, index) => {
          const rank = bidder.rank || (index + 1);
          const isWinner = rank <= maxWinners;
          const rankClass = rank === 1 ? 'rank-1' : rank === 2 ? 'rank-2' : rank === 3 ? 'rank-3' : 'rank';
          const isMe = bidder.userId === user.id || bidder.user_id === user.id;
          const score = parseFloat(bidder.score || 0);
          const memberWeight = parseFloat(bidder.memberWeight || bidder.member_weight || 1);
          
          return `
            <tr class="${isWinner ? 'winner' : ''}" style="${isMe ? 'font-weight: bold; background: #fff3cd;' : ''}">
              <td class="${rankClass}">#${rank}</td>
              <td>${bidder.email || 'Unknown'}${isMe ? ' (You)' : ''}</td>
              <td>${score.toFixed(2)}</td>
              <td>${memberWeight.toFixed(2)}</td>
            </tr>
          `;
        }).join('')}
      </tbody>
    </table>
    <small style="display: block; margin-top: 10px; color: #666; text-align: center;">
      Last updated: ${new Date(data.timestamp || Date.now()).toLocaleTimeString()}
    </small>
  `;
}

// Update connection status
function updateConnectionStatus(connected, ended = false) {
  const statusEl = document.getElementById('connectionStatus');
  if (ended) {
    statusEl.innerHTML = '<span class="connection-status ended"></span> Sale Ended - Final Results';
  } else if (connected) {
    statusEl.innerHTML = '<span class="connection-status connected"></span> Connected';
  } else {
    statusEl.innerHTML = '<span class="connection-status disconnected"></span> Disconnected';
  }
}

// Helper functions
function showError(message) {
  const errorEl = document.getElementById('bidError');
  const successEl = document.getElementById('bidSuccess');
  errorEl.textContent = message;
  errorEl.style.display = 'block';
  successEl.style.display = 'none';
}

function showSuccess(message) {
  const errorEl = document.getElementById('bidError');
  const successEl = document.getElementById('bidSuccess');
  successEl.textContent = message;
  successEl.style.display = 'block';
  errorEl.style.display = 'none';
}

function clearMessages() {
  document.getElementById('bidError').style.display = 'none';
  document.getElementById('bidSuccess').style.display = 'none';
}

function setLoading(loading) {
  const submitBtn = document.getElementById('submitBidBtn');
  const updateBtn = document.getElementById('updateBidBtn');
  submitBtn.disabled = loading;
  updateBtn.disabled = loading;
}

function goBack() {
  if (socket) {
    socket.emit('unsubscribe_leaderboard', productId);
    socket.disconnect();
  }
  window.location.href = 'dashboard.html';
}

// Initialize on page load
init();

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  if (socket) {
    socket.emit('unsubscribe_leaderboard', productId);
    socket.disconnect();
  }
});
