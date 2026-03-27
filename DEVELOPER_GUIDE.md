# Network Document Folder - Developer Quick Start Guide

## Overview

Network Document Folder enables cross-organizational collaboration on participant and incident data within CVI networks. This guide helps developers quickly understand the architecture and start contributing.

---

## Architecture at a Glance

### Unified Schema Pattern

```
network_shared_records (ALL types)
  ├─ record_type: 'participant' | 'incident'
  ├─ metadata: JSON (type-specific data)
  └─ sources → network_record_sources
      ├─ source_type: 'apricot' | 'snowflake'
      └─ dsf_view_data: JSON (PII filtered by field IDs)
```

**Key Insight**: One table for all shared record types. Add new types (veteran, family) without schema changes.

---

## Quick Setup

### 1. Database Setup

```bash
# Navigate to project
cd /Users/patrick.kennedy/Desktop/Apricot_Files/whiteboarding/network-document-folder

# Run migration
mysql -u root -p apricot_dev < database-schema-unified.sql

# Load test data
mysql -u root -p apricot_dev < sample-data-unified.sql

# Verify tables created
mysql -u root -p apricot_dev -e "SHOW TABLES LIKE 'network_%'"
```

**Expected Output**: 7 tables
- `network_shared_records`
- `network_record_sources`
- `network_record_responses`
- `network_notes`
- `network_audit_log`
- `network_member_orgs`
- `network_participant_potential_matches`

### 2. Backend Setup (Apricot API)

```bash
# Navigate to API
cd /Users/patrick.kennedy/Desktop/Apricot_Files/apricot-api

# Install WebSocket dependencies (if not already installed)
npm install graphql-ws@^5.14.0 ws@^8.14.0 graphql-redis-subscriptions@^2.6.0

# Create model files
mkdir -p src/repository/models/global
touch src/repository/models/global/network_shared_records.ts
touch src/repository/models/global/network_record_sources.ts
# ... etc

# Create service files
mkdir -p src/application/services
touch src/application/services/networkDocumentFolderService.ts
touch src/application/services/participantMatchingService.ts
touch src/application/services/networkPIIService.ts
```

### 3. Frontend Setup (React App)

```bash
# Create React app directory
cd /Users/patrick.kennedy/Desktop/Apricot_Files
mkdir network-document-folder-react
cd network-document-folder-react

# Initialize project
npm init -y
npm install react@^18.3.1 react-dom@^18.3.1 react-router-dom@^7.1.1
npm install react-relay@^18.2.0 relay-runtime@^18.2.0
npm install jotai@^2.10.3
npm install @mui/material@^6.1.6 @mui/icons-material@^6.1.6

# Dev dependencies
npm install -D vite@^5.4.14 @vitejs/plugin-react@^4.3.4
npm install -D typescript@^5.5.3 relay-compiler@^18.2.0
npm install -D vite-plugin-relay@^2.1.0
```

---

## Core Concepts

### 1. Unified Record Model

**Participant Record**:
```json
{
  "id": 1,
  "network_id": 1,
  "record_type": "participant",
  "status": "confirmed",
  "match_confidence_score": 95.5,
  "metadata": {
    "matching_algorithm_version": "1.0",
    "confirmed_at": "2025-02-01T10:30:00Z"
  }
}
```

**Incident Record**:
```json
{
  "id": 10,
  "network_id": 1,
  "record_type": "incident",
  "status": "confirmed",
  "metadata": {
    "severity": "critical",
    "incident_type": "shooting",
    "location": "Portland, OR",
    "occurred_at": "2025-02-20T22:30:00Z"
  }
}
```

### 2. PII Filtering by Field IDs

**Org's PII Settings**:
```json
{
  "org_id": 102,
  "pii_sharing_enabled": true,
  "pii_fields_shared": [4721, 4722, 4723]  // name, dob, ssn field IDs
}
```

**Filtering Logic**:
```typescript
function filterPIIFields(
  dsfViewData: Record<string, any>,
  allowedFieldIds: number[]
): Record<string, any> {
  const filtered: Record<string, any> = {};

  for (const [key, value] of Object.entries(dsfViewData)) {
    const fieldId = parseInt(key.replace('field_', ''));

    if (allowedFieldIds.includes(fieldId)) {
      filtered[key] = value;  // Include
    } else {
      filtered[key] = '● ● ●';  // Mask
    }
  }

  return filtered;
}
```

### 3. Dual Source Queries (Apricot vs Snowflake)

