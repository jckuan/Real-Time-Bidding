// Admin Dashboard JavaScript
const API_BASE = window.API_CONFIG?.BASE_URL || 'http://localhost:3000/api/v1';

let authToken = null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  authToken = localStorage.getItem('token');
  
  if (!authToken) {
    window.location.href = '/login.html';
    return;
  }

  // Display user email
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const userEmailEl = document.getElementById('userEmail');
  if (userEmailEl && user.email) {
    userEmailEl.textContent = user.email;
  }

  initializeTabs();
  initializeForms();
  loadProducts();
  loadScoringParameters();
  
  document.getElementById('logoutBtn').addEventListener('click', logout);
});

// Tab Management
function initializeTabs() {
  const tabBtns = document.querySelectorAll('.filter-tab');
  
  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const tabName = btn.dataset.tab;
      
      // Update active states
      document.querySelectorAll('.filter-tab').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      
      btn.classList.add('active');
      document.getElementById(`${tabName}Tab`).classList.add('active');
    });
  });
}

// Form Initialization
function initializeForms() {
  document.getElementById('createProductForm').addEventListener('submit', handleCreateProduct);
  document.getElementById('updateScoringForm').addEventListener('submit', handleUpdateScoring);
  document.getElementById('productSelect').addEventListener('change', handleProductSelect);
}

// Create Product
async function handleCreateProduct(e) {
  e.preventDefault();
  
  const productData = {
    name: document.getElementById('productName').value,
    description: document.getElementById('productDescription').value,
    base_price: parseFloat(document.getElementById('basePrice').value),
    initial_inventory: parseInt(document.getElementById('initialInventory').value),
    max_winners: parseInt(document.getElementById('maxWinners').value),
    sale_start_time: new Date(document.getElementById('saleStartTime').value).toISOString(),
    sale_end_time: new Date(document.getElementById('saleEndTime').value).toISOString()
  };

  try {
    const response = await fetch(`${API_BASE}/admin/products`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify(productData)
    });

    const data = await response.json();

    if (data.success) {
      showMessage('Product created successfully!', 'success');
      document.getElementById('createProductForm').reset();
      
      // Ask if want to activate
      if (confirm('Product created! Do you want to activate the sale now?')) {
        await activateProduct(data.data.id);
      }
      
      loadProducts();
    } else {
      showMessage(data.error.message || 'Failed to create product', 'error');
    }
  } catch (error) {
    showMessage('Error creating product: ' + error.message, 'error');
  }
}

// Activate Product
async function activateProduct(productId) {
  try {
    const response = await fetch(`${API_BASE}/admin/products/${productId}/activate`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });

    const data = await response.json();

    if (data.success) {
      showMessage('Sale activated successfully!', 'success');
      loadProducts();
    } else {
      showMessage(data.error.message || 'Failed to activate sale', 'error');
    }
  } catch (error) {
    showMessage('Error activating sale: ' + error.message, 'error');
  }
}

// End Product Sale
async function endProduct(productId) {
  if (!confirm('Are you sure you want to end this sale?')) return;
  
  try {
    const response = await fetch(`${API_BASE}/admin/products/${productId}/end`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });

    const data = await response.json();

    if (data.success) {
      showMessage('Sale ended successfully!', 'success');
      loadProducts();
    } else {
      showMessage(data.error.message || 'Failed to end sale', 'error');
    }
  } catch (error) {
    showMessage('Error ending sale: ' + error.message, 'error');
  }
}

// Load Products
async function loadProducts() {
  try {
    const response = await fetch(`${API_BASE}/products`, {
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });

    const data = await response.json();
    console.log('Products response:', data);

    if (data.success) {
      const products = data.data?.products || [];
      displayProducts(products);
      populateProductSelect(products);
    } else {
      console.error('Load products failed:', data);
      document.getElementById('productsList').innerHTML = '<div class="card"><p style="color: #f44336;">Failed to load products: ' + (data.error?.message || 'Unknown error') + '</p></div>';
    }
  } catch (error) {
    console.error('Load products error:', error);
    document.getElementById('productsList').innerHTML = '<div class="card"><p style="color: #f44336;">Error loading products: ' + error.message + '</p></div>';
  }
}

