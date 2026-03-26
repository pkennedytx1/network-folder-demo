# Network Document Folder - Demos

## 🎨 Full Application Demo

**File:** `full-app-demo.html`

**Open it:** Double-click the file or run:
```bash
open full-app-demo.html
```

### What's Included

This is a **complete interactive demo** showing how the full Network Document Folder works:

#### 📊 Dashboard View
- Network overview with key statistics
- Real-time activity feed
- Quick access to pending actions

#### 👥 People View
- Full participant list with confirmed matches
- **Pending match card** - click to review
- Multi-org source tracking
- Recent activity for each participant
- High-risk indicators

#### 🚨 Incidents View
- Active critical incidents
- Multi-org response tracking
- Real-time status updates
- Participant involvement
- Tags and categorization

#### 🤝 Referrals View
- Cross-org referrals workflow
- Pending, accepted, completed states
- Accept/decline actions
- Urgency levels (critical, routine)

#### 📝 Notes View
- Network-wide collaboration
- Alerts, coordination, updates
- Linked to participants and incidents
- Org attribution

#### ⚡ Interactive Features
- Tab navigation between views
- Filter buttons (active/inactive states)
- Search bars
- Modal for match review
- Notification badges
- Responsive design

### Sample Data

The demo uses **realistic data** from `sample-data.sql`:
- **6 organizations** in the network
- **10 participants** (3 confirmed matches, 1 pending review)
- **5 incidents** (2 critical active)
- **5 referrals** (various states)
- **11 notes** (alerts, coordination, updates)

### Match Review Modal

Click on the **"Tyrell/Tyrel Jenkins"** card or the **"Review Pending Match"** button to see:
- Side-by-side comparison table
- Match score visualization (78.5)
- Field-by-field indicators (✓ ≈ ✗)
- Reasoning for the match
- Action buttons (Confirm / Needs More Info / Reject)

---

## 🎯 Matching Algorithm Demo

**File:** `index.html`

**Open it:**
```bash
open index.html
```

### What's Included

Focused demo of the **matching algorithm** with 6 scenarios:

1. **High Confidence Match** (95+) - Auto-suggest
2. **Potential Match** (70-89) - Needs review
3. **No Match** (<70) - Create new
4. **Three-Way Match** - Complex merging
5. **Nickname Variation** - Michael → Mike
6. **Data Entry Error** - DOB off by 1 day

#### Features
- Score visualization with animated gauge
- Detailed score breakdown (SSN + DOB + Name)
- PII visibility toggle
- Comparison table
- Action workflows

---

## 🔄 Differences Between Demos

| Feature | Full App Demo | Matching Demo |
|---------|--------------|---------------|
| **Scope** | Complete application | Matching algorithm only |
| **Views** | 5 views (Dashboard, People, Incidents, Referrals, Notes) | 1 view (Matching scenarios) |
| **Navigation** | Tab-based navigation | Dropdown selector |
| **Data** | All sample data (10 participants, 5 incidents) | 6 matching scenarios |
| **Focus** | Overall UX and workflow | Algorithm details |
| **Best For** | Stakeholder demos, UX review | Technical understanding |

---

## 💡 How to Use

### For Stakeholder Presentations
1. Start with **`full-app-demo.html`** - shows the complete system
2. Navigate through each tab to demonstrate features
3. Click on the pending match to show review workflow
4. Explain the multi-org response tracking on incidents

### For Technical Review
1. Use **`index.html`** - detailed matching algorithm
2. Walk through each scenario
3. Toggle PII visibility to show privacy controls
4. Explain score calculation

### For UX Feedback
1. Open **`full-app-demo.html`**
2. Navigate as a user would
3. Identify confusing elements
4. Test responsiveness (resize browser)

---

## 🚀 Next: Building the Real Thing

These demos show what the system **will look like**. The actual implementation will:

1. **Backend**: Query real DSF views from multiple tenant databases
2. **API**: GraphQL subscriptions for real-time updates
3. **Cache**: Redis caching for performance
4. **Auth**: Real user authentication and PII permissions
5. **Database**: Store actual network-level data

See `../README.md` for the complete implementation roadmap.

---

## 📁 Demo Files

```
demo/
├── full-app-demo.html          # Complete application (NEW!)
├── index.html                  # Matching algorithm demo
├── styles.css                  # Shared styles
├── matching-demo.js            # Matching scenarios
└── README.md                   # This file
```

**Total**: ~1,300 lines of HTML/CSS/JS showing the complete system
