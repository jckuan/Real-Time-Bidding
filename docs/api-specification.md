# API Specification

## Overview

This document defines the REST API endpoints and WebSocket protocols for the Real-Time Bidding & Flash Sale System.

**Base URL:** `http://localhost:3000/api/v1` (development)

**Authentication:** JWT tokens via `Authorization: Bearer <token>` header

---

## REST API Endpoints

### Authentication & User Management

#### POST /auth/register

Register a new user account.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "username": "johndoe"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "username": "johndoe",
      "member_weight": 1.00,
      "created_at": "2025-12-05T10:30:00Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Errors:**
- `400` - Invalid input (email format, weak password)
- `409` - Email already exists

---

#### POST /auth/login

Authenticate user and receive JWT token.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "username": "johndoe",
      "member_weight": 1.50
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Errors:**
- `401` - Invalid credentials
- `404` - User not found

---

#### GET /auth/me

Get current user profile.

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com",
    "username": "johndoe",
    "member_weight": 1.50,
    "created_at": "2025-12-05T10:30:00Z",
    "last_login": "2025-12-05T15:45:00Z"
  }
}
```

---

### Product Management

#### GET /products

List all products (active, upcoming, or ended sales).

**Query Parameters:**
- `status` (optional): `pending`, `active`, `ended` (default: `active`)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": 1,
        "name": "iPhone 15 Pro",
        "description": "Latest flagship smartphone",
        "base_price": 999.00,
        "current_inventory": 50,
        "max_winners": 50,
        "sale_start_time": "2025-12-10T12:00:00Z",
        "sale_end_time": "2025-12-10T12:30:00Z",
        "status": "active"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 1
    }
  }
}
```

---

#### GET /products/:id

Get detailed information about a specific product.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "iPhone 15 Pro",
    "description": "Latest flagship smartphone",
    "base_price": 999.00,
    "initial_inventory": 50,
    "current_inventory": 50,
    "max_winners": 50,
    "sale_start_time": "2025-12-10T12:00:00Z",
    "sale_end_time": "2025-12-10T12:30:00Z",
    "status": "active",
    "scoring_params": {
      "alpha": 1.0,
      "beta": 100.0,
      "gamma": 50.0
    }
  }
}
```

**Errors:**
- `404` - Product not found

---

### Bidding

#### POST /bids

Submit a new bid for a product.

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "product_id": 1,
  "bid_price": 1050.00
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "bid": {
      "id": 123,
      "user_id": 1,
      "product_id": 1,
      "bid_price": 1050.00,
      "reaction_time": 5.234,
      "member_weight": 1.50,
      "calculated_score": 1267.45,
      "bid_timestamp": "2025-12-10T12:00:05Z",
      "rank": 15
    },
    "leaderboard_position": {
      "current_rank": 15,
      "total_bids": 847,
      "in_top_k": true,
      "threshold_score": 1200.00
    }
  }
}
```

**Errors:**
- `400` - Invalid bid price (must be >= base_price)
- `401` - Unauthorized (no token)
- `403` - Sale not active or user already has winning bid
- `404` - Product not found
- `429` - Rate limit exceeded

---

#### PUT /bids/:id

Update an existing bid (increase price).

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "bid_price": 1100.00
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "bid": {
      "id": 124,
      "user_id": 1,
      "product_id": 1,
      "bid_price": 1100.00,
      "reaction_time": 125.456,
      "member_weight": 1.50,
      "calculated_score": 1275.87,
      "bid_timestamp": "2025-12-10T12:02:05Z",
      "rank": 12
    },
    "leaderboard_position": {
      "current_rank": 12,
      "total_bids": 1203,
      "in_top_k": true,
      "threshold_score": 1250.00
    }
  }
}
```

**Errors:**
- `400` - New price must be higher than current bid
- `404` - Bid not found
- `403` - Cannot modify other user's bid

---

#### GET /bids/my-bids

Get current user's bid history.

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `product_id` (optional): Filter by product
- `page` (optional): Page number
- `limit` (optional): Items per page

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "bids": [
      {
        "id": 124,
        "product_id": 1,
        "product_name": "iPhone 15 Pro",
        "bid_price": 1100.00,
        "calculated_score": 1275.87,
        "rank": 12,
        "is_latest": true,
        "status": "active",
        "bid_timestamp": "2025-12-10T12:02:05Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 1
    }
  }
}
```

---

### Leaderboard

#### GET /leaderboard/:product_id

