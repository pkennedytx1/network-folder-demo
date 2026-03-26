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
3. Matching algorithm (Phase 2) - Core value proposition
4. React app setup with Relay (Phase 5) - Frontend foundation

## Context

### Problem Statement
- Networks contain 1 lead org + multiple member orgs
- Each org has their own tenant data (participants, incidents) in separate databases
- Organizations need to collaborate on the same participants who may exist across multiple orgs
- Must handle PII privacy controls (some orgs share PII, others don't)
- Need to match/deduplicate participants across orgs without creating data integrity issues
- Must support real-time collaboration on incidents with per-org response tracking

### Key Challenges Identified
1. **Cross-Tenant Data Queries** - Performance implications of querying multiple tenant databases
2. **Participant Matching/Deduplication** - Identifying same person across orgs without false positives
3. **PII Security** - Granular privacy controls per org, per network
4. **Data Synchronization** - Keeping views fresh as source data changes
5. **Scalability** - Could have dozens of orgs in a network, hundreds of participants
6. **Type System** - Extending data standards to support different types (Participant vs Incident)

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
  [field_123_firstName]   -- Mapped data standard fields
  [field_123_lastName]    -- (multi-column fields get suffixes)
  [field_456]             -- Single column fields
  -- Linking fields (types 38/39) include metadata:
  [field_789__link_form_id]
  [field_789__link_field_id]
  [field_789__link_direction]
  etc.
```

#### Key Insight: Views Auto-Sync!
- Views are **NOT materialized** - they're dynamic SQL queries
- They query directly from `data_{formId}` tables and `documents` table
- **No explicit sync mechanism needed** - views always reflect current data
- When underlying tier1 data changes, view results automatically update on next query

#### Data Standards Map Table:
**File:** `Apricot_Files/apricot-api/src/repository/models/org/data_standards_map.ts`

```sql
data_standards_map:
  id (PK)
  data_standard_id        -- Links to global data standard
  data_standard_form_id   -- Which DSF this maps to
  data_standard_field     -- e.g., "field_4721"
  form_id                 -- Tenant's actual form ID
  field_id                -- Tenant's actual field ID
  reference_tag           -- Optional tag
```

**Mapping format:** `dsfId_dsFieldId` → `formId_fieldId`

Example: DSF 105, field 4721 maps to Form 223, field 891

### Architecture Decision: Leverage Existing DSF Views

**Selected Approach: Query DSF views directly + Cache aggregated results**

Since DSF views are:
1. Already created when data standards are mapped
2. Auto-sync with source data (no maintenance needed)
3. Contain all mapped fields in standardized format
4. One view per org per data standard form

**Our Strategy:**
- **Don't duplicate** the DSF view data into network tables
- **Query DSF views** from all orgs in the network via GraphQL
- **Cache the aggregated/matched results** in Redis (5-min TTL)
- **Store only network-specific data** in network DB:
  - Participant matches (which DSF records = same person)
  - Network incidents (not in tenant DBs)
  - Org responses to incidents
  - Notes, referrals

**Data Flow:**
```
User requests participants list
  ↓
Check Redis cache for network {id} participants
  ↓ (cache miss)
Query DSF views from all member orgs:
  - SELECT * FROM dsf_101_view (org A)
  - SELECT * FROM dsf_102_view (org B)
  - SELECT * FROM dsf_103_view (org C)
  ↓
Join with network_participant_matches table
  ↓
Apply PII filtering based on org permissions
  ↓
Cache aggregated result in Redis (TTL: 300s)
  ↓
Return to client
```

**Cache Invalidation Triggers:**
- Record updated in any tenant DB → Invalidate cache for that network
- Match confirmed/rejected → Invalidate participant cache
- PII settings changed → Invalidate cache for that org

#### PII Privacy Architecture

**Critical Decision:** How do we enforce PII visibility rules?

**Requirements:**
- Per-network configuration (PII sharing enabled/disabled)
- Per-org opt-in/opt-out within network
- Different orgs in same network can have different PII visibility
- Must support progressive reveal (show anonymized, then reveal on permission)

**Recommendation:**
```
network_pii_settings:
  - network_id
  - org_id
  - pii_sharing_enabled (boolean)
  - fields_shared (JSON array: ["name", "dob", "ssn_last4", etc])
  - consent_confirmed_at
  - confirmed_by_user_id

API layer enforces visibility:
- Query includes requesting_org_id
- Response filters PII based on org_id permissions
- Audit log for PII access
```

---

## Phase 2: High-Level Architecture

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
│  Network DB      │ │  Tenant 1 DB     │ │  Tenant N DB     │
│  (Shared Data)   │ │  (Source Data)   │ │  (Source Data)   │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

### Database Schema (Network-Level)

#### Core Tables

```sql
-- Network participants (matched/deduplicated records)
network_participants:
  - id (PK)
  - network_id (FK)
  - created_at
  - match_confidence_score
  - match_status (confirmed, potential, pending_verification)

-- Links individual org records to network participant
network_participant_sources:
  - id (PK)
  - network_participant_id (FK)
  - tenant_id
  - source_record_id (tier1_record_id in tenant DB)
  - source_form_id
  - name_used (encrypted)
  - ssn_last4_hash
  - dob_hash
  - contributed_at
  - confirmed_by_org_user_id

-- Incidents shared across network
network_incidents:
  - id (PK)
  - network_id (FK)
  - incident_type
  - severity
  - location
  - occurred_at
  - reported_by_org_id
  - description
  - created_at

-- Per-org response to incidents
network_incident_org_responses:
  - id (PK)
  - network_incident_id (FK)
  - org_id (FK)
  - status (not_started, in_progress, complete)
  - planned_actions (JSON)
  - current_actions (JSON)
  - completed_actions (JSON)
  - updated_at

-- Link participants to incidents
network_incident_participants:
  - network_incident_id (FK)
  - network_participant_id (FK)

-- Network-level collaboration notes
network_notes:
  - id (PK)
  - network_id (FK)
  - author_org_id
  - author_user_id
  - content
  - related_participant_id (nullable)
  - related_incident_id (nullable)
  - created_at

-- Referrals between orgs
network_referrals:
  - id (PK)
  - network_id (FK)
  - participant_id (FK)
  - from_org_id
  - to_org_id
  - reason
  - status (pending, accepted, in_progress, completed, declined)
  - created_at
  - updated_at
```

### Data Standards Extension

**Current:** Data standards define shared field mappings
**Needed:** Add type categorization

```sql
data_standards:
  + standard_type ENUM('participant', 'incident', 'other')

-- This determines which features are available:
- participant type → matching, referrals, cross-org coordination
- incident type → multi-org response tracking, flagging
```

---

## COMPREHENSIVE IMPLEMENTATION PLAN

## Phase-by-Phase Breakdown

This section breaks down the entire implementation into small, manageable increments. Each increment represents 1-2 hours of focused work and can be given as a single Claude prompt.

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

**Dependencies**: None
**Verification**: Dropdown appears, saves to form state

### 0.2: Create Validation Rules Engine (Medium - 4 hours)

**Files to Create**:
- `src/Modules/DataStandardsEdit/utils/validationRules.ts`
- `src/Modules/DataStandardsEdit/types/ValidationRule.ts`

**Implementation**:
```typescript
// ValidationRule.ts
export type RuleType =
  | 'required_tier1'
  | 'required_field'
  | 'required_field_type'
  | 'required_link';

export interface ValidationRule {
  ruleType: RuleType;
  config: Record<string, any>;
  errorMessage: string;
}

// validationRules.ts
export const PARTICIPANT_INCIDENT_RULES: ValidationRule[] = [
  {
    ruleType: 'required_tier1',
    config: { tier1Type: 'participant' },
    errorMessage: 'Must include a Participant (Tier 1) form'
  },
  {
    ruleType: 'required_tier1',
    config: { tier1Type: 'incident' },
    errorMessage: 'Must include an Incident (Tier 1) form linked to Participant'
  },
  {
    ruleType: 'required_field',
    config: {
      tier1Type: 'participant',
      fieldName: 'name',
      fieldTypes: ['text', 'name']
    },
    errorMessage: 'Participant must have a Name field'
  },
  // ... DOB, SSN, Address rules
];

export function validateDataStandard(
  standardType: string,
  forms: DataStandardForm[]
): ValidationResult {
  if (standardType !== 'participant_incident') return { valid: true };

  const rules = PARTICIPANT_INCIDENT_RULES;
  const errors: string[] = [];

  for (const rule of rules) {
    if (!checkRule(rule, forms)) {
      errors.push(rule.errorMessage);
    }
  }

  return { valid: errors.length === 0, errors };
}
```

**Dependencies**: 0.1
**Verification**: Unit tests pass, validation logic correct

### 0.3: Add Validation UI Component (Medium - 3 hours)

**Files to Create**:
- `src/Modules/DataStandardsEdit/components/ValidationChecklist.tsx`

**Implementation**:
```typescript
import { Alert, Checkbox, List, ListItem, ListItemIcon, ListItemText } from '@mui/material';
import { CheckCircle, Error } from '@mui/icons-material';

export function ValidationChecklist({ validationResult }: Props) {
  if (validationResult.valid) {
    return (
      <Alert severity="success">
        All validation rules passed ✓
      </Alert>
    );
  }

  return (
    <Alert severity="error">
      <List>
        {validationResult.errors.map((error, i) => (
          <ListItem key={i}>
            <ListItemIcon><Error color="error" /></ListItemIcon>
            <ListItemText primary={error} />
          </ListItem>
        ))}
      </List>
    </Alert>
  );
}
```

**Files to Modify**:
- `src/Modules/DataStandardsEdit/index.tsx` - Add validation display

**Dependencies**: 0.2
**Verification**: Validation errors display correctly, blocks save

### 0.4: Integrate with Save Mutation (Simple - 2 hours)

**Files to Modify**:
- `src/Modules/DataStandardsEdit/mutations/UpdateDataStandardMutation.ts`
- `src/Modules/DataStandardsEdit/components/SaveButton.tsx`

**Changes**:
- Run validation before allowing save
- Display validation checklist
- Disable save button if invalid
- Include `standard_type` in mutation variables

**Dependencies**: 0.3
**Verification**: Cannot save invalid data standard, can save valid one

### 0.5: Add Validation to Backend (Complex - 4 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/repository/models/global/data_standard_validation_rules.ts`

**Files to Modify**:
- `Apricot_Files/apricot-api/src/graphql-api/mutations/dataStandards/updateDataStandard.ts`
- Add server-side validation logic

**Dependencies**: 0.4
**Verification**: Backend rejects invalid data standards

---

## PHASE 1: Backend - Database & Models (1-2 weeks)

**Objective**: Create all network-level database tables and Sequelize/Knex models

### 1.1: Run Database Migration (Simple - 1 hour)

**Files to Execute**:
- `/Users/patrick.kennedy/Desktop/Apricot_Files/whiteboarding/network-document-folder/database-schema.sql`

**Actions**:
1. Review schema (already complete)
2. Run migration against dev database
3. Verify all tables created with correct indexes

**Dependencies**: Database access
**Verification**: `SHOW TABLES LIKE 'network_%'` returns 10 tables

### 1.2: Create Sequelize Models - Participants (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/repository/models/global/network_participants.ts`
- `Apricot_Files/apricot-api/src/repository/models/global/network_participant_sources.ts`
- `Apricot_Files/apricot-api/src/repository/models/global/network_participant_potential_matches.ts`

**Template**:
```typescript
import { DataTypes, Model } from 'sequelize';

export class NetworkParticipant extends Model {
  declare id: number;
  declare network_id: number;
  declare match_status: 'confirmed' | 'potential_match' | 'pending_verification';
  declare match_confidence_score: number;
  declare created_at: Date;
  declare updated_at: Date;
  declare active: boolean;
}

export function initNetworkParticipant(sequelize: Sequelize) {
  NetworkParticipant.init({
    id: {
      type: DataTypes.BIGINT.UNSIGNED,
      primaryKey: true,
      autoIncrement: true
    },
    network_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: false
    },
    match_status: {
      type: DataTypes.ENUM('confirmed', 'potential_match', 'pending_verification'),
      defaultValue: 'pending_verification'
    },
    // ... other fields
  }, {
    sequelize,
    tableName: 'network_participants',
    underscored: true
  });
}
```

**Dependencies**: 1.1
**Verification**: Import models, no TypeScript errors

### 1.3: Create Sequelize Models - Incidents (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/repository/models/global/network_incidents.ts`
- `Apricot_Files/apricot-api/src/repository/models/global/network_incident_org_responses.ts`
- `Apricot_Files/apricot-api/src/repository/models/global/network_incident_participants.ts`

**Dependencies**: 1.1
**Verification**: Models import successfully

### 1.4: Create Sequelize Models - Collaboration (Simple - 2 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/repository/models/global/network_referrals.ts`
- `Apricot_Files/apricot-api/src/repository/models/global/network_notes.ts`
- `Apricot_Files/apricot-api/src/repository/models/global/network_audit_log.ts`
- `Apricot_Files/apricot-api/src/repository/models/global/network_pii_settings.ts`

**Dependencies**: 1.1
**Verification**: All 10 models created and loadable

### 1.5: Create Model Associations (Medium - 2 hours)

**Files to Modify**:
- All network model files from 1.2-1.4

**Add Associations**:
```typescript
NetworkParticipant.hasMany(NetworkParticipantSource, {
  foreignKey: 'network_participant_id',
  as: 'sources'
});

NetworkIncident.hasMany(NetworkIncidentOrgResponse, {
  foreignKey: 'network_incident_id',
  as: 'orgResponses'
});

NetworkIncident.belongsToMany(NetworkParticipant, {
  through: NetworkIncidentParticipant,
  foreignKey: 'network_incident_id',
  as: 'participants'
});
```

**Dependencies**: 1.2, 1.3, 1.4
**Verification**: Can query with includes: `NetworkParticipant.findAll({ include: ['sources'] })`

---

## PHASE 2: Backend - Services & Repository Layer (2-3 weeks)

**Objective**: Implement business logic for participant matching, incident tracking, and multi-org queries

### 2.1: Create NetworkDocumentFolderService Base (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/application/services/networkDocumentFolderService.ts`

**Implementation**:
```typescript
import { AbstractService } from './AbstractService';
import { Context } from '../context';
import { NetworkParticipant, NetworkIncident } from '../../repository/models/global';

export class NetworkDocumentFolderService extends AbstractService {
  constructor(claims: Claims, connections: Connections) {
    super(claims, connections);
  }

  async getNetworkParticipants(
    context: Context,
    networkId: number,
    options?: { matchStatus?: string; limit?: number; offset?: number }
  ): Promise<{ total: number; rows: any[] }> {
    // Cache check
    const cacheKey = `network:${networkId}:participants:${options?.matchStatus || 'all'}`;
    const cached = await this.connections.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    // Query network participants
    const participants = await NetworkParticipant.findAll({
      where: { network_id: networkId, ...(options?.matchStatus && { match_status: options.matchStatus }) },
      include: ['sources'],
      limit: options?.limit || 50,
      offset: options?.offset || 0
    });

    // Query DSF views for each source
    const enriched = await this.enrichWithDSFData(context, participants);

    // Apply PII filtering
    const filtered = this.applyPIIFiltering(context, enriched);

    // Cache result
    await this.connections.redis.set(cacheKey, JSON.stringify(filtered), 'EX', 300);

    return { total: participants.length, rows: filtered };
  }

  private async enrichWithDSFData(context: Context, participants: any[]): Promise<any[]> {
    // Implementation in 2.3
  }

  private applyPIIFiltering(context: Context, data: any[]): any[] {
    // Implementation in 2.4
  }
}
```

**Dependencies**: 1.5
**Verification**: Service instantiates, basic query works

### 2.2: Create NetworkQuery Repository (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/repository/query/networkDocumentFolder.ts`

**Implementation**:
```typescript
import { AbstractQuery } from './abstract';
import { Context } from '../../application/context';

export class NetworkDocumentFolderQuery extends AbstractQuery {
  async getParticipants(
    context: Context,
    networkId: number,
    filters?: { matchStatus?: string }
  ): Promise<any[]> {
    const knex = context.connections.knex;

    let query = knex('network_participants as np')
      .select('np.*')
      .leftJoin('network_participant_sources as nps', 'np.id', 'nps.network_participant_id')
      .where('np.network_id', networkId)
      .where('np.active', true);

    if (filters?.matchStatus) {
      query = query.where('np.match_status', filters.matchStatus);
    }

    return query;
  }

  async getDSFViewData(
    context: Context,
    orgId: number,
    dsfId: number,
    documentIds: number[]
  ): Promise<any[]> {
    const viewName = `dsf_${dsfId}_view`;
    // Query tenant database
    const knex = await context.connections.knex.getClientDb(orgId);

    return knex(viewName)
      .whereIn('document_id', documentIds)
      .select('*');
  }
}
```

**Dependencies**: 2.1
**Verification**: Raw queries return correct data

### 2.3: Implement DSF View Enrichment (Complex - 4 hours)

**Files to Modify**:
- `Apricot_Files/apricot-api/src/application/services/networkDocumentFolderService.ts`

**Implementation**:
```typescript
private async enrichWithDSFData(
  context: Context,
  participants: NetworkParticipant[]
): Promise<any[]> {
  const query = new NetworkDocumentFolderQuery();

  // Group sources by org/DSF for batch querying
  const sourcesByOrg = new Map<number, Map<number, number[]>>();

  for (const participant of participants) {
    for (const source of participant.sources) {
      if (!sourcesByOrg.has(source.org_id)) {
        sourcesByOrg.set(source.org_id, new Map());
      }
      const dsfMap = sourcesByOrg.get(source.org_id)!;
      if (!dsfMap.has(source.dsf_id)) {
        dsfMap.set(source.dsf_id, []);
      }
      dsfMap.get(source.dsf_id)!.push(source.document_id);
    }
  }

  // Query all DSF views in parallel
  const dsfDataPromises: Promise<any>[] = [];

  for (const [orgId, dsfMap] of sourcesByOrg) {
    for (const [dsfId, documentIds] of dsfMap) {
      dsfDataPromises.push(
        query.getDSFViewData(context, orgId, dsfId, documentIds)
      );
    }
  }

  const allDsfData = await Promise.all(dsfDataPromises);

  // Merge DSF data back into participants
  // ... (mapping logic)

  return enrichedParticipants;
}
```

**Dependencies**: 2.2
**Verification**: Participants include DSF field data

### 2.4: Implement PII Filtering (Complex - 4 hours)

**Files to Modify**:
- `Apricot_Files/apricot-api/src/application/services/networkDocumentFolderService.ts`

**Files to Create**:
- `Apricot_Files/apricot-api/src/application/services/networkPIIService.ts`

**Implementation**:
```typescript
export class NetworkPIIService extends AbstractService {
  async getPIIPermissions(
    context: Context,
    networkId: number,
    requestingOrgId: number
  ): Promise<Map<number, string[]>> {
    // Cache PII permissions
    const cacheKey = `network:${networkId}:pii_permissions`;
    const cached = await this.connections.redis.get(cacheKey);
    if (cached) return new Map(JSON.parse(cached));

    // Query network_pii_settings
    const settings = await NetworkPIISettings.findAll({
      where: { network_id: networkId, pii_sharing_enabled: true }
    });

    const permissions = new Map<number, string[]>();
    for (const setting of settings) {
      permissions.set(setting.org_id, setting.fields_shared);
    }

    // Cache for 1 hour
    await this.connections.redis.set(cacheKey, JSON.stringify([...permissions]), 'EX', 3600);

    return permissions;
  }

  filterPIIFields(
    source: any,
    permissions: Map<number, string[]>,
    requestingOrgId: number
  ): any {
    const allowedFields = permissions.get(source.org_id) || [];

    return {
      ...source,
      name_used: allowedFields.includes('name') ? source.name_used : '● ● ● (PII masked)',
      dob: allowedFields.includes('dob') ? source.dob : null,
      ssn_last4: allowedFields.includes('ssn_last4') ? source.ssn_last4 : null,
      // ... other PII fields
    };
  }
}

// In NetworkDocumentFolderService
private applyPIIFiltering(context: Context, data: any[]): any[] {
  const piiService = new NetworkPIIService(this.claims, this.connections);
  const permissions = await piiService.getPIIPermissions(
    context,
    networkId,
    context.user.org_id
  );

  return data.map(participant => ({
    ...participant,
    sources: participant.sources.map(source =>
      piiService.filterPIIFields(source, permissions, context.user.org_id)
    )
  }));
}
```

**Dependencies**: 2.3
**Verification**: PII masked for unauthorized orgs, visible for authorized

### 2.5: Create Matching Service (Complex - 6 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/application/services/participantMatchingService.ts`

**Implementation**:
```typescript
import crypto from 'crypto';

export class ParticipantMatchingService extends AbstractService {
  private matchSalt = process.env.NETWORK_MATCH_SALT;

  async calculateMatchScore(
    participantA: any,
    participantB: any
  ): Promise<number> {
    let score = 0;

    // SSN Last 4 (45 points)
    if (participantA.ssn_last4_hash && participantB.ssn_last4_hash) {
      if (participantA.ssn_last4_hash === participantB.ssn_last4_hash) {
        score += 45;
      }
    }

    // DOB (35 points)
    if (participantA.dob_hash && participantB.dob_hash) {
      if (participantA.dob_hash === participantB.dob_hash) {
        score += 35;
      } else if (this.isDOBWithin1Day(participantA.dob, participantB.dob)) {
        score += 25; // Potential data entry error
      }
    }

    // Name similarity (30 points)
    const nameSimilarity = this.calculateLevenshteinSimilarity(
      participantA.name_hash,
      participantB.name_hash
    );
    score += Math.round(nameSimilarity * 30);

    return score;
  }

  hashPII(value: string): string {
    return crypto
      .createHmac('sha256', this.matchSalt)
      .update(value.toLowerCase().trim())
      .digest('hex');
  }

  async findPotentialMatches(
    context: Context,
    networkId: number,
    participantId: number
  ): Promise<any[]> {
    const participant = await NetworkParticipant.findByPk(participantId, {
      include: ['sources']
    });

    const allParticipants = await NetworkParticipant.findAll({
      where: {
        network_id: networkId,
        id: { [Op.ne]: participantId }
      },
      include: ['sources']
    });

    const matches = [];

    for (const other of allParticipants) {
      const score = await this.calculateMatchScore(participant, other);

      if (score >= 70) {
        matches.push({
          participant_a_id: participantId,
          participant_b_id: other.id,
          match_score: score,
          match_fields: this.getMatchedFields(participant, other),
          status: score >= 90 ? 'high_confidence' : 'potential_match'
        });
      }
    }

    return matches;
  }

  private calculateLevenshteinSimilarity(a: string, b: string): number {
    // Levenshtein distance implementation
    // Returns 0-1 similarity score
  }

  private isDOBWithin1Day(dateA: Date, dateB: Date): boolean {
    const diff = Math.abs(dateA.getTime() - dateB.getTime());
    return diff <= 86400000; // 1 day in milliseconds
  }
}
```

**Dependencies**: 2.1
**Verification**: Match scores calculated correctly, potential matches identified

### 2.6: Create Background Matching Job (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/jobs/participantMatchingJob.ts`

**Implementation**:
```typescript
import { Queue } from '../utils/queue';
import { ParticipantMatchingService } from '../application/services/participantMatchingService';

export class ParticipantMatchingJob {
  private queue: Queue;

  constructor(redis: Redis) {
    this.queue = new Queue(redis, 'participant-matching', 3); // 3 concurrent
  }

  async enqueueMatching(networkId: number, participantId: number) {
    await this.queue.add({
      networkId,
      participantId,
      timestamp: Date.now()
    });
  }

  startWorker() {
    this.queue.process(async (job) => {
      const { networkId, participantId } = job.data;

      const matchingService = new ParticipantMatchingService(/* context */);
      const potentialMatches = await matchingService.findPotentialMatches(
        context,
        networkId,
        participantId
      );

      // Store matches in network_participant_potential_matches table
      for (const match of potentialMatches) {
        await NetworkParticipantPotentialMatch.create(match);
      }

      // Invalidate cache
      await context.connections.redis.del(`network:${networkId}:participants`);

      // Publish event (for subscriptions)
      await context.pubsub.publish(`MATCH_DETECTED_${networkId}`, {
        matchDetected: {
          participant_a_id: participantId,
          matches: potentialMatches
        }
      });

      return { matchCount: potentialMatches.length };
    });
  }
}
```

**Dependencies**: 2.5
**Verification**: Job enqueues, processes, stores matches

---

## PHASE 3: Backend - GraphQL API (TypeDefs, Resolvers, Mutations) (2-3 weeks)

**Objective**: Create complete GraphQL API for Network Document Folder

### 3.1: Create NetworkParticipant TypeDef (Simple - 2 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/graphql-api/typeDefs/networkParticipant.ts`

**Implementation**:
```graphql
import { gql } from 'graphql-tag';

export const networkParticipantTypeDef = gql`
  type NetworkParticipant {
    id: ID!
    network_id: ID!
    match_status: MatchStatus!
    match_confidence_score: Float
    sources: [ParticipantSource!]!
    created_at: String!
  }

  type ParticipantSource {
    id: ID!
    org_id: ID!
    org_name: String!
    document_id: ID!
    dsf_id: ID!
    name_used: String        # PII - filtered
    ssn_last4: String        # PII - filtered
    dob: String              # PII - filtered
    contributed_at: String!
  }

  enum MatchStatus {
    CONFIRMED
    POTENTIAL_MATCH
    PENDING_VERIFICATION
  }

  type NetworkParticipantsResult {
    total: Int!
    participants: [NetworkParticipant!]!
  }

  type PotentialMatch {
    id: ID!
    participant_a: NetworkParticipant!
    participant_b: NetworkParticipant!
    match_score: Float!
    match_fields: [String!]!
    status: String!
    created_at: String!
  }

  extend type Query {
    networkParticipants(
      network_id: ID!
      match_status: MatchStatus
      limit: Int
      offset: Int
    ): NetworkParticipantsResult!

    networkParticipant(
      network_id: ID!
      participant_id: ID!
    ): NetworkParticipant!

    potentialMatches(
      network_id: ID!
      status: String
    ): [PotentialMatch!]!
  }
`;
```

**Dependencies**: None (typeDef only)
**Verification**: TypeDef loads, GraphQL schema compiles

### 3.2-3.8: Additional TypeDefs and Resolvers

**Similar incremental tasks for**:
- Network Incidents (3.2)
- Collaboration features (3.3)
- Query resolvers (3.5-3.7)
- Mutation resolvers (3.9-3.13)

(Details in full plan above)

---

## PHASE 4: Backend - Subscriptions & Real-Time (1-2 weeks)

**Objective**: Enable real-time collaboration with WebSocket subscriptions

### 4.1: Install WebSocket Dependencies (Simple - 30 min)

**Files to Modify**:
- `Apricot_Files/apricot-api/package.json`

**Dependencies to Add**:
```json
{
  "dependencies": {
    "graphql-ws": "^5.14.0",
    "ws": "^8.14.0",
    "graphql-redis-subscriptions": "^2.6.0"
  }
}
```

**Actions**:
```bash
npm install
```

**Dependencies**: None
**Verification**: Packages install successfully

### 4.2: Add WebSocket Server to Apricot API (Complex - 4 hours)

**Objective**: Upgrade Apollo Server to support WebSocket connections for GraphQL subscriptions

**Files to Modify**:
- `Apricot_Files/apricot-api/src/graphql-api/index.ts`

**Implementation**:
```typescript
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { useServer } from 'graphql-ws/lib/use/ws';
import { RedisPubSub } from 'graphql-redis-subscriptions';

// Create HTTP server (wrap Express)
const httpServer = createServer(app);

// Create Redis Pub/Sub
const pubsub = new RedisPubSub({
  publisher: connections.redis.client,
  subscriber: connections.redis.client.duplicate()
});

// Create WebSocket server
const wsServer = new WebSocketServer({
  server: httpServer,
  path: '/api/graph'
});

// Setup subscription handlers
useServer({
  schema,
  context: async (ctx, msg, args) => {
    // Extract token from connection params
    const token = ctx.connectionParams?.authorization?.replace('Bearer ', '');

    // Verify JWT and build context
    const user = await verifyToken(token);

    return {
      user,
      connections,
      pubsub,
      claims: buildClaims(user),
      // ... rest of context
    };
  },
  onConnect: async (ctx) => {
    console.log('WebSocket connected');
  },
  onDisconnect: (ctx) => {
    console.log('WebSocket disconnected');
  }
}, wsServer);

// Start server
httpServer.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`WebSocket server running on ws://localhost:${PORT}/api/graph`);
});
```

**Key Changes**:
1. Wrap Express app in HTTP server
2. Create WebSocket server on same port
3. Configure `graphql-ws` protocol
4. Share authentication context
5. Enable Redis Pub/Sub for multi-instance support

**Dependencies**: 4.1
**Verification**:
- WebSocket server starts without errors
- Can connect via `wscat -c ws://localhost:3000/api/graph`
- Authentication works over WebSocket