```typescript
async function getDSFViewData(source: NetworkRecordSource): Promise<any> {
  if (source.source_type === 'apricot') {
    // Query Apricot tenant database
    const knex = await getApricotTenantConnection(source.org_id);
    return knex(`dsf_${source.dsf_id}_view`)
      .where('document_id', source.tenant_document_id)
      .first();

  } else if (source.source_type === 'snowflake') {
    // Query Snowflake
    const snowflake = await getSnowflakeConnection(source.source_connection_id);
    return snowflake.execute({
      sqlText: `SELECT * FROM ${source.snowflake_schema}.dsf_${source.dsf_id}_view WHERE document_id = ?`,
      binds: [source.tenant_document_id]
    });
  }
}
```

---

## Common Queries

### Get All Participants

```graphql
query GetParticipants($networkId: ID!) {
  networkSharedRecords(
    network_id: $networkId
    record_type: "participant"
    status: "confirmed"
  ) {
    records {
      id
      metadata
      sources {
        org_name
        dsf_view_data  # PII filtered automatically
      }
    }
  }
}
```

### Get Incidents with Responses

```graphql
query GetIncidents($networkId: ID!) {
  networkSharedRecords(
    network_id: $networkId
    record_type: "incident"
    status: "confirmed"
  ) {
    records {
      id
      metadata  # severity, incident_type, location, etc.
      responses {
        org_name
        response_type
        response_data  # status, actions, etc.
      }
    }
  }
}
```

### Get Potential Matches

```graphql
query GetMatches($networkId: ID!) {
  networkPotentialMatches(network_id: $networkId, status: "pending_review") {
    id
    match_score
    match_factors  # {"ssn": 45, "dob": 35, "name": 20}
    shared_record_a {
      sources { org_name, dsf_view_data }
    }
    shared_record_b {
      sources { org_name, dsf_view_data }
    }
  }
}
```

---

## Common Mutations

### Share Record to Network

```graphql
mutation ShareParticipant($input: ShareRecordInput!) {
  shareRecordToNetwork(
    network_id: "1"
    record_type: "participant"
    tenant_document_id: "5001"
    dsf_id: "201"
    metadata: {
      matching_algorithm_version: "1.0"
    }
  ) {
    id
    status
    sources {
      org_name
    }
  }
}
```

### Confirm Participant Match

```graphql
mutation ConfirmMatch($input: ConfirmMatchInput!) {
  confirmMatch(
    network_id: "1"
    shared_record_id: "1"
    source_ids: ["1", "2", "3"]
  ) {
    id
    status  # Now 'confirmed'
    match_confidence_score
  }
}
```

### Respond to Incident

```graphql
mutation RespondToIncident($input: RespondInput!) {
  respondToIncident(
    network_id: "1"
    shared_record_id: "10"
    response_data: {
      status: "in_progress"
      planned_actions: ["Contact families", "Deploy street team"]
      current_actions: ["Street team deployed"]
    }
  ) {
    id
    org_name
    response_data
  }
}
```

---

## Real-Time Subscriptions

### Subscribe to Record Updates

```graphql
subscription OnRecordUpdate($networkId: ID!) {
  recordUpdated(network_id: $networkId, record_type: "participant") {
    record {
      id
      metadata
    }
    change_type  # CREATED, UPDATED, DELETED, MATCH_CONFIRMED
    changed_by_org_id
  }
}
```

**React Hook Example**:
```typescript
import { useSubscription } from '@apollo/client';

function useRecordSubscription(networkId: string) {
  const { data } = useSubscription(RECORD_UPDATED_SUBSCRIPTION, {
    variables: { networkId }
  });

  useEffect(() => {
    if (data?.recordUpdated) {
      // Invalidate cache, show toast, etc.
      queryClient.invalidateQueries(['network', networkId, 'records']);
      toast.info(`Record updated by ${data.recordUpdated.changed_by_org_id}`);
    }
  }, [data]);
}
```

---

## Testing

### Unit Tests

```typescript
// Test participant matching
describe('ParticipantMatchingService', () => {
  it('should calculate match score correctly', () => {
    const participantA = {
      ssn_last4_hash: hash('4521'),
      dob_hash: hash('1998-03-15'),
      name_hash: hash('marcusthompson')
    };

    const participantB = {
      ssn_last4_hash: hash('4521'),
      dob_hash: hash('1998-03-15'),
      name_hash: hash('marcusathompson')
    };

    const score = calculateMatchScore(participantA, participantB);
    expect(score).toBeGreaterThan(90);  // High confidence match
  });
});
```

### Integration Tests

```typescript
// Test full workflow
describe('Share participant to network', () => {
  it('should create shared record and trigger matching', async () => {
    // 1. Share participant
    const result = await shareRecordToNetwork({
      network_id: 1,
      record_type: 'participant',
      tenant_document_id: 5001,
      dsf_id: 201
    });

    expect(result.id).toBeDefined();
    expect(result.status).toBe('pending');

    // 2. Wait for matching job to complete
    await waitFor(() => {
      const matches = getPotentialMatches(1);
      expect(matches.length).toBeGreaterThan(0);
    });

    // 3. Confirm match
    const confirmed = await confirmMatch({
      network_id: 1,
      shared_record_id: result.id,
      source_ids: [1, 2]
    });

    expect(confirmed.status).toBe('confirmed');
  });
});
```

