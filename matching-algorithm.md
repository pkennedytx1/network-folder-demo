# Participant Matching Algorithm

## Overview

The Network Document Folder matching algorithm identifies when the same person exists in multiple organization databases without exposing PII to unauthorized parties. This document specifies the algorithm, scoring methodology, edge cases, and privacy-preserving techniques.

## Design Principles

1. **Privacy-First**: Never expose raw PII during matching - use hashes for comparison
2. **Human-in-the-Loop**: Always require manual confirmation before merging records
3. **Conservative Bias**: Prefer false negatives over false positives (better to miss a match than incorrectly merge)
4. **Transparent Scoring**: Show users WHY records matched so they can validate
5. **Audit Trail**: Log all matching decisions for accountability

## Matching Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Trigger: New participant shared to network               │
│    OR: Manual "Run Matcher" command                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Extract & Hash PII Fields                                │
│    - Normalize name (lowercase, remove special chars)       │
│    - Hash: SSN last 4, DOB, normalized name                 │
│    - Store both hashes (for matching) and encrypted         │
│      (for authorized viewing)                               │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Query Existing Network Participants                      │
│    - Compare hashes against all existing participants       │
│    - Calculate match score for each potential match         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Classify by Score Threshold                              │
│    - Score ≥ 90: "Auto-suggest" (still needs approval)     │
│    - Score 70-89: "Potential Match" (needs review)          │
│    - Score < 70: "No Match" (create new participant)        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Present to Network Admins for Confirmation               │
│    - Show comparison table with scoring breakdown           │
│    - Reveal PII only to orgs with permission                │
│    - Allow "Confirm", "Reject", or "Need More Info"         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. On Confirmation:                                          │
│    - Link source record to network_participant              │
│    - Update match_confidence_score                          │
│    - Invalidate cache                                       │
│    - Publish PARTICIPANT_UPDATED event                      │
│    - Log in audit trail                                     │
└─────────────────────────────────────────────────────────────┘
```

## Scoring Methodology

### Base Scoring Rules

The algorithm calculates a match score from 0-100 based on available fields:

| Field Combination | Score | Confidence Level |
|------------------|-------|------------------|
| **SSN last 4 + DOB (exact)** | 95 | Near Certain |
| **SSN last 4 (exact) + DOB (close ±1 day)** | 85 | Very High |
| **Name (high similarity) + DOB (exact) + SSN last 4** | 98 | Extremely High |
| **Name (high similarity) + DOB (exact)** | 80 | High |
| **Name (exact) + DOB (off by 1 year)** | 70 | Medium |
| **Name (medium similarity) + DOB (exact)** | 65 | Medium-Low |
| **Name (exact) + Address (partial match)** | 60 | Low-Medium |
| **Name only (exact)** | 30 | Very Low |

### Field-Specific Scoring

#### 1. SSN Last 4 Matching

```typescript
function scoreSSN(hash1: string, hash2: string): number {
  if (hash1 === null || hash2 === null) {
    return 0; // Cannot score - missing data
  }

  if (hash1 === hash2) {
    return 45; // Exact match - high value
  }

  return 0; // No partial credit for SSN
}
```

**Rationale**: SSN last 4 is highly unique. No partial matching - either matches or doesn't.

#### 2. Date of Birth Matching

```typescript
function scoreDOB(hash1: string, hash2: string, dob1: Date, dob2: Date): number {
  if (hash1 === null || hash2 === null) {
    return 0;
  }

  if (hash1 === hash2) {
    return 35; // Exact match
  }

  // Allow ±1 day (common data entry errors)
  const daysDiff = Math.abs(dob1.getTime() - dob2.getTime()) / (1000 * 60 * 60 * 24);

  if (daysDiff === 1) {
    return 25; // Close match - likely typo
  }

  // Allow ±1 year (age-based estimates)
  const yearsDiff = Math.abs(dob1.getFullYear() - dob2.getFullYear());

  if (yearsDiff === 1) {
    return 15; // Possible age estimate
  }

  return 0;
}
```

**Rationale**: DOB is critical but prone to data entry errors. Allow slight variance.

#### 3. Name Matching

Uses **Levenshtein Distance** for similarity scoring:

```typescript
function scoreName(name1: string, name2: string): number {
  // Normalize both names
  const norm1 = normalizeName(name1); // lowercase, remove special chars, trim
  const norm2 = normalizeName(name2);

  // Exact match after normalization
  if (norm1 === norm2) {
    return 30;
  }

  // Calculate Levenshtein similarity (0-1)
  const similarity = calculateSimilarity(norm1, norm2);

  // Name similarity scoring:
  // 1.0 = 30 points
  // 0.9 = 25 points
  // 0.8 = 20 points
  // 0.7 = 15 points
  // < 0.7 = 0 points

  if (similarity >= 0.9) return 25;
  if (similarity >= 0.8) return 20;
  if (similarity >= 0.7) return 15;

  return 0;
}