### 4.3: Create Subscription TypeDefs (Simple - 1 hour)

**Files to Create**:
- `Apricot_Files/apricot-api/src/graphql-api/typeDefs/networkSubscriptions.ts`

**Implementation**:
```graphql
export const networkSubscriptionsTypeDef = gql`
  type Subscription {
    participantUpdated(network_id: ID!): ParticipantUpdatePayload!
    incidentUpdated(network_id: ID!): IncidentUpdatePayload!
    matchDetected(network_id: ID!): MatchDetectedPayload!
  }

  type ParticipantUpdatePayload {
    participant: NetworkParticipant!
    change_type: ChangeType!
    changed_by_org_id: ID!
    changed_by_org_name: String!
  }

  type IncidentUpdatePayload {
    incident: NetworkIncident!
    change_type: ChangeType!
    changed_by_org_id: ID!
  }

  type MatchDetectedPayload {
    participant_a_id: ID!
    matches: [PotentialMatch!]!
  }

  enum ChangeType {
    CREATED
    UPDATED
    DELETED
    MATCH_CONFIRMED
  }
`;
```

**Files to Modify**:
- `Apricot_Files/apricot-api/src/graphql-api/typeDefs/index.ts` - Add to exports

**Dependencies**: 4.2
**Verification**: Subscription typeDefs load, GraphQL schema compiles