// Display Products
function displayProducts(products) {
  const container = document.getElementById('productsList');
  
  if (!products || !Array.isArray(products) || products.length === 0) {
    container.innerHTML = '<p style="text-align: center; color: #999; padding: 20px;">No products yet. Create one above!</p>';
    return;
  }

  const html = `
    <table style="width: 100%; border-collapse: collapse;">
      <thead>
        <tr style="border-bottom: 2px solid #e0e0e0;">
          <th style="text-align: left; padding: 12px 8px; color: #666; font-weight: 600;">Product Name</th>
          <th style="text-align: left; padding: 12px 8px; color: #666; font-weight: 600;">Base Price</th>
          <th style="text-align: left; padding: 12px 8px; color: #666; font-weight: 600;">Inventory</th>
          <th style="text-align: left; padding: 12px 8px; color: #666; font-weight: 600;">Max Winners</th>
          <th style="text-align: left; padding: 12px 8px; color: #666; font-weight: 600;">Sale Period</th>
          <th style="text-align: left; padding: 12px 8px; color: #666; font-weight: 600;">Status</th>
          <th style="text-align: right; padding: 12px 8px; color: #666; font-weight: 600;">Action</th>
        </tr>
      </thead>
      <tbody>
        ${products.map(product => `
          <tr style="border-bottom: 1px solid #f0f0f0;">
            <td style="padding: 16px 8px;">
              <strong>${product.name}</strong>
              ${product.description ? `<br><span style="color: #999; font-size: 12px;">${product.description}</span>` : ''}
            </td>
            <td style="padding: 16px 8px;">$${product.base_price}</td>
            <td style="padding: 16px 8px;">${product.initial_inventory}</td>
            <td style="padding: 16px 8px;">${product.max_winners}</td>
            <td style="padding: 16px 8px; font-size: 12px;">
              <div>${new Date(product.sale_start_time).toLocaleString()}</div>
              <div style="color: #999;">${new Date(product.sale_end_time).toLocaleString()}</div>
            </td>
            <td style="padding: 16px 8px;">
              <span class="badge ${product.status === 'active' ? 'badge-success' : product.status === 'pending' ? 'badge-warning' : ''}">${product.status}</span>
            </td>
            <td style="padding: 16px 8px; text-align: right;">
              ${product.status === 'pending' ? 
                `<button class="btn btn-primary" style="width: auto; padding: 8px 16px; font-size: 13px;" onclick="activateProduct(${product.id})">Activate Sale</button>` : 
                product.status === 'active' ?
                `<button class="btn btn-secondary" style="width: auto; padding: 8px 16px; font-size: 13px;" onclick="endProduct(${product.id})">End Sale</button>` :
                `<span style="color: #999;">Completed</span>`
              }
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;

  container.innerHTML = html;
}

// Populate Product Select
function populateProductSelect(products) {
  const select = document.getElementById('productSelect');
  
  if (!select) return;
  
  select.innerHTML = '<option value="">Global Default</option>';
  
  products.forEach(product => {
    const option = document.createElement('option');
    option.value = product.id;
    option.textContent = `${product.name} (${product.status})`;
    select.appendChild(option);
  });
}

// Handle Product Select
async function handleProductSelect(e) {
  const productId = e.target.value;
  
  if (!productId) {
    document.getElementById('currentAlpha').textContent = '-';
    document.getElementById('currentBeta').textContent = '-';
    document.getElementById('currentGamma').textContent = '-';
    return;
  }

  // Load current parameters (from global scoring_parameters table)
  loadScoringParameters();
}

