# Network Document Folder - Technical Diagrams

This directory contains Mermaid diagrams documenting the architecture, data flows, and component structure of the Network Document Folder feature.

## Viewing the Diagrams

### Option 1: VS Code (Recommended)
1. Install the **Mermaid Preview** extension
2. Right-click any `.mmd` file → "Open Preview"

### Option 2: GitHub/GitLab
Simply view the `.mmd` files in GitHub - they render automatically!

### Option 3: Online Mermaid Live Editor
1. Go to https://mermaid.live/
2. Copy/paste the contents of any `.mmd` file
3. Instant rendered diagram

### Option 4: Convert to Images
```bash
# Install Mermaid CLI
npm install -g @mermaid-js/mermaid-cli

# Convert to PNG
mmdc -i 01-system-architecture.mmd -o 01-system-architecture.png

# Convert all at once
for file in *.mmd; do mmdc -i "$file" -o "${file%.mmd}.png"; done
```

## Diagram Index

### 1. System Architecture (`01-system-architecture.mmd`)
**Purpose**: Complete system overview showing all layers and components

**Shows**:
- Client layer (React app)
- API layer (GraphQL HTTP + WebSocket)
- Application services (business logic)
- Data layer (network DB + tenant DBs)
- Infrastructure (Redis, Bull Queue)

**Use for**: Understanding how all pieces fit together

---

### 2. Database ER Diagram (`02-database-er-diagram.mmd`)
**Purpose**: Entity-relationship diagram of all network-level tables

**Shows**:
- 10 network tables with all fields
- Relationships between entities
- Foreign key constraints
- Primary keys

**Use for**: Database schema design, understanding data model

---

### 3a. Participant Matching Flow (`03a-participant-matching-flow.mmd`)
**Purpose**: Step-by-step flow of how participants are matched

**Shows**:
- User requests participant list
- Cache check (hit/miss)
- DSF view queries (parallel)
- PII filtering
- Background matching job
- Score calculation
- Potential match detection
- Real-time notification

**Use for**: Understanding the matching algorithm implementation

---

### 3b. Real-Time Update Flow (`03b-realtime-update-flow.mmd`)
**Purpose**: How real-time updates propagate to all connected clients

**Shows**:
- WebSocket connection setup
- Subscription to events
- User makes a change (confirm match)
- Redis Pub/Sub broadcasting
- All clients receive update instantly
- UI updates without refresh

**Use for**: Understanding WebSocket subscriptions and real-time collaboration

---

### 3c. PII Filtering Flow (`03c-pii-filtering-flow.mmd`)
**Purpose**: How PII is filtered based on org permissions

**Shows**:
- User requests participant data
- PII permissions lookup (with caching)
- Per-source filtering logic
- Different orgs see different levels of PII
- Audit logging for compliance

**Use for**: Understanding privacy controls and PII masking

---

### 4. Component Hierarchy (`04-component-hierarchy.mmd`)
**Purpose**: Complete frontend and backend component structure

**Shows**:
- React component tree (views → organisms → molecules → atoms)
- Custom hooks for state management
- GraphQL queries/mutations/subscriptions
- Backend services and dependencies
- Infrastructure components

**Use for**: Development planning, understanding code organization

---

### 5a. Participant Match States (`05a-participant-match-states.mmd`)
**Purpose**: State machine for participant matching lifecycle

**Shows**:
- New participant → matching → verification → confirmation
- All possible states and transitions
- Score thresholds (< 70, 70-89, >= 90)
- Actions on each transition (logging, caching, events)

**Use for**: Understanding match status flow, implementing state transitions

---

### 5b. Incident Response Workflow (`05b-incident-response-workflow.mmd`)
**Purpose**: Multi-org incident response tracking

**Shows**:
- Incident reported → notification → multi-org response
- Parallel org response tracking
- Severity-based notification strategy
- Resolution criteria

**Use for**: Understanding incident coordination, multi-org workflows

---

## Color Coding

All diagrams use consistent color coding:

- 🔵 **Blue** (`#e1f5ff`): Client/Frontend components
- 🟠 **Orange** (`#fff3e0`): API layer
- 🟣 **Purple** (`#f3e5f5`): Application services
- 🟢 **Green** (`#e8f5e9`): Data layer / Database
- 🔴 **Pink** (`#fce4ec`): Infrastructure (Redis, Queue)

---

## Diagram Generation Script

Want to export all diagrams as images?

```bash
#!/bin/bash
# File: export-diagrams.sh

# Install mermaid-cli if not present
if ! command -v mmdc &> /dev/null; then
    echo "Installing @mermaid-js/mermaid-cli..."
    npm install -g @mermaid-js/mermaid-cli
fi

# Create output directory
mkdir -p exports

# Convert all .mmd files to PNG
for file in *.mmd; do
    if [ -f "$file" ]; then
        echo "Converting $file..."
        mmdc -i "$file" -o "exports/${file%.mmd}.png" -b transparent
        mmdc -i "$file" -o "exports/${file%.mmd}.svg" -b transparent
    fi
done

echo "✓ All diagrams exported to exports/ directory"
```

Usage:
```bash
chmod +x export-diagrams.sh
./export-diagrams.sh
```

---

## Embedding in Documentation

### Markdown
```markdown
![System Architecture](./diagrams/exports/01-system-architecture.png)
```

### HTML
```html
<img src="./diagrams/exports/01-system-architecture.svg" alt="System Architecture" />
```

### Confluence / Notion
Upload the PNG/SVG files from `exports/` directory

---

## Updating Diagrams

When making changes:
1. Edit the `.mmd` source files
2. Preview changes locally
3. Re-export to PNG/SVG if needed
4. Commit both source and exports

---

## Questions?

- **Mermaid Syntax**: https://mermaid.js.org/intro/
- **Live Editor**: https://mermaid.live/
- **VS Code Extension**: Search "Mermaid Preview" in Extensions

---

**Created**: March 26, 2025
**Last Updated**: March 26, 2025
**Maintainer**: Development Team
