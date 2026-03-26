-- ============================================================================
-- Network Document Folder - Sample Data
-- ============================================================================
-- Purpose: Realistic test data demonstrating various scenarios:
-- - Confirmed matches (same person, multiple orgs)
-- - Potential matches (need review)
-- - Unmatched participants (unique to one org)
-- - Multi-org incident responses
-- - PII sharing variations
-- - Cross-org referrals
-- ============================================================================

-- Assumptions:
-- - Network ID: 1 (existing "Chicago West Side CVI Network")
-- - 6 member orgs (IDs: 101-106)
-- - Organizations:
--   * 101: Lead Org (full PII sharing)
--   * 102: Violence Prevention Coalition (full PII)
--   * 103: Community Outreach Partners (partial PII)
--   * 104: Youth Services Network (no PII sharing)
--   * 105: Street Outreach Team (full PII)
--   * 106: Case Management Services (partial PII)

-- ============================================================================
-- NETWORK PII SETTINGS
-- ============================================================================

-- Configure PII sharing for each org in the network
INSERT INTO network_pii_settings (network_id, org_id, pii_sharing_enabled, fields_shared, consent_confirmed_at, consent_confirmed_by_user_id) VALUES
-- Lead org - shares all PII
(1, 101, TRUE, '["name", "dob", "ssn_last4", "address", "phone", "email"]', '2025-01-15 10:00:00', 1001),

-- Full sharing orgs
(1, 102, TRUE, '["name", "dob", "ssn_last4", "address", "phone"]', '2025-01-16 14:30:00', 1002),
(1, 105, TRUE, '["name", "dob", "address", "phone"]', '2025-01-17 09:00:00', 1005),

-- Partial sharing orgs
(1, 103, TRUE, '["name", "dob"]', '2025-01-18 11:00:00', 1003),
(1, 106, TRUE, '["name", "dob", "phone"]', '2025-01-19 13:45:00', 1006),

-- No PII sharing
(1, 104, FALSE, '[]', NULL, NULL);

-- ============================================================================
-- NETWORK PARTICIPANTS - CONFIRMED MATCHES
-- ============================================================================

-- Participant 1: Marcus Thompson (confirmed across 3 orgs)
INSERT INTO network_participants (id, network_id, match_status, match_confidence_score, confirmed_at, confirmed_by_user_id, active)
VALUES (1, 1, 'confirmed', 95.50, '2025-02-01 10:30:00', 1001, TRUE);

-- Sources for Marcus Thompson
INSERT INTO network_participant_sources (network_participant_id, org_id, document_id, dsf_id, form_id, name_hash, ssn_last4_hash, dob_hash, name_encrypted, ssn_last4_encrypted, dob_encrypted, contributed_at, confirmed_by_org_user_id)
VALUES
-- Org 101 (Lead)
(1, 101, 5001, 101, 10,
 SHA2('marcusthompson', 256),
 SHA2('4521', 256),
 SHA2('1998-03-15', 256),
 'encrypted:Marcus Thompson',
 'encrypted:4521',
 'encrypted:1998-03-15',
 '2025-01-20 09:00:00', 1001),

-- Org 102 (VPC) - same person, slightly different name format
(1, 102, 3245, 102, 15,
 SHA2('marcusthompson', 256),
 SHA2('4521', 256),
 SHA2('1998-03-15', 256),
 'encrypted:Marcus A. Thompson',
 'encrypted:4521',
 'encrypted:1998-03-15',
 '2025-01-22 14:00:00', 1002),

-- Org 105 (Street Outreach) - knows him as "Marc"
(1, 105, 7821, 105, 22,
 SHA2('marcthompson', 256),
 NULL, -- No SSN
 SHA2('1998-03-15', 256),
 'encrypted:Marc Thompson',
 NULL,
 'encrypted:1998-03-15',
 '2025-01-25 11:30:00', 1005);

-- Participant 2: Jasmine Rodriguez (confirmed across 2 orgs)
INSERT INTO network_participants (id, network_id, match_status, match_confidence_score, confirmed_at, confirmed_by_user_id, active)
VALUES (2, 1, 'confirmed', 98.00, '2025-02-03 15:00:00', 1001, TRUE);

INSERT INTO network_participant_sources (network_participant_id, org_id, document_id, dsf_id, form_id, name_hash, ssn_last4_hash, dob_hash, name_encrypted, ssn_last4_encrypted, dob_encrypted, contributed_at, confirmed_by_org_user_id)
VALUES
(2, 101, 5002, 101, 10,
 SHA2('jasminerodriguez', 256),
 SHA2('7834', 256),
 SHA2('2001-07-22', 256),
 'encrypted:Jasmine Rodriguez',
 'encrypted:7834',
 'encrypted:2001-07-22',
 '2025-01-21 10:00:00', 1001),

