# Network Document Folder - Complete Implementation Plan

## 📋 Overview

The **Network Document Folder** is a microservice that enables cross-org collaboration on participant records and incident data within CVI (Community Violence Intervention) networks. It allows multiple tenant organizations to:

- **Share & deduplicate** participant records across orgs with privacy controls
- **Coordinate responses** to incidents in real-time
- **Make referrals** between organizations
- **Collaborate** with network-wide notes and alerts

**Status**: 🏗️ **Architecture Complete** - Ready for implementation

---

## 🎯 Key Features

### ✅ Participant Matching & Deduplication
- Privacy-preserving matching algorithm (hash-based)
- Human-in-the-loop confirmation required
- Handles edge cases (3-way matches, nickname variations, data entry errors)
- Score thresholds: 90+ (high confidence), 70-89 (needs review), <70 (no match)

### ✅ Cross-Org Incident Tracking
- Network-level incident creation and tracking
- Per-org response management (planned/current/completed actions)
- Multi-participant linking with role tracking
- Real-time status updates via WebSocket

### ✅ PII Privacy Controls
- Granular field-level permissions per org
- Hash-based matching without exposing raw PII
- Encryption at rest (Laravel encryption)
- Complete audit trail of all PII access

### ✅ Real-Time Collaboration
- GraphQL subscriptions over WebSocket
- Live updates for participants, incidents, notes
- Typing indicators and presence detection
- Critical alert notifications

### ✅ Cross-Org Referrals
- Full referral workflow (pending → accepted → in-progress → completed)
- Urgency levels (routine, urgent, critical)
- Optional local record creation on acceptance

---

## 📁 Repository Structure

```
network-document-folder/
├── README.md                          # This file
│
├── database-schema.sql                # Complete DB schema with indexes
├── sample-data.sql                    # Realistic test data (10 participants, 5 incidents)
├── matching-algorithm.md              # Detailed matching specification
│
├── demo/                              # Interactive demo (no backend required)
│   ├── index.html                     # Matching UI demo
│   ├── styles.css                     # Polished design
│   └── matching-demo.js               # Interactive scenarios
│
├── api-examples/                      # GraphQL API reference
│   ├── queries.graphql                # All query operations
│   ├── mutations.graphql              # All mutation operations
│   ├── subscriptions.graphql          # Real-time subscriptions
│   └── sample-responses.json          # Example responses with PII filtering
│
├── docs/                              # Comprehensive documentation
│   └── ARCHITECTURE.md                # System architecture & design decisions
│
└── react-app-spec/                    # (To be created)
    └── component-specs.md             # React component specifications
```

---

## 🚀 Quick Start

### 1. Review the Architecture

Start by reading the complete system design:
```bash
open docs/ARCHITECTURE.md
```

Key sections:
- System architecture diagram
- Data flow (participant queries, incident creation, real-time updates)
- Component architecture (frontend + backend)
- Database design (network tables + DSF views)
- Caching strategy (3-tier: request/Redis/LRU)
- Real-time subscriptions (WebSocket + Redis Pub/Sub)

### 2. Explore the Demo

See the matching algorithm in action:
```bash
open demo/index.html
```

Interactive scenarios:
- ✅ High confidence match (Score: 95+)
- ⚠️ Potential match needing review (Score: 70-89)
- ❌ No match found (Score: <70)
- 🔗 Three-way match (complex)
- 💬 Nickname variations
- ⚠️ Data entry errors (DOB off by 1 day)

### 3. Review the API

Study the GraphQL schema:
```bash
open api-examples/queries.graphql
open api-examples/mutations.graphql
open api-examples/subscriptions.graphql
```

See example responses with PII filtering:
```bash
open api-examples/sample-responses.json
```

### 4. Understand Matching

Read the matching algorithm specification:
```bash
open matching-algorithm.md
```

Key concepts:
- Field scoring (SSN: 45pts, DOB: 35pts, Name: 30pts)
- Privacy-preserving hashing (HMAC-SHA256)
- Edge case handling (3-way conflicts, typos, nickname variations)
- Performance optimization (indexed hash lookups)

### 5. Set Up Database

Create network-level tables:
```sql
-- Run in global database
source database-schema.sql

-- Load test data
source sample-data.sql
```

Tables created:
- `network_participants` - Deduplicated people
- `network_participant_sources` - Links to org records
- `network_incidents` - Shared incidents
- `network_incident_org_responses` - Per-org tracking
- `network_referrals` - Cross-org referrals
- `network_notes` - Collaboration notes
- `network_audit_log` - PII access tracking
- `network_pii_settings` - Privacy configurations

---

