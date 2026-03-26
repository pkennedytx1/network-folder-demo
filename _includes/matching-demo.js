// Network Document Folder - Interactive Matching Demo

// Test scenarios with different match scores
const scenarios = {
    'high-confidence': {
        name: 'High Confidence Match',
        score: 95,
        badge: 'Auto-Suggest Confirmation',
        recordA: {
            org: 'Lead Organization (Org 101)',
            name: 'Marcus Thompson',
            dob: '1998-03-15',
            ssn: '4521',
            address: '3400 W. Chicago Ave'
        },
        recordB: {
            org: 'Violence Prevention Coalition (Org 102)',
            name: 'Marcus A. Thompson',
            dob: '1998-03-15',
            ssn: '4521',
            address: '3402 W. Chicago Ave'
        },
        breakdown: [
            { icon: '🔢', title: 'SSN Last 4 (Exact Match)', detail: '4521 = 4521', points: 45 },
            { icon: '📅', title: 'Date of Birth (Exact Match)', detail: '1998-03-15 = 1998-03-15', points: 35 },
            { icon: '👤', title: 'Name (High Similarity)', detail: 'Marcus Thompson ≈ Marcus A. Thompson (95% similar)', points: 25 },
            { icon: '⭐', title: 'Confidence Bonus', detail: 'All three fields match with high confidence', points: 5 }
        ],
        matches: {
            name: 'partial',
            dob: 'match',
            ssn: 'match',
            address: 'partial'
        }
    },
    'potential-match': {
        name: 'Potential Match',
        score: 78,
        badge: 'Needs Manual Review',
        recordA: {
            org: 'Violence Prevention Coalition (Org 102)',
            name: 'Tyrell Jenkins',
            dob: '2002-05-14',
            ssn: '5567',
            address: '2800 W. Madison St'
        },
        recordB: {
            org: 'Street Outreach Team (Org 105)',
            name: 'Tyrel Jenkins',
            dob: '2002-05-15',
            ssn: 'Not provided',
            address: 'Unknown'
        },
        breakdown: [
            { icon: '📅', title: 'Date of Birth (Close Match)', detail: '2002-05-14 vs 2002-05-15 (1 day difference)', points: 25 },
            { icon: '👤', title: 'Name (High Similarity)', detail: 'Tyrell Jenkins ≈ Tyrel Jenkins (96% similar - likely spelling variation)', points: 25 },
            { icon: '🔢', title: 'SSN Not Available', detail: 'One record missing SSN last 4', points: 0 }
        ],
        matches: {
            name: 'partial',
            dob: 'partial',
            ssn: 'no-match',
            address: 'no-match'
        }
    },
    'no-match': {
        name: 'No Match Found',
        score: 45,
        badge: 'Create New Participant',
        recordA: {
            org: 'Lead Organization (Org 101)',
            name: 'Marcus Thompson',
            dob: '1998-03-15',
            ssn: '4521',
            address: '3400 W. Chicago Ave'
        },
        recordB: {
            org: 'Community Outreach Partners (Org 103)',
            name: 'Mark Thompson',
            dob: '2001-08-20',
            ssn: '7834',
            address: '4500 W. Lake St'
        },
        breakdown: [
            { icon: '👤', title: 'Name (Medium Similarity)', detail: 'Marcus Thompson ≈ Mark Thompson (70% similar)', points: 15 },
            { icon: '📅', title: 'Date of Birth (No Match)', detail: '1998-03-15 vs 2001-08-20 (3+ years difference)', points: 0 },
            { icon: '🔢', title: 'SSN Last 4 (No Match)', detail: '4521 ≠ 7834', points: 0 }
        ],
        matches: {
            name: 'partial',
            dob: 'no-match',
            ssn: 'no-match',
            address: 'no-match'
        }
    },
    'three-way': {
        name: 'Three-Way Match',
        score: 92,
        badge: 'Complex Match - Multiple Orgs',
        recordA: {
            org: 'Multiple Organizations (3 records)',
            name: 'Deandre Williams',
            dob: '1999-11-08',
            ssn: '9201',
            address: '2900 W. Chicago Ave'
        },
        recordB: {
            org: 'Lead Org (101), VPC (102), Case Mgmt (106)',
            name: 'DeAndre "Dre" Williams',
            dob: '1999-11-08',
            ssn: '9201',
            address: '2900 W. Chicago (various formats)'
        },
        breakdown: [
            { icon: '🔢', title: 'SSN Last 4 (Exact Match)', detail: 'All 3 orgs have matching SSN: 9201', points: 45 },
            { icon: '📅', title: 'Date of Birth (Exact Match)', detail: 'All 3 orgs agree: 1999-11-08', points: 35 },
            { icon: '👤', title: 'Name (Variations)', detail: 'Deandre / DeAndre / "Dre" (common variations)', points: 20 },
            { icon: '🏢', title: 'Multi-Org Confirmation', detail: '3 organizations already confirmed this match', points: 5 }
        ],
        matches: {
            name: 'partial',
            dob: 'match',
            ssn: 'match',
            address: 'match'
        }
    },
    'nickname': {
        name: 'Nickname Variation',
        score: 83,
        badge: 'Likely Nickname Match',
        recordA: {
            org: 'Lead Organization (Org 101)',
            name: 'Michael Johnson',
            dob: '2000-06-10',
            ssn: '3421',
            address: '3100 W. Madison St'
        },
        recordB: {
            org: 'Youth Services Network (Org 104)',
            name: 'Mike Johnson',
            dob: '2000-06-10',
            ssn: 'Not provided',
            address: '3100 W. Madison St'
        },
        breakdown: [
            { icon: '👤', title: 'Name (Nickname Match)', detail: 'Michael → Mike (known nickname variation)', points: 25 },
            { icon: '📅', title: 'Date of Birth (Exact Match)', detail: '2000-06-10 = 2000-06-10', points: 35 },
            { icon: '🏠', title: 'Address (Exact Match)', detail: 'Same address confirms identity', points: 15 },
            { icon: '🔢', title: 'SSN Not Available', detail: 'One record missing SSN', points: 0 }
        ],
        matches: {
            name: 'partial',
            dob: 'match',
            ssn: 'no-match',
            address: 'match'
        }
    },
    'data-entry-error': {
        name: 'Data Entry Error',
        score: 85,
        badge: 'Likely Typo - Review Needed',
        recordA: {
            org: 'Community Outreach Partners (Org 103)',
            name: 'Jasmine Rodriguez',
            dob: '2001-07-22',
            ssn: '7834',
            address: '2700 W. Lake St'
        },
        recordB: {
            org: 'Case Management Services (Org 106)',
            name: 'Jasmine M. Rodriguez',
            dob: '2001-07-23',
            ssn: '7834',
            address: '2700 W. Lake St'
        },
        breakdown: [
            { icon: '🔢', title: 'SSN Last 4 (Exact Match)', detail: '7834 = 7834', points: 45 },
            { icon: '📅', title: 'Date of Birth (Off by 1 day)', detail: '2001-07-22 vs 2001-07-23 (likely data entry error)', points: 25 },
            { icon: '👤', title: 'Name (High Similarity)', detail: 'Jasmine Rodriguez ≈ Jasmine M. Rodriguez', points: 25 },
            { icon: '🏠', title: 'Address (Exact Match)', detail: 'Same address confirms identity', points: 15 }
        ],
        matches: {
            name: 'partial',
            dob: 'partial',
            ssn: 'match',
            address: 'match'
        }
    }
};