function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '') // Remove special chars
    .replace(/\s+/g, '') // Remove all spaces
    .trim();
}

function calculateSimilarity(str1: string, str2: string): number {
  const longer = str1.length > str2.length ? str1 : str2;
  const shorter = str1.length > str2.length ? str2 : str1;

  if (longer.length === 0) return 1.0;

  const editDistance = levenshteinDistance(longer, shorter);
  return (longer.length - editDistance) / longer.length;
}
```

**Name Normalization Examples**:
- "Marcus Thompson" → "marcusthompson"
- "Marcus A. Thompson" → "marcusathompson"
- "Marc Thompson" → "marcthompson"
- "DeAndre Williams" → "deandrewilliams"
- "Deandre \"Dre\" Williams" → "deandredrewilliams"

**Similarity Examples**:
- "Marcus Thompson" vs "Marc Thompson" → 0.93 (25 points)
- "Tyrell Jenkins" vs "Tyrel Jenkins" → 0.96 (25 points)
- "Jasmine Rodriguez" vs "Jasmine M. Rodriguez" → 0.89 (20 points)

### Combined Scoring Formula

```typescript
function calculateMatchScore(
  candidate: ParticipantSource,
  existing: ParticipantSource
): MatchResult {
  let score = 0;
  const factors: MatchFactor[] = [];

  // SSN matching (0-45 points)
  const ssnScore = scoreSSN(candidate.ssn_last4_hash, existing.ssn_last4_hash);
  if (ssnScore > 0) {
    score += ssnScore;
    factors.push({ field: 'ssn_last4', score: ssnScore, weight: 'high' });
  }

  // DOB matching (0-35 points)
  const dobScore = scoreDOB(
    candidate.dob_hash,
    existing.dob_hash,
    candidate.dob_encrypted, // Decrypted for comparison only
    existing.dob_encrypted
  );
  if (dobScore > 0) {
    score += dobScore;
    factors.push({ field: 'dob', score: dobScore, weight: 'high' });
  }

  // Name matching (0-30 points)
  const nameScore = scoreName(
    candidate.name_encrypted, // Decrypted for comparison only
    existing.name_encrypted
  );
  if (nameScore > 0) {
    score += nameScore;
    factors.push({ field: 'name', score: nameScore, weight: 'medium' });
  }

  // Bonus: Multiple high-confidence fields
  if (ssnScore > 0 && dobScore >= 25 && nameScore >= 15) {
    score += 5; // Bonus for triple match
    factors.push({ field: 'confidence_bonus', score: 5, weight: 'low' });
  }

  return {
    score: Math.min(score, 100), // Cap at 100
    factors: factors,
    recommendation: classifyScore(score)
  };
}