// Load Scoring Parameters
async function loadScoringParameters() {
  try {
    // Fetch all scoring parameters
    const response = await fetch(`${API_BASE}/admin/scoring-parameters`, {
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });

    if (!response.ok) {
      console.error('Scoring parameters request failed:', response.status, response.statusText);
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    console.log('Scoring parameters response:', data);
    
    if (data.success && data.data && data.data.length > 0) {
      displayScoringParameters(data.data);
    } else {
      // Show default global parameters
      const currentParamsDiv = document.getElementById('currentParams');
      currentParamsDiv.innerHTML = `
        <h3 style="margin: 0 0 20px 0; padding-bottom: 10px; border-bottom: 2px solid #e0e0e0;">Global Default</h3>
        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px;">
          <div>
            <p style="color: #666; margin: 0; font-size: 12px;">α (Price Weight)</p>
            <p style="font-size: 24px; font-weight: 700; color: #667eea; margin: 5px 0 0 0;">${(1.0).toFixed(4)}</p>
          </div>
          <div>
            <p style="color: #666; margin: 0; font-size: 12px;">β (Time Weight)</p>
            <p style="font-size: 24px; font-weight: 700; color: #667eea; margin: 5px 0 0 0;">${(100.0).toFixed(4)}</p>
          </div>
          <div>
            <p style="color: #666; margin: 0; font-size: 12px;">γ (Member Weight)</p>
            <p style="font-size: 24px; font-weight: 700; color: #667eea; margin: 5px 0 0 0;">${(50.0).toFixed(4)}</p>
          </div>
        </div>
        <p class="info-text" style="margin-top: 20px; margin-bottom: 0;">These are the default parameters when no product-specific settings exist.</p>
      `;
    }
  } catch (error) {
    console.error('Error loading parameters:', error);
    document.getElementById('currentParams').innerHTML = '<p style="color: #999; text-align: center; padding: 20px;">Unable to load parameters</p>';
  }
}

// Display Scoring Parameters
function displayScoringParameters(params) {
  const currentParamsDiv = document.getElementById('currentParams');
  
  const html = params.map((param, index) => `
    <div style="${index > 0 ? 'margin-top: 30px; padding-top: 30px; border-top: 2px solid #e0e0e0;' : ''}">
      <h3 style="margin: 0 0 15px 0;">
        ${param.product_name || (param.product_id ? `Product #${param.product_id}` : 'Global Default')}
        ${param.is_active ? '<span class="badge badge-success" style="margin-left: 10px; font-size: 12px;">Active</span>' : ''}
      </h3>
      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px;">
        <div>
          <p style="color: #666; margin: 0; font-size: 12px;">α (Price Weight)</p>
          <p style="font-size: 24px; font-weight: 700; color: #667eea; margin: 5px 0 0 0;">${parseFloat(param.alpha).toFixed(4)}</p>
        </div>
        <div>
          <p style="color: #666; margin: 0; font-size: 12px;">β (Time Weight)</p>
          <p style="font-size: 24px; font-weight: 700; color: #667eea; margin: 5px 0 0 0;">${parseFloat(param.beta).toFixed(4)}</p>
        </div>
        <div>
          <p style="color: #666; margin: 0; font-size: 12px;">γ (Member Weight)</p>
          <p style="font-size: 24px; font-weight: 700; color: #667eea; margin: 5px 0 0 0;">${parseFloat(param.gamma).toFixed(4)}</p>
        </div>
      </div>
    </div>
  `).join('');
  
  currentParamsDiv.innerHTML = html;
}

// Update Scoring Parameters
async function handleUpdateScoring(e) {
  e.preventDefault();
  
  const productId = document.getElementById('productSelect').value;
  
  if (!productId) {
    showMessage('Please select a product', 'error');
    return;
  }

  const alpha = document.getElementById('alpha').value;
  const beta = document.getElementById('beta').value;
  const gamma = document.getElementById('gamma').value;

  if (!alpha || !beta || !gamma) {
    showMessage('Please fill in all parameters (α, β, γ)', 'error');
    return;
  }

  try {
    const response = await fetch(`${API_BASE}/admin/products/${productId}/scoring`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({
        alpha: parseFloat(alpha),
        beta: parseFloat(beta),
        gamma: parseFloat(gamma)
      })
    });

    const data = await response.json();

    if (data.success) {
      showMessage('Scoring parameters updated successfully!', 'success');
      document.getElementById('updateScoringForm').reset();
      document.getElementById('productSelect').value = '';
      loadScoringParameters();
    } else {
      showMessage(data.error.message || 'Failed to update parameters', 'error');
    }
  } catch (error) {
    showMessage('Error updating parameters: ' + error.message, 'error');
  }
}

// Message Box
function showMessage(message, type = 'info') {
  const messageBox = document.getElementById('messageBox');
  messageBox.textContent = message;
  messageBox.className = `message-box ${type} show`;
  
  setTimeout(() => {
    messageBox.classList.remove('show');
  }, 4000);
}

// Logout
function logout() {
  localStorage.removeItem('token');
  window.location.href = '/login.html';
}