(2, 103, 4567, 103, 18,
 SHA2('jasminerodriguez', 256),
 SHA2('7834', 256),
 SHA2('2001-07-22', 256),
 'encrypted:Jasmine M. Rodriguez',
 'encrypted:7834',
 'encrypted:2001-07-22',
 '2025-01-28 09:30:00', 1003);

-- Participant 3: Deandre Williams (confirmed across 4 orgs - high-risk individual)
INSERT INTO network_participants (id, network_id, match_status, match_confidence_score, confirmed_at, confirmed_by_user_id, active)
VALUES (3, 1, 'confirmed', 97.25, '2025-02-05 11:00:00', 1001, TRUE);

INSERT INTO network_participant_sources (network_participant_id, org_id, document_id, dsf_id, form_id, name_hash, ssn_last4_hash, dob_hash, name_encrypted, ssn_last4_encrypted, dob_encrypted, contributed_at, confirmed_by_org_user_id)
VALUES
(3, 101, 5003, 101, 10,
 SHA2('deandrewilliams', 256),
 SHA2('9201', 256),
 SHA2('1999-11-08', 256),
 'encrypted:Deandre Williams',
 'encrypted:9201',
 'encrypted:1999-11-08',
 '2025-01-19 08:00:00', 1001),

(3, 102, 3246, 102, 15,
 SHA2('deandrewilliams', 256),
 SHA2('9201', 256),
 SHA2('1999-11-08', 256),
 'encrypted:DeAndre Williams',
 'encrypted:9201',
 'encrypted:1999-11-08',
 '2025-01-20 13:00:00', 1002),

(3, 105, 7822, 105, 22,
 SHA2('deandrewilliams', 256),
 NULL,
 SHA2('1999-11-08', 256),
 'encrypted:Deandre "Dre" Williams',
 NULL,
 'encrypted:1999-11-08',
 '2025-01-23 16:00:00', 1005),

(3, 106, 9104, 106, 25,
 SHA2('deandrewilliams', 256),
 SHA2('9201', 256),
 SHA2('1999-11-08', 256),
 'encrypted:D. Williams',
 'encrypted:9201',
 'encrypted:1999-11-08',
 '2025-02-01 10:00:00', 1006);

-- ============================================================================
-- NETWORK PARTICIPANTS - POTENTIAL MATCHES (Need Review)
-- ============================================================================

-- Participant 4 & 5: Potentially same person (similar names, close DOB)
INSERT INTO network_participants (id, network_id, match_status, match_confidence_score, confirmed_at, confirmed_by_user_id, active)
VALUES
(4, 1, 'potential_match', 78.50, NULL, NULL, TRUE),
(5, 1, 'potential_match', 78.50, NULL, NULL, TRUE);

INSERT INTO network_participant_sources (network_participant_id, org_id, document_id, dsf_id, form_id, name_hash, ssn_last4_hash, dob_hash, name_encrypted, ssn_last4_encrypted, dob_encrypted, contributed_at)
VALUES
-- Could be "Tyrell" vs "Tyrel" (spelling variation)
(4, 102, 3247, 102, 15,
 SHA2('tyrelljenkins', 256),
 SHA2('5567', 256),
 SHA2('2002-05-14', 256),
 'encrypted:Tyrell Jenkins',
 'encrypted:5567',
 'encrypted:2002-05-14',
 '2025-02-10 09:00:00'),

(5, 105, 7823, 105, 22,
 SHA2('tyreljenkins', 256),
 NULL, -- No SSN
 SHA2('2002-05-15', 256), -- Off by one day (data entry error?)
 'encrypted:Tyrel Jenkins',
 NULL,
 'encrypted:2002-05-15',
 '2025-02-12 14:00:00');

-- Store the potential match for review
INSERT INTO network_participant_potential_matches (network_id, participant_a_id, participant_b_id, match_score, match_factors, status)
VALUES (1, 4, 5, 78.50, '{"name_similarity": 0.95, "dob_close_match": true, "ssn_unavailable": true}', 'pending_review');

-- ============================================================================
-- NETWORK PARTICIPANTS - PENDING VERIFICATION (Newly Added)
-- ============================================================================