Get the current Top K leaderboard for a product.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "product_id": 1,
    "max_winners": 50,
    "total_participants": 1523,
    "top_bids": [
      {
        "rank": 1,
        "user_id": 42,
        "username": "speedy_bidder",
        "bid_price": 1500.00,
        "calculated_score": 2145.67,
        "bid_timestamp": "2025-12-10T12:00:01Z"
      },
      {
        "rank": 2,
        "user_id": 89,
        "username": "quick_buyer",
        "bid_price": 1450.00,
        "calculated_score": 2098.23,
        "bid_timestamp": "2025-12-10T12:00:02Z"
      }
      // ... up to rank 50
    ],
    "threshold_score": 1250.00,
    "last_updated": "2025-12-10T12:05:30Z"
  }
}
```

**Notes:**
- Updates in real-time via WebSocket (see below)
- This endpoint provides snapshot at request time

---

### Admin Endpoints

#### POST /admin/products

Create a new product/sale event.

**Headers:** `Authorization: Bearer <admin-token>`

**Request:**
```json
{
  "name": "iPhone 15 Pro",
  "description": "Latest flagship smartphone",
  "base_price": 999.00,
  "initial_inventory": 50,
  "max_winners": 50,
  "sale_start_time": "2025-12-10T12:00:00Z",
  "sale_end_time": "2025-12-10T12:30:00Z"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "iPhone 15 Pro",
    "status": "pending",
    "created_at": "2025-12-05T10:00:00Z"
  }
}
```

**Errors:**
- `403` - Insufficient permissions
- `400` - Invalid input

---

#### PUT /admin/products/:id/scoring

Update scoring parameters for a product.

**Headers:** `Authorization: Bearer <admin-token>`

**Request:**
```json
{
  "alpha": 1.2,
  "beta": 120.0,
  "gamma": 60.0
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "product_id": 1,
    "alpha": 1.2,
    "beta": 120.0,
    "gamma": 60.0,
    "updated_at": "2025-12-10T11:55:00Z"
  }
}
```

**Notes:**
- Updates are applied immediately to new bids
- Existing bids retain their original scores

---

#### POST /admin/products/:id/finalize

Finalize sale and create orders for Top K winners.

**Headers:** `Authorization: Bearer <admin-token>`

**Request:**
```json
{
  "force": false
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "product_id": 1,
    "total_bids": 1523,
    "winners_count": 50,
    "orders_created": 50,
    "final_inventory": 0,
    "finalized_at": "2025-12-10T12:30:05Z"
  }
}
```

**Errors:**
- `400` - Sale is still active
- `409` - Already finalized

---

## WebSocket Protocol

### Connection

**URL:** `ws://localhost:3000/ws`

**Authentication:** Send JWT token in connection query parameter
```
ws://localhost:3000/ws?token=<jwt-token>
```

---

### Client → Server Events

#### Subscribe to Leaderboard

```json
{
  "event": "subscribe_leaderboard",
  "data": {
    "product_id": 1
  }
}
```

**Response:**
```json
{
  "event": "subscribed",
  "data": {
    "product_id": 1,
    "room": "leaderboard:1"
  }
}
```

---

#### Unsubscribe from Leaderboard

```json
{
  "event": "unsubscribe_leaderboard",
  "data": {
    "product_id": 1
  }
}
```

---

### Server → Client Events

#### Leaderboard Update

Broadcast to all subscribers when leaderboard changes.

```json
{
  "event": "leaderboard_update",
  "data": {
    "product_id": 1,
    "max_winners": 50,
    "total_participants": 1524,
    "top_bids": [
      {
        "rank": 1,
        "username": "speedy_bidder",
        "calculated_score": 2145.67
      }
      // Top 10 or Top K, depending on configuration
    ],
    "threshold_score": 1250.00,
    "your_rank": 12,
    "your_score": 1275.87,
    "timestamp": "2025-12-10T12:05:31Z"
  }
}
```

**Broadcast Frequency:**
- Every 1-2 seconds during active sale
- On every bid submission (debounced to prevent spam)

---

#### Bid Status Update

Sent to individual user when their bid is processed.

```json
{
  "event": "bid_status",
  "data": {
    "bid_id": 124,
    "product_id": 1,
    "status": "accepted",
    "calculated_score": 1275.87,
    "rank": 12,
    "in_top_k": true,
    "message": "Your bid has been updated successfully"
  }
}
```

---

#### Sale Status Change

Broadcast when sale starts or ends.

```json
{
  "event": "sale_status",
  "data": {
    "product_id": 1,
    "status": "ended",
    "final_winners_count": 50,
    "timestamp": "2025-12-10T12:30:00Z"
  }
}
```

---

#### Error Event

Sent when operation fails.

```json
{
  "event": "error",
  "data": {
    "code": "INVALID_PRODUCT",
    "message": "Product not found or sale not active"
  }
}
```

---

## Response Format Standards

### Success Response

```json
{
  "success": true,
  "data": { /* response data */ }
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": { /* optional additional context */ }
  }
}
```

---

## HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful GET, PUT, DELETE |
| 201 | Created | Successful POST creating resource |
| 400 | Bad Request | Invalid input/validation error |
| 401 | Unauthorized | Missing or invalid auth token |
| 403 | Forbidden | Valid auth but insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate resource or state conflict |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |

---

## Rate Limiting

- **Authentication endpoints:** 5 requests per minute per IP
- **Bid submission:** 10 requests per minute per user
- **Bid update:** 20 requests per minute per user
- **Read endpoints:** 100 requests per minute per user

**Rate Limit Headers:**
```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 7
X-RateLimit-Reset: 1702305600
```

---

## CORS Configuration

**Allowed Origins (Development):**
- `http://localhost:3000`
- `http://localhost:5173`

**Allowed Methods:**
- GET, POST, PUT, DELETE, OPTIONS

**Allowed Headers:**
- `Authorization`, `Content-Type`

---

## Versioning

API version is included in the base path: `/api/v1`

Breaking changes will increment the major version: `/api/v2`

---

## Future API Extensions

- **GraphQL endpoint** for flexible querying
- **Batch bid operations** for advanced users
- **Webhooks** for external integrations
- **Admin analytics endpoints** for reporting
