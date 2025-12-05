# Real-Time Bidding & Flash Sale System

## Project Overview

**Objective:** Design and implement a cloud-based backend system capable of handling "Thundering Herd" traffic for a mixed "Dynamic Bidding" and "Flash Sale" e-commerce event.

**Core Challenge:** Ensure data consistency (no over-selling), real-time leaderboard updates, and high availability under high concurrency.

---

## Phase 1: Architecture Design & Technical Strategy

**Goal:** Define the system blueprint, select the technology stack, and plan for scalability.

### 1.1 Requirements Analysis

- Analyze the scoring formula: 
  
  $$Score = \alpha \cdot P + \frac{\beta}{T+1} + \gamma \cdot W$$

- Define the interaction flow between:
  - Price ($P$)
  - Reaction Time ($T$)
  - Member Weight ($W$)

### 1.2 Technology Stack Selection

- **Backend:** Select a high-performance language (e.g., Go, Node.js, or Java Spring Boot)
- **Database:**
  - **Persistent Store:** Relational DB (PostgreSQL/MySQL) for user data and final orders
  - **In-Memory Store:** Redis for real-time leaderboards (Sorted Sets), caching, and session management
- **Message Queue (Optional but recommended):** Kafka or RabbitMQ for buffering write requests if using an asynchronous write-behind strategy

### 1.3 Database Schema Design

- Design schemas for Users, Products, Bids, and Orders
- **Critical:** Design the inventory locking mechanism to prevent over-selling (e.g., Optimistic Locking or Redis Lua scripts)

### 1.4 API Contract Definition

- Define RESTful or gRPC endpoints for Login, Bidding, and Admin actions
- Define WebSocket/SSE protocols for the real-time leaderboard

---

## Phase 2: Core Infrastructure & Basic Modules

**Goal:** Set up the development environment and implement non-critical support systems.

### 2.1 Environment Setup

- Initialize the Git repository
- Set up local Docker environment (Docker Compose) for the App, Database, and Redis

### 2.2 Member System Implementation

- Implement Registration and Login APIs
- **Implement the Logic for Member Weight ($W$):**
  - Create a mechanism to assign $W$ (random assignment or preset based on mock user tiers)
  - Store $W$ in the user profile/session for quick access during bidding

### 2.3 Admin Dashboard (Backend)

- Implement API to create products and set inventory ($K$)
- Implement API to configure dynamic parameters ($\alpha$, $\beta$, $\gamma$)

---

## Phase 3: The Bidding Engine (Core Logic)

**Goal:** Implement the high-concurrency bidding logic and scoring algorithm.

### 3.1 Scoring Algorithm Implementation

- Develop the function to calculate $Score$ based on:
  - Input $P$ (Price)
  - Calculated $T$ (time delta)
  - Retrieved $W$ (Member Weight)
- Ensure parameters $\alpha$, $\beta$, $\gamma$ can be hot-reloaded or fetched dynamically without restarting the service

### 3.2 High-Concurrency Bidding API

- Implement the `POST /bid` and `PUT /bid` endpoints
- **Optimization:** Implement a write-heavy strategy. Instead of hitting the SQL DB immediately:
  1. Validate the bid
  2. Calculate the Score
  3. Update the Redis Sorted Set (ZSET) for the leaderboard
  4. Push the bid to a queue or persistence layer asynchronously

### 3.3 Inventory Control & Consistency

- Implement strict inventory checks
- Define the logic for "Tentative Winners" (Top $K$ in the Redis ZSET)
- Ensure the final commit (converting a tentative win to an order) checks the database inventory atomically

---

## Phase 4: Real-Time Data & Frontend Integration

**Goal:** Visualize the bidding war and ensure users see updates instantly.

### 4.1 Real-Time Leaderboard Backend

- Implement a WebSocket or Server-Sent Events (SSE) service
- Create a periodic or event-driven broadcaster that fetches the Top $K$ users, highest bid, and entry threshold score from Redis
- **Constraint Check:** Ensure the broadcast is efficient and doesn't crash under 1000+ connections

### 4.2 Frontend Development (Minimal/Functional)

- **Login Page:** Simple entry point
- **Bidding Interface:**
  - Display Item Info
  - Input field for Price ($P$)
  - "Submit Bid" and "Update Bid" buttons
- **Live Dashboard:**
  - Display the "Tentative Winners" list (Top $K$)
  - Display current User Rank and Score
  - Refresh data automatically via WebSocket/SSE

---

## Phase 5: Cloud Deployment & Scalability

**Goal:** Deploy to the cloud and configure auto-scaling for the "Thundering Herd."

### 5.1 Containerization

- Finalize Dockerfile for backend services and frontend (if separate)
- Ensure images are optimized and lightweight

### 5.2 Cloud Environment Setup (AWS/GCP)

- Provision a Managed Kubernetes Cluster (EKS/GKE) OR Container Service (ECS/Cloud Run)
- Set up a managed Database (RDS/Cloud SQL) and Redis (ElastiCache/Memorystore)

### 5.3 Scalability Configuration

- **Horizontal Pod Autoscaling (HPA):** Configure rules to scale CPU/Memory usage (e.g., scale out when CPU > 70%)
- **Load Balancing:** Configure the Application Load Balancer (ALB/Ingress) to distribute traffic

---

## Phase 6: Testing, Optimization & Final Deliverables

**Goal:** Prove the system works under pressure and prepare presentation materials.

### 6.1 Stress Testing (The "Thundering Herd")

- **Tooling:** Write scripts using JMeter, Locust, or k6
- **Scenario 1:** 1000+ concurrent users logging in and bidding simultaneously
- **Scenario 2:** Exponential growth of "Update Bid" requests as the deadline approaches

### 6.2 Consistency Verification

- Run a test where Total Bids >> Inventory ($K$)
- Verify SQL database records after the event: `Count(Sold Items) <= K`

### 6.3 Performance Tuning

- Analyze bottlenecks (CPU spikes, DB locks)
- Tune Redis persistence and connection pooling settings

### 6.4 Demo Preparation

#### Video Recording (3 mins):
1. System startup & Config
2. User flow (Login → Bid → Rank change)
3. Load Test visualization (Split screen: Load tool vs. System Dashboards)
4. Cloud Auto-scaling (Show Pods increasing count)
5. Final Consistency Check (Database query result)

#### Presentation Slides (10-15 pages):
- Architecture Diagram
- The formula & data flow
- Consistency strategy (How you avoided over-selling)
- Stress test graphs (Response time vs. Load)