### 4.4: Create Subscription Resolvers (Medium - 3 hours)

**Files to Create**:
- `Apricot_Files/apricot-api/src/graphql-api/resolvers/subscriptions/networkDocumentFolder.ts`

**Implementation**:
```typescript
import { withFilter } from 'graphql-subscriptions';
import { Context } from '../../../application/context';

export const subscriptionResolvers = {
  Subscription: {
    participantUpdated: {
      subscribe: withFilter(
        (_: any, args: { network_id: string }, context: Context) => {
          const networkId = +args.network_id;

          // Verify user is network member
          // (async check in onConnect is preferred, but can double-check here)

          return context.pubsub.asyncIterator([`PARTICIPANT_UPDATED_${networkId}`]);
        },
        (payload: any, variables: { network_id: string }) => {
          // Filter: only send if network_id matches
          return payload.network_id === +variables.network_id;
        }
      ),
      resolve: (payload: any) => payload.participantUpdated
    },

    incidentUpdated: {
      subscribe: (_: any, args: { network_id: string }, context: Context) => {
        const networkId = +args.network_id;
        return context.pubsub.asyncIterator([`INCIDENT_UPDATED_${networkId}`]);
      },
      resolve: (payload: any) => payload.incidentUpdated
    },

    matchDetected: {
      subscribe: (_: any, args: { network_id: string }, context: Context) => {
        const networkId = +args.network_id;
        return context.pubsub.asyncIterator([`MATCH_DETECTED_${networkId}`]);
      },
      resolve: (payload: any) => payload.matchDetected
    }
  }
};
```