## 🏗️ Implementation Roadmap

### Phase 1: Database & Core Services ✅ (Planned)

**Files to create in `Apricot_Files/apricot-api/`**:

1. **Database Models** (`src/repository/models/global/`)
   ```
   network_participants.ts
   network_participant_sources.ts
   network_incidents.ts
   network_incident_org_responses.ts
   network_referrals.ts
   network_notes.ts
   network_audit_log.ts
   network_pii_settings.ts
   ```

2. **Repository Services** (`src/repository/services/`)
   ```
   NetworkParticipantService.ts
   NetworkIncidentService.ts
   NetworkReferralService.ts
   ```

3. **SQL Queries** (`src/repository/query/`)
   ```
   networkDocumentFolder.ts
   ```

### Phase 2: Business Logic ✅ (Planned)

**Application Services** (`src/application/services/`):

1. **networkDocumentFolderService.ts**
   - Main orchestration layer
   - Aggregates DSF view data
   - Applies PII filtering
   - Manages cache invalidation

2. **participantMatchingService.ts**
   - Matching algorithm implementation
   - Hash generation & comparison
   - Score calculation
   - Potential match detection

3. **networkCacheService.ts**
   - Multi-tier caching (Redis + LRU)
   - Cache key management
   - Selective invalidation

4. **networkEventService.ts**
   - Redis pub/sub wrapper
   - Event publishing
   - Subscription management

### Phase 3: GraphQL API ✅ (Planned)

**GraphQL Layer** (`src/graphql-api/`):

1. **Type Definitions** (`typeDefs/`)
   ```
   networkDocumentFolder.ts      # Root schema
   networkParticipant.ts
   networkIncident.ts
   networkReferral.ts
   networkNote.ts
   ```

2. **Resolvers** (`resolvers/networkDocumentFolder/`)
   ```
   queries.ts                    # All query resolvers
   mutations.ts                  # All mutation resolvers
   subscriptions.ts              # WebSocket subscriptions
   ```

3. **WebSocket Setup** (modify `index.ts`)
   - Add WebSocketServer
   - Configure RedisPubSub
   - Enable subscription handlers

### Phase 4: Frontend (React) ✅ (Planned)

**React App** (new app in Apricot UI):

```
src/NetworkDocumentFolder/
├── views/
│   ├── PeopleView/
│   │   ├── ParticipantList.tsx
│   │   ├── ParticipantDetail.tsx
│   │   ├── MatchReviewModal.tsx
│   │   └── PIIVisibilityToggle.tsx
│   │
│   ├── IncidentsView/
│   │   ├── IncidentList.tsx
│   │   ├── IncidentDetail.tsx
│   │   └── OrgResponseTracker.tsx
│   │
│   ├── ReferralsView/
│   │   ├── ReferralList.tsx
│   │   └── ReferralDetail.tsx
│   │
│   └── DashboardView/
│       └── NetworkOverview.tsx
│
├── components/
│   ├── NetworkHeader.tsx
│   ├── MatchComparisonTable.tsx
│   └── IncidentTimeline.tsx
│
├── hooks/
│   ├── useNetworkParticipants.ts
│   ├── useParticipantSubscription.ts
│   └── usePIIPermissions.ts
│
└── graphql/
    ├── client.ts                  # Apollo Client + WebSocket
    ├── queries/
    ├── mutations/
    └── subscriptions/
```

### Phase 5: Testing & Deployment 🔜 (To Plan)

1. Unit tests (matching algorithm, PII filtering)
2. Integration tests (full workflows)
3. Performance tests (100+ participants, 10 orgs)
4. Load testing (WebSocket connections)
5. Security audit (PII protection)
6. Documentation (API docs, user guide)
7. Production deployment

---

## 🔧 Technical Stack

### Backend
- **API**: GraphQL (Apollo Server 3.13.0)
- **Real-time**: WebSocket (graphql-ws)
- **Database**: MySQL (network tables) + Tenant DBs (DSF views)
- **Cache**: Redis 4.x (cache + pub/sub)
- **Jobs**: Bull queue
- **Language**: TypeScript/Node.js

### Frontend
- **Framework**: React 18+
- **Data**: Apollo Client (GraphQL + subscriptions)
- **State**: React Query + Context API
- **UI**: Tailwind CSS + shadcn/ui
- **Build**: Vite or Webpack

### Infrastructure
- **Network Tables**: Global MySQL database
- **DSF Views**: Auto-syncing views in tenant databases
- **Redis**: Separate DBs for cache (4) and queue (0)
- **WebSocket**: WSS for production, WS for dev

---

## 📊 Sample Data

