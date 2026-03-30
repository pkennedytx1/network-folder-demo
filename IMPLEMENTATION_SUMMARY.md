# Network Document Folder - Comprehensive Implementation Plan

## Executive Summary

**Project**: Network Document Folder - Cross-organizational collaboration tool for CVI networks

**Scope**: Full-stack feature enabling multiple organizations to share participant/incident data with privacy controls, real-time updates, and intelligent matching algorithms.

**Total Estimated Effort**: 16-20 weeks (320-400 hours)
- Backend: 8-10 weeks
- Frontend: 6-8 weeks
- Integration/Testing: 2-3 weeks

**Team Composition**:
- 1-2 Backend Engineers (Node.js/GraphQL/PostgreSQL)
- 1-2 Frontend Engineers (React/TypeScript/Relay)
- 1 DevOps Engineer (part-time, for WebSocket infrastructure)

**Critical Path Items**:
1. Data Standards validation engine (Phase 0) - BLOCKER for MVP
2. WebSocket infrastructure (Phase 4) - Required for real-time
3. Matching algorithm (Phase 2) - Core value proposition (participants only)
4. React app setup with Relay (Phase 5) - Frontend foundation

## Context

### Problem Statement
- Networks contain 1 lead org + multiple member orgs
- Each org has their own tenant data (participants, incidents) in separate databases (Apricot or Snowflake)
- Organizations need to collaborate on the same participants who may exist across multiple orgs
- Must handle PII privacy controls at field-level (some orgs share specific fields, others don't)
- Need to match/deduplicate participants across orgs without creating data integrity issues
- Must support real-time collaboration on incidents with per-org response tracking
- Architecture must support adding new record types (veteran, family, program) without schema migrations

### Key Challenges Identified
1. **Cross-Tenant Data Queries** - Performance implications of querying multiple tenant databases (Apricot) and Snowflake
2. **Participant Matching/Deduplication** - Identifying same person across orgs without false positives
3. **PII Security** - Field-level privacy controls (field IDs, not field names)
4. **Data Synchronization** - Keeping views fresh as source data changes
5. **Scalability** - 10K+ records per network × 200+ networks = ~2M shared records
6. **Future-Proof Schema** - Must support new data standard types without migrations

---

## Architectural Updates (March 27, 2025)

### UNIFIED DATABASE SCHEMA

**Key Requirement**: Must support adding new data standard types (veteran, family, etc.) without schema migrations.

**Scale Target**: 10K+ records per network × 200+ networks = ~2M shared records

**Decision**: Single unified table approach with JSONB for flexibility

### Why Unified Schema?

**Rejected Approach: Separate Tables Per Type**
- ❌ Adding "veteran" type requires new tables: `network_veterans`, `network_veteran_sources`, etc.
- ❌ Schema migrations for each new type
- ❌ Duplicated workflow code (sharing, matching, responding)
- ❌ Complex queries: "show all shared items" requires UNION across multiple tables
- ❌ Not future-proof

**Chosen Approach: Unified Table (5 core tables)**
- ✅ Add new type: just add ENUM value + define JSONB structure (no migration)
- ✅ Single workflow codebase for all types
- ✅ Simple queries: `SELECT * FROM network_shared_records WHERE network_id = X`
- ✅ Proven at scale: 2M records in single table is standard PostgreSQL/MySQL
- ✅ JSONB provides schema flexibility without losing relational benefits
- ✅ Indexes on `(network_id, record_type, status)` make queries fast

---

## Phase 1: Understanding Existing Infrastructure

### How Data Standard Views Work (From Codebase Analysis)

**File:** `Apricot_Files/apricot-api/src/application/services/dataStandardsService.ts`

#### View Creation Process:
When a data standard is mapped to member org forms:
1. Each mapping creates a row in `data_standard_forms` table (per org, per form)
2. Each DSF row triggers creation of a database VIEW in that org's tenant DB
3. View name format: `dsf_{data_standard_form_id}_view`
4. Views are **dynamic SQL views** (not materialized) - they query live data at runtime

#### View Structure (Standard Columns):
```sql
dsf_123_view:
  org_id                  -- Current organization ID
  parent_id               -- From documents table
  document_id             -- Primary key reference
  document_ids            -- Concatenated document IDs (for multiple T2s)
  binding_t1_id           -- Tier 1 document ID binding
  active                  -- Excludes drafts (active = 1)
  mod_time                -- Last modification time
  [field_4721]            -- Mapped data standard fields (by field ID)
  [field_4722]            -- Single column fields
  [field_4723]            -- etc.
```

#### Key Insight: Views Auto-Sync!
- Views are **NOT materialized** - they're dynamic SQL queries
- They query directly from `data_{formId}` tables and `documents` table
- **No explicit sync mechanism needed** - views always reflect current data
- When underlying tier1 data changes, view results automatically update on next query

### Architecture Decision: Leverage Existing DSF Views

**Selected Approach: Query DSF views directly + Cache aggregated results**

Since DSF views are:
1. Already created when data standards are mapped
2. Auto-sync with source data (no maintenance needed)
3. Contain all mapped fields in standardized format (by field ID)
4. One view per org per data standard form

**Our Strategy:**
- **Don't duplicate** the DSF view data into network tables
- **Query DSF views** from all orgs in the network via GraphQL
- **Cache the aggregated/matched results** in Redis (5-min TTL)
- **Store only network-specific data** in network DB:
  - Shared record entries (participant, incident, etc.)
  - Record sources (links to tenant tier1 records)
  - Responses (match confirmations, incident responses, notes)
  - Audit trail

**Data Flow:**
```
User requests shared records list
  ↓
Check Redis cache for network {id} records
  ↓ (cache miss)
Query DSF views from all member orgs:
  - SELECT * FROM dsf_101_view (org A - Apricot)
  - SELECT * FROM dsf_102_view (org B - Apricot)
  - SELECT * FROM snowflake_view (org C - Snowflake)
  ↓
Join with network_record_sources table
  ↓
Apply PII filtering based on field IDs in metadata
  ↓
Cache aggregated result in Redis (TTL: 300s)
  ↓
Return to client
```

---

## Phase 2: Unified Database Schema

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Network Document Folder                 │
│                        (React App)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Apricot API                             │
│                  (Network Folder Endpoints)                  │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  Network DB      │ │  Apricot Tenant  │ │  Snowflake       │
│  (Shared Data)   │ │  (Source Data)   │ │  (Source Data)   │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

### Core Tables (5 Total)

```sql
-- UNIFIED table for ALL shared records (participants, incidents, future types)
CREATE TABLE network_shared_records (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  network_id BIGINT UNSIGNED NOT NULL,
  data_standard_id BIGINT UNSIGNED NOT NULL,
  record_type ENUM('participant', 'incident', 'general') NOT NULL,  -- extensible
  status ENUM('pending', 'confirmed', 'rejected') NOT NULL DEFAULT 'pending',
  match_confidence_score DECIMAL(5,2) NULL,  -- for participant matching only
  metadata JSON NOT NULL,  -- type-specific flexible data
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_by_org_id BIGINT UNSIGNED NOT NULL,
  active BOOLEAN DEFAULT TRUE,

  INDEX idx_network_type (network_id, record_type, status),
  INDEX idx_created (created_at DESC),
  INDEX idx_confidence (match_confidence_score DESC),
  FOREIGN KEY (network_id) REFERENCES networks(id),
  FOREIGN KEY (data_standard_id) REFERENCES data_standards(id)
);

-- Links org tenant records to shared network record
-- HANDLES BOTH APRICOT AND SNOWFLAKE SOURCES
CREATE TABLE network_record_sources (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  network_shared_record_id BIGINT UNSIGNED NOT NULL,
  org_id BIGINT UNSIGNED NOT NULL,
  tenant_document_id BIGINT UNSIGNED NOT NULL,  -- tier1 record ID
  dsf_id BIGINT UNSIGNED NOT NULL,  -- which DSF view to query
  source_type ENUM('apricot', 'snowflake') NOT NULL,  -- data source type
  source_connection_id BIGINT UNSIGNED NULL,  -- connection config reference
  contributed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  confirmed_by_org_user_id BIGINT UNSIGNED NULL,
  metadata JSON NULL,  -- matching scores, confirmation details
  active BOOLEAN DEFAULT TRUE,

  INDEX idx_shared_record (network_shared_record_id),
  INDEX idx_org_document (org_id, tenant_document_id),
  INDEX idx_source_type (source_type),
  FOREIGN KEY (network_shared_record_id) REFERENCES network_shared_records(id) ON DELETE CASCADE
);

-- Org responses to ANY shared record type
CREATE TABLE network_record_responses (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  network_shared_record_id BIGINT UNSIGNED NOT NULL,
  org_id BIGINT UNSIGNED NOT NULL,
  response_type ENUM('match_confirmed', 'match_rejected', 'incident_responded', 'note_added', 'imported_to_tenant') NOT NULL,
  response_data JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_by_user_id BIGINT UNSIGNED NOT NULL,

  INDEX idx_shared_record (network_shared_record_id, response_type),
  INDEX idx_org (org_id, created_at DESC),
  FOREIGN KEY (network_shared_record_id) REFERENCES network_shared_records(id) ON DELETE CASCADE
);

-- Network notes (can attach to any record type)
CREATE TABLE network_notes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  network_id BIGINT UNSIGNED NOT NULL,
  network_shared_record_id BIGINT UNSIGNED NULL,  -- links to any shared record
  author_org_id BIGINT UNSIGNED NOT NULL,
  author_user_id BIGINT UNSIGNED NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  active BOOLEAN DEFAULT TRUE,

  INDEX idx_network (network_id, created_at DESC),
  INDEX idx_shared_record (network_shared_record_id),
  FOREIGN KEY (network_id) REFERENCES networks(id),
  FOREIGN KEY (network_shared_record_id) REFERENCES network_shared_records(id) ON DELETE CASCADE
);

-- Audit log for compliance
CREATE TABLE network_audit_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  network_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  org_id BIGINT UNSIGNED NOT NULL,
  action VARCHAR(100) NOT NULL,  -- 'view_pii', 'confirm_match', 'share_record', etc.
  resource_type VARCHAR(50) NOT NULL,
  resource_id BIGINT UNSIGNED NOT NULL,
  details JSON NULL,
  ip_address VARCHAR(45) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_network_action (network_id, action, created_at DESC),
  INDEX idx_resource (resource_type, resource_id),
  FOREIGN KEY (network_id) REFERENCES networks(id)
);
```

### JSONB Metadata Structure Examples

**Participant Record** (`record_type = 'participant'`):
```json
{
  "pii_fields_shared": [4721, 4722, 4723],  // FIELD IDS from data_standards
  "pii_consent_confirmed_at": "2025-03-27T10:00:00Z",
  "pii_consent_by_user_id": 456,
  "matching_algorithm_version": "1.0",
  "last_match_run_at": "2025-03-27T12:00:00Z"
}
```

**Incident Record** (`record_type = 'incident'`):
```json
{
  "severity": "high",
  "incident_type": "safety_concern",
  "location": "Portland, OR",
  "occurred_at": "2025-03-26T15:00:00Z",
  "tags": ["housing", "mental_health"],
  "reported_by_org_name": "Youth Org A",
  "description": "Detailed incident description"
}
```

**Future: Veteran Record** (`record_type = 'veteran'`):
```json
{
  "branch": "Army",
  "service_years": "2010-2018",
  "discharge_type": "honorable",
  "va_eligible": true,
  "pii_fields_shared": [4721, 4722, 4800, 4801]
}
```

### Data Standards Extension

**Current:** Data standards define shared field mappings
**Needed:** Add type categorization

```sql
data_standards:
  + standard_type ENUM('participant', 'incident', 'other')

-- This determines which features are available:
- participant type → matching, cross-org coordination
- incident type → multi-org response tracking, flagging
```

### Share Up Pattern

**Both participants AND incidents follow "share up" pattern:**

1. Create record in tenant DB (tier1 record)
2. Share to network → creates `network_shared_records` entry
3. Other orgs see the shared record
4. Other orgs respond → creates `network_record_responses` entries
5. Other orgs can optionally import to their tenant DB

This unified pattern justifies the unified schema - both workflows are identical at the abstract level.

### Field ID-Based PII Filtering

**Critical Decision:** PII filtering based on field IDs (not field names)

**Implementation:**
```typescript
function filterPIIFields(
  recordData: any,
  piiFieldsShared: number[],  // field IDs from metadata
  dataStandard: DataStandard
): any {
  const filtered = { ...recordData };

  // Iterate through all fields in data standard
  for (const field of dataStandard.fields) {
    const fieldId = field.id;
    const fieldKey = `field_${fieldId}`;

    // If this field is NOT in the shared list, mask it
    if (!piiFieldsShared.includes(fieldId)) {
      if (filtered[fieldKey]) {
        filtered[fieldKey] = '● ● ●';  // Masked
      }
    }
  }

  return filtered;
}
```

### Apricot vs Snowflake Data Sources

**Solution**: `source_type` field in `network_record_sources` table.

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
      sqlText: `SELECT * FROM dsf_${source.dsf_id}_view WHERE document_id = ?`,
      binds: [source.tenant_document_id]
    });
  }
}
```

### Permission Model

**Network-Level Access**:
- User must have "Network Document Folder - Advanced Access" permission
- This is the gate to see ANY network shared data

**Own Org Records** (stricter):
- Must have network access
- AND must have permission to specific `tenant_document_id` in their Apricot DB
- Uses existing Apricot record-level permissions

**Other Orgs' Records** (PII filtered):
- Only need network access
- PII filtered based on `pii_fields_shared` in metadata (field IDs)
- Don't check Apricot permissions in other orgs' databases

---

## Phase 3: GraphQL API Design

### Unified GraphQL Schema

```graphql
type NetworkSharedRecord {
  id: ID!
  network_id: ID!
  data_standard_id: ID!
  record_type: RecordType!
  status: RecordStatus!
  match_confidence_score: Float
  metadata: JSON!
  sources: [NetworkRecordSource!]!
  responses: [NetworkRecordResponse!]!
  created_at: String!
  created_by_org_id: ID!
}