// State
let currentScenario = null;
let piiEnabled = true;

// DOM Elements
const scenarioSelect = document.getElementById('scenario-select');
const piiToggle = document.getElementById('pii-toggle');
const runMatcherBtn = document.getElementById('run-matcher');
const matchingResults = document.getElementById('matching-results');
const matchBadge = document.getElementById('match-badge');
const scoreCircle = document.getElementById('score-circle');
const scoreValue = document.getElementById('score-value');
const scoreBreakdown = document.getElementById('score-breakdown');
const comparisonTbody = document.getElementById('comparison-tbody');
const confirmMatchBtn = document.getElementById('confirm-match');
const needsReviewBtn = document.getElementById('needs-review');
const rejectMatchBtn = document.getElementById('reject-match');
const actionResult = document.getElementById('action-result');

// Event Listeners
scenarioSelect.addEventListener('change', () => {
    matchingResults.classList.add('hidden');
    actionResult.classList.add('hidden');
});

piiToggle.addEventListener('change', (e) => {
    piiEnabled = e.target.checked;
    if (currentScenario) {
        renderComparison(currentScenario);
    }
});

runMatcherBtn.addEventListener('click', () => {
    const scenarioKey = scenarioSelect.value;
    currentScenario = scenarios[scenarioKey];
    runMatchingAlgorithm();
});

confirmMatchBtn.addEventListener('click', () => handleAction('confirm'));
needsReviewBtn.addEventListener('click', () => handleAction('review'));
rejectMatchBtn.addEventListener('click', () => handleAction('reject'));

// Main Functions
function runMatchingAlgorithm() {
    // Hide previous results
    actionResult.classList.add('hidden');

    // Simulate algorithm running
    runMatcherBtn.textContent = 'Running Algorithm...';
    runMatcherBtn.disabled = true;

    setTimeout(() => {
        displayResults();
        runMatcherBtn.textContent = 'Run Matching Algorithm';
        runMatcherBtn.disabled = false;
    }, 800);
}