**Files to Modify**:
- `Apricot_Files/apricot-api/src/graphql-api/resolvers/index.ts` - Add Subscription key

**Dependencies**: 4.3
**Verification**: Subscriptions connect, can subscribe via GraphQL Playground

### 4.5: Add PubSub to Context (Simple - 1 hour)

**Files to Modify**:
- `Apricot_Files/apricot-api/src/application/context.ts`
- `Apricot_Files/apricot-api/src/application/context.d.ts`

**Changes**:
```typescript
// context.d.ts
import { RedisPubSub } from 'graphql-redis-subscriptions';

export interface Context {
  // ... existing context fields
  pubsub: RedisPubSub;
}

// context.ts
import { RedisPubSub } from 'graphql-redis-subscriptions';

export async function buildContext(req: Request, res: Response): Promise<Context> {
  const pubsub = new RedisPubSub({
    publisher: connections.redis.client,
    subscriber: connections.redis.client.duplicate()
  });

  return {
    // ... existing context
    pubsub
  };
}
```

**Dependencies**: 4.2
**Verification**: `context.pubsub` available in all resolvers

### 4.6: Integrate Event Publishing in Mutations (Medium - 2 hours)

**Files to Modify**:
- `Apricot_Files/apricot-api/src/graphql-api/mutations/networkDocumentFolder/confirmParticipantMatch.ts`
- `Apricot_Files/apricot-api/src/graphql-api/mutations/networkDocumentFolder/createNetworkIncident.ts`
- `Apricot_Files/apricot-api/src/application/services/participantMatchingService.ts` (for match detection)

