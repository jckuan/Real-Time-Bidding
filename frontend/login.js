// DOM Elements
const loginForm = document.getElementById('login');
const registerForm = document.getElementById('register');
const showRegisterLink = document.getElementById('showRegister');
const showLoginLink = document.getElementById('showLogin');
const errorMessage = document.getElementById('errorMessage');
const successMessage = document.getElementById('successMessage');

// Toggle between login and register forms
showRegisterLink.addEventListener('click', (e) => {
  e.preventDefault();
  document.getElementById('loginForm').style.display = 'none';
  document.getElementById('registerForm').style.display = 'block';
  clearMessages();
});

showLoginLink.addEventListener('click', (e) => {
  e.preventDefault();
  document.getElementById('registerForm').style.display = 'none';
  document.getElementById('loginForm').style.display = 'block';
  clearMessages();
});

// Login handler
loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  clearMessages();

  const email = document.getElementById('loginEmail').value;
  const password = document.getElementById('loginPassword').value;

  try {
    const response = await fetch(`${API_BASE_URL}/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email, password })
    });

    const data = await response.json();

    if (data.success) {
      // Store token and user info
      localStorage.setItem('token', data.data.token);
      localStorage.setItem('user', JSON.stringify(data.data.user));
      
      showSuccess('Login successful! Redirecting...');
      
      // Redirect based on user role
      setTimeout(() => {
        if (data.data.user.role === 'admin') {
          window.location.href = 'admin.html';
        } else {
          window.location.href = 'dashboard.html';
        }
      }, 1000);
    } else {
      showError(data.error?.message || 'Login failed');
    }
  } catch (error) {
    showError('Connection error. Please check if the server is running.');
    console.error('Login error:', error);
  }
});

// Register handler
registerForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  clearMessages();

  const username = document.getElementById('registerUsername').value;
  const email = document.getElementById('registerEmail').value;
  const password = document.getElementById('registerPassword').value;

  try {
    const response = await fetch(`${API_BASE_URL}/auth/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ username, email, password })
    });

    const data = await response.json();

    if (data.success) {
      showSuccess(`Registration successful! Your member weight: ${data.data.memberWeight.toFixed(2)}`);
      
      // Switch to login form after 2 seconds
      setTimeout(() => {
        document.getElementById('registerForm').style.display = 'none';
        document.getElementById('loginForm').style.display = 'block';
        document.getElementById('loginEmail').value = email;
        clearMessages();
      }, 2000);
    } else {
      showError(data.error?.message || 'Registration failed');
    }
  } catch (error) {
    showError('Connection error. Please check if the server is running.');
    console.error('Registration error:', error);
  }
});

// Helper functions
function showError(message) {
  errorMessage.textContent = message;
  errorMessage.style.display = 'block';
  successMessage.style.display = 'none';
}

function showSuccess(message) {
  successMessage.textContent = message;
  successMessage.style.display = 'block';
  errorMessage.style.display = 'none';
}

function clearMessages() {
  errorMessage.style.display = 'none';
  successMessage.style.display = 'none';
}

// Check if already logged in
if (localStorage.getItem('token')) {
  window.location.href = 'dashboard.html';
}