-- Participant 6: Just added, needs matching check
INSERT INTO network_participants (id, network_id, match_status, match_confidence_score, active)
VALUES (6, 1, 'pending_verification', NULL, TRUE);

INSERT INTO network_participant_sources (network_participant_id, org_id, document_id, dsf_id, form_id, name_hash, ssn_last4_hash, dob_hash, name_encrypted, ssn_last4_encrypted, dob_encrypted, contributed_at)
VALUES
(6, 103, 4568, 103, 18,
 SHA2('karimahmad', 256),
 SHA2('3421', 256),
 SHA2('2000-09-30', 256),
 'encrypted:Karim Ahmad',
 'encrypted:3421',
 'encrypted:2000-09-30',
 '2025-03-20 10:00:00');

-- ============================================================================
-- NETWORK PARTICIPANTS - UNIQUE (No Matches)
-- ============================================================================

-- Participants 7-10: Unique to single orgs (no duplicates found)
INSERT INTO network_participants (id, network_id, match_status, match_confidence_score, confirmed_at, confirmed_by_user_id, active)
VALUES
(7, 1, 'confirmed', 100.00, '2025-02-15 10:00:00', 1002, TRUE),
(8, 1, 'confirmed', 100.00, '2025-02-16 11:00:00', 1003, TRUE),
(9, 1, 'confirmed', 100.00, '2025-02-18 09:00:00', 1005, TRUE),
(10, 1, 'confirmed', 100.00, '2025-02-20 14:00:00', 1006, TRUE);

INSERT INTO network_participant_sources (network_participant_id, org_id, document_id, dsf_id, form_id, name_hash, ssn_last4_hash, dob_hash, name_encrypted, ssn_last4_encrypted, dob_encrypted, contributed_at)
VALUES
(7, 102, 3248, 102, 15,
 SHA2('alexismorales', 256),
 SHA2('6789', 256),
 SHA2('2003-01-18', 256),
 'encrypted:Alexis Morales',
 'encrypted:6789',
 'encrypted:2003-01-18',
 '2025-02-15 10:00:00'),

(8, 103, 4569, 103, 18,
 SHA2('tanyalee', 256),
 SHA2('4455', 256),
 SHA2('1997-12-05', 256),
 'encrypted:Tanya Lee',
 'encrypted:4455',
 'encrypted:1997-12-05',
 '2025-02-16 11:00:00'),

(9, 105, 7824, 105, 22,
 SHA2('javonbrown', 256),
 NULL,
 SHA2('2001-04-20', 256),
 'encrypted:Javon Brown',
 NULL,
 'encrypted:2001-04-20',
 '2025-02-18 09:00:00'),

(10, 106, 9105, 106, 25,
 SHA2('mariasanchez', 256),
 SHA2('8821', 256),
 SHA2('1999-08-12', 256),
 'encrypted:Maria Sanchez',
 'encrypted:8821',
 'encrypted:1999-08-12',
 '2025-02-20 14:00:00');

-- ============================================================================
-- NETWORK INCIDENTS
-- ============================================================================

-- Incident 1: Critical shooting - multi-org response (Deandre Williams involved)
INSERT INTO network_incidents (id, network_id, incident_type, severity, status, location, occurred_at, reported_by_org_id, reported_by_user_id, title, description, tags)
VALUES (1, 1, 'shooting', 'critical', 'active', '3400 W. Chicago Ave', '2025-03-15 21:30:00', 101, 1001,
        'Shooting on W. Chicago Ave - 1 victim',
        'Drive-by shooting near commercial district. One victim transported to hospital. Witnesses report ongoing gang conflict.',
        '["gang_related", "retaliation", "firearms"]');

-- Link participants to incident
INSERT INTO network_incident_participants (network_incident_id, network_participant_id, role, notes)
VALUES
(1, 3, 'victim', 'Shot in leg, non-life-threatening'),
(1, 1, 'witness', 'Was present at scene, gave statement to police');

-- Org responses to incident 1
INSERT INTO network_incident_org_responses (network_incident_id, org_id, status, planned_actions, current_actions, completed_actions, last_updated_by_user_id)
VALUES
-- Lead org - actively coordinating
(1, 101, 'in_progress',
 '["Hospital outreach", "Family contact", "Conflict mediation", "Coordinate with law enforcement"]',
 '["Hospital outreach", "Family contact"]',
 '["Initial assessment", "Notification to network"]',
 1001),