enum RecordType {
  PARTICIPANT
  INCIDENT
}

enum RecordStatus {
  PENDING
  CONFIRMED
  REJECTED
}

type NetworkRecordSource {
  id: ID!
  org_id: ID!
  org_name: String!
  tenant_document_id: ID!
  dsf_id: ID!
  source_type: SourceType!
  dsf_view_data: JSON!  # Actual field data from DSF view
  contributed_at: String!
}

enum SourceType {
  APRICOT
  SNOWFLAKE
}

type NetworkRecordResponse {
  id: ID!
  org_id: ID!
  org_name: String!
  response_type: ResponseType!
  response_data: JSON!
  created_at: String!
  created_by_user_id: ID!
}

enum ResponseType {
  MATCH_CONFIRMED
  MATCH_REJECTED
  INCIDENT_RESPONDED
  NOTE_ADDED
  IMPORTED_TO_TENANT
}

type Query {
  # Get all shared records for a network (participants + incidents)
  networkSharedRecords(
    network_id: ID!
    record_type: RecordType
    status: RecordStatus
    limit: Int = 50
    offset: Int = 0
  ): NetworkSharedRecordsResult!

  # Get single shared record
  networkSharedRecord(
    network_id: ID!
    record_id: ID!
  ): NetworkSharedRecord!
}

