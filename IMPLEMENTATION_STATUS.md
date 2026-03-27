# Network Document Folder - Implementation Status

**Date**: March 27, 2025
**Status**: Architecture Updated, Ready for Backend Implementation

## What Has Been Completed

### 1. ✅ Architectural Updates (CRITICAL)

**Major Change**: Moved from separate tables per type to **unified schema**

#### Old Approach (10 tables)
- Separate tables: `network_participants`, `network_incidents`, `network_referrals`
- Each type needed its own CRUD operations
- Adding new types required schema migrations

#### New Approach (5 core tables)
- **Unified**: `network_shared_records` (all types in one table)
- **Flexible**: JSONB `metadata` field for type-specific data
- **Future-proof**: Add new types without schema changes
- **Dual-source**: Supports both Apricot (tenant DBs) and Snowflake (Impact Hub)

### 2. ✅ Database Schema

**Files Created**:
- `/database-schema-unified.sql` - NEW unified schema (USE THIS)
- `/sample-data-unified.sql` - Test data for unified schema

**Key Tables**:
1. `network_shared_records` - All shared records (participants, incidents, future types)
2. `network_record_sources` - Links tenant records to shared records (Apricot + Snowflake)
3. `network_record_responses` - Org responses (matches, incident responses, imports)
4. `network_notes` - Network-level notes
5. `network_audit_log` - Compliance audit trail
6. `network_member_orgs` - Org membership + PII settings (field ID-based)
7. `network_participant_potential_matches` - Matching algorithm support
8. `data_standard_validation_rules` - Phase 0 validation

**Scale Targets**:
- 10K+ records per network
- 200+ networks
- ~2M total shared records
- Query time: <500ms (P95)

### 3. ✅ GraphQL API Design

**Files Created**:
- `/api-examples/queries-unified.graphql` - Complete query reference
- `/api-examples/mutations-unified.graphql` - Complete mutation reference
- `/api-examples/subscriptions-unified.graphql` - Real-time subscription examples

**Key Changes**:
- Single `networkSharedRecords` query (replaces separate queries)
- `record_type` filter: 'participant' or 'incident'
- `metadata` JSON field for type-specific data
- Field ID-based PII filtering
- **Referrals removed** (separate microservice)