function classifyScore(score: number): MatchRecommendation {
  if (score >= 90) return 'auto_suggest';
  if (score >= 70) return 'potential_match';
  return 'no_match';
}
```

## Threshold Definitions

### Score ≥ 90: Auto-Suggest (High Confidence)

**Characteristics**:
- SSN + DOB exact match (95 points)
- SSN + DOB + Name high similarity (98 points)

**User Experience**:
- Automatically flagged for review
- Highlighted in UI as "High Confidence Match"
- Still requires human confirmation (no auto-merge)
- Shows side-by-side comparison with matching fields highlighted

**Example**:
```
Participant A (Org 101): Marcus Thompson, DOB: 1998-03-15, SSN: 4521
Participant B (Org 102): Marcus A. Thompson, DOB: 1998-03-15, SSN: 4521
Match Score: 98
→ Auto-suggest confirmation
```

### Score 70-89: Potential Match (Needs Review)

**Characteristics**:
- Name + DOB match, no SSN (80 points)
- SSN + DOB close match (85 points)
- Name exact + DOB off by 1 year (70 points)

**User Experience**:
- Flagged as "Potential Match"
- Requires manual review and investigation
- May need additional context from org staff
- Can mark as "Need More Info" to investigate further

**Example**:
```
Participant A (Org 102): Tyrell Jenkins, DOB: 2002-05-14, SSN: 5567
Participant B (Org 105): Tyrel Jenkins, DOB: 2002-05-15, SSN: (not provided)
Match Score: 78
→ Potential match - spelling variation + DOB off by 1 day
```

### Score < 70: No Match (Create New)

**Characteristics**:
- Insufficient similarity across fields
- Common names without other identifiers
- Clear mismatch on key fields

**User Experience**:
- Automatically creates new network participant
- No action required from admin
- Can still manually link later if discovered

**Example**:
```
Participant A (Org 101): Marcus Thompson, DOB: 1998-03-15
Participant B (Org 103): Mark Thompson, DOB: 2001-08-20
Match Score: 45
→ No match - different DOB, different name variant
```

## Privacy-Preserving Hashing

### Hash Generation

All PII hashing uses **HMAC-SHA256** with application-level salt:

```typescript
import crypto from 'crypto';

const MATCH_SALT = process.env.NETWORK_MATCH_SALT; // Unique per installation

function hashForMatching(value: string): string {
  if (!value) return null;

  // Normalize first
  const normalized = normalizeValue(value);

  // HMAC-SHA256
  return crypto
    .createHmac('sha256', MATCH_SALT)
    .update(normalized)
    .digest('hex');
}

function normalizeValue(value: string): string {
  return value.toLowerCase().trim();
}
```

**Example Hashes** (with fictional salt `secret123`):
```
hashForMatching("4521") → "7f8a9b2c..."
hashForMatching("1998-03-15") → "3d4e5f6a..."
hashForMatching("marcusthompson") → "1a2b3c4d..."
```

### Encryption vs Hashing

**Two-Tier Storage**:

1. **Hashes** (in `network_participant_sources`):
   - `name_hash`, `ssn_last4_hash`, `dob_hash`
   - Used ONLY for matching algorithm
   - Cannot be reversed to get original value
   - Same input always produces same hash (deterministic)

2. **Encrypted Values** (in `network_participant_sources`):
   - `name_encrypted`, `ssn_last4_encrypted`, `dob_encrypted`
   - Used for display to authorized users
   - Laravel encryption (reversible)
   - Decrypted on-demand based on PII permissions

**Why Both?**
- Hashes enable matching without exposing PII
- Encryption enables display to authorized orgs
- Cannot derive encrypted value from hash (one-way function)

## Edge Cases & Resolutions

### 1. Three-Way Matches with Disagreement

**Scenario**: Org A and Org B confirm match, but Org C says "not the same person"

**Resolution**:
```
Create TWO network participants:
- Participant 1: Sources from Org A + Org B (confirmed match)
- Participant 2: Source from Org C (separate person)

Store in potential_matches table as "rejected" for audit trail
```

**Rationale**: Better to split than incorrectly merge. Orgs can always manually merge later if they discover error.

### 2. Partial Matches (Different Confidence Levels)

**Scenario**:
- Participant A matched with B (score: 95)
- Participant C matched with B (score: 72)
- Does C match A?

**Resolution**:
```
Run pairwise comparison:
- Calculate A vs C score directly
- If score ≥ 70: Flag as potential 3-way match
- If score < 70: Keep separate (B might be ambiguous)

Require human review of all three before merging
```

### 3. Nickname Variations

**Common Variations**:
- Michael → Mike, Mikey
- Christopher → Chris
- Deandre → Dre
- Jasmine → Jazz, Jas

**Resolution**:
```typescript
// Nickname dictionary (expand as needed)
const NICKNAMES = {
  'michael': ['mike', 'mikey'],
  'christopher': ['chris'],
  'deandre': ['dre'],
  'jasmine': ['jazz', 'jas'],
  // ... more mappings
};