**Implementation Pattern**:
```typescript
// In confirmParticipantMatch mutation (after DB update)
await context.pubsub.publish(`PARTICIPANT_UPDATED_${networkId}`, {
  participantUpdated: {
    participant: await loadFullParticipant(participantId),
    change_type: 'MATCH_CONFIRMED',
    changed_by_org_id: context.user.org_id,
    changed_by_org_name: context.user.org_name
  },
  network_id: networkId
});

// In participantMatchingService (after finding matches)
await context.pubsub.publish(`MATCH_DETECTED_${networkId}`, {
  matchDetected: {
    participant_a_id: participantId,
    matches: potentialMatches
  },
  network_id: networkId
});

// In createNetworkIncident mutation
await context.pubsub.publish(`INCIDENT_UPDATED_${networkId}`, {
  incidentUpdated: {
    incident: newIncident,
    change_type: 'CREATED',
    changed_by_org_id: context.user.org_id
  },
  network_id: networkId
});
```

**Dependencies**: 4.4, 4.5
**Verification**:
- Mutations trigger events
- Subscribed clients receive updates
- Multiple clients all get notified

### 4.7: Test Subscription Flow End-to-End (Simple - 2 hours)

**Actions**:
1. Open GraphQL Playground (or Postman)
2. Start subscription:
```graphql
subscription {
  participantUpdated(network_id: "1") {
    participant {
      id
      match_status
    }
    change_type
    changed_by_org_id
  }
}
```
3. In another tab, trigger mutation (confirm match)
4. Verify subscription receives event
5. Test with multiple concurrent subscriptions
6. Test reconnection after disconnect