type Mutation {
  # Share a local tier1 record to the network
  shareRecordToNetwork(
    network_id: ID!
    record_type: RecordType!
    tenant_document_id: ID!
    dsf_id: ID!
    metadata: JSON!
  ): NetworkSharedRecord!

  # Confirm a participant match
  confirmMatch(
    network_id: ID!
    shared_record_id: ID!
    source_ids: [ID!]!
  ): NetworkSharedRecord!

  # Respond to an incident
  respondToIncident(
    network_id: ID!
    shared_record_id: ID!
    response_data: JSON!
  ): NetworkRecordResponse!

  # Import a shared record to your tenant DB
  importToTenantDB(
    network_id: ID!
    shared_record_id: ID!
  ): ImportResult!
}

type Subscription {
  # Subscribe to updates for any record type
  recordUpdated(
    network_id: ID!
    record_type: RecordType
  ): RecordUpdatePayload!
}

type RecordUpdatePayload {
  record: NetworkSharedRecord!
  change_type: ChangeType!
  changed_by_org_id: ID!
}

enum ChangeType {
  CREATED
  UPDATED
  DELETED
  MATCH_CONFIRMED
  MATCH_REJECTED
}
```

### Performance Optimization Strategy

**Leveraging Existing Infrastructure:**
- **Redis:** Already configured (db 4 for cache, db 0 for Bull queue)
- **LRU Cache:** Available at `src/utils/cache.ts`
- **Bull Queue:** For background matching jobs

#### Multi-Tier Caching Layer

```typescript
// TIER 1: Request-scoped cache (GraphQL context)
context.contextCache.set('network_records_123', data);