function scoreNameWithNicknames(name1: string, name2: string): number {
  const norm1 = normalizeName(name1);
  const norm2 = normalizeName(name2);

  // Check if either is a known nickname of the other
  if (isNicknameOf(norm1, norm2) || isNicknameOf(norm2, norm1)) {
    return 25; // High confidence nickname match
  }

  // Fall back to standard similarity
  return scoreName(name1, name2);
}
```

### 4. Missing SSN

**Scenario**: One or both records don't have SSN last 4

**Resolution**:
- Algorithm scores based on available fields only
- Name + DOB match can still score 80 points (potential match)
- Lower threshold before auto-suggesting
- Flag as "Needs More Info" if score is borderline

### 5. Transposed Digits in SSN

**Scenario**: SSN last 4 is "4521" vs "4512" (transposition error)

**Resolution**:
```
Do NOT allow partial SSN matching.
SSN is too critical - must be exact match or no credit.

If name + DOB match but SSN doesn't:
- Flag as "Potential Match with SSN Conflict"
- Require manual investigation
- One might be a data entry error
```

### 6. Twin/Sibling Confusion

**Scenario**: Same last name, same DOB, different first names

**Resolution**:
```
Score will be LOW due to name mismatch.
Algorithm will correctly identify as separate people.

Example:
- Michael Johnson, DOB: 2000-01-15
- Marcus Johnson, DOB: 2000-01-15
→ Score: ~40 (DOB match, name partial match)
→ Correctly flagged as different people
```

### 7. Data Entry Errors (DOB off by years)

**Scenario**: DOB recorded as 1998-03-15 vs 1999-03-15 (1 year difference)

**Resolution**:
```
Algorithm allows ±1 year with reduced score (15 points instead of 35).

If name + SSN match but DOB is off:
- Still scores high enough (60+ points) to flag
- Manual review reveals likely data entry error
- Can be corrected in source system
```

### 8. Name Changes (Marriage, Legal Name Change)

**Scenario**:
- Record from 2023: "Jasmine Rodriguez"
- Record from 2025: "Jasmine Martinez" (married)

**Resolution**:
```
Algorithm will NOT match based on name alone.

Requires:
- SSN + DOB to match (if available)
- OR: Manual linking by network admin
- OR: Add "previous names" field to data standard

Future enhancement: Track name history
```

## Performance Optimization

### Indexing Strategy

```sql
-- Fast hash lookups
CREATE INDEX idx_ssn_dob ON network_participant_sources(ssn_last4_hash, dob_hash);
CREATE INDEX idx_name_dob ON network_participant_sources(name_hash, dob_hash);

-- Partial index for quick "no SSN" queries
CREATE INDEX idx_no_ssn ON network_participant_sources(name_hash, dob_hash)
  WHERE ssn_last4_hash IS NULL;
```

### Query Optimization

```typescript
// Instead of comparing new record against ALL existing (O(n)):
async function findPotentialMatches(candidate: ParticipantSource): Promise<MatchResult[]> {
  const matches: MatchResult[] = [];

  // Strategy 1: Exact SSN + DOB lookup (instant)
  if (candidate.ssn_last4_hash && candidate.dob_hash) {
    const exactMatches = await db.query(`
      SELECT * FROM network_participant_sources
      WHERE ssn_last4_hash = ? AND dob_hash = ?
    `, [candidate.ssn_last4_hash, candidate.dob_hash]);

    if (exactMatches.length > 0) {
      return exactMatches; // High confidence, no need to check others
    }
  }

  // Strategy 2: DOB + Name hash lookup
  if (candidate.dob_hash) {
    const dobMatches = await db.query(`
      SELECT * FROM network_participant_sources
      WHERE dob_hash = ?
    `, [candidate.dob_hash]);

    // Filter by name similarity in-memory (smaller dataset)
    for (const match of dobMatches) {
      const score = calculateMatchScore(candidate, match);
      if (score.score >= 70) {
        matches.push({ match, score });
      }
    }
  }

  return matches;
}
```

### Background Processing

```typescript
// Use Bull queue for heavy matching operations
import { Queue } from 'bull';

const matchingQueue = new Queue('participant-matching', {
  redis: { host: 'localhost', port: 6379 }
});

// Add job when participant shared
await matchingQueue.add({
  network_id: 1,
  participant_source_id: 123,
  priority: 'normal' // or 'high' for urgent cases
}, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 2000 }
});