function displayResults() {
    // Show results section
    matchingResults.classList.remove('hidden');

    // Update badge
    matchBadge.textContent = currentScenario.badge;
    matchBadge.className = 'match-badge';

    if (currentScenario.score >= 90) {
        matchBadge.classList.add('high-confidence');
    } else if (currentScenario.score >= 70) {
        matchBadge.classList.add('potential-match');
    } else {
        matchBadge.classList.add('no-match');
    }

    // Animate score
    animateScore(currentScenario.score);

    // Render breakdown
    renderBreakdown(currentScenario.breakdown);

    // Render comparison table
    renderComparison(currentScenario);

    // Scroll to results
    matchingResults.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function animateScore(targetScore) {
    let currentScore = 0;
    const increment = targetScore / 50;
    const interval = 20;

    scoreCircle.style.setProperty('--score', 0);

    const timer = setInterval(() => {
        currentScore += increment;
        if (currentScore >= targetScore) {
            currentScore = targetScore;
            clearInterval(timer);
        }

        scoreValue.textContent = Math.round(currentScore);
        scoreCircle.style.setProperty('--score', currentScore);
    }, interval);
}

function renderBreakdown(items) {
    scoreBreakdown.innerHTML = '';

    items.forEach(item => {
        const div = document.createElement('div');
        div.className = 'score-item';
        div.innerHTML = `
            <div class="score-item-icon">${item.icon}</div>
            <div class="score-item-content">
                <div class="score-item-title">${item.title}</div>
                <div class="score-item-detail">${item.detail}</div>
            </div>
            <div class="score-item-points">+${item.points}</div>
        `;
        scoreBreakdown.appendChild(div);
    });
}

function renderComparison(scenario) {
    comparisonTbody.innerHTML = '';

    const fields = ['name', 'dob', 'ssn', 'address'];
    const fieldLabels = {
        name: 'Full Name',
        dob: 'Date of Birth',
        ssn: 'SSN Last 4',
        address: 'Address'
    };

    fields.forEach(field => {
        const tr = document.createElement('tr');

        const valueA = scenario.recordA[field];
        const valueB = scenario.recordB[field];
        const matchStatus = scenario.matches[field];

        tr.innerHTML = `
            <td class="field-name">${fieldLabels[field]}</td>
            <td>${formatFieldValue(field, valueA, scenario.recordA.org)}</td>
            <td>${formatFieldValue(field, valueB, scenario.recordB.org)}</td>
            <td style="text-align: center;">
                <span class="match-indicator ${matchStatus}">
                    ${matchStatus === 'match' ? '✓' : matchStatus === 'partial' ? '≈' : '✗'}
                </span>
            </td>
        `;

        comparisonTbody.appendChild(tr);
    });
}

function formatFieldValue(field, value, org) {
    const isPII = ['name', 'dob', 'ssn', 'address'].includes(field);

    if (!piiEnabled && isPII) {
        return `<span class="pii-masked">● ● ● ● (PII masked - ${org} has not shared this field)</span>`;
    }

    if (!value || value === 'Not provided' || value === 'Unknown') {
        return `<span class="pii-masked">${value || 'Not provided'}</span>`;
    }

    return `<span class="pii-revealed">${value}</span>`;
}

function handleAction(action) {
    actionResult.classList.remove('hidden');

    switch (action) {
        case 'confirm':
            actionResult.className = 'action-result success';
            actionResult.innerHTML = `
                <h4>✓ Match Confirmed</h4>
                <p>Records have been linked. All ${getOrgCount()} organizations in the network can now coordinate on this participant.</p>
                <p style="margin-top: 0.5rem;"><strong>Next steps:</strong></p>
                <ul style="margin-left: 1.5rem; margin-top: 0.5rem;">
                    <li>Network participant record created</li>
                    <li>Source records linked from both organizations</li>
                    <li>Cache invalidated for fresh data</li>
                    <li>PARTICIPANT_UPDATED event published to network</li>
                    <li>Audit log entry created</li>
                </ul>
            `;
            break;

        case 'review':
            actionResult.className = 'action-result warning';
            actionResult.innerHTML = `
                <h4>⚠ Flagged for Additional Review</h4>
                <p>Match has been saved as "Needs More Info". Network administrators from both organizations will be notified to investigate further.</p>
                <p style="margin-top: 0.5rem;"><strong>Possible next steps:</strong></p>
                <ul style="margin-left: 1.5rem; margin-top: 0.5rem;">
                    <li>Contact staff from both orgs to verify identity</li>
                    <li>Request additional identifying information</li>
                    <li>Check for aliases or name changes</li>
                    <li>Review case notes for confirmation</li>
                </ul>
            `;
            break;

        case 'reject':
            actionResult.className = 'action-result info';
            actionResult.innerHTML = `
                <h4>✗ Match Rejected</h4>
                <p>Records confirmed as different people. Separate network participant records will be maintained.</p>
                <p style="margin-top: 0.5rem;"><strong>Actions taken:</strong></p>
                <ul style="margin-left: 1.5rem; margin-top: 0.5rem;">
                    <li>Potential match marked as "rejected" for audit trail</li>
                    <li>Algorithm will not suggest this pairing again</li>
                    <li>Both participants remain separate in network</li>
                    <li>Decision logged for future reference</li>
                </ul>
            `;
            break;
    }

    actionResult.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function getOrgCount() {
    if (currentScenario.name === 'Three-Way Match') {
        return '3';
    }
    return '2';
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    console.log('Network Document Folder Demo Loaded');
    console.log('Available scenarios:', Object.keys(scenarios));
});
