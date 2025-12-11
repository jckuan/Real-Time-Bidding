# Documentation Index

This project has been consolidated to essential documentation only. Below is a guide to what each file contains.

## Core Documentation

### `/readme.md`
**Project overview and phase completion summary**
- High-level project objectives
- All 6 phases marked as complete (✅)
- Quick stats on performance (99% bid success, 6.5% error rate at 1000 users)
- References to detailed documentation

### `/docs/architecture.md`
**Comprehensive system architecture and design**
- Production architecture diagram (AWS deployment)
- Component descriptions (ECS, RDS, Redis, ALB)
- Implementation progress for all phases
- Stress test results (100 and 1000 concurrent users)
- Auto-scaling configuration and impact
- Security considerations and monitoring

### `/docs/auto-scaling-improvements.md`
**Detailed auto-scaling analysis**
- Before/after comparison (15-20% error → 6.5%)
- Auto-scaling configuration (4-10 tasks, 70% CPU)
- Observed behavior during load tests
- Bottlenecks identified and future optimizations
- Verification commands

## Technical Specifications

### `/docs/api-specification.md`
**Complete REST API and WebSocket reference**
- All endpoints with request/response examples
- Authentication flow (JWT)
- Bidding endpoints (submit, update, leaderboard)
- Admin endpoints (product management, scoring parameters)
- WebSocket events and protocols
- Error codes and validation rules

### `/docs/database-schema.md`
**PostgreSQL database design**
- Table schemas (users, products, bids, orders, scoring_parameters)
- Relationships and foreign keys
- Indexes for performance
- Migration scripts

### `/docs/design-decisions.md`
**Architectural choices and rationale**
- Why PostgreSQL vs NoSQL
- Redis Sorted Sets for leaderboards
- WebSocket vs polling
- Scoring algorithm implementation
- Consistency mechanisms (atomic operations, orders table)

### `/docs/tech-stack.md`
**Technology choices and versions**
- Node.js/Express backend
- PostgreSQL 15.8 database
- Redis 7.0 cache
- Socket.IO for WebSocket
- AWS services (ECS Fargate, RDS, ElastiCache, ALB)
- k6 for load testing

## AWS Deployment

### `/aws/DEPLOYMENT.md`
**Step-by-step AWS deployment guide**
- Prerequisites and critical requirements
- AWS services overview (ECR, ECS, RDS, ElastiCache, etc.)
- Deployment steps (IAM, VPC, security groups, etc.)
- Auto-scaling configuration
- Common deployment issues and fixes
- Troubleshooting commands
- Cleanup instructions

### `/aws/AWS-ARCHITECTURE.md`
**Detailed AWS infrastructure reference**
- Complete list of AWS services used
- Service configurations and endpoints
- Detailed architecture diagram with VPC layout
- Security group rules
- VPC endpoints setup
- Real-world resource identifiers

### `/aws/iam/IAM-SETUP.md`
**IAM roles configuration**
- RTB-ecsTaskExecutionRole setup
- RTB-ecsTaskRole setup
- Policy documents
- Automated setup script usage

## Testing

### `/tests/README.md`
**Test suite overview**
- Test files description
- Usage instructions
- Expected results

### `/tests/stress/README.md`
**Stress testing guide**
- k6 load testing setup
- Test scenarios (validation, thundering herd, sustained load, update spike)
- Running tests (quiet mode with saved results)
- Viewing results with `view-results.sh`
- Test metrics and thresholds

## Demo Materials

### `/demo-quick-start.md`
**3-minute demo recording guide**
- Pre-recording setup checklist
- Timeline (00:00-03:00) with script
- Required browser windows and terminal setup
- Step-by-step actions for each demo section
- Tips for smooth recording

### `/frontend/README.md`
**Frontend dashboard documentation**
- HTML/JavaScript implementation
- Login, dashboard, bidding, and admin interfaces
- WebSocket integration
- Local development setup

## Quick Reference

**Getting Started:**
1. Read `/readme.md` for overview
2. Review `/docs/architecture.md` for system design
3. Follow `/aws/DEPLOYMENT.md` for AWS setup
4. Check `/docs/api-specification.md` for API usage

**For Demos:**
1. Use `/demo-quick-start.md` for recording guide
2. Run `/tests/stress/run-stress-tests.sh` for load testing
3. Check `/docs/auto-scaling-improvements.md` for performance stats

**For Development:**
1. See `/docs/database-schema.md` for data model
2. Check `/docs/tech-stack.md` for dependencies
3. Review `/docs/design-decisions.md` for context

---

**Total Documentation:** 14 markdown files (consolidated from 20+ originally)
**Last Updated:** December 12, 2025