// TIER 2: Redis cache (5-minute TTL for aggregated data)
const cacheKey = `network:${networkId}:records:${recordType}:${status}`;
await redisClient.set(cacheKey, JSON.stringify(result), 'EX', 300);

// TIER 3: Process-level LRU cache (for PII config, field types)
import { LRUCache } from '../../utils/cache';
const piiConfigCache = new LRUCache({ max: 100, ttl: 3600 });
```

**Cache Keys Pattern:**
```
network:{networkId}:records:{recordType}:{status}
network:{networkId}:record:{recordId}
network:{networkId}:org:{orgId}:pii_config
```

---

## COMPREHENSIVE IMPLEMENTATION PLAN

## Phase-by-Phase Breakdown

This section breaks down the entire implementation into small, manageable increments. Each increment represents 1-2 hours of focused work.

---

## PHASE 0: Data Standards React - Validation Engine (2-3 weeks)

**Objective**: Add "Participant Incident" data standard type with field validation

**Location**: `/Users/patrick.kennedy/Desktop/Apricot_Files/data-standards-react/`

### 0.1: Add Standard Type Dropdown (Simple - 2 hours)

**Files to Modify**:
- `src/Modules/DataStandardsEdit/components/BasicInfo.tsx`
- `src/Modules/DataStandardsEdit/state/dataStandardEditAtoms.ts`

**Changes**:
```typescript
// Add to form state
standardType: 'general' | 'participant_incident'