-- Violence Prevention Coalition - deploying outreach
(1, 102, 'in_progress',
 '["Street outreach to affected areas", "Intelligence gathering", "Mediation offer"]',
 '["Street outreach to affected areas"]',
 '["Team deployed"]',
 1002),

-- Community Outreach Partners - supporting
(1, 103, 'in_progress',
 '["Community meeting", "Peace walk planning"]',
 '[]',
 '["Stakeholder notification"]',
 1003),

-- Youth Services - declined (not their focus area)
(1, 104, 'declined',
 '[]', '[]', '[]', 1004),

-- Street Outreach - active on scene
(1, 105, 'in_progress',
 '["24/7 presence in area", "Intel sharing", "Victim support"]',
 '["24/7 presence in area", "Victim support"]',
 '["Initial scene response"]',
 1005),

-- Case Management - preparing support
(1, 106, 'not_started',
 '["Victim services referral", "Long-term case management"]',
 '[]',
 '[]',
 1006);

-- Incident 2: High-priority assault (Marcus Thompson involved)
INSERT INTO network_incidents (id, network_id, incident_type, severity, status, location, occurred_at, reported_by_org_id, reported_by_user_id, title, description, tags)
VALUES (2, 1, 'assault', 'high', 'monitoring', '2800 W. Madison St', '2025-03-10 18:45:00', 105, 1005,
        'Assault at Madison/Kedzie - Retaliation risk',
        'Physical altercation between two individuals. Risk of retaliation identified.',
        '["assault", "retaliation_risk", "intervention_needed"]');

INSERT INTO network_incident_participants (network_incident_id, network_participant_id, role, notes)
VALUES
(2, 1, 'victim', 'Assaulted, refusing to cooperate with police'),
(2, 7, 'aggressor', 'Identified by witnesses');

INSERT INTO network_incident_org_responses (network_incident_id, org_id, status, planned_actions, current_actions, completed_actions)
VALUES
(2, 101, 'in_progress', '["Risk assessment", "Mediation"]', '["Risk assessment"]', '[]'),
(2, 105, 'in_progress', '["Direct outreach to both parties", "De-escalation"]', '["Direct outreach to both parties"]', '["Initial contact"]'),
(2, 106, 'in_progress', '["Victim services", "Counseling referral"]', '[]', '[]');

-- Incident 3: Medium-priority conflict (community event dispute)
INSERT INTO network_incidents (id, network_id, incident_type, severity, status, location, occurred_at, reported_by_org_id, reported_by_user_id, title, description, tags)
VALUES (3, 1, 'conflict', 'medium', 'resolved', 'Garfield Park Community Center', '2025-03-05 15:00:00', 102, 1002,
        'Verbal altercation at community event',
        'Dispute between two groups at basketball tournament. Resolved without violence.',
        '["conflict", "community_event", "resolved"]');

INSERT INTO network_incident_participants (network_incident_id, network_participant_id, role)
VALUES
(3, 2, 'at_risk'),
(3, 8, 'at_risk');

INSERT INTO network_incident_org_responses (network_incident_id, org_id, status, completed_actions)
VALUES
(2, 102, 'complete', '["On-site mediation", "Follow-up with both groups", "Event security plan"]'),
(3, 103, 'complete', '["Community dialogue session"]');

-- Incident 4: Low-priority monitoring (potential risk)
INSERT INTO network_incidents (id, network_id, incident_type, severity, status, location, occurred_at, reported_by_org_id, reported_by_user_id, title, description, tags)
VALUES (4, 1, 'threat', 'low', 'monitoring', 'Social media', '2025-03-18 12:00:00', 102, 1002,
        'Social media threats detected',
        'Vague threats posted on social media. Monitoring situation.',
        '["social_media", "monitoring", "threat_assessment"]');

INSERT INTO network_incident_org_responses (network_incident_id, org_id, status, planned_actions, current_actions)
VALUES
(4, 101, 'not_started', '["Monitor situation"]', '[]'),
(4, 102, 'in_progress', '["Social media monitoring", "Intelligence gathering"]', '["Social media monitoring"]');

-- Incident 5: Recent critical incident (just reported today)
INSERT INTO network_incidents (id, network_id, incident_type, severity, status, location, occurred_at, reported_by_org_id, reported_by_user_id, title, description, tags)
VALUES (5, 1, 'shooting', 'critical', 'active', '4100 W. Lake St', '2025-03-24 02:15:00', 105, 1005,
        'Early morning shooting - Lake St',
        'Shooting just occurred. Multiple shots fired. Victim status unknown. Area extremely volatile.',
        '["shooting", "active", "high_priority"]');

