-- ============================================================================
-- Network Document Folder - Sample Data (UNIFIED SCHEMA)
-- ============================================================================
-- Purpose: Realistic test data demonstrating various scenarios with unified schema
-- - Shared participant records (confirmed matches, potential matches)
-- - Shared incident records (multi-org responses)
-- - PII sharing variations (field ID-based)
-- - Apricot + Snowflake source examples
-- ============================================================================

-- Test Network: "Portland Metro CVI Collaborative"
-- Network ID: 1
-- Lead Org: 101
-- Member Orgs: 101-106

-- ============================================================================
-- NETWORK MEMBER ORGS (With PII Settings)
-- ============================================================================

INSERT INTO network_member_orgs (
    network_id, org_id, member_type, data_standard_form_id,
    pii_sharing_enabled, pii_fields_shared,
    pii_consent_confirmed_at, pii_consent_confirmed_by,
    active, joined_at
) VALUES
-- Org 101: Lead Org (Apricot, full PII sharing)
(1, 101, 'internal', 201,
 TRUE, '[4721, 4722, 4723, 4724, 4725]', -- name, dob, ssn, address, phone field IDs
 '2025-01-15 10:00:00', 1001, TRUE, '2025-01-15 10:00:00'),

-- Org 102: Violence Prevention Coalition (Apricot, full PII)
(1, 102, 'internal', 202,
 TRUE, '[4721, 4722, 4723, 4724]', -- name, dob, ssn, address
 '2025-01-16 14:30:00', 1002, TRUE, '2025-01-16 14:30:00'),

-- Org 103: Community Outreach (Apricot, partial PII)
(1, 103, 'internal', 203,
 TRUE, '[4721, 4722]', -- name, dob only
 '2025-01-18 11:00:00', 1003, TRUE, '2025-01-18 11:00:00'),

-- Org 104: Youth Services (Apricot, NO PII sharing)
(1, 104, 'internal', 204,
 FALSE, '[]',
 NULL, NULL, TRUE, '2025-01-19 09:00:00'),

-- Org 105: Street Outreach (Snowflake, full PII)
(1, 105, 'external', NULL,
 TRUE, '[4721, 4722, 4724, 4725]', -- name, dob, address, phone
 '2025-01-17 09:00:00', 1005, TRUE, '2025-01-17 09:00:00'),

-- Org 106: Case Management (Apricot, partial PII)
(1, 106, 'internal', 206,
 TRUE, '[4721, 4722, 4725]', -- name, dob, phone
 '2025-01-19 13:45:00', 1006, TRUE, '2025-01-19 13:45:00');

-- Update Org 105 with Snowflake connection details
UPDATE network_member_orgs
SET snowflake_view = 'dsf_205_view',
    snowflake_schema = 'impact_hub',
    snowflake_connection_id = 1
WHERE network_id = 1 AND org_id = 105;

-- ============================================================================
-- SHARED RECORDS: PARTICIPANTS (Confirmed Matches)
-- ============================================================================

-- Participant 1: Marcus Thompson (confirmed across 3 orgs)
INSERT INTO network_shared_records (
    id, network_id, data_standard_id, record_type, status,
    match_confidence_score, metadata, created_by_org_id, created_at
) VALUES (
    1, 1, 10, 'participant', 'confirmed', 95.50,
    JSON_OBJECT(
        'pii_sharing_enabled', TRUE,
        'matching_algorithm_version', '1.0',
        'last_match_run_at', '2025-02-01T10:30:00Z',
        'confirmed_at', '2025-02-01T10:30:00Z',
        'confirmed_by_user_id', 1001
    ),
    101, '2025-01-20 09:00:00'
);

-- Sources for Marcus Thompson
INSERT INTO network_record_sources (
    network_shared_record_id, org_id, tenant_document_id, dsf_id,
    source_type, contributed_at, confirmed_by_org_user_id, metadata
) VALUES
-- Org 101 (Lead) - Apricot source
(1, 101, 5001, 201, 'apricot',
 '2025-01-20 09:00:00', 1001,
 JSON_OBJECT(
     'name_hash', SHA2('marcusthompson', 256),
     'ssn_last4_hash', SHA2('4521', 256),
     'dob_hash', SHA2('1998-03-15', 256),
     'match_score', 100
 )),

-- Org 102 (VPC) - Apricot source (slightly different name)
(1, 102, 3245, 202, 'apricot',
 '2025-01-22 14:00:00', 1002,
 JSON_OBJECT(
     'name_hash', SHA2('marcusathompson', 256),
     'ssn_last4_hash', SHA2('4521', 256),
     'dob_hash', SHA2('1998-03-15', 256),
     'match_score', 95
 )),