// Add MUI Select dropdown
<FormControl>
  <InputLabel>Data Standard Type</InputLabel>
  <Select
    value={formData.standardType}
    onChange={handleTypeChange}
  >
    <MenuItem value="general">General</MenuItem>
    <MenuItem value="participant_incident">Participant Incident</MenuItem>
  </Select>
</FormControl>
```

### 0.2-0.5: Validation Rules Engine, UI, Integration

(Detailed steps for validation logic, UI components, and backend integration)

**Dependencies**: Sequential (0.1 → 0.2 → 0.3 → 0.4 → 0.5)
**Verification**: Cannot save invalid data standard, can save valid one

---

## PHASE 1: Backend - Database & Models (1-2 weeks)

**Objective**: Create unified database tables and Sequelize models

### 1.1: Run Database Migration (Simple - 1 hour)

**Files to Execute**:
- `/Users/patrick.kennedy/Desktop/Apricot_Files/whiteboarding/network-document-folder/database-schema-unified.sql`

**Actions**:
1. Review schema (already complete)
2. Run migration against dev database
3. Verify all tables created with correct indexes

**Verification**: `SHOW TABLES LIKE 'network_%'` returns 5 tables

### 1.2: Create Sequelize Model - NetworkSharedRecord (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/repository/models/global/network_shared_records.ts`

**Template**:
```typescript
import { DataTypes, Model } from 'sequelize';

export class NetworkSharedRecord extends Model {
  declare id: number;
  declare network_id: number;
  declare data_standard_id: number;
  declare record_type: 'participant' | 'incident';
  declare status: 'pending' | 'confirmed' | 'rejected';
  declare match_confidence_score: number | null;
  declare metadata: any;  // JSON
  declare created_at: Date;
  declare updated_at: Date;
  declare created_by_org_id: number;
  declare active: boolean;
}

export function initNetworkSharedRecord(sequelize: Sequelize) {
  NetworkSharedRecord.init({
    id: {
      type: DataTypes.BIGINT.UNSIGNED,
      primaryKey: true,
      autoIncrement: true
    },
    network_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: false
    },
    record_type: {
      type: DataTypes.ENUM('participant', 'incident'),
      allowNull: false
    },
    status: {
      type: DataTypes.ENUM('pending', 'confirmed', 'rejected'),
      defaultValue: 'pending'
    },
    metadata: {
      type: DataTypes.JSON,
      allowNull: false
    },
    // ... other fields
  }, {
    sequelize,
    tableName: 'network_shared_records',
    underscored: true
  });
}
```

**Dependencies**: 1.1
**Verification**: Import model, no TypeScript errors

