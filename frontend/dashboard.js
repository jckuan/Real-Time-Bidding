// Check authentication
const token = localStorage.getItem('token');
const user = JSON.parse(localStorage.getItem('user') || '{}');

if (!token) {
  window.location.href = 'login.html';
}

// State
let currentFilter = 'active';

// Display user info
document.getElementById('userEmail').textContent = user.email || '';
document.getElementById('memberWeight').textContent = `Weight: ${parseFloat(user.member_weight || user.memberWeight || 1.0).toFixed(2)}`;

// Logout handler
document.getElementById('logoutBtn').addEventListener('click', () => {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
  window.location.href = 'login.html';
});

// Filter tab handlers
document.querySelectorAll('.filter-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    const filter = tab.getAttribute('data-filter');
    
    // Update active tab
    document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
    
    // Update title
    const title = filter === 'active' ? 'Active Flash Sales' : 'Past Flash Sales';
    document.getElementById('productsTitle').textContent = title;
    
    // Update filter and reload
    currentFilter = filter;
    loadProducts(filter);
  });
});

// Fetch and display products
async function loadProducts(status = 'active') {
  try {
    const response = await fetch(`${API_BASE_URL}/products?status=${status}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const data = await response.json();

    if (data.success) {
      displayProducts(data.data.products, status);
    } else {
      const emptyMessage = status === 'active' ? 'No active products' : 'No past sales';
      document.getElementById('productList').innerHTML = 
        `<div class="empty-state"><h3>${emptyMessage}</h3></div>`;
    }
  } catch (error) {
    console.error('Failed to load products:', error);
    document.getElementById('productList').innerHTML = 
      '<div class="error-message">Failed to load products. Please refresh the page.</div>';
  }
}

function displayProducts(products, status = 'active') {
  const productList = document.getElementById('productList');

  if (products.length === 0) {
    const emptyMessage = status === 'active' 
      ? 'No Active Products' 
      : 'No Past Sales';
    const emptySubtext = status === 'active'
      ? 'Check back later for flash sales!'
      : 'Completed sales will appear here';
    
    productList.innerHTML = `
      <div class="empty-state">
        <h3>${emptyMessage}</h3>
        <p>${emptySubtext}</p>
      </div>
    `;
    return;
  }

  productList.innerHTML = products.map(product => {
    const now = new Date();
    const startTime = new Date(product.sale_start_time);
    const endTime = new Date(product.sale_end_time);
    
    let statusClass = 'status-pending';
    let statusText = 'Upcoming';
    let timerText = '';
    let timerClass = '';

    if (now >= startTime && now <= endTime) {
      statusClass = 'status-active';
      statusText = 'Live Now';
      const remaining = Math.floor((endTime - now) / 1000);
      timerText = `Ends in ${formatTime(remaining)}`;
      timerClass = 'active';
    } else if (now < startTime) {
      const until = Math.floor((startTime - now) / 1000);
      timerText = `Starts in ${formatTime(until)}`;
    } else {
      statusClass = 'status-completed';
      statusText = 'Ended';
      timerText = 'Sale Ended';
    }

    return `
      <div class="product-card">
        <span class="product-status ${statusClass}">${statusText}</span>
        <h3 class="product-name">${product.name}</h3>
        <div class="product-details">
          <p>${product.description || ''}</p>
          <p><strong>Base Price:</strong> $${parseFloat(product.base_price).toFixed(2)}</p>
          <p><strong>Max Winners:</strong> ${product.max_winners}</p>
          <p><strong>Inventory:</strong> ${product.current_inventory}</p>
        </div>
        <div class="timer ${timerClass}" id="timer-${product.id}">${timerText}</div>
        <button class="btn btn-primary" data-product-id="${product.id}">
          ${now >= startTime && now <= endTime ? 'Place Bid' : 'View Details'}
        </button>
      </div>
    `;
  }).join('');

  // Update timers every second
  setInterval(() => updateTimers(products), 1000);
  
  // Add event listeners to all buttons
  attachButtonListeners();
}

function updateTimers(products) {
  const now = new Date();
  
  products.forEach(product => {
    const startTime = new Date(product.sale_start_time);
    const endTime = new Date(product.sale_end_time);
    const timerEl = document.getElementById(`timer-${product.id}`);
    
    if (!timerEl) return;

    if (now >= startTime && now <= endTime) {
      const remaining = Math.floor((endTime - now) / 1000);
      timerEl.textContent = `Ends in ${formatTime(remaining)}`;
      timerEl.className = 'timer active';
      
      if (remaining <= 0) {
        loadProducts(); // Reload to update status
      }
    } else if (now < startTime) {
      const until = Math.floor((startTime - now) / 1000);
      timerEl.textContent = `Starts in ${formatTime(until)}`;
      timerEl.className = 'timer';
      
      if (until <= 0) {
        loadProducts(); // Reload to update status
      }
    }
  });
}

function formatTime(seconds) {
  if (seconds < 0) return '0s';
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  } else {
    return `${secs}s`;
  }
}

function attachButtonListeners() {
  const buttons = document.querySelectorAll('.product-card .btn');
  buttons.forEach(button => {
    button.addEventListener('click', () => {
      const productId = button.getAttribute('data-product-id');
      if (productId) {
        window.location.href = `bidding.html?productId=${productId}`;
      }
    });
  });
}

// Load products on page load
loadProducts();