-- Org 105 (Street Outreach) - Snowflake source (known as "Marc")
(1, 105, 7821, 205, 'snowflake',
 '2025-01-25 11:30:00', 1005,
 JSON_OBJECT(
     'name_hash', SHA2('marcthompson', 256),
     'dob_hash', SHA2('1998-03-15', 256),
     'match_score', 92
 ));

-- Participant 2: Jasmine Rodriguez (confirmed across 2 orgs)
INSERT INTO network_shared_records (
    id, network_id, data_standard_id, record_type, status,
    match_confidence_score, metadata, created_by_org_id, created_at
) VALUES (
    2, 1, 10, 'participant', 'confirmed', 98.00,
    JSON_OBJECT(
        'matching_algorithm_version', '1.0',
        'confirmed_at', '2025-02-03T15:00:00Z',
        'confirmed_by_user_id', 1001
    ),
    101, '2025-01-21 10:00:00'
);

INSERT INTO network_record_sources (
    network_shared_record_id, org_id, tenant_document_id, dsf_id,
    source_type, contributed_at, confirmed_by_org_user_id, metadata
) VALUES
(2, 101, 5002, 201, 'apricot',
 '2025-01-21 10:00:00', 1001,
 JSON_OBJECT(
     'name_hash', SHA2('jasminerodriguez', 256),
     'ssn_last4_hash', SHA2('7834', 256),
     'dob_hash', SHA2('2001-07-22', 256),
     'match_score', 100
 )),
(2, 103, 4567, 203, 'apricot',
 '2025-01-23 16:00:00', 1003,
 JSON_OBJECT(
     'name_hash', SHA2('jasminerodriguez', 256),
     'ssn_last4_hash', SHA2('7834', 256),
     'dob_hash', SHA2('2001-07-22', 256),
     'match_score', 98
 ));

-- Participant 3: Devon Carter (pending verification - single org)
INSERT INTO network_shared_records (
    id, network_id, data_standard_id, record_type, status,
    match_confidence_score, metadata, created_by_org_id, created_at
) VALUES (
    3, 1, 10, 'participant', 'pending', NULL,
    JSON_OBJECT('matching_algorithm_version', '1.0'),
    104, '2025-02-05 11:00:00'
);

INSERT INTO network_record_sources (
    network_shared_record_id, org_id, tenant_document_id, dsf_id,
    source_type, contributed_at, metadata
) VALUES
(3, 104, 8901, 204, 'apricot',
 '2025-02-05 11:00:00',
 JSON_OBJECT(
     'name_hash', SHA2('devoncarter', 256),
     'dob_hash', SHA2('2000-11-08', 256)
 ));

-- ============================================================================
-- SHARED RECORDS: POTENTIAL MATCHES (Need Review)
-- ============================================================================

-- Participant 4 & 5: Potential match (different orgs, similar data)
INSERT INTO network_shared_records (
    id, network_id, data_standard_id, record_type, status,
    match_confidence_score, metadata, created_by_org_id, created_at
) VALUES
(4, 1, 10, 'participant', 'pending', 78.00,
 JSON_OBJECT('matching_algorithm_version', '1.0'),
 102, '2025-02-10 09:00:00'),
(5, 1, 10, 'participant', 'pending', NULL,
 JSON_OBJECT('matching_algorithm_version', '1.0'),
 106, '2025-02-11 14:00:00');

INSERT INTO network_record_sources (
    network_shared_record_id, org_id, tenant_document_id, dsf_id,
    source_type, contributed_at, metadata
) VALUES
(4, 102, 3456, 202, 'apricot',
 '2025-02-10 09:00:00',
 JSON_OBJECT(
     'name_hash', SHA2('tyreejohnson', 256),
     'ssn_last4_hash', SHA2('8362', 256),
     'dob_hash', SHA2('1999-05-14', 256)
 )),
(5, 106, 9234, 206, 'apricot',
 '2025-02-11 14:00:00',
 JSON_OBJECT(
     'name_hash', SHA2('tyreejohnsn', 256), -- typo: "johnsn" vs "johnson"
     'ssn_last4_hash', SHA2('8362', 256),
     'dob_hash', SHA2('1999-05-15', 256) -- off by 1 day
 ));

-- Potential match record
INSERT INTO network_participant_potential_matches (
    network_id, shared_record_a_id, shared_record_b_id,
    match_score, match_factors, status, created_at
) VALUES (
    1, 4, 5, 78.00,
    JSON_OBJECT(
        'ssn_last4', 45,
        'dob', 25,
        'name', 18,
        'details', 'SSN match + DOB within 1 day + name similar (possible typo)'
    ),
    'pending_review', '2025-02-11 14:30:00'
);

-- ============================================================================
-- SHARED RECORDS: INCIDENTS
-- ============================================================================