### 1.3-1.5: Create Remaining Models and Associations

**Files to Create**:
- `network_record_sources.ts`
- `network_record_responses.ts`
- `network_notes.ts`
- `network_audit_log.ts`

**Add Associations**:
```typescript
NetworkSharedRecord.hasMany(NetworkRecordSource, {
  foreignKey: 'network_shared_record_id',
  as: 'sources'
});

NetworkSharedRecord.hasMany(NetworkRecordResponse, {
  foreignKey: 'network_shared_record_id',
  as: 'responses'
});
```

**Dependencies**: 1.2
**Verification**: Can query with includes: `NetworkSharedRecord.findAll({ include: ['sources', 'responses'] })`

---

## PHASE 2: Backend - Services & Repository Layer (2-3 weeks)

**Objective**: Implement business logic for unified record management

### 2.1: Create NetworkDocumentFolderService (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/application/services/networkDocumentFolderService.ts`

**Implementation**:
```typescript
import { AbstractService } from './AbstractService';
import { Context } from '../context';
import { NetworkSharedRecord } from '../../repository/models/global';

export class NetworkDocumentFolderService extends AbstractService {
  async getNetworkSharedRecords(
    context: Context,
    networkId: number,
    options?: {
      recordType?: 'participant' | 'incident';
      status?: string;
      limit?: number;
      offset?: number;
    }
  ): Promise<{ total: number; rows: any[] }> {
    // Cache check
    const cacheKey = `network:${networkId}:records:${options?.recordType || 'all'}:${options?.status || 'all'}`;
    const cached = await this.connections.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    // Query network shared records
    const records = await NetworkSharedRecord.findAll({
      where: {
        network_id: networkId,
        active: true,
        ...(options?.recordType && { record_type: options.recordType }),
        ...(options?.status && { status: options.status })
      },
      include: ['sources', 'responses'],
      limit: options?.limit || 50,
      offset: options?.offset || 0
    });

    // Query DSF views for each source (supports Apricot + Snowflake)
    const enriched = await this.enrichWithDSFData(context, records);

    // Apply field-level PII filtering based on metadata
    const filtered = await this.applyPIIFiltering(context, networkId, enriched);

    // Cache result
    await this.connections.redis.set(cacheKey, JSON.stringify(filtered), 'EX', 300);

    return { total: records.length, rows: filtered };
  }
}
```

### 2.2: Create SourceConnectorService (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/application/services/sourceConnectorService.ts`

**Implementation**:
```typescript
export class SourceConnectorService extends AbstractService {
  async getDSFViewData(
    context: Context,
    source: NetworkRecordSource
  ): Promise<any> {
    if (source.source_type === 'apricot') {
      return this.getApricotDSFData(context, source);
    } else if (source.source_type === 'snowflake') {
      return this.getSnowflakeDSFData(context, source);
    }
  }

  private async getApricotDSFData(
    context: Context,
    source: NetworkRecordSource
  ): Promise<any> {
    const knex = await context.connections.knex.getClientDb(source.org_id);
    const viewName = `dsf_${source.dsf_id}_view`;

    return knex(viewName)
      .where('document_id', source.tenant_document_id)
      .first();
  }

  private async getSnowflakeDSFData(
    context: Context,
    source: NetworkRecordSource
  ): Promise<any> {
    const snowflake = await getSnowflakeConnection(source.source_connection_id);

    const result = await snowflake.execute({
      sqlText: `SELECT * FROM dsf_${source.dsf_id}_view WHERE document_id = ?`,
      binds: [source.tenant_document_id]
    });

    return result.rows[0];
  }
}
```

### 2.3: Implement Field-Level PII Filtering (Complex - 4 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/application/services/networkPIIService.ts`

