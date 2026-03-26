-- ============================================================================
-- Network Document Folder - Database Schema
-- ============================================================================
-- Purpose: Enable cross-tenant collaboration on participant records and
--          incident data across organizational boundaries in CVI networks
--
-- Key Design Decisions:
-- 1. Network-level tables store ONLY network-specific data (matches, incidents)
-- 2. Source participant data remains in tenant DBs via DSF views (auto-syncing)
-- 3. PII visibility controlled per-org, per-network with audit trail
-- 4. Real-time updates via Redis pub/sub + GraphQL subscriptions
-- ============================================================================

-- ============================================================================
-- CORE NETWORK PARTICIPANTS
-- ============================================================================

-- Network participants represent deduplicated people across multiple orgs
-- Each participant aggregates multiple source records from different tenant DBs
CREATE TABLE network_participants (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,

    -- Match status tracking
    match_status ENUM('confirmed', 'potential_match', 'pending_verification') NOT NULL DEFAULT 'pending_verification',
    match_confidence_score DECIMAL(5,2) NULL COMMENT 'Score 0-100 from matching algorithm',

    -- Metadata
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP NULL COMMENT 'When match was confirmed by network admin',
    confirmed_by_user_id BIGINT UNSIGNED NULL,

    -- Soft delete support
    active BOOLEAN NOT NULL DEFAULT TRUE,

    INDEX idx_network_status (network_id, match_status, active),
    INDEX idx_network_confidence (network_id, match_confidence_score DESC),
    INDEX idx_created_at (created_at),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Links individual org records (from DSF views) to network participants
-- This is the JOIN table between network participants and tenant data
CREATE TABLE network_participant_sources (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_participant_id BIGINT UNSIGNED NOT NULL,

    -- Reference to source tenant data
    org_id BIGINT UNSIGNED NOT NULL COMMENT 'Tenant organization ID',
    document_id BIGINT UNSIGNED NOT NULL COMMENT 'tier1_record_id in tenant DB',
    dsf_id BIGINT UNSIGNED NOT NULL COMMENT 'data_standard_form_id',
    form_id INT UNSIGNED NOT NULL COMMENT 'Source form ID in tenant',

    -- Hashed PII for matching (privacy-preserving)
    name_hash VARCHAR(64) NULL COMMENT 'SHA256 hash of normalized name',
    ssn_last4_hash VARCHAR(64) NULL COMMENT 'SHA256 hash of SSN last 4',
    dob_hash VARCHAR(64) NULL COMMENT 'SHA256 hash of DOB',

    -- Encrypted PII (only decrypted for authorized orgs)
    name_encrypted TEXT NULL COMMENT 'Laravel encrypted full name',
    ssn_last4_encrypted VARCHAR(255) NULL,
    dob_encrypted VARCHAR(255) NULL,

    -- Tracking
    contributed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_by_org_user_id BIGINT UNSIGNED NULL COMMENT 'User from this org who confirmed match',

    -- Status
    active BOOLEAN NOT NULL DEFAULT TRUE,

    INDEX idx_network_participant (network_participant_id),
    INDEX idx_org_document (org_id, document_id),
    INDEX idx_dsf (dsf_id),

    -- Matching indexes (for fast hash lookups)
    INDEX idx_ssn_dob_hash (ssn_last4_hash, dob_hash),
    INDEX idx_name_dob_hash (name_hash, dob_hash),

    UNIQUE KEY unique_source (org_id, document_id, network_participant_id),

    FOREIGN KEY (network_participant_id) REFERENCES network_participants(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- NETWORK INCIDENTS
-- ============================================================================

-- Incidents that affect the network (shootings, conflicts, etc.)
-- Can be linked to participants and tracked by multiple orgs
CREATE TABLE network_incidents (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,

    -- Incident details
    incident_type VARCHAR(100) NOT NULL COMMENT 'shooting, assault, conflict, retaliation, etc.',
    severity ENUM('critical', 'high', 'medium', 'low') NOT NULL,
    status ENUM('active', 'monitoring', 'resolved', 'closed') NOT NULL DEFAULT 'active',

    -- Location & timing
    location TEXT NULL COMMENT 'Address or general area',
    location_lat DECIMAL(10, 8) NULL,
    location_lng DECIMAL(11, 8) NULL,
    occurred_at TIMESTAMP NOT NULL,

    -- Reporting
    reported_by_org_id BIGINT UNSIGNED NOT NULL,
    reported_by_user_id BIGINT UNSIGNED NULL,

    -- Content
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    tags JSON NULL COMMENT 'Array of tags for filtering',

    -- Metadata
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_network_date (network_id, occurred_at DESC),
    INDEX idx_network_severity (network_id, severity),
    INDEX idx_network_status (network_id, status),
    INDEX idx_reported_by (reported_by_org_id),
    INDEX idx_occurred_at (occurred_at DESC),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (reported_by_org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Per-org response tracking for incidents
-- Each org in the network can track their own response status
CREATE TABLE network_incident_org_responses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_incident_id BIGINT UNSIGNED NOT NULL,
    org_id BIGINT UNSIGNED NOT NULL,

    -- Response status
    status ENUM('not_started', 'in_progress', 'complete', 'declined') NOT NULL DEFAULT 'not_started',

    -- Action tracking (JSON arrays of strings)
    planned_actions JSON NULL COMMENT 'Actions the org plans to take',
    current_actions JSON NULL COMMENT 'Actions currently in progress',
    completed_actions JSON NULL COMMENT 'Actions that have been completed',

    -- Optional: Link to org's internal incident record
    local_incident_document_id BIGINT UNSIGNED NULL COMMENT 'If imported to org DB',

    -- Tracking
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_updated_by_user_id BIGINT UNSIGNED NULL,

    INDEX idx_incident_org (network_incident_id, org_id),
    INDEX idx_org_status (org_id, status),

    UNIQUE KEY unique_incident_org (network_incident_id, org_id),

    FOREIGN KEY (network_incident_id) REFERENCES network_incidents(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Link participants to incidents (many-to-many)
CREATE TABLE network_incident_participants (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_incident_id BIGINT UNSIGNED NOT NULL,
    network_participant_id BIGINT UNSIGNED NOT NULL,

    -- Role in incident
    role ENUM('victim', 'aggressor', 'witness', 'at_risk', 'other') NULL,
    notes TEXT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_incident (network_incident_id),
    INDEX idx_participant (network_participant_id),

    UNIQUE KEY unique_incident_participant (network_incident_id, network_participant_id),

    FOREIGN KEY (network_incident_id) REFERENCES network_incidents(id) ON DELETE CASCADE,
    FOREIGN KEY (network_participant_id) REFERENCES network_participants(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- COLLABORATION FEATURES
-- ============================================================================

-- Network-level notes (shared across orgs)
CREATE TABLE network_notes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,

    -- Author info
    author_org_id BIGINT UNSIGNED NOT NULL,
    author_user_id BIGINT UNSIGNED NOT NULL,

    -- Content
    content TEXT NOT NULL,
    note_type ENUM('general', 'coordination', 'alert', 'update') NOT NULL DEFAULT 'general',

    -- Optional associations
    related_participant_id BIGINT UNSIGNED NULL,
    related_incident_id BIGINT UNSIGNED NULL,

    -- Metadata
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    edited BOOLEAN NOT NULL DEFAULT FALSE,

    INDEX idx_network (network_id, created_at DESC),
    INDEX idx_participant (related_participant_id),
    INDEX idx_incident (related_incident_id),
    INDEX idx_author_org (author_org_id),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (author_org_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (related_participant_id) REFERENCES network_participants(id) ON DELETE CASCADE,
    FOREIGN KEY (related_incident_id) REFERENCES network_incidents(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cross-org referrals
CREATE TABLE network_referrals (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,
    network_participant_id BIGINT UNSIGNED NOT NULL,

    -- Referral flow
    from_org_id BIGINT UNSIGNED NOT NULL,
    to_org_id BIGINT UNSIGNED NOT NULL,

    -- Referral details
    reason TEXT NOT NULL,
    services_requested TEXT NULL COMMENT 'What services/support is needed',
    urgency ENUM('routine', 'urgent', 'critical') NOT NULL DEFAULT 'routine',

    -- Status tracking
    status ENUM('pending', 'accepted', 'in_progress', 'completed', 'declined') NOT NULL DEFAULT 'pending',

    -- Response
    response_notes TEXT NULL,
    declined_reason TEXT NULL,

    -- Tracking
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,

    -- User tracking
    created_by_user_id BIGINT UNSIGNED NOT NULL,
    accepted_by_user_id BIGINT UNSIGNED NULL,

    INDEX idx_network (network_id),
    INDEX idx_participant (network_participant_id),
    INDEX idx_from_org (from_org_id, status),
    INDEX idx_to_org (to_org_id, status),
    INDEX idx_status (status),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (network_participant_id) REFERENCES network_participants(id) ON DELETE CASCADE,
    FOREIGN KEY (from_org_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (to_org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- PII PRIVACY CONTROLS
-- ============================================================================

-- Per-org PII sharing settings within a network
CREATE TABLE network_pii_settings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,
    org_id BIGINT UNSIGNED NOT NULL,

    -- Global PII sharing toggle
    pii_sharing_enabled BOOLEAN NOT NULL DEFAULT FALSE,

    -- Granular field-level sharing (JSON array of field names)
    -- Example: ["name", "dob", "ssn_last4", "address", "phone"]
    fields_shared JSON NULL COMMENT 'Array of PII field names this org shares',

    -- Consent tracking
    consent_confirmed_at TIMESTAMP NULL,
    consent_confirmed_by_user_id BIGINT UNSIGNED NULL,
    consent_document_url VARCHAR(500) NULL,

    -- Metadata
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_network_org (network_id, org_id),

    UNIQUE KEY unique_network_org (network_id, org_id),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit log for PII access (compliance requirement)
CREATE TABLE network_audit_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Who accessed
    user_id BIGINT UNSIGNED NOT NULL,
    org_id BIGINT UNSIGNED NOT NULL,
    network_id BIGINT UNSIGNED NOT NULL,

    -- What was accessed
    action VARCHAR(100) NOT NULL COMMENT 'view_pii, confirm_match, create_incident, etc.',
    resource_type ENUM('participant', 'incident', 'note', 'referral', 'settings') NOT NULL,
    resource_id BIGINT UNSIGNED NULL,

    -- PII accessed (if applicable)
    pii_fields_accessed JSON NULL COMMENT 'Array of PII field names that were revealed',

    -- Request details
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,

    -- Additional context
    metadata JSON NULL COMMENT 'Additional context about the action',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_network (network_id, created_at DESC),
    INDEX idx_user (user_id, created_at DESC),
    INDEX idx_org (org_id, created_at DESC),
    INDEX idx_resource (resource_type, resource_id),
    INDEX idx_action (action, created_at DESC),

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- MATCHING ALGORITHM SUPPORT
-- ============================================================================

-- Stores potential matches that need review
-- Cleared after confirmation or rejection
CREATE TABLE network_participant_potential_matches (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    network_id BIGINT UNSIGNED NOT NULL,

    -- The two participants that might be the same person
    participant_a_id BIGINT UNSIGNED NOT NULL,
    participant_b_id BIGINT UNSIGNED NOT NULL,

    -- Match confidence
    match_score DECIMAL(5,2) NOT NULL COMMENT 'Score 0-100 from algorithm',

    -- What matched?
    match_factors JSON NOT NULL COMMENT 'Which fields contributed to the match',

    -- Review status
    status ENUM('pending_review', 'confirmed', 'rejected', 'needs_more_info') NOT NULL DEFAULT 'pending_review',
    reviewed_by_user_id BIGINT UNSIGNED NULL,
    reviewed_at TIMESTAMP NULL,
    review_notes TEXT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_network_status (network_id, status),
    INDEX idx_participants (participant_a_id, participant_b_id),
    INDEX idx_score (match_score DESC),

    FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE,
    FOREIGN KEY (participant_a_id) REFERENCES network_participants(id) ON DELETE CASCADE,
    FOREIGN KEY (participant_b_id) REFERENCES network_participants(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- ALTERATIONS TO EXISTING TABLES
-- ============================================================================

-- Add standard_type to data_standards table (if not exists)
-- This categorizes data standards as participant, incident, or other types
ALTER TABLE data_standards
ADD COLUMN standard_type ENUM('participant', 'incident', 'other') NOT NULL DEFAULT 'other'
COMMENT 'Type of data standard - determines network folder features available';

-- Add index for filtering by type
CREATE INDEX idx_standard_type ON data_standards(standard_type);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Network participants with source count
CREATE OR REPLACE VIEW v_network_participants_with_sources AS
SELECT
    np.id,
    np.network_id,
    np.match_status,
    np.match_confidence_score,
    np.created_at,
    COUNT(nps.id) as source_count,
    GROUP_CONCAT(DISTINCT nps.org_id) as org_ids
FROM network_participants np
LEFT JOIN network_participant_sources nps ON np.id = nps.network_participant_id
WHERE np.active = TRUE AND nps.active = TRUE
GROUP BY np.id, np.network_id, np.match_status, np.match_confidence_score, np.created_at;

-- View: Incident summary with participant and org counts
CREATE OR REPLACE VIEW v_network_incidents_summary AS
SELECT
    ni.id,
    ni.network_id,
    ni.incident_type,
    ni.severity,
    ni.status,
    ni.occurred_at,
    ni.reported_by_org_id,
    COUNT(DISTINCT nip.network_participant_id) as participant_count,
    COUNT(DISTINCT nior.org_id) as responding_org_count,
    ni.created_at
FROM network_incidents ni
LEFT JOIN network_incident_participants nip ON ni.id = nip.network_incident_id
LEFT JOIN network_incident_org_responses nior ON ni.id = nior.network_incident_id
GROUP BY ni.id, ni.network_id, ni.incident_type, ni.severity, ni.status,
         ni.occurred_at, ni.reported_by_org_id, ni.created_at;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Additional composite indexes for common query patterns
CREATE INDEX idx_sources_network_org ON network_participant_sources(network_participant_id, org_id);
CREATE INDEX idx_incident_network_severity_date ON network_incidents(network_id, severity, occurred_at DESC);
CREATE INDEX idx_referrals_network_status ON network_referrals(network_id, status, created_at DESC);

-- ============================================================================
-- NOTES
-- ============================================================================

-- Performance Considerations:
-- 1. Cache Keys Pattern: network:{id}:participants:{status}:{matchStatus}
-- 2. Cache TTL: 5 minutes (300 seconds) for aggregated data
-- 3. Cache Invalidation: On any DSF view data change, match confirmation, or incident update
-- 4. Redis Pub/Sub Channels: PARTICIPANT_UPDATED_{network_id}, INCIDENT_UPDATED_{network_id}

-- Security Considerations:
-- 1. All PII fields are encrypted at rest using Laravel encryption
-- 2. PII hashes use HMAC-SHA256 with application-level salt
-- 3. Audit log tracks all PII access with IP and user agent
-- 4. PII visibility enforced at API layer based on network_pii_settings

-- Scalability Notes:
-- 1. Assumes 6-15 orgs per network (typical)
-- 2. Assumes 100-500 participants per network
-- 3. Target query time: <500ms for GraphQL queries
-- 4. DSF views are queried in parallel (not sequentially)