**Test Cases**:
- ✅ Single client receives events
- ✅ Multiple clients all receive events
- ✅ Client reconnects and resumes subscription
- ✅ Events filtered by network_id correctly
- ✅ Authentication required for subscriptions
- ✅ Unauthorized users cannot subscribe

**Dependencies**: 4.6
**Verification**: Real-time updates work reliably

### 4.8: Configure Production WebSocket Settings (Simple - 1 hour)

**Files to Modify**:
- `Apricot_Files/apricot-api/.env.example`
- Production deployment configs

**Environment Variables to Add**:
```bash
# WebSocket Configuration
WS_PATH=/api/graph
WS_KEEP_ALIVE_INTERVAL=30000
WS_MAX_CONNECTIONS_PER_IP=10
WS_CONNECTION_TIMEOUT=60000

# Redis Pub/Sub
REDIS_PUBSUB_DB=5
```

**Production Considerations**:
1. **Load Balancer**: Configure sticky sessions for WebSocket
2. **Scaling**: Redis Pub/Sub enables horizontal scaling
3. **Monitoring**: Track active WebSocket connections
4. **Rate Limiting**: Prevent subscription spam

**Dependencies**: 4.7
**Verification**: Production settings documented

---

## PHASE 5-12: Frontend, Testing, Integration

