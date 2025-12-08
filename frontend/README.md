# Frontend - Real-Time Bidding System

A minimal but functional frontend for the Real-Time Bidding & Flash Sale System.

## Overview

This frontend provides:
- **Login/Register** - User authentication with member weight display
- **Dashboard** - Product listing with live countdown timers
- **Bidding Interface** - Real-time bid submission and updates
- **Live Leaderboard** - WebSocket-powered real-time leaderboard updates

## Technology Stack

- **Pure HTML/CSS/JavaScript** - No build step required
- **Socket.io Client** - For WebSocket real-time updates
- **Fetch API** - For REST API calls

## File Structure

```
frontend/
├── login.html          # Login and registration page
├── login.js            # Login/register logic
├── dashboard.html      # Product listing page
├── dashboard.js        # Dashboard logic with timers
├── bidding.html        # Bidding interface with live leaderboard
├── bidding.js          # Bidding logic and WebSocket handling
├── styles.css          # Unified styles for all pages
└── config.js           # API configuration
```

## Features

### 1. Login/Register Page (`login.html`)
- Toggle between login and register forms
- Email and password validation
- Displays member weight upon registration
- Automatic redirect to dashboard after login
- Token storage in localStorage

### 2. Dashboard (`dashboard.html`)
- Lists all active products
- Real-time countdown timers for:
  - Time until sale starts
  - Time remaining in sale
- Status badges (Upcoming, Live, Ended)
- Click to navigate to bidding interface

### 3. Bidding Interface (`bidding.html`)

#### Product Information
- Product name, description, pricing
- Sale timing and inventory details
- Current sale status

#### My Bid Status
- Current bid price
- Calculated score
- Current rank
- Bid timestamp

#### Bidding Form
- Submit new bid (first-time bidders)
- Update existing bid (price increase)
- Real-time validation
- Error and success messages

#### Live Leaderboard
- WebSocket connection status indicator
- Key statistics:
  - Total bidders
  - Highest score
  - Entry threshold (score needed for top K)
- Real-time table showing:
  - Rank (with gold/silver/bronze highlighting)
  - Email (with "You" indicator)
  - Score
  - Member weight
- Winner highlighting (top K users in green)
- Auto-refresh every 2 seconds via WebSocket

## Usage

### Running the Frontend

The frontend is automatically served by the backend server:

```bash
# Start the backend server
cd /Users/jckuan/Dev/Real-Time-Bidding
node src/server.js
```

Access the frontend at:
```
http://localhost:3000/login.html
```

### User Flow

1. **Register/Login**
   - Navigate to `http://localhost:3000/login.html`
   - Create an account or login
   - Note your member weight (affects scoring)

2. **Browse Products**
   - View active/upcoming products
   - See countdown timers
   - Click "Place Bid" on active sales

3. **Place Bids**
   - Enter bid price (≥ base price)
   - Submit bid
   - View your rank and score immediately

4. **Update Bids**
   - Increase your bid price to improve rank
   - See real-time rank changes
   - Monitor leaderboard for competition

5. **Watch Leaderboard**
   - Live updates every 2 seconds
   - See your position highlighted
   - Top K winners highlighted in green

## WebSocket Events

### Client → Server

```javascript
// Subscribe to product leaderboard
socket.emit('subscribe_leaderboard', productId);

// Unsubscribe
socket.emit('unsubscribe_leaderboard', productId);
```

### Server → Client

```javascript
// Periodic broadcast (every 2 seconds)
socket.on('leaderboard_broadcast', (data) => {
  // data: { productId, leaderboard, highestScore, entryThreshold, ... }
});

// Individual bid update
socket.on('leaderboard_update', (data) => {
  // data: { userId, productId, bidPrice, score, rank, ... }
});

// Sale ended
socket.on('sale_ended', (data) => {
  // data: { productId, message, timestamp }
});
```

## API Integration

All API calls use the configuration from `config.js`:

```javascript
const API_BASE_URL = 'http://localhost:3000/api/v1';
const WS_URL = 'http://localhost:3000';
```

Authentication:
```javascript
const token = localStorage.getItem('token');

fetch(`${API_BASE_URL}/endpoint`, {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

## Styling

The UI uses a modern, responsive design:
- **Colors**: Purple gradient theme (#667eea → #764ba2)
- **Typography**: System fonts for optimal performance
- **Layout**: CSS Grid and Flexbox
- **Responsive**: Mobile-friendly breakpoints
- **Animations**: Smooth transitions and pulse effects

### Key CSS Classes

- `.card` - White rounded card container
- `.btn-primary` - Purple gradient button
- `.product-card` - Product display card with hover effect
- `.my-bid-status` - User's current bid display (purple gradient)
- `.leaderboard-table` - Sortable table with winner highlighting
- `.status-active/pending/completed` - Status badges
- `.rank-1/2/3` - Gold/silver/bronze rank colors

## Performance Considerations

1. **WebSocket Efficiency**
   - Broadcasts only to subscribed rooms
   - Auto-stops when no subscribers
   - 2-second interval balances freshness and load

2. **Minimal Dependencies**
   - Only Socket.io client library required
   - No build step or bundler
   - Fast page loads

3. **State Management**
   - localStorage for authentication
   - In-memory state for real-time data
   - Minimal DOM updates

## Browser Compatibility

Tested on:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

Requires:
- ES6+ JavaScript support
- WebSocket support
- Fetch API support
- localStorage

## Security Notes

1. **Token Storage**: Tokens are stored in localStorage (acceptable for demo, consider httpOnly cookies for production)
2. **CORS**: Configured for localhost:3000
3. **Input Validation**: Client-side validation plus server-side enforcement
4. **XSS Protection**: Basic sanitization (enhance for production)

## Customization

### Changing Broadcast Frequency

Edit `src/services/broadcastService.js`:
```javascript
this.broadcastFrequency = 2000; // Change to desired milliseconds
```

### Changing API Endpoint

Edit `frontend/config.js`:
```javascript
const API_BASE_URL = 'http://your-server:port/api/v1';
const WS_URL = 'http://your-server:port';
```

### Styling Customization

Edit `frontend/styles.css` - all styles are in one file for easy modification.

## Troubleshooting

### WebSocket Not Connecting
- Check server is running: `http://localhost:3000/health`
- Check browser console for errors
- Verify Socket.io version matches server (4.6.1)

### Frontend Not Loading
- Ensure server is serving static files (check `src/server.js`)
- Clear browser cache
- Check browser console for 404 errors

### Real-time Updates Not Working
- Check connection status indicator on bidding page
- Verify you're subscribed to the correct productId
- Check server logs for WebSocket activity

### Authentication Issues
- Clear localStorage: `localStorage.clear()`
- Register new account
- Check token expiration (1 hour)

## Next Steps for Production

1. **Build Process**: Add bundler (Webpack/Vite) for optimization
2. **Framework**: Consider React/Vue for better state management
3. **Security**: Implement httpOnly cookies, CSRF protection
4. **Error Handling**: More robust error boundaries
5. **Testing**: Add E2E tests with Cypress/Playwright
6. **Performance**: Implement virtual scrolling for large leaderboards
7. **Accessibility**: Add ARIA labels and keyboard navigation
8. **Internationalization**: Multi-language support

## Demo Credentials

For testing, you can use the test script to create users:

```bash
cd tests
chmod +x test-phase4.sh
./test-phase4.sh
```

This creates 5 test users and a product, then opens the bidding interface for testing.