The `sample-data.sql` includes:

**Network**: Chicago West Side CVI Network (ID: 1)

**Organizations** (6):
- 101: Lead Organization (full PII sharing)
- 102: Violence Prevention Coalition (full PII)
- 103: Community Outreach Partners (partial PII)
- 104: Youth Services Network (no PII sharing)
- 105: Street Outreach Team (full PII minus SSN)
- 106: Case Management Services (partial PII)

**Participants** (10):
- 3 confirmed matches (Marcus, Jasmine, Deandre)
- 2 potential matches needing review (Tyrell/Tyrel)
- 1 pending verification (Karim)
- 4 unique participants (no duplicates)

**Incidents** (5):
- 2 critical shootings
- 1 high-priority assault
- 1 resolved conflict
- 1 low-priority social media threat

**Referrals** (5):
- 2 accepted & in progress
- 1 pending response
- 1 completed
- 1 declined

**PII Settings**: Varied configurations demonstrate different sharing scenarios

---

## 🔒 Security & Privacy

### PII Protection Layers

1. **Hash-Based Matching**
   - HMAC-SHA256 with application salt
   - Normalized inputs before hashing
   - One-way function (cannot reverse)

2. **Encryption at Rest**
   - Laravel encryption for stored PII
   - Separate from hashes (used for display only)

3. **API-Level Filtering**
   - Resolver middleware checks permissions
   - Masks fields based on `network_pii_settings`
   - Never exposes unauthorized data

4. **Audit Trail**
   - Logs every PII access
   - Includes: user, org, action, fields, IP, timestamp
   - Required for compliance (HIPAA, GDPR)

### Compliance Features

- ✅ **HIPAA**: De-identification via hashing + encryption
- ✅ **GDPR**: Audit log, consent tracking, data minimization
- ✅ **State Privacy Laws**: Granular per-org controls

---

## 📈 Performance

### Targets

| Metric | Target | Strategy |
|--------|--------|----------|
| API Response (P95) | < 500ms | Multi-tier caching |
| DSF View Query | < 200ms per org | Parallel queries + indexes |
| Cache Hit Rate | > 80% | 5-min TTL, selective invalidation |
| Matching Job | < 5s (100 participants) | Background jobs (Bull) |
| WebSocket Latency | < 100ms | Redis pub/sub |

### Scalability

**Current**: Single network, 6-15 orgs, 100-500 participants
**Future**: Multiple networks, 50+ orgs, 10,000+ participants

**Strategies**:
- Horizontal API scaling (stateless servers)
- Redis-backed pub/sub for cross-instance events
- Read replicas for DSF view queries
- Pagination + virtual scrolling (client-side)

---

## 🎨 Demo Features

The interactive demo (`demo/index.html`) showcases:

### Scenarios

1. **High Confidence Match** (95+)
   - SSN + DOB + Name all match
   - Auto-suggests for confirmation

2. **Potential Match** (70-89)
   - Name spelling variation (Tyrell vs Tyrel)
   - DOB off by 1 day
   - SSN unavailable

3. **No Match** (<70)
   - Different DOB, different SSN
   - Name partial match only

4. **Three-Way Match**
   - Same person across 3 orgs
   - Nickname variations handled

5. **Nickname Variation**
   - Michael → Mike
   - DOB + Address confirm identity

6. **Data Entry Error**
   - DOB off by 1 day (typo)
   - SSN + Name + Address match

### Features

- ✅ **Score Visualization**: Circular gauge with breakdown
- ✅ **PII Toggle**: Show/hide sensitive data
- ✅ **Comparison Table**: Side-by-side field comparison
- ✅ **Match Indicators**: Visual cues (✓ ≈ ✗)
- ✅ **Action Buttons**: Confirm, Review, Reject
- ✅ **Responsive Design**: Mobile-friendly

---

## 🤔 Design Decisions

### Why Not Materialize DSF Views?

**Decision**: Query DSF views directly instead of copying data

**Rationale**:
- ✅ DSF views auto-sync (no maintenance)
- ✅ Source of truth remains in tenant DB
- ✅ No data duplication
- ✅ Cache layer handles performance

**Tradeoff**:
- ❌ Requires querying multiple databases
- ✅ Solved by parallel queries + caching

### Why Human Confirmation Required?

**Decision**: Never auto-merge records, even with high scores

**Rationale**:
- Incorrectly merging two different people is worse than missing a match
- Legal/compliance implications of wrong data sharing
- False positives are hard to undo
- Users need to see WHY algorithm suggests a match

### Why Redis Pub/Sub Instead of Database Triggers?

**Decision**: Use Redis for event broadcasting, not DB triggers