INSERT INTO network_incident_participants (network_incident_id, network_participant_id, role, notes)
VALUES
(5, 3, 'at_risk', 'Known associate of suspected target'),
(5, 9, 'witness', 'Called 911');

-- Initial org responses (just started)
INSERT INTO network_incident_org_responses (network_incident_id, org_id, status, planned_actions, current_actions)
VALUES
(5, 101, 'in_progress', '["Emergency response coordination", "Hospital outreach"]', '["Emergency response coordination"]'),
(5, 105, 'in_progress', '["Team en route to scene", "Area canvassing"]', '["Team en route to scene"]');

-- ============================================================================
-- NETWORK NOTES
-- ============================================================================

-- Notes about participants
INSERT INTO network_notes (network_id, author_org_id, author_user_id, content, note_type, related_participant_id, created_at)
VALUES
(1, 101, 1001, 'Marcus has been responsive to outreach. Good candidate for employment program referral.', 'coordination', 1, '2025-03-01 10:00:00'),

(1, 105, 1005, 'Deandre is at high risk. Multiple associates recently arrested. Increasing street presence around him.', 'alert', 3, '2025-03-12 14:30:00'),

(1, 102, 1002, 'Jasmine has completed anger management program. Seeing positive behavior changes.', 'update', 2, '2025-03-08 11:00:00'),

(1, 106, 1006, 'Deandre missed last two case management appointments. Will attempt home visit.', 'coordination', 3, '2025-03-18 09:00:00');

-- Notes about incidents
INSERT INTO network_notes (network_id, author_org_id, author_user_id, content, note_type, related_incident_id, created_at)
VALUES
(1, 101, 1001, 'Incident #1: Hospital reports victim is stable and cooperative. Family wants to meet with us.', 'update', 1, '2025-03-16 08:00:00'),

(1, 105, 1005, 'Incident #1: Street intel suggests this is retaliation for earlier incident. Tensions remain high in area.', 'alert', 1, '2025-03-16 16:00:00'),

(1, 102, 1002, 'Incident #3: Both groups agreed to informal truce. Will monitor at next community event.', 'update', 3, '2025-03-06 10:00:00');

-- General coordination notes
INSERT INTO network_notes (network_id, author_org_id, author_user_id, content, note_type, created_at)
VALUES
(1, 101, 1001, 'Network meeting scheduled for Friday 3/28 at 10am. Will discuss recent uptick in shootings.', 'general', '2025-03-20 15:00:00'),

(1, 103, 1003, 'Community peace walk planned for April 5th. All orgs invited to participate.', 'general', '2025-03-21 11:00:00');

-- ============================================================================
-- CROSS-ORG REFERRALS
-- ============================================================================

-- Active referral: Marcus Thompson (Lead Org → Case Management)
INSERT INTO network_referrals (network_id, network_participant_id, from_org_id, to_org_id, reason, services_requested, urgency, status, created_by_user_id, created_at)
VALUES
(1, 1, 101, 106,
 'Client needs long-term case management and employment support. Ready to engage with services.',
 'Case management, employment assistance, life skills training',
 'routine', 'accepted', 1001, '2025-03-10 10:00:00');

UPDATE network_referrals SET
    accepted_at = '2025-03-11 14:00:00',
    accepted_by_user_id = 1006,
    response_notes = 'Accepted. Will reach out to client this week to schedule intake.'
WHERE id = 1;

-- Pending referral: Jasmine Rodriguez (Community Outreach → Youth Services)
INSERT INTO network_referrals (network_id, network_participant_id, from_org_id, to_org_id, reason, services_requested, urgency, status, created_by_user_id, created_at)
VALUES
(1, 2, 103, 104,
 'Young client would benefit from youth mentoring and education support programs.',
 'Mentorship program, tutoring, college prep',
 'routine', 'pending', 1003, '2025-03-18 09:00:00');

-- Urgent referral: Deandre Williams (Street Outreach → Lead Org)
INSERT INTO network_referrals (network_id, network_participant_id, from_org_id, to_org_id, reason, services_requested, urgency, status, created_by_user_id, created_at)
VALUES
(1, 3, 105, 101,
 'Client at imminent risk following recent shooting. Needs crisis intervention and relocation assistance immediately.',
 'Crisis intervention, emergency housing, relocation assistance',
 'critical', 'accepted', 1005, '2025-03-16 17:00:00');

UPDATE network_referrals SET
    accepted_at = '2025-03-16 17:30:00',
    accepted_by_user_id = 1001,
    response_notes = 'Crisis team deployed. Client in safe location. Will coordinate full plan tomorrow.'