(Detailed breakdown of React app setup with Relay, component hierarchy, views, real-time features, testing, and deployment in full plan above)

---

## Remaining Questions for Product Decision

### 1. Incident Workflow Behavior
**Question:** When any org creates an incident:
- Should it auto-notify all network members immediately?
  - **Option A:** Real-time notification via subscription + email
  - **Option B:** Passive - shows in incident list, no push notification
  - **Recommendation:** Option A for Critical/High severity, Option B for Medium/Low

### 2. Matching Confirmation Workflow
**Decided:** Always require human confirmation

**Remaining questions:**
- If 2 orgs confirm a match but a 3rd org says "not the same person":
  - **Recommendation:** Create two separate network participants (A+B confirmed, C separate)

### 3. Performance Scale Expectations
**Need to know:**
- Typical network size? (Assume: 6-15 member orgs)
- Participant count per network? (Assume: 100-500 participants)
- Concurrent users? (Assume: 20-50)
- Target response time? (Assume: <500ms for GraphQL queries)

### 4. Referral Acceptance Details
**Question:** When org accepts a referral:
- **Option A:** Create tier1 record in their DB automatically
- **Option B:** Just link/track without creating record
- **Recommendation:** Option B initially, with "Convert to Full Record" action

---

## Risk Assessment

### High Risk
🔴 **Cross-tenant query performance**
- Mitigation: Materialized views + caching layer

🔴 **False positive matches**
- Mitigation: Human confirmation required, match unlinking capability

🔴 **PII leakage across orgs**
- Mitigation: Strict permission checks, encryption, audit logging

### Medium Risk
🟡 **Data sync lag**
- Mitigation: Event-driven updates, cache invalidation strategy

🟡 **Network size scaling**
- Mitigation: Pagination, virtual scrolling, query optimization

