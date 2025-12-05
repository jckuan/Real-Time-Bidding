# Real-Time Bidding System - API Reference

## Base URL
`http://localhost:3000/api/v1`

---

## Authentication Endpoints

### Register
**POST** `/auth/register`

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "username": "johndoe"
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "username": "johndoe",
      "member_weight": 1.45,
      "created_at": "2025-12-05T..."
    },
    "token": "eyJhbGc..."
  }
}
```

---

### Login
**POST** `/auth/login`

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "username": "johndoe",
      "member_weight": 1.45
    },
    "token": "eyJhbGc..."
  }
}
```

---

### Get Profile
**GET** `/auth/me`

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com",
    "username": "johndoe",
    "member_weight": 1.45,
    "created_at": "2025-12-05T...",
    "last_login": "2025-12-05T..."
  }
}
```

---

## Product Endpoints

### Get All Products
**GET** `/products?status=active&page=1&limit=10`

**Query Parameters:**
- `status` (optional): `pending`, `active`, `ended`
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)

**Response (200):**
```json
{
  "success": true,
  "data": {
    "products": [...],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 5
    }
  }
}
```

---

### Get Product by ID
**GET** `/products/:id`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "iPhone 15 Pro",
    "description": "Latest flagship smartphone",
    "base_price": 999.00,
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

---

## Admin Endpoints

### Create Product
**POST** `/admin/products`

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
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

**Response (201):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "iPhone 15 Pro",
    ...
  }
}
```

---

### Update Scoring Parameters
**PUT** `/admin/products/:id/scoring`

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "alpha": 1.2,
  "beta": 120.0,
  "gamma": 60.0
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "product_id": 1,
    "alpha": 1.2,
    "beta": 120.0,
    "gamma": 60.0
  }
}
```

---

### Activate Sale
**POST** `/admin/products/:id/activate`

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "status": "active",
    ...
  }
}
```

---

### End Sale
**POST** `/admin/products/:id/end`

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "status": "ended",
    ...
  }
}
```

---

## Error Response Format

```json
{
  "success": false,
  "error": {
    "message": "Error description"
  }
}
```

---

## Common HTTP Status Codes

- **200 OK** - Successful request
- **201 Created** - Resource created successfully
- **400 Bad Request** - Invalid input
- **401 Unauthorized** - Missing or invalid token
- **404 Not Found** - Resource not found
- **409 Conflict** - Duplicate resource
- **500 Internal Server Error** - Server error