WHERE id = 3;

-- Completed referral: Alexis Morales (VPC → Case Management)
INSERT INTO network_referrals (network_id, network_participant_id, from_org_id, to_org_id, reason, services_requested, urgency, status, created_by_user_id, created_at, completed_at)
VALUES
(1, 7, 102, 106,
 'Client successfully completed outreach phase, ready for case management.',
 'Long-term case management, housing assistance',
 'routine', 'completed', 1002, '2025-02-20 11:00:00', '2025-03-15 10:00:00');

UPDATE network_referrals SET
    accepted_at = '2025-02-21 09:00:00',
    accepted_by_user_id = 1006,
    response_notes = 'Client has been assigned case manager. Meeting regularly. Making good progress on goals.'
WHERE id = 4;

-- Declined referral: Tanya Lee (Community Outreach → Street Outreach)
INSERT INTO network_referrals (network_id, network_participant_id, from_org_id, to_org_id, reason, services_requested, urgency, status, created_by_user_id, created_at)
VALUES
(1, 8, 103, 105,
 'Client needs street-level intervention support.',
 'Street outreach, conflict mediation',
 'urgent', 'declined', 1003, '2025-03-05 14:00:00');

UPDATE network_referrals SET
    response_notes = 'Client is already connected with our team through another program. No additional outreach needed at this time.',
    declined_reason = 'Already engaged with client through existing relationship'
WHERE id = 5;

-- ============================================================================
-- AUDIT LOG SAMPLES
-- ============================================================================

-- Log PII access events
INSERT INTO network_audit_log (user_id, org_id, network_id, action, resource_type, resource_id, pii_fields_accessed, ip_address, created_at)
VALUES
-- User from Org 101 views Marcus Thompson's PII
(1001, 101, 1, 'view_pii', 'participant', 1, '["name", "dob", "ssn_last4", "address"]', '192.168.1.100', '2025-03-15 10:00:00'),

-- User from Org 104 (no PII sharing) attempts to view but gets masked data
(1004, 104, 1, 'view_participant_masked', 'participant', 1, '[]', '192.168.1.105', '2025-03-15 10:05:00'),

-- User confirms match
(1001, 101, 1, 'confirm_match', 'participant', 1, NULL, '192.168.1.100', '2025-02-01 10:30:00'),

-- User creates incident
(1005, 105, 1, 'create_incident', 'incident', 5, NULL, '192.168.1.110', '2025-03-24 02:20:00'),

-- User views incident details
(1002, 102, 1, 'view_incident', 'incident', 1, NULL, '192.168.1.102', '2025-03-16 09:00:00'),

-- User creates referral
(1003, 103, 1, 'create_referral', 'referral', 2, NULL, '192.168.1.103', '2025-03-18 09:00:00'),

-- User updates PII settings
(1003, 103, 1, 'update_pii_settings', 'settings', NULL, NULL, '192.168.1.103', '2025-01-18 11:00:00');

-- ============================================================================
-- DATA SUMMARY
-- ============================================================================

-- Summary of test data:
--
-- PARTICIPANTS (10 total):
-- - 3 confirmed matches across multiple orgs (Marcus, Jasmine, Deandre)
-- - 2 potential matches needing review (Tyrell/Tyrel)
-- - 1 pending verification (Karim - just added)
-- - 4 unique participants (no matches)
--
-- INCIDENTS (5 total):
-- - 2 critical shootings (1 active, 1 today)
-- - 1 high-priority assault with retaliation risk
-- - 1 resolved medium-priority conflict
-- - 1 low-priority social media monitoring
--
-- PII SHARING:
-- - 2 orgs with full PII sharing (101, 102)
-- - 1 org with full sharing minus SSN (105)
-- - 2 orgs with partial sharing (103, 106)
-- - 1 org with no PII sharing (104)
--
-- REFERRALS (5 total):
-- - 2 accepted and in progress
-- - 1 pending response
-- - 1 completed
-- - 1 declined
--
-- NOTES: 11 total
-- - 4 about participants
-- - 3 about incidents
-- - 4 general coordination
--
-- This data demonstrates:
-- ✓ Participant matching across orgs with varying PII
-- ✓ Multi-org incident response coordination
-- ✓ Different PII sharing scenarios
-- ✓ Full referral workflow (pending → accepted → completed)
-- ✓ Real-time collaboration scenarios (notes, updates)
-- ✓ Audit trail for compliance
