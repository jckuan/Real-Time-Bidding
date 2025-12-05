# Phase 2 Setup Guide

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Start Docker Services

```bash
# Start PostgreSQL and Redis
docker-compose up -d postgres redis

# Check if services are running
docker-compose ps
```

### 3. Run Database Migrations

```bash
npm run migrate
```

This will create all the necessary tables:
- `users`
- `products`
- `bids`
- `orders`
- `scoring_parameters`

### 4. Start the Development Server

```bash
npm run dev
```

The server will start on `http://localhost:3000`

---

## Testing the API

### Check Health

```bash
curl http://localhost:3000/health
```

### Register a User

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "username": "testuser"
  }'
```

Response will include:
- User details with assigned `member_weight`
- JWT `token` (copy this for authenticated requests)

### Login

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Get Profile (Authenticated)

```bash
curl http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### Create a Product (Admin)

```bash
curl -X POST http://localhost:3000/api/v1/admin/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "name": "iPhone 15 Pro",
    "description": "Latest flagship smartphone",
    "base_price": 999.00,
    "initial_inventory": 50,
    "max_winners": 50,
    "sale_start_time": "2025-12-10T12:00:00Z",
    "sale_end_time": "2025-12-10T12:30:00Z"
  }'
```

### Get All Products

```bash
curl http://localhost:3000/api/v1/products
```

### Get Product by ID

```bash
curl http://localhost:3000/api/v1/products/1
```

### Update Scoring Parameters

```bash
curl -X PUT http://localhost:3000/api/v1/admin/products/1/scoring \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "alpha": 1.2,
    "beta": 120.0,
    "gamma": 60.0
  }'
```

### Activate Sale

```bash
curl -X POST http://localhost:3000/api/v1/admin/products/1/activate \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Optional: Using GUI Tools

### PostgreSQL (pgAdmin)

Access at: `http://localhost:5050`
- Email: `admin@rtb.local`
- Password: `admin`

Add server connection:
- Host: `postgres`
- Port: `5432`
- Database: `rtb_database`
- Username: `rtb_user`
- Password: `rtb_password`

### Redis (Redis Commander)

Access at: `http://localhost:8081`

---

## Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clears all data)
docker-compose down -v
```

---

## What's Implemented

✅ **Environment Setup**
- Docker Compose with PostgreSQL, Redis
- Environment configuration

✅ **Database**
- PostgreSQL connection pooling
- All table schemas with migrations
- Optimistic locking support
- Indexes for performance

✅ **Authentication System**
- User registration with password hashing
- Login with JWT tokens
- Auth middleware for protected routes
- Member weight assignment (random 0.5-2.0)

✅ **Product Management**
- Create products (admin)
- Get all products
- Get product by ID
- Update scoring parameters (α, β, γ)
- Activate/end sales

✅ **Infrastructure**
- Express server with WebSocket support
- Error handling
- Logging with Winston
- Rate limiting ready
- CORS configured

---

## Next: Phase 3 - Bidding Engine

Coming up:
- Bid submission and updates
- Score calculation algorithm
- Redis leaderboard (ZSET)
- Real-time WebSocket updates
- Async bid persistence