---

## Debugging Tips

### Check PII Filtering

```sql
-- See which field IDs org is sharing
SELECT pii_fields_shared FROM network_member_orgs
WHERE network_id = 1 AND org_id = 102;

-- Result: [4721, 4722, 4723]
```

### Check Cache

```bash
# Redis CLI
redis-cli

# Check cache key
GET network:1:records:participant:confirmed

# See all network cache keys
KEYS network:1:*

# Invalidate cache
DEL network:1:records:participant:confirmed
```

### Check Audit Log

```sql
-- See who accessed PII
SELECT user_id, org_id, action, details, created_at
FROM network_audit_log
WHERE network_id = 1 AND action = 'view_pii'
ORDER BY created_at DESC
LIMIT 10;
```

### Check WebSocket Connections

```bash
# In server logs
grep "WebSocket" logs/apricot-api.log

# Count active connections
redis-cli
CLIENT LIST | grep websocket | wc -l
```

---

## Performance Optimization

### Caching Strategy

```typescript
// 3-tier caching
// 1. Request cache (in-memory, per-request)
context.cache.set('network:1:participant:123', data);

// 2. Redis cache (5-minute TTL)
await redis.set('network:1:records:participant', JSON.stringify(data), 'EX', 300);

// 3. LRU cache (process-level, for config)
const piiConfig = lruCache.get('network:1:org:102:pii');
```

### Database Indexes

```sql
-- Most important indexes (already in schema)
idx_network_type_status (network_id, record_type, status, active)
idx_shared_record (network_shared_record_id, active)
idx_org_document (org_id, tenant_document_id)
```

### Parallel Queries

```typescript
// Query all org DSF views in parallel
const sources = await NetworkRecordSource.findAll({
  where: { network_shared_record_id: recordId }
});

const dsfDataPromises = sources.map(source =>
  getDSFViewData(source)
);

const allDsfData = await Promise.all(dsfDataPromises);
```

---

## Common Pitfalls

### ❌ Don't: Query tenant DBs sequentially

```typescript
// BAD - slow!
for (const source of sources) {
  const data = await getDSFViewData(source);
}
```

### ✅ Do: Query in parallel

```typescript
// GOOD - fast!
const data = await Promise.all(
  sources.map(getDSFViewData)
);
```

---

### ❌ Don't: Filter PII client-side

```typescript
// BAD - security risk!
const data = await fetchAllData();
const filtered = data.filter(item => allowedFields.includes(item.field));
```

### ✅ Do: Filter PII server-side

```typescript
// GOOD - secure!
const data = await fetchAllData(orgId);  // Already filtered by server
```

---

### ❌ Don't: Store PII in metadata JSON

```typescript
// BAD - metadata is not encrypted!
metadata: {
  name: "Marcus Thompson",  // Don't do this!
  ssn: "4521"
}
```

### ✅ Do: Store PII in tenant DBs only

```typescript
// GOOD - query DSF views for PII
const dsfData = await queryDSFView(dsfId, documentId);
// Then filter by allowed field IDs
```

---

## Useful Resources

### Documentation
- `/database-schema-unified.sql` - Full schema with comments
- `/sample-data-unified.sql` - Test data examples
- `/api-examples/queries-unified.graphql` - Complete query reference
- `/IMPLEMENTATION_STATUS.md` - Current progress and next steps

### Code References
- Existing data standards service: `apricot-api/src/application/services/dataStandardsService.ts`
- DSF view generation: Line 6246 in dataStandardsService.ts
- Redis connection: `apricot-api/src/repository/connections/redis/index.ts`
- GraphQL setup: `apricot-api/src/graphql-api/index.ts`

### External Resources
- GraphQL Subscriptions: https://www.apollographql.com/docs/apollo-server/data/subscriptions/
- Relay: https://relay.dev/docs/
- Jotai: https://jotai.org/
- Sequelize: https://sequelize.org/docs/v6/

---

## Getting Help

1. **Architecture questions**: See `/docs/ARCHITECTURE.md`
2. **Schema questions**: See comments in `/database-schema-unified.sql`
3. **API questions**: See `/api-examples/queries-unified.graphql`
4. **Implementation questions**: Review main implementation plan document

---

## Next Steps for New Developers

1. ✅ Read this guide
2. ✅ Set up local environment (database, API)
3. ✅ Run sample data and test queries
4. ✅ Review existing data standards service code
5. ✅ Pick a task from Phase 1 or 2
6. ✅ Write tests first
7. ✅ Implement feature
8. ✅ Submit for code review

**Welcome to the team!** 🚀
