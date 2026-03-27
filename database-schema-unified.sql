-- ============================================================================
-- Network Document Folder - UNIFIED Database Schema (v2.0)
-- ============================================================================
-- Purpose: Enable cross-organizational collaboration on ANY data standard type
--          (participants, incidents, veterans, families, etc.)
--
-- Key Architectural Decisions (March 27, 2025):
-- 1. UNIFIED TABLE DESIGN: Single table for all shared record types
-- 2. JSONB METADATA: Type-specific data stored flexibly (no schema migrations)
-- 3. DUAL SOURCE SUPPORT: Both Apricot (tenant DBs) and Snowflake (Impact Hub)
-- 4. FIELD ID-BASED PII: Filter by field IDs from data_standards table
-- 5. SCALABILITY: Designed for 10K+ records/network × 200+ networks = ~2M records
-- 6. REFERRALS REMOVED: Separate microservice (not in this feature scope)
-- ============================================================================

-- ============================================================================
-- CORE: UNIFIED SHARED RECORDS TABLE
-- ============================================================================

-- Single table for ALL shared record types (participants, incidents, future types)
-- Replaces: network_participants, network_incidents, network_veterans (future)
CREATE TABLE network_shared_records (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Network & Type
    network_id BIGINT UNSIGNED NOT NULL,
    data_standard_id BIGINT UNSIGNED NOT NULL COMMENT 'Links to global data standard definition',
    record_type ENUM('participant', 'incident') NOT NULL COMMENT 'Extensible: add veteran, family, etc. without migration',

    -- Status & Confidence
    status ENUM('pending', 'confirmed', 'rejected') NOT NULL DEFAULT 'pending',
    match_confidence_score DECIMAL(5,2) NULL COMMENT 'For participant matching: 0-100 score',

    -- Type-Specific Flexible Data (JSONB approach)
    -- Examples:
    --   Participant: {"pii_sharing_enabled": true, "pii_fields_shared": [4721, 4722], "matching_algorithm_version": "1.0"}
    --   Incident: {"severity": "high", "incident_type": "safety_concern", "location": "Portland, OR", "occurred_at": "2025-03-26T15:00:00Z"}
    --   Veteran (future): {"branch": "Army", "service_years": "2010-2018", "discharge_type": "honorable"}
    metadata JSON NOT NULL COMMENT 'Type-specific data stored flexibly',

    -- Tracking
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by_org_id BIGINT UNSIGNED NOT NULL,

    -- Soft Delete
    active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Indexes for common queries
    INDEX idx_network_type_status (network_id, record_type, status, active),
    INDEX idx_created_desc (created_at DESC),
    INDEX idx_type_status (record_type, status),
    INDEX idx_confidence_score (match_confidence_score DESC),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (data_standard_id) REFERENCES data_standards(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Unified table for all shared record types. Add new types via ENUM + metadata structure.';

-- ============================================================================
-- CORE: RECORD SOURCES (Links tenant records to shared records)
-- ============================================================================

-- Links individual org tenant records (Apricot OR Snowflake) to network shared records
-- Replaces: network_participant_sources, network_incident_sources (implied)
CREATE TABLE network_record_sources (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Links to shared record
    network_shared_record_id BIGINT UNSIGNED NOT NULL,

    -- Source Organization
    org_id BIGINT UNSIGNED NOT NULL COMMENT 'Organization that contributed this source',
    tenant_document_id BIGINT UNSIGNED NOT NULL COMMENT 'tier1_record_id in source system',
    dsf_id BIGINT UNSIGNED NOT NULL COMMENT 'data_standard_form_id for querying DSF view',

    -- NEW: Source Type (Apricot vs Snowflake)
    source_type ENUM('apricot', 'snowflake') NOT NULL DEFAULT 'apricot',
    source_connection_id BIGINT UNSIGNED NULL COMMENT 'For Snowflake: which connection config to use',

    -- Tracking
    contributed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_by_org_user_id BIGINT UNSIGNED NULL COMMENT 'User who confirmed this source belongs to shared record',

    -- Additional source metadata (matching scores, confirmation details, etc.)
    metadata JSON NULL COMMENT 'Source-specific data like match scores, hashes',

    -- Status
    active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Indexes
    INDEX idx_shared_record (network_shared_record_id, active),
    INDEX idx_org_document (org_id, tenant_document_id),
    INDEX idx_dsf (dsf_id),
    INDEX idx_source_type (source_type),

    -- Prevent duplicate sources
    UNIQUE KEY unique_source (org_id, tenant_document_id, network_shared_record_id),

    FOREIGN KEY (network_shared_record_id) REFERENCES network_shared_records(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Links org tenant records (Apricot or Snowflake) to network shared records';

-- ============================================================================
-- CORE: RECORD RESPONSES (Org responses to shared records)
-- ============================================================================

-- Tracks org responses to ANY shared record type
-- Replaces: network_incident_org_responses, network_participant_confirmations (implied)
-- Handles: match confirmations, incident responses, imports to tenant DB, etc.
CREATE TABLE network_record_responses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- What record is this responding to?
    network_shared_record_id BIGINT UNSIGNED NOT NULL,
    org_id BIGINT UNSIGNED NOT NULL,

    -- Type of response
    response_type ENUM(
        'match_confirmed',           -- Confirmed participant match
        'match_rejected',            -- Rejected participant match
        'incident_responded',        -- Updated incident response status
        'note_added',               -- Added note to record
        'imported_to_tenant',       -- Imported shared record to local tenant DB
        'pii_revealed'              -- Revealed PII (for audit trail)
    ) NOT NULL,

    -- Response-specific data (flexible JSON)
    -- Examples:
    --   match_confirmed: {"source_ids": [123, 456], "confirmed_by_user_id": 789}
    --   incident_responded: {"status": "in_progress", "planned_actions": ["contact family", "schedule meeting"]}
    --   imported_to_tenant: {"local_document_id": 9876, "form_id": 223}
    response_data JSON NOT NULL,

    -- Tracking
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id BIGINT UNSIGNED NOT NULL,

    -- Indexes
    INDEX idx_shared_record_type (network_shared_record_id, response_type),
    INDEX idx_org_created (org_id, created_at DESC),
    INDEX idx_user (created_by_user_id),

    FOREIGN KEY (network_shared_record_id) REFERENCES network_shared_records(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Unified responses to any shared record type';

-- ============================================================================
-- COLLABORATION: NETWORK NOTES
-- ============================================================================

-- Network-level notes (can attach to any shared record)
-- UNCHANGED from old schema (works with unified approach)
CREATE TABLE network_notes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Network context
    network_id BIGINT UNSIGNED NOT NULL,
    network_shared_record_id BIGINT UNSIGNED NULL COMMENT 'Optional: attach note to specific shared record',

    -- Author
    author_org_id BIGINT UNSIGNED NOT NULL,
    author_user_id BIGINT UNSIGNED NOT NULL,

    -- Content
    content TEXT NOT NULL,
    note_type ENUM('general', 'coordination', 'alert', 'update') NOT NULL DEFAULT 'general',

    -- Tracking
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    edited BOOLEAN NOT NULL DEFAULT FALSE,

    -- Status
    active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Indexes
    INDEX idx_network_created (network_id, created_at DESC),
    INDEX idx_shared_record (network_shared_record_id),
    INDEX idx_author_org (author_org_id),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (network_shared_record_id) REFERENCES network_shared_records(id) ON DELETE CASCADE,
    FOREIGN KEY (author_org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- COMPLIANCE: AUDIT LOG
-- ============================================================================

-- Audit log for all network actions (especially PII access)
-- UPDATED to use generic resource_id (works with unified table)
CREATE TABLE network_audit_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Who
    user_id BIGINT UNSIGNED NOT NULL,
    org_id BIGINT UNSIGNED NOT NULL,
    network_id BIGINT UNSIGNED NOT NULL,

    -- What
    action VARCHAR(100) NOT NULL COMMENT 'view_pii, confirm_match, share_record, import_record, etc.',
    resource_type VARCHAR(50) NOT NULL COMMENT 'shared_record, note, settings',
    resource_id BIGINT UNSIGNED NOT NULL COMMENT 'ID of the resource (e.g., network_shared_records.id)',

    -- Details
    details JSON NULL COMMENT 'Action-specific details like PII fields accessed, field IDs',

    -- Request context
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_network_action_created (network_id, action, created_at DESC),
    INDEX idx_resource (resource_type, resource_id),
    INDEX idx_user_created (user_id, created_at DESC),
    INDEX idx_org_created (org_id, created_at DESC),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- ALTERATIONS TO EXISTING TABLES
-- ============================================================================

-- Add standard_type to data_standards table
-- This determines which record types can use this data standard
ALTER TABLE data_standards
ADD COLUMN IF NOT EXISTS standard_type ENUM('general', 'participant', 'incident') NOT NULL DEFAULT 'general'
COMMENT 'Type of data standard - determines network folder features available';

-- Add index for filtering by type
CREATE INDEX IF NOT EXISTS idx_standard_type ON data_standards(standard_type);

-- Add fields_shared to data_standards table (field IDs, not names)
-- This defines which fields can be shared when PII sharing is enabled
ALTER TABLE data_standards
ADD COLUMN IF NOT EXISTS shareable_field_ids JSON NULL
COMMENT 'Array of field IDs that orgs can choose to share (for PII filtering): [4721, 4722, 4723]';

-- ============================================================================
-- DATA STANDARD VALIDATION RULES (Phase 0)
-- ============================================================================

-- Validation rules for Participant Incident data standards
-- Ensures required fields/structure before allowing network sharing
CREATE TABLE IF NOT EXISTS data_standard_validation_rules (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    data_standard_id BIGINT UNSIGNED NOT NULL,

    -- Rule definition
    rule_type ENUM(
        'required_tier1',
        'required_field',
        'required_field_type',
        'required_link',
        'min_field_count'
    ) NOT NULL,

    -- Rule configuration (JSON)
    rule_config JSON NOT NULL COMMENT '{"tier1_type": "participant", "required_fields": ["name", "dob"]}',

    -- Human-readable
    rule_description TEXT NULL,
    error_message TEXT NOT NULL,

    -- Status
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_data_standard (data_standard_id, active),

    FOREIGN KEY (data_standard_id) REFERENCES data_standards(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- NETWORK MEMBER ORGANIZATIONS
-- ============================================================================

-- Tracks which orgs are members of which networks
-- Supports internal (Apricot DSF) and external (Snowflake) members
CREATE TABLE IF NOT EXISTS network_member_orgs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,

    -- Organization
    org_id BIGINT UNSIGNED NOT NULL COMMENT 'Apricot org ID (for auth/permissions)',
    member_type ENUM('internal', 'external') NOT NULL DEFAULT 'internal',

    -- Internal member config (Apricot)
    data_standard_form_id BIGINT UNSIGNED NULL COMMENT 'DSF view for internal members',

    -- External member config (Snowflake/Impact Hub)
    snowflake_view VARCHAR(255) NULL COMMENT 'Snowflake view name for external members',
    snowflake_schema VARCHAR(255) NULL DEFAULT 'public',
    snowflake_connection_id BIGINT UNSIGNED NULL COMMENT 'Which Snowflake connection to use',

    -- PII Settings (per org, per network)
    pii_sharing_enabled BOOLEAN DEFAULT FALSE,
    pii_fields_shared JSON NULL COMMENT 'Array of FIELD IDs this org shares: [4721, 4722, 4723]',
    pii_consent_confirmed_at TIMESTAMP NULL,
    pii_consent_confirmed_by BIGINT UNSIGNED NULL,

    -- Status
    active BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP NULL,

    -- Indexes
    INDEX idx_network_active (network_id, active),
    INDEX idx_network_type (network_id, member_type),
    INDEX idx_org (org_id),

    UNIQUE KEY unique_network_org (network_id, org_id),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (data_standard_form_id) REFERENCES data_standard_forms(id) ON DELETE SET NULL,

    -- Constraint: Ensure proper config based on member type
    CONSTRAINT chk_member_config CHECK (
        (member_type = 'internal' AND data_standard_form_id IS NOT NULL) OR
        (member_type = 'external' AND snowflake_view IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Phase 1: internal only. Phase 2: add external (Snowflake query).';

-- ============================================================================
-- MATCHING ALGORITHM SUPPORT (Participant type only)
-- ============================================================================

-- Potential matches that need review (only for record_type='participant')
CREATE TABLE IF NOT EXISTS network_participant_potential_matches (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,

    -- The two shared records that might be the same person
    shared_record_a_id BIGINT UNSIGNED NOT NULL,
    shared_record_b_id BIGINT UNSIGNED NOT NULL,

    -- Match confidence
    match_score DECIMAL(5,2) NOT NULL COMMENT '0-100 from matching algorithm',
    match_factors JSON NOT NULL COMMENT 'Which fields contributed: {"ssn": 45, "dob": 35, "name": 20}',

    -- Review status
    status ENUM('pending_review', 'confirmed', 'rejected', 'needs_more_info') NOT NULL DEFAULT 'pending_review',
    reviewed_by_user_id BIGINT UNSIGNED NULL,
    reviewed_at TIMESTAMP NULL,
    review_notes TEXT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_network_status (network_id, status),
    INDEX idx_shared_records (shared_record_a_id, shared_record_b_id),
    INDEX idx_score_desc (match_score DESC),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (shared_record_a_id) REFERENCES network_shared_records(id) ON DELETE CASCADE,
    FOREIGN KEY (shared_record_b_id) REFERENCES network_shared_records(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Potential participant matches requiring human review';

-- ============================================================================
-- SUMMARY OF SCHEMA CHANGES (Old vs New)
-- ============================================================================

-- OLD SCHEMA (10 tables):
-- ❌ network_participants
-- ❌ network_participant_sources
-- ❌ network_participant_potential_matches (kept, but references shared_records)
-- ❌ network_incidents
-- ❌ network_incident_org_responses
-- ❌ network_incident_participants
-- ❌ network_referrals (REMOVED - separate microservice)
-- ✅ network_notes (unchanged, but references shared_records)
-- ✅ network_pii_settings (merged into network_member_orgs)
-- ✅ network_audit_log (unchanged, but uses generic resource_id)

-- NEW SCHEMA (5 core tables):
-- 1. network_shared_records (unified for all types)
-- 2. network_record_sources (unified sources, Apricot + Snowflake)
-- 3. network_record_responses (unified responses)
-- 4. network_notes (unchanged)
-- 5. network_audit_log (unchanged)

-- Supporting tables:
-- 6. network_member_orgs (includes PII settings)
-- 7. network_participant_potential_matches (participant-specific)
-- 8. data_standard_validation_rules (Phase 0)

-- ============================================================================
-- METADATA JSON EXAMPLES
-- ============================================================================

-- Participant Record (record_type='participant'):
-- {
--   "pii_sharing_enabled": true,
--   "pii_fields_shared": [4721, 4722, 4723],
--   "pii_consent_confirmed_at": "2025-03-27T10:00:00Z",
--   "pii_consent_by_user_id": 456,
--   "matching_algorithm_version": "1.0",
--   "last_match_run_at": "2025-03-27T12:00:00Z"
-- }

-- Incident Record (record_type='incident'):
-- {
--   "severity": "high",
--   "incident_type": "safety_concern",
--   "location": "Portland, OR",
--   "occurred_at": "2025-03-26T15:00:00Z",
--   "tags": ["housing", "mental_health"],
--   "reported_by_org_name": "Youth Org A",
--   "description": "Detailed incident description",
--   "status": "active"
-- }

-- Veteran Record (FUTURE - record_type='veteran'):
-- {
--   "branch": "Army",
--   "service_years": "2010-2018",
--   "discharge_type": "honorable",
--   "va_eligible": true,
--   "pii_fields_shared": [4800, 4801, 4802]
-- }

-- ============================================================================
-- PERFORMANCE NOTES
-- ============================================================================

-- Query Pattern: Get all participants in a network
-- SELECT * FROM network_shared_records
-- WHERE network_id = ? AND record_type = 'participant' AND status = 'confirmed'
-- ORDER BY created_at DESC
-- LIMIT 50;
-- Expected: <500ms at 10K records/network

-- Cache Keys:
-- network:{networkId}:records:{recordType}:{status}
-- network:{networkId}:record:{recordId}
-- network:{networkId}:org:{orgId}:pii_config

-- Cache TTL:
-- - Aggregated data: 5 minutes (300s)
-- - PII config: 1 hour (3600s)
-- - Individual records: 10 minutes (600s)

-- Indexes support:
-- - List view: idx_network_type_status
-- - Detail view: PRIMARY KEY
-- - Sorting: idx_created_desc
-- - Matching: idx_confidence_score

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================

-- PII Filtering:
-- 1. Check requesting org's permissions in network_member_orgs.pii_fields_shared
-- 2. Filter DSF view data to only include allowed field IDs
-- 3. Log all PII access in network_audit_log with field IDs in details JSON

-- Permission Checks:
-- 1. Network access: User has "Network Document Folder - Advanced Access" permission
-- 2. Own org records: User has Apricot record-level permission to tenant_document_id
-- 3. Other org records: Only network access needed (PII filtered)

-- Audit Trail:
-- - Every PII reveal logged with field IDs
-- - Every match confirmation logged
-- - Every record share logged
-- - Retention: 7 years (compliance requirement)

-- ============================================================================
-- MIGRATION FROM OLD SCHEMA (If needed)
-- ============================================================================

-- Step 1: Migrate participants to shared_records
-- INSERT INTO network_shared_records (network_id, data_standard_id, record_type, status, match_confidence_score, metadata, created_by_org_id)
-- SELECT network_id, data_standard_id, 'participant', match_status, match_confidence_score,
--        JSON_OBJECT('matching_algorithm_version', '1.0'), created_by_org_id
-- FROM network_participants;

-- Step 2: Migrate participant sources to record_sources
-- INSERT INTO network_record_sources (network_shared_record_id, org_id, tenant_document_id, dsf_id, source_type, contributed_at)
-- SELECT nsr.id, nps.org_id, nps.document_id, nps.dsf_id, 'apricot', nps.contributed_at
-- FROM network_participant_sources nps
-- JOIN network_shared_records nsr ON (...);

-- Step 3: Migrate incidents to shared_records
-- (Similar pattern)

-- Step 4: Migrate incident responses to record_responses
-- (Convert to response_type + response_data JSON)

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