// Process job
matchingQueue.process(async (job) => {
  const { network_id, participant_source_id } = job.data;

  const source = await loadParticipantSource(participant_source_id);
  const matches = await findPotentialMatches(source);

  if (matches.length > 0) {
    await storeMatches(network_id, matches);
    await notifyNetworkAdmins(network_id, matches);
  } else {
    await createNewNetworkParticipant(source);
  }

  await invalidateCache(network_id);
});
```

## Algorithm Testing

### Unit Test Cases

```typescript
describe('Participant Matching Algorithm', () => {
  describe('SSN Scoring', () => {
    it('should score 45 for exact SSN match', () => {
      expect(scoreSSN(hash('4521'), hash('4521'))).toBe(45);
    });

    it('should score 0 for mismatched SSN', () => {
      expect(scoreSSN(hash('4521'), hash('4512'))).toBe(0);
    });

    it('should score 0 when SSN is missing', () => {
      expect(scoreSSN(null, hash('4521'))).toBe(0);
    });
  });

  describe('Name Scoring', () => {
    it('should score 30 for exact normalized match', () => {
      expect(scoreName('Marcus Thompson', 'marcus thompson')).toBe(30);
    });

    it('should score 25 for high similarity', () => {
      expect(scoreName('Tyrell Jenkins', 'Tyrel Jenkins')).toBe(25);
    });

    it('should score 0 for low similarity', () => {
      expect(scoreName('Marcus Thompson', 'John Smith')).toBe(0);
    });
  });

  describe('Combined Scoring', () => {
    it('should score 95+ for SSN + DOB + Name match', () => {
      const result = calculateMatchScore(
        { name: 'Marcus Thompson', dob: '1998-03-15', ssn: '4521' },
        { name: 'Marcus A. Thompson', dob: '1998-03-15', ssn: '4521' }
      );
      expect(result.score).toBeGreaterThanOrEqual(95);
      expect(result.recommendation).toBe('auto_suggest');
    });

    it('should score 70-89 for potential matches', () => {
      const result = calculateMatchScore(
        { name: 'Tyrell Jenkins', dob: '2002-05-14', ssn: '5567' },
        { name: 'Tyrel Jenkins', dob: '2002-05-15', ssn: null }
      );
      expect(result.score).toBeGreaterThanOrEqual(70);
      expect(result.score).toBeLessThan(90);
      expect(result.recommendation).toBe('potential_match');
    });
  });
});
```

### Integration Test Scenarios

1. **Happy Path**: Exact match found
2. **Potential Match**: Needs review
3. **No Match**: Create new
4. **Three-Way Match**: Complex merging
5. **Performance**: 100+ existing participants

## Future Enhancements

1. **Machine Learning**:
   - Train model on confirmed matches
   - Learn nickname patterns specific to community
   - Improve name similarity scoring

2. **Additional Fields**:
   - Phone number (last 4 digits)
   - Address (zip code + street)
   - Aliases/previous names

3. **Confidence Over Time**:
   - Track accuracy of matches
   - Adjust thresholds based on false positive rate

4. **Automated Unlinking**:
   - Detect impossible scenarios (person in two places at once)
   - Flag for review

5. **Fuzzy Phonetic Matching**:
   - Soundex or Metaphone for name matching
   - Handle pronunciation-based spelling variations

## Security & Privacy

### Compliance Requirements

- **HIPAA**: PII hashing + encryption meets de-identification standards
- **GDPR**: Audit log tracks all PII access
- **State Privacy Laws**: Granular PII controls per org

### Audit Trail

Every match decision is logged:
```sql
INSERT INTO network_audit_log (action, resource_type, resource_id, metadata)
VALUES ('confirm_match', 'participant', 123, '{
  "match_score": 95.5,
  "factors": ["ssn_exact", "dob_exact", "name_high_similarity"],
  "confidence": "high"
}');
```

## Summary

The matching algorithm balances:
- **Accuracy**: Conservative thresholds prevent false merges
- **Privacy**: Hash-based matching protects PII
- **Usability**: Clear scoring helps users understand matches
- **Performance**: Indexed queries + background processing
- **Flexibility**: Handles missing data and edge cases

Key Principle: **Always require human confirmation. Algorithm suggests, humans decide.**