**Implementation**:
```typescript
export class NetworkPIIService extends AbstractService {
  async filterRecordPII(
    context: Context,
    record: NetworkSharedRecord,
    requestingOrgId: number
  ): Promise<any> {
    // Get PII field IDs from metadata
    const piiFieldsShared = record.metadata.pii_fields_shared || [];

    // Filter each source's DSF view data
    const filteredSources = record.sources.map(source => {
      // Own org sees everything
      if (source.org_id === requestingOrgId) {
        return source;
      }

      // Other orgs: filter by field IDs
      const filteredData = this.filterFieldsByIds(
        source.dsf_view_data,
        piiFieldsShared
      );

      return {
        ...source,
        dsf_view_data: filteredData
      };
    });

    return {
      ...record.toJSON(),
      sources: filteredSources
    };
  }

  private filterFieldsByIds(
    dsfData: any,
    allowedFieldIds: number[]
  ): any {
    const filtered = { ...dsfData };

    // Iterate through all fields in DSF view data
    Object.keys(filtered).forEach(key => {
      // Extract field ID from key (e.g., "field_4721" → 4721)
      const match = key.match(/^field_(\d+)/);
      if (match) {
        const fieldId = parseInt(match[1], 10);

        // If field ID not in allowed list, mask it
        if (!allowedFieldIds.includes(fieldId)) {
          filtered[key] = '● ● ●';
        }
      }
    });

    return filtered;
  }
}
```

### 2.4: Create Matching Service (Participants Only) (Complex - 6 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/application/services/participantMatchingService.ts`

**Implementation**:
```typescript
export class ParticipantMatchingService extends AbstractService {
  async findPotentialMatches(
    context: Context,
    networkId: number,
    sharedRecordId: number
  ): Promise<any[]> {
    const record = await NetworkSharedRecord.findByPk(sharedRecordId, {
      where: { record_type: 'participant' },
      include: ['sources']
    });

    if (!record) return [];

    const allRecords = await NetworkSharedRecord.findAll({
      where: {
        network_id: networkId,
        record_type: 'participant',
        id: { [Op.ne]: sharedRecordId }
      },
      include: ['sources']
    });

    const matches = [];

    for (const other of allRecords) {
      const score = await this.calculateMatchScore(record, other);

      if (score >= 70) {
        matches.push({
          shared_record_a_id: sharedRecordId,
          shared_record_b_id: other.id,
          match_score: score,
          status: score >= 90 ? 'high_confidence' : 'potential_match'
        });
      }
    }

    return matches;
  }

  async calculateMatchScore(
    recordA: NetworkSharedRecord,
    recordB: NetworkSharedRecord
  ): Promise<number> {
    // Extract PII from sources (first source of each)
    const sourceA = recordA.sources[0];
    const sourceB = recordB.sources[0];

    if (!sourceA || !sourceB) return 0;

    let score = 0;

    // SSN Last 4 (45 points)
    const ssnA = sourceA.dsf_view_data.field_4723; // example field ID
    const ssnB = sourceB.dsf_view_data.field_4723;
    if (ssnA && ssnB && ssnA === ssnB) {
      score += 45;
    }

    // DOB (35 points)
    const dobA = sourceA.dsf_view_data.field_4722;
    const dobB = sourceB.dsf_view_data.field_4722;
    if (dobA && dobB) {
      if (dobA === dobB) {
        score += 35;
      } else if (this.isDOBWithin1Day(dobA, dobB)) {
        score += 25;
      }
    }

    // Name similarity (30 points)
    const nameA = sourceA.dsf_view_data.field_4721;
    const nameB = sourceB.dsf_view_data.field_4721;
    if (nameA && nameB) {
      const similarity = this.calculateLevenshteinSimilarity(nameA, nameB);
      score += Math.round(similarity * 30);
    }

    return score;
  }

  private isDOBWithin1Day(dateA: string, dateB: string): boolean {
    const diff = Math.abs(new Date(dateA).getTime() - new Date(dateB).getTime());
    return diff <= 86400000; // 1 day in milliseconds
  }

  private calculateLevenshteinSimilarity(a: string, b: string): number {
    // Levenshtein distance implementation
    // Returns 0-1 similarity score
    const distance = this.levenshteinDistance(a.toLowerCase(), b.toLowerCase());
    const maxLength = Math.max(a.length, b.length);
    return maxLength === 0 ? 1 : 1 - (distance / maxLength);
  }

  private levenshteinDistance(a: string, b: string): number {
    const matrix = [];

    for (let i = 0; i <= b.length; i++) {
      matrix[i] = [i];
    }

    for (let j = 0; j <= a.length; j++) {
      matrix[0][j] = j;
    }

    for (let i = 1; i <= b.length; i++) {
      for (let j = 1; j <= a.length; j++) {
        if (b.charAt(i - 1) === a.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j] + 1
          );
        }
      }
    }

    return matrix[b.length][a.length];
  }
}
```