**Rationale**:
- ✅ Decoupled from database
- ✅ Horizontal scaling support
- ✅ Language-agnostic
- ✅ Can replay events

### Why 5-Minute Cache TTL?

**Decision**: Relatively short TTL for aggregated data

**Rationale**:
- Balance between performance and freshness
- PII changes need to reflect quickly
- Incidents need near-real-time updates
- Explicit invalidation handles most cases

---

## 📚 Documentation

### Completed
- ✅ **Architecture**: System design, data flow, components
- ✅ **Matching Algorithm**: Scoring, hashing, edge cases
- ✅ **API Examples**: Queries, mutations, subscriptions
- ✅ **Sample Data**: Realistic test scenarios
- ✅ **Interactive Demo**: Visual proof of concept

### To Create
- 🔲 **Deployment Guide**: Infrastructure setup
- 🔲 **User Guide**: How to use the system
- 🔲 **Developer Guide**: Extending the system
- 🔲 **Security Audit**: Penetration testing results
- 🔲 **Performance Benchmarks**: Load testing results

---

## 🎯 Next Steps

### Immediate (This Week)
1. ✅ Review architecture with team
2. ✅ Demo matching UI to stakeholders
3. ✅ Confirm API design with frontend team
4. 🔲 Answer remaining product questions (see below)

### Short-Term (Next Sprint)
1. 🔲 Create database migrations
2. 🔲 Implement matching service (backend)
3. 🔲 Build GraphQL resolvers
4. 🔲 Set up WebSocket subscriptions
5. 🔲 Create React components (ParticipantList, MatchReview)

### Medium-Term (Next Month)
1. 🔲 Complete frontend implementation
2. 🔲 Integration testing
3. 🔲 Performance optimization
4. 🔲 Security audit
5. 🔲 Beta deployment

---

## ❓ Remaining Product Questions

These questions need stakeholder input before finalizing implementation:

### 1. Incident Notification Behavior

**Question**: When an org creates a critical incident, should all network members be notified immediately?

**Options**:
- A) Real-time notification via subscription + email (for Critical/High)
- B) Passive - shows in incident list, no push notification
- C) Configurable per network

**Recommendation**: Option A for Critical/High, Option B for Medium/Low

### 2. Match Conflict Resolution

**Question**: If Org A and Org B confirm a match, but Org C says "not the same person", what happens?

**Recommendation**: Create TWO network participants (A+B confirmed, C separate). Allow unlinking later if discovered to be error.

### 3. Referral Acceptance Behavior

**Question**: When an org accepts a referral, should it auto-create a record in their local database?

**Options**:
- A) Auto-create tier1 record (full case management immediately)
- B) Track referral only, with "Convert to Full Record" action later
- C) Ask user on acceptance

**Recommendation**: Option B (lightweight), with easy conversion to full record

### 4. Incident Import Workflow

**Question**: What triggers "Import Incident to My Org" action?

**Answer Needed**:
- Should imported incidents auto-link to network incident?
- Should updates in local record sync back to network?
- Should local record creation be optional or required?

### 5. Scale Expectations

**Question**: What are the expected network sizes?

**Needed for optimization**:
- Typical number of orgs per network?
- Expected participants per network?
- Concurrent users?
- Target response time?

**Current Assumptions** (based on v0 example):
- 6-15 member orgs per network
- 100-500 participants per network
- 20-50 concurrent users
- < 500ms API response time (P95)

---

## 🤝 Contributing

### Code Organization

Follow existing patterns:
- **Models**: Sequelize ORM entities
- **Services**: Business logic, no database calls directly
- **Repository**: Database queries, no business logic
- **Resolvers**: Thin layer, delegate to services
- **Tests**: Co-located with code (`*.test.ts`)

### Pull Request Process

1. Create feature branch from `main`
2. Write tests (unit + integration)
3. Update documentation
4. Run linter and type checks
5. Submit PR with description
6. Address review comments
7. Merge after approval

---

## 📞 Support

### Questions?

- **Architecture**: Review `docs/ARCHITECTURE.md`
- **API**: Check `api-examples/` folder
- **Matching**: Read `matching-algorithm.md`
- **Demo**: Open `demo/index.html`

### Feedback

Found an issue or have a suggestion? Create a GitHub issue with:
- Clear description
- Steps to reproduce (if bug)
- Expected vs actual behavior
- Screenshots if applicable

---

## 📄 License

Internal Apricot Software - Proprietary

---

**Version**: 1.0.0 (Architecture Complete)
**Last Updated**: March 24, 2025
**Status**: 🏗️ Ready for Implementation
# network-folder-demo