-- Incident 1: Critical shooting incident (multiple orgs responding)
INSERT INTO network_shared_records (
    id, network_id, data_standard_id, record_type, status,
    match_confidence_score, metadata, created_by_org_id, created_at
) VALUES (
    10, 1, 11, 'incident', 'confirmed', NULL,
    JSON_OBJECT(
        'severity', 'critical',
        'incident_type', 'shooting',
        'location', '1234 SE Division St, Portland, OR 97214',
        'occurred_at', '2025-02-20T22:30:00Z',
        'reported_by_org_name', 'Lead Org',
        'description', 'Multiple shots fired near community center. 2 individuals transported to hospital.',
        'tags', JSON_ARRAY('violence', 'firearms', 'hospital'),
        'status', 'active'
    ),
    101, '2025-02-20 23:00:00'
);

-- Link to participants involved
INSERT INTO network_record_sources (
    network_shared_record_id, org_id, tenant_document_id, dsf_id,
    source_type, contributed_at, metadata
) VALUES
-- Lead org's incident record
(10, 101, 6001, 211, 'apricot',
 '2025-02-20 23:00:00',
 JSON_OBJECT(
     'linked_participants', JSON_ARRAY(1, 3), -- Marcus Thompson, Devon Carter
     'incident_tier1_document_id', 6001
 ));

-- Org responses to incident 1
INSERT INTO network_record_responses (
    network_shared_record_id, org_id, response_type, response_data,
    created_by_user_id, created_at
) VALUES
-- Lead org response
(10, 101, 'incident_responded',
 JSON_OBJECT(
     'status', 'in_progress',
     'planned_actions', JSON_ARRAY('Contact families', 'Coordinate with hospital', 'Schedule community meeting'),
     'current_actions', JSON_ARRAY('Contacted families', 'Hospital coordination ongoing'),
     'completed_actions', JSON_ARRAY(),
     'local_incident_document_id', 6001
 ),
 1001, '2025-02-20 23:15:00'),

-- Violence Prevention Coalition response
(10, 102, 'incident_responded',
 JSON_OBJECT(
     'status', 'in_progress',
     'planned_actions', JSON_ARRAY('Deploy street outreach team', 'Assess retaliation risk', 'Offer counseling'),
     'current_actions', JSON_ARRAY('Street team deployed'),
     'completed_actions', JSON_ARRAY('Initial assessment complete'),
     'local_incident_document_id', 3500
 ),
 1002, '2025-02-21 08:00:00'),

-- Street Outreach Team response (Snowflake org)
(10, 105, 'incident_responded',
 JSON_OBJECT(
     'status', 'in_progress',
     'planned_actions', JSON_ARRAY('24-hour presence', 'Connect victims to services'),
     'current_actions', JSON_ARRAY('On-site presence maintained'),
     'completed_actions', JSON_ARRAY()
 ),
 1005, '2025-02-21 01:00:00'),

-- Youth Services - imported but not yet responded
(10, 104, 'imported_to_tenant',
 JSON_OBJECT('local_document_id', 8902),
 1004, '2025-02-21 09:00:00');

-- Incident 2: Medium priority community conflict
INSERT INTO network_shared_records (
    id, network_id, data_standard_id, record_type, status,
    match_confidence_score, metadata, created_by_org_id, created_at
) VALUES (
    11, 1, 11, 'incident', 'confirmed', NULL,
    JSON_OBJECT(
        'severity', 'medium',
        'incident_type', 'conflict',
        'location', 'Community Park, Portland, OR',
        'occurred_at', '2025-02-15T16:00:00Z',
        'reported_by_org_name', 'Community Outreach Partners',
        'description', 'Verbal altercation between two groups. Mediation attempted.',
        'tags', JSON_ARRAY('conflict', 'mediation'),
        'status', 'monitoring'
    ),
    103, '2025-02-15 18:00:00'
);

INSERT INTO network_record_sources (
    network_shared_record_id, org_id, tenant_document_id, dsf_id,
    source_type, contributed_at, metadata
) VALUES
(11, 103, 4580, 213, 'apricot',
 '2025-02-15 18:00:00',
 JSON_OBJECT(
     'linked_participants', JSON_ARRAY(2), -- Jasmine Rodriguez involved
     'incident_tier1_document_id', 4580
 ));

-- Response to incident 2
INSERT INTO network_record_responses (
    network_shared_record_id, org_id, response_type, response_data,
    created_by_user_id, created_at
) VALUES
(11, 103, 'incident_responded',
 JSON_OBJECT(
     'status', 'complete',
     'planned_actions', JSON_ARRAY('Mediate conflict', 'Follow-up meetings'),
     'current_actions', JSON_ARRAY(),
     'completed_actions', JSON_ARRAY('Mediation session held', '2 follow-up meetings completed', 'Conflict resolved')
 ),
 1003, '2025-02-22 14:00:00');

-- ============================================================================
-- NETWORK NOTES
-- ============================================================================