---

## PHASE 3: Backend - GraphQL API (2-3 weeks)

**Objective**: Create unified GraphQL API

### 3.1: Create Unified TypeDefs (Simple - 2 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/graphql-api/typeDefs/networkSharedRecords.ts`

**Implementation**: (See unified schema above)

### 3.2-3.8: Query and Mutation Resolvers

**Files to Create**:
- `src/graphql-api/resolvers/networkSharedRecords/queries.ts`
- `src/graphql-api/resolvers/networkSharedRecords/mutations.ts`

**Key Mutations**:
1. `shareRecordToNetwork` - Share tier1 record to network
2. `confirmMatch` - Confirm participant match (participants only)
3. `respondToIncident` - Org response to incident
4. `importToTenantDB` - Import shared record back to tenant

---

## PHASE 4: Backend - Subscriptions & Real-Time (1-2 weeks)

**Objective**: Enable WebSocket subscriptions for real-time updates

### 4.1-4.8: WebSocket Setup

(Detailed steps for installing dependencies, creating WebSocket server, subscription resolvers, and event publishing)

**Key Points**:
- Single subscription: `recordUpdated(network_id, record_type)`
- Works for all record types (participant, incident, future types)
- Redis Pub/Sub for multi-instance support

---

## PHASE 5-10: Frontend (6-8 weeks)

**Objective**: Build React app with Relay, Jotai, and real-time features

### Key Components:
1. **Setup**: Vite + TypeScript + Relay + Jotai
2. **State**: Unified atoms for all record types
3. **Queries**: Relay queries for networkSharedRecords
4. **Components**: RecordList, RecordDetail (type-specific rendering)
5. **Subscriptions**: Real-time updates via WebSocket

---

## Remaining Questions for Product Decision

### 1. Incident Workflow
- Auto-notify all orgs on Critical/High incidents?
- Passive notification for Medium/Low?

### 2. Matching Confirmation
- If 2 orgs confirm but 3rd rejects, create separate records?

### 3. Performance Targets
- Network size: 6-15 orgs (max 50)?
- Records per network: 100-500 (max 10K)?
- Response time: <500ms acceptable?

---

## Risk Assessment

### High Risk
- 🔴 Cross-tenant query performance (Apricot + Snowflake)
- 🔴 False positive matches (human confirmation required)
- 🔴 PII leakage (field-level filtering, audit logging)

### Medium Risk
- 🟡 Data sync lag (event-driven updates, cache invalidation)
- 🟡 Network scaling (pagination, virtual scrolling)

---

## Success Metrics

- Participant match accuracy > 95%
- Page load time < 1 second (P95)
- Zero PII leakage incidents
- API response time < 300ms (P95)
- User adoption: 80% of network members active monthly

---

## Technical Decisions & Rationale

### 1. Why Unified Schema?
- Add new types without migrations
- Single workflow codebase
- Proven at 2M+ record scale
- JSONB flexibility

### 2. Why Field ID-Based PII?
- Exact field control
- Works across Apricot + Snowflake
- Auditable and secure

### 3. Why WebSocket Subscriptions?
- True real-time updates
- Efficient (only sends changes)
- Better UX (instant collaboration)

---

## Files Modified Summary

### Created (Unified Approach)
- `database-schema-unified.sql` - 5 core tables
- `sample-data-unified.sql` - Test data
- `api-examples/queries-unified.graphql`
- `api-examples/mutations-unified.graphql`
- `api-examples/subscriptions-unified.graphql`

### Backend Models
- `network_shared_records.ts`
- `network_record_sources.ts`
- `network_record_responses.ts`
- `network_notes.ts`
- `network_audit_log.ts`

### Services
- `networkDocumentFolderService.ts` - Unified record management
- `sourceConnectorService.ts` - Apricot + Snowflake support
- `networkPIIService.ts` - Field-level filtering
- `participantMatchingService.ts` - Matching algorithm

### GraphQL
- `typeDefs/networkSharedRecords.ts` - Unified schema
- `resolvers/networkSharedRecords.ts` - Unified resolvers

---

**Status**: Architecture defined, unified schema implemented, ready for development

**Next**: Begin Phase 0 (Data Standards validation) or Phase 1 (Backend models)