**Example Query**:
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
        dsf_view_data  # PII filtered by field IDs
      }
    }
  }
}
```

### 4. ✅ Documentation

**Files Updated**:
- Main plan document includes architectural updates section
- Database schema fully documented with comments
- Sample data includes Apricot + Snowflake examples
- GraphQL queries include migration notes

## What Needs To Be Done

### Phase 0: Data Standards Validation (2-3 weeks)

**Blockers**: Must complete before MVP

**Location**: `/Users/patrick.kennedy/Desktop/Apricot_Files/data-standards-react/`

**Tasks**:
1. Add `standard_type` dropdown to BasicInfo component
2. Create validation rules engine
3. Build validation UI component (checklist)
4. Integrate with save mutation
5. Add server-side validation

**Deliverable**: Data standards can be validated as "participant" or "incident" type before sharing to network

---

### Phase 1: Backend - Database & Models (1-2 weeks)

**Tasks**:
1. Run migration: Execute `database-schema-unified.sql`
2. Create Sequelize models:
   - `NetworkSharedRecord` (polymorphic)
   - `NetworkRecordSource`
   - `NetworkRecordResponse`
   - `NetworkNote`
   - `NetworkAuditLog`
   - `NetworkMemberOrg`
   - `NetworkParticipantPotentialMatch`
3. Set up model associations

**Verification**: Can query models, associations work

---

### Phase 2: Backend - Services & Repository (2-3 weeks)

**Key Services**:
1. `NetworkDocumentFolderService` - Main business logic
2. `ParticipantMatchingService` - Matching algorithm
3. `NetworkPIIService` - Field ID-based filtering
4. `SourceConnectorService` - Apricot vs Snowflake queries

**Key Repositories**:
1. `NetworkDocumentFolderQuery` - Raw SQL queries
2. DSF view enrichment (parallel org queries)

**Verification**: Can fetch shared records, PII filtered correctly

---

### Phase 3: Backend - GraphQL API (2-3 weeks)

**TypeDefs**:
- `networkSharedRecords.ts` - Unified types

**Resolvers**:
- `networkSharedRecords.ts` - Query resolvers
- `networkSharedRecordsMutations.ts` - Mutation resolvers

**Mutations**:
- `shareRecordToNetwork` - Share tier1 record to network
- `confirmMatch` - Confirm participant match
- `respondToIncident` - Update org response
- `importToTenantDB` - Import shared record to local DB

**Verification**: GraphQL Playground queries work, permissions enforced

---

### Phase 4: Backend - Real-Time (1-2 weeks)

**Tasks**:
1. Install WebSocket dependencies
2. Create WebSocket server
3. Add GraphQL subscriptions
4. Integrate Redis Pub/Sub

**Subscriptions**:
- `recordUpdated` - Real-time updates for any record type

**Verification**: WebSocket connections stable, events delivered

---

### Phase 5-10: Frontend (6-8 weeks)

**Setup** (Phase 5):
- Create React app with Vite
- Configure Relay
- Set up folder structure

**State Management** (Phase 6):
- Jotai atoms for network, records, UI state

**GraphQL** (Phase 7):
- Relay queries, mutations, subscriptions

**Components** (Phase 8):
- Atomic design: atoms → molecules → organisms → templates

**Views** (Phase 9):
- Dashboard, People, Incidents, Notes

**Real-Time** (Phase 10):
- WebSocket subscription hooks
- Optimistic updates

---

### Phase 11: Data Standards Integration (1 week)

**Tasks**:
1. Complete Phase 0 validation UI
2. Add "Open Network Document Folder" button in Networks React app

---

### Phase 12: Integration & Testing (2-3 weeks)

**Tasks**:
1. End-to-end testing (6 workflows)
2. Performance testing (benchmarks)
3. Security audit (PII, permissions)
4. Bug fixes and polish

---

## Critical Decisions Made

### 1. Unified Schema
**Decision**: Single table for all record types
**Rationale**: Extensible without migrations, simpler codebase, proven at scale

### 2. Field ID-Based PII
**Decision**: Filter by field IDs from data_standards, not field names
**Rationale**: Works across orgs with different field configurations

### 3. Dual Source Support
**Decision**: `source_type` enum ('apricot' or 'snowflake')
**Rationale**: Phase 1 internal-only, Phase 2 adds external orgs

### 4. Referrals Removed
**Decision**: Separate microservice, not in Network Document Folder
**Rationale**: Different access patterns, scaling needs

### 5. Metadata JSON
**Decision**: Use JSONB for type-specific data
**Rationale**: Flexibility without losing relational benefits

---

## Key Files Reference

### Database
- ✅ `database-schema-unified.sql` - Unified schema (all record types)
- ✅ `sample-data-unified.sql` - Test data with Apricot + Snowflake examples
- ~~Old files removed: database-schema.sql, sample-data.sql~~

### API (All Unified)
- ✅ `api-examples/queries-unified.graphql` - Complete query reference
- ✅ `api-examples/mutations-unified.graphql` - Complete mutation reference
- ✅ `api-examples/subscriptions-unified.graphql` - Real-time subscriptions
- ~~Old files removed: queries.graphql, mutations.graphql, subscriptions.graphql~~

### Documentation
- ✅ `/docs/ARCHITECTURE.md` - Existing architecture doc
- ✅ `/QUICK_START.md` - Quick reference
- ✅ `/README.md` - Project overview

### Demo
- ✅ `/index.html` - HTML demo (uses old schema concepts, still useful for UX)
- ✅ `/_includes/network-folder-demo.html` - Full demo HTML
- ✅ `/_includes/matching-demo.js` - Scenario-based simulation
- ✅ `/_includes/styles.css` - Standalone styles

---

## Next Steps (Priority Order)

### Immediate (This Week)
1. **Review & Approve Architecture**: Confirm unified schema approach with team
2. **Run Database Migration**: Execute `database-schema-unified.sql` on dev DB
3. **Start Phase 0**: Begin Data Standards validation UI

### Short-Term (Next 2-4 Weeks)
1. Complete Phase 0 (validation UI)
2. Create Sequelize models (Phase 1)
3. Build core services (Phase 2)

### Medium-Term (Next 2-3 Months)
1. GraphQL API implementation (Phase 3)
2. WebSocket subscriptions (Phase 4)
3. React frontend setup (Phase 5)

### Long-Term (3-6 Months)
1. Frontend components and views (Phases 6-10)
2. Integration with Data Standards/Networks apps (Phase 11)
3. End-to-end testing and launch (Phase 12)

---

## Resources Needed

### Team
- 1-2 Backend Engineers (Node.js, GraphQL, PostgreSQL)
- 1-2 Frontend Engineers (React, TypeScript, Relay)
- 1 DevOps Engineer (part-time, for WebSocket infrastructure)

### Timeline
- **MVP (Internal only)**: 12-16 weeks
- **Full Feature (External orgs)**: 16-20 weeks

### External Dependencies
- Snowflake access for Phase 2 (external org support)
- ZF1 embedding patterns (for React app integration)

---

## Questions for Leadership

1. **Approve unified schema approach?** (replaces separate tables)
2. **Prioritize Phase 0 (validation)?** (blocks MVP)
3. **MVP timeline?** When is internal-only version needed?
4. **External orgs in MVP?** Or Phase 2 after internal launch?
5. **Team allocation?** 1+1 or 2+2 engineers?

---

## Risk Mitigation

### High Risk
- **Multi-tenant query performance**: Mitigate with caching, parallel queries
- **False positive matches**: Mitigate with human confirmation, unlinking
- **PII leakage**: Mitigate with strict permissions, audit trail, encryption

### Medium Risk
- **Data sync lag**: Mitigate with event-driven updates, cache invalidation
- **Network size scaling**: Mitigate with pagination, virtual scrolling

### Low Risk
- **Browser compatibility**: React supports all modern browsers
- **Storage costs**: Network-level data is small (~5-10 GB for 2M records)

---

## Success Metrics

- Participant match accuracy > 95%
- Page load time < 1 second (P95)
- Zero PII leakage incidents
- API response time < 300ms (P95)
- User adoption: 80% of network members active monthly

---

## Contact

For questions or clarifications:
- Architecture: See `/docs/ARCHITECTURE.md`
- Queries: See `/api-examples/queries-unified.graphql`
- Schema: See `/database-schema-unified.sql`
- Plan: See main implementation plan document

---

**Status**: Ready to proceed with Phase 0 (Data Standards validation) and Phase 1 (Backend database setup).