INSERT INTO network_notes (
    network_id, network_shared_record_id, author_org_id, author_user_id,
    content, note_type, created_at
) VALUES
-- Note on Marcus Thompson
(1, 1, 101, 1001,
 'Marcus has been consistently attending weekly check-ins. Showing positive progress with job placement program.',
 'update', '2025-02-25 10:00:00'),

-- Note on shooting incident
(1, 10, 102, 1002,
 'URGENT: Street intelligence suggests potential retaliation. Increased patrols needed in SE Division corridor.',
 'alert', '2025-02-21 09:30:00'),

-- General network coordination note
(1, NULL, 105, 1005,
 'Monthly network coordination meeting scheduled for March 1st at 2pm. All orgs please confirm attendance.',
 'coordination', '2025-02-26 14:00:00'),

-- Note on potential match
(1, 4, 106, 1006,
 'Reviewed potential match between Tyree records. Name spelling difference might be data entry error. Recommend confirmation.',
 'general', '2025-02-12 11:00:00');

-- ============================================================================
-- AUDIT LOG EXAMPLES
-- ============================================================================

INSERT INTO network_audit_log (
    network_id, user_id, org_id, action, resource_type, resource_id,
    details, ip_address, created_at
) VALUES
-- PII access
(1, 1001, 101, 'view_pii', 'shared_record', 1,
 JSON_OBJECT('field_ids_accessed', JSON_ARRAY(4721, 4722, 4723)),
 '192.168.1.10', '2025-02-25 10:30:00'),

-- Match confirmation
(1, 1001, 101, 'confirm_match', 'shared_record', 1,
 JSON_OBJECT('source_ids', JSON_ARRAY(1, 2, 3), 'match_score', 95.5),
 '192.168.1.10', '2025-02-01 10:30:00'),

-- Incident shared
(1, 1001, 101, 'share_record', 'shared_record', 10,
 JSON_OBJECT('record_type', 'incident', 'severity', 'critical'),
 '192.168.1.10', '2025-02-20 23:00:00'),

-- Incident imported by another org
(1, 1004, 104, 'import_record', 'shared_record', 10,
 JSON_OBJECT('local_document_id', 8902),
 '192.168.1.14', '2025-02-21 09:00:00'),

-- PII revealed to external org
(1, 1005, 105, 'view_pii', 'shared_record', 1,
 JSON_OBJECT('field_ids_accessed', JSON_ARRAY(4721, 4722), 'source_type', 'snowflake'),
 '192.168.1.15', '2025-02-25 14:00:00');

-- ============================================================================
-- SUMMARY OF TEST DATA
-- ============================================================================

-- Networks: 1
-- Member Orgs: 6 (4 Apricot internal, 1 Snowflake external, 1 no PII sharing)

-- Shared Participant Records: 5
--   - Confirmed matches: 2 (records 1, 2)
--   - Pending verification: 1 (record 3)
--   - Potential matches: 2 (records 4, 5)

-- Shared Incident Records: 2
--   - Critical: 1 (record 10 - active response)
--   - Medium: 1 (record 11 - resolved)

-- Record Sources: 10 (8 Apricot, 2 Snowflake)

-- Org Responses: 5
--   - Incident responses: 4
--   - Imports to tenant: 1

-- Network Notes: 4

-- Audit Log Entries: 5

-- Potential Matches: 1 (needs review)

-- ============================================================================
-- QUERY EXAMPLES FOR TESTING
-- ============================================================================

-- Get all participants in network 1:
-- SELECT * FROM network_shared_records
-- WHERE network_id = 1 AND record_type = 'participant' AND active = TRUE;

-- Get confirmed participants with sources:
-- SELECT nsr.*, nrs.*
-- FROM network_shared_records nsr
-- JOIN network_record_sources nrs ON nsr.id = nrs.network_shared_record_id
-- WHERE nsr.network_id = 1 AND nsr.record_type = 'participant' AND nsr.status = 'confirmed';

-- Get all incidents with response counts:
-- SELECT nsr.id, nsr.metadata, COUNT(nrr.id) as response_count
-- FROM network_shared_records nsr
-- LEFT JOIN network_record_responses nrr ON nsr.id = nrr.network_shared_record_id
-- WHERE nsr.network_id = 1 AND nsr.record_type = 'incident'
-- GROUP BY nsr.id;

-- Get Org 105's PII-filtered view:
-- SELECT nmo.pii_fields_shared
-- FROM network_member_orgs nmo
-- WHERE nmo.network_id = 1 AND nmo.org_id = 105;
-- -- Then filter DSF view data to only include field IDs: [4721, 4722, 4724, 4725]

-- Find potential matches needing review:
-- SELECT * FROM network_participant_potential_matches
-- WHERE network_id = 1 AND status = 'pending_review';
