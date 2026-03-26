# Network Document Folder - Architecture Documentation

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Data Flow](#data-flow)
- [Component Architecture](#component-architecture)
- [Database Design](#database-design)
- [API Layer](#api-layer)
- [Caching Strategy](#caching-strategy)
- [Real-Time Updates](#real-time-updates)
- [Security Architecture](#security-architecture)
- [Scalability](#scalability)

---

## Overview

The **Network Document Folder** is a microservice that enables multiple tenant organizations in a CVI (Community Violence Intervention) network to share and collaborate on participant records and incident data across organizational boundaries.

###Key Design Decisions

1. **Leverage Existing DSF Views**: Don't duplicate data - query DSF views directly
2. **Cache Aggregated Results**: Use Redis with 5-minute TTL
3. **Privacy-First Matching**: Use hashes for matching, encryption for display
4. **Human Confirmation Required**: Algorithm suggests, humans decide
5. **Real-Time Collaboration**: WebSocket subscriptions for live updates

### Problem Solved

- **Before**: Organizations work in silos, duplicate effort, miss connections
- **After**: Coordinated network response with privacy controls and real-time updates

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Network Document Folder UI                         │
│                           (React + Apollo)                               │
└────────────────────┬────────────────────────────────────────────────────┘
                     │ GraphQL (HTTP/WebSocket)
                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Apricot API                                     │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  GraphQL Layer (Apollo Server 3)                                  │  │
│  │  - Query Resolvers                                                │  │
│  │  - Mutation Resolvers                                             │  │
│  │  - Subscription Resolvers (WebSocket)                             │  │
│  └──────────┬──────────────────────────────────────────┬─────────────┘  │
│             │                                           │                │
│             ▼                                           ▼                │
│  ┌──────────────────────────┐          ┌─────────────────────────────┐ │
│  │ Application Services     │          │  Cache Layer                │ │
│  │ - networkFolderService   │◄─────────┤  - Redis (cache)            │ │
│  │ - matchingService        │          │  - LRU (process memory)     │ │
│  │ - cacheService           │          └─────────────────────────────┘ │
│  └──────────┬───────────────┘                                           │
│             │                                                            │
│             ▼                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Repository Layer                                                 │  │
│  │ - NetworkParticipantService                                      │  │
│  │ - NetworkIncidentService                                         │  │
│  │ - Raw SQL queries                                                │  │
│  └──────────┬───────────────────────────────────────────────────────┘  │
└─────────────┼──────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Database Layer                                    │
│  ┌───────────────────┐  ┌──────────────────┐  ┌──────────────────────┐ │
│  │  Network DB       │  │  Tenant 1 DB     │  │  Tenant N DB         │ │
│  │  (Global)         │  │  (Org-specific)  │  │  (Org-specific)      │ │
│  │                   │  │                  │  │                      │ │
│  │ - network_        │  │ - DSF views      │  │ - DSF views          │ │
│  │   participants    │  │   (auto-sync)    │  │   (auto-sync)        │ │
│  │ - network_        │  │ - data_N tables  │  │ - data_N tables      │ │
│  │   incidents       │  │ - documents      │  │ - documents          │ │
│  │ - network_        │  │                  │  │                      │ │
│  │   referrals       │  │                  │  │                      │ │
│  │ - network_notes   │  │                  │  │                      │ │
│  │ - network_        │  │                  │  │                      │ │
│  │   audit_log       │  │                  │  │                      │ │
│  └───────────────────┘  └──────────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                      Supporting Services                                 │
│  ┌───────────────────┐  ┌──────────────────┐  ┌──────────────────────┐ │
│  │  Redis Pub/Sub    │  │  Bull Queue      │  │  Background Jobs     │ │
│  │  - Event          │  │  - Matching      │  │  - Match calculation │ │
│  │    broadcasting   │  │    jobs          │  │  - Cache warming     │ │
│  │  - Cache          │  │  - Sync jobs     │  │  - Data aggregation  │ │
│  └───────────────────┘  └──────────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Participant Data Flow

```
1. User requests participant list:
   GET /api/graph?query=networkParticipants(network_id: "1")

2. GraphQL Resolver:
   ├─ Check context cache (request-scoped)
   │  └─ Cache hit: return immediately
   │
   └─ Check Redis cache:
      ├─ Cache hit: return cached data
      │
      └─ Cache miss:
         ├─ Query network_participants table (get IDs)
         ├─ Query network_participant_sources (get org mappings)
         ├─ Query DSF views from each org IN PARALLEL:
         │  ├─ SELECT * FROM org101.dsf_101_view WHERE document_id IN (...)
         │  ├─ SELECT * FROM org102.dsf_102_view WHERE document_id IN (...)
         │  └─ SELECT * FROM org105.dsf_105_view WHERE document_id IN (...)
         │
         ├─ Merge results (JOIN network participant IDs with DSF data)
         ├─ Apply PII filtering based on requesting org permissions
         ├─ Cache aggregated result in Redis (TTL: 300s)
         └─ Return to client
```

### Incident Creation Flow

```
1. User creates incident:
   POST /api/graph mutation createNetworkIncident(...)

2. Mutation Resolver:
   ├─ Validate input
   ├─ Insert into network_incidents table
   ├─ Create initial org_responses for all network members
   ├─ Link participants (if provided)
   ├─ Invalidate cache: network:{id}:incidents
   ├─ Publish event: INCIDENT_CREATED_{network_id}
   │  └─ All subscribed clients receive update
   │
   └─ Return created incident
```

### Real-Time Update Flow

```
1. Tier 1 record updated in Tenant DB:
   UPDATE org101.data_10 SET field_123 = 'new value' WHERE id = 5001

2. DSF view auto-reflects change (it's a dynamic SQL view)

3. Application triggers cache invalidation:
   ├─ Detect change via document update hook
   ├─ Find which networks include this org+form
   ├─ For each network:
   │  ├─ Invalidate Redis cache
   │  └─ Publish PARTICIPANT_UPDATED_{network_id} event
   │
   └─ WebSocket clients receive subscription update

4. React app receives update:
   ├─ useSubscription hook fires
   ├─ React Query cache invalidated
   ├─ Component re-fetches fresh data
   └─ UI updates automatically
```

---

## Component Architecture

### Frontend (React)

```
src/
├── app/
│   └── NetworkDocumentFolder/
│       ├── index.tsx              # Main entry point
│       ├── router.tsx             # Routing configuration
│       └── context/
│           ├── NetworkContext.tsx # Current network state
│           └── PIIContext.tsx     # PII permissions
│
├── views/
│   ├── PeopleView/
│   │   ├── ParticipantList.tsx
│   │   ├── ParticipantDetail.tsx
│   │   ├── MatchReview.tsx
│   │   └── PIIToggle.tsx
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
│       ├── NetworkOverview.tsx
│       ├── RecentActivity.tsx
│       └── PendingActions.tsx
│
├── components/
│   ├── NetworkHeader/
│   ├── OrgMemberList/
│   ├── PrivacyIndicator/
│   ├── MatchComparisonTable/
│   └── IncidentTimeline/
│
├── hooks/
│   ├── useNetworkParticipants.ts
│   ├── useParticipantSubscription.ts
│   ├── useIncidents.ts
│   ├── usePIIPermissions.ts
│   └── useOptimisticUpdate.ts
│
├── graphql/
│   ├── client.ts              # Apollo Client setup
│   ├── queries/
│   ├── mutations/
│   └── subscriptions/
│
└── services/
    ├── piiFilter.ts           # Client-side PII masking
    ├── matchingScore.ts       # Score calculation
    └── notification.ts        # Toast/alert service
```

### Backend (Apricot API)

```
src/
├── graphql-api/
│   ├── index.ts                        # Apollo Server setup + WebSocket
│   │
│   ├── typeDefs/
│   │   ├── networkDocumentFolder.ts    # Root types
│   │   ├── networkParticipant.ts
│   │   ├── networkIncident.ts
│   │   └── networkReferral.ts
│   │
│   └── resolvers/
│       └── networkDocumentFolder/
│           ├── queries.ts              # Query resolvers
│           ├── mutations.ts            # Mutation resolvers
│           └── subscriptions.ts        # Subscription resolvers
│
├── application/services/
│   ├── networkDocumentFolderService.ts # Main business logic
│   ├── participantMatchingService.ts   # Matching algorithm
│   ├── networkCacheService.ts          # Cache management
│   └── networkEventService.ts          # Pub/sub events
│
├── repository/
│   ├── services/
│   │   ├── NetworkParticipantService.ts
│   │   ├── NetworkIncidentService.ts
│   │   └── NetworkReferralService.ts
│   │
│   ├── query/
│   │   └── networkDocumentFolder.ts    # Raw SQL queries
│   │
│   └── models/
│       ├── global/
│       │   ├── network_participants.ts
│       │   ├── network_incidents.ts
│       │   └── network_referrals.ts
│       │
│       └── org/
│           └── data_standards_map.ts   # DSF mappings
│
└── domain/entities/
    ├── networkParticipant.ts
    └── networkIncident.ts
```

---

## Database Design

### Network-Level Tables (Global DB)

**Core principle**: Store ONLY network-specific data. Source data stays in tenant DBs.

#### network_participants
- **Purpose**: Deduplicated people across orgs
- **Key Fields**: `id`, `network_id`, `match_status`, `match_confidence_score`
- **Relationships**: Many sources (from different orgs)

#### network_participant_sources
- **Purpose**: Links individual org records to network participants
- **Key Fields**: `network_participant_id`, `org_id`, `document_id`, `dsf_id`
- **PII Storage**:
  - Hashes: `name_hash`, `ssn_last4_hash`, `dob_hash` (for matching)
  - Encrypted: `name_encrypted`, `ssn_last4_encrypted` (for display)

#### network_incidents
- **Purpose**: Incidents affecting the network
- **Key Fields**: `id`, `incident_type`, `severity`, `status`, `occurred_at`
- **Not Duplicated**: Stored ONLY in network DB (not tenant DBs unless imported)

#### network_incident_org_responses
- **Purpose**: Each org tracks their response to incidents
- **Key Fields**: `incident_id`, `org_id`, `status`, `planned_actions`, `current_actions`, `completed_actions`

### Tenant-Level Data (Org DBs)

#### DSF Views (Auto-Generated)
- **Format**: `dsf_{data_standard_form_id}_view`
- **Type**: Dynamic SQL view (not materialized)
- **Auto-Sync**: Always reflects current tier1 data
- **Columns**: `org_id`, `document_id`, `field_123`, `field_456`, etc.

**Example**:
```sql
CREATE OR REPLACE VIEW org101.dsf_101_view AS
SELECT
    101 AS org_id,
    d.id AS document_id,
    d.parent_id,
    df123.value AS field_123_firstName,
    df124.value AS field_124_lastName,
    df125.value AS field_125_dob
FROM documents d
LEFT JOIN data_10 df123 ON df123.document_id = d.id AND df123.field_id = 123
LEFT JOIN data_10 df124 ON df124.document_id = d.id AND df124.field_id = 124
LEFT JOIN data_10 df125 ON df125.document_id = d.id AND df125.field_id = 125
WHERE d.active = 1;
```

---

## API Layer

### GraphQL Schema Structure

```graphql
type NetworkParticipant {
  id: ID!
  network_id: ID!
  match_status: MatchStatus!
  sources: [ParticipantSource!]!
}

type ParticipantSource {
  org_id: ID!
  org_name: String!
  document_id: ID!
  name_used: String  # PII - filtered
  dob: String        # PII - filtered
  ssn_last4: String  # PII - filtered
}

type Query {
  networkParticipants(network_id: ID!): NetworkParticipantsResult!
  networkIncidents(network_id: ID!): NetworkIncidentsResult!
}

type Mutation {
  confirmParticipantMatch(...): NetworkParticipant!
  createNetworkIncident(...): NetworkIncident!
}

type Subscription {
  participantUpdated(network_id: ID!): ParticipantUpdatePayload!
  incidentUpdated(network_id: ID!): IncidentUpdatePayload!
}
```

### PII Filtering (Middleware)

Every resolver automatically filters PII based on requesting org's permissions:

```typescript
// Resolver context includes requesting org
context = {
  user: { id, org_id },
  piiPermissions: { /* loaded from cache */ }
}

// PII filtering applied in resolver
function resolveParticipantSource(source, args, context) {
  const { org_id } = context.user;
  const permissions = context.piiPermissions;

  // Check if requesting org can see this field
  if (!permissions.canViewPIIFrom(source.org_id)) {
    return {
      ...source,
      name_used: '● ● ● ● (PII masked)',
      dob: null,
      ssn_last4: null
    };
  }

  return source;
}
```

---

## Caching Strategy

### Three-Tier Cache

1. **Request-Scoped Cache** (GraphQL Context)
   - Lifetime: Single request
   - Use: Prevent duplicate queries in same request
   - Example: DataLoader pattern

2. **Redis Cache** (Shared)
   - Lifetime: 5 minutes (300 seconds)
   - Use: Aggregated participant/incident data
   - Keys: `network:{id}:participants:{status}`

3. **LRU Cache** (Process Memory)
   - Lifetime: 1 hour
   - Use: PII configurations, field types
   - Size: 100-500 entries

### Cache Keys Pattern

```
network:{network_id}:participants:{status}:{matchStatus}
network:{network_id}:participant:{participant_id}
network:{network_id}:incidents:{severity}
network:{network_id}:org:{org_id}:pii_config
```

### Cache Invalidation

**Triggers**:
- DSF view data changes (tier1 record updated)
- Match confirmed/rejected
- Incident created/updated
- PII settings changed

**Strategy**:
```typescript
async function invalidateNetworkCache(networkId: number, type: string) {
  const keys = await redis.keys(`network:${networkId}:${type}:*`);
  await redis.del(...keys);

  // Publish invalidation event
  await pubsub.publish(`CACHE_INVALIDATED_${networkId}`, { type });
}
```

---

## Real-Time Updates

### WebSocket Subscriptions

**Apollo Server Configuration**:
```typescript
import { WebSocketServer } from 'ws';
import { useServer } from 'graphql-ws/lib/use/ws';
import { RedisPubSub } from 'graphql-redis-subscriptions';

const pubsub = new RedisPubSub({
  publisher: redisClient.client,
  subscriber: redisClient.client.duplicate()
});

const wsServer = new WebSocketServer({
  server: httpServer,
  path: '/api/graph'
});

useServer({ schema, context }, wsServer);
```

### Event Channels (Redis Pub/Sub)

```
PARTICIPANT_UPDATED_{network_id}
INCIDENT_UPDATED_{network_id}
MATCH_DETECTED_{network_id}
REFERRAL_{network_id}_{org_id}
```

### Client-Side Subscription

```typescript
const { data } = useSubscription(ON_PARTICIPANT_UPDATED, {
  variables: { networkId: "1" }
});

useEffect(() => {
  if (data?.participantUpdated) {
    queryClient.invalidateQueries(['participants', networkId]);
    toast.info(`Participant updated by ${data.changed_by_org_name}`);
  }
}, [data]);
```

---

## Security Architecture

### Authentication & Authorization

1. **Network Membership Check**: Verify user's org is in network
2. **PII Permission Check**: Enforce field-level visibility
3. **Audit Logging**: Track all PII access

### PII Protection Layers

1. **Hash-Based Matching**: Never expose raw PII during matching
2. **Encryption at Rest**: Laravel encryption for stored PII
3. **API-Level Filtering**: Resolver middleware masks unauthorized fields
4. **Audit Trail**: Every PII access logged with IP, user agent

### Audit Log Entry

```typescript
await logAuditEvent({
  user_id: context.user.id,
  org_id: context.user.org_id,
  network_id: networkId,
  action: 'view_pii',
  resource_type: 'participant',
  resource_id: participantId,
  pii_fields_accessed: ['name', 'dob', 'ssn_last4'],
  ip_address: context.request.ip,
  user_agent: context.request.headers['user-agent']
});
```

---

## Scalability

### Bottlenecks & Solutions

| Bottleneck | Solution |
|------------|----------|
| **Querying multiple DSF views** | Parallel queries + DataLoader |
| **Cache invalidation overhead** | Granular keys, selective invalidation |
| **WebSocket connections** | Redis-backed pub/sub for horizontal scaling |
| **Matching algorithm CPU** | Background jobs (Bull queue) |
| **Large result sets** | Pagination + virtual scrolling (client) |

### Performance Targets

- **API Response**: < 500ms (P95)
- **Cache Hit Rate**: > 80%
- **DSF View Query**: < 200ms per org
- **Matching Job**: < 5 seconds for 100 participants
- **WebSocket Latency**: < 100ms for event delivery

### Horizontal Scaling

**Supported**:
- Multiple API server instances (stateless)
- Redis pub/sub for cross-instance events
- Bull queue for distributed job processing

**Limitations**:
- WebSocket connections tied to specific server
- Requires load balancer with sticky sessions OR Redis adapter

---

## Deployment Considerations

### Environment Variables

```bash
# Network matching
NETWORK_MATCH_SALT=<secret-for-hashing>

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB_CACHE=4
REDIS_DB_QUEUE=0

# WebSocket
WS_ENABLED=true
WS_PATH=/api/graph
```

### Database Migrations

1. Run `database-schema.sql` to create network tables
2. Update `data_standards` table with `standard_type` column
3. Configure PII settings for each org in network

### Monitoring

**Key Metrics**:
- Cache hit rate
- API response times (P50, P95, P99)
- WebSocket connection count
- Background job queue length
- DSF view query duration

**Alerts**:
- Cache hit rate < 70%
- API P95 > 1 second
- Job queue > 100 pending
- WebSocket disconnections > 10% of users

---

## Future Enhancements

1. **ML-Based Matching**: Train model on confirmed matches
2. **Read Replicas**: For DSF view queries at scale
3. **Event Sourcing**: Full audit trail with replay capability
4. **Advanced Analytics**: Network-wide trends and insights
5. **Mobile App**: Native iOS/Android with push notifications