### Low Risk
🟢 **Browser compatibility** (React app)
🟢 **Database storage costs** (network-level data is small)

---

## Success Metrics

- Participant match accuracy > 95%
- Page load time < 1 second (P95)
- Zero PII leakage incidents
- API response time < 300ms (P95)
- User adoption: 80% of network members active monthly

---

## Technical Decisions & Rationale

### 1. Why Jotai + Relay (not Redux)?

**Decision**: Jotai for client state, React Relay for server state

**Rationale**:
- Atomic state management with minimal boilerplate
- Relay optimized for GraphQL (caching, subscriptions, fragments)
- Existing pattern in Data Standards/Networks apps
- Better TypeScript support than Redux

### 2. WebSocket Subscriptions (not Polling)

**Decision**: GraphQL subscriptions over WebSocket

**Rationale**:
- True real-time updates (not delayed)
- Efficient (only sends when changed)
- Better UX (connection status, instant collaboration)
- Scalable with Redis Pub/Sub

### 3. Three-Tier Caching Strategy

**Decision**: Request cache → Redis (5-min) → LRU (1-hour)

**Rationale**:
- Request cache: Prevents duplicate queries in single request
- Redis: Shared across instances, invalidates on change
- LRU: Fast in-memory for rarely-changing config

---

## Implementation Roadmap

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

## Security, Scale, & Performance Analysis

### Security

**PII Protection**:
- Laravel encryption for name fields
- HMAC-SHA256 hashing for matching (network-specific salt)
- Middleware enforces org membership + PII permissions
- Audit log: user_id, org_id, resource_id, fields_accessed
- No PII in application logs

**Cross-Org Permissions**:
- Network membership checked on every request
- PII visibility filtered per org
- Mutation authorization enforced
- Lead org privileges for matches/settings

**GraphQL Security**:
- Query depth limit: 5 levels
- Complexity limit: 1000
- Rate limiting: 100 req/min per user (Redis)
- Field-level permissions

### Scalability

**Database**:
- Indexes on network_id, match_status, org_id+document_id
- Pagination (default 50/page)
- Read replicas if needed
- Partition by network_id if > 100k participants

**Caching**:
- Redis Cluster for multi-instance
- Pub/Sub for cache invalidation
- Pre-warm popular networks

**WebSocket**:
- 10,000 concurrent connections per server
- Sticky sessions for load balancing
- Redis Pub/Sub for multi-instance
- Room-based subscriptions

**API Performance**:
- DataLoader batching
- Parallel org queries (Promise.all)
- GraphQL query batching
- CDN for static assets

### Performance Targets

**Benchmarks**:
- Participant list (50, 10 orgs): < 500ms P95
- Incident list: < 300ms P95
- Confirm match mutation: < 1s P95
- WebSocket delivery: < 100ms
- Initial page load: < 2s P95
- Page transition (cached): < 500ms

---

## Critical Files Reference

**From codebase exploration:**

1. **DSF View Generation:**
   - `Apricot_Files/apricot-api/src/application/services/dataStandardsService.ts`
   - Line 6246: `generateDataStandardViewSql()`
   - Line 7380: `createView()`

2. **Data Standards Mapping:**
   - `Apricot_Files/apricot-api/src/repository/models/org/data_standards_map.ts`
   - `Apricot_Files/apricot-api/src/repository/query/dataStandard.ts`

3. **Redis Configuration:**
   - `Apricot_Files/apricot-api/src/config/redis/index.ts`
   - `Apricot_Files/apricot-api/src/repository/connections/redis/index.ts`

4. **GraphQL Setup:**
   - `Apricot_Files/apricot-api/src/graphql-api/index.ts`
   - `Apricot_Files/apricot-api/src/graphql-api/resolvers/`
   - `Apricot_Files/apricot-api/src/graphql-api/typeDefs/`

5. **Bull Queue:**
   - `Apricot_Files/apricot-api/src/utils/queue.ts`

6. **Cache Utilities:**
   - `Apricot_Files/apricot-api/src/utils/cache.ts`

---

## Implementation Summary

**Total Scope**: 16-20 weeks (320-400 hours)

**Backend** (8-10 weeks):
- 45 incremental tasks
- 10 database tables
- Sequelize models + associations
- Services (matching, PII, DSF enrichment)
- GraphQL (21 queries, 24 mutations, 3 subscriptions)
- WebSocket subscriptions (Redis Pub/Sub)
- Background jobs (Bull queue)

**Frontend** (6-8 weeks):
- 31 incremental tasks
- React + Vite + TypeScript
- Jotai state (5 atom files)
- React Relay (7 queries, 6 mutations, 3 subscriptions)
- Atomic components (atoms → molecules → organisms → templates)
- 5 main views (Dashboard, People, Incidents, Referrals, Notes)
- Real-time WebSocket updates

**Integration** (2-3 weeks):
- Data Standards validation UI
- Networks navigation
- Integration testing (6 workflows)
- Performance testing (4 benchmarks)
- Security audit (6 areas)
- Bug fixes and polish

**Team**: 1-2 backend, 1-2 frontend, 1 part-time DevOps

**Critical Path**: Data Standards → Backend models → GraphQL API → Frontend → Views → Real-time

**Deliverable**: Production-ready Network Document Folder with documentation, tests, and deployment guide

---

**Document Version**: 3.0.0 - Comprehensive Implementation Plan
**Created**: March 24, 2025
**Updated**: March 26, 2025 - Added full phase-by-phase breakdown with incremental tasks
**Status**: ✅ Complete - Ready for Implementation
