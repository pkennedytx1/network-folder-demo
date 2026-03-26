# Network Document Folder - Technical Diagrams

This document contains all technical diagrams for the Network Document Folder feature. All diagrams are also available as standalone Mermaid source files in the `diagrams/` directory.

**View these diagrams on GitHub** - they render automatically! Or open in VS Code with the Mermaid Preview extension.

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Database ER Diagram](#2-database-er-diagram)
3. [Sequence Diagrams](#3-sequence-diagrams)
   - [3a. Participant Matching Flow](#3a-participant-matching-flow)
   - [3b. Real-Time Update Flow](#3b-real-time-update-flow)
   - [3c. PII Filtering Flow](#3c-pii-filtering-flow)
4. [Component Hierarchy](#4-component-hierarchy)
5. [State Machine Diagrams](#5-state-machine-diagrams)
   - [5a. Participant Match States](#5a-participant-match-states)
   - [5b. Incident Response Workflow](#5b-incident-response-workflow)

---

## 1. System Architecture

**Purpose**: Complete system overview showing all layers and components

**Shows**: Client layer (React), API layer (GraphQL + WebSocket), Application services, Data layer (network DB + tenant DBs), Infrastructure (Redis, Bull Queue)

**Source**: [`diagrams/01-system-architecture.mmd`](diagrams/01-system-architecture.mmd)

```mermaid
graph TB
    subgraph "Client Layer"
        Browser["Web Browser"]
        ReactApp["Network Document Folder<br/>React App (Relay)"]
    end

    subgraph "API Layer"
        ApolloServer["Apollo GraphQL Server<br/>(HTTP + WebSocket)"]
        RestAPI["REST API<br/>(Legacy Support)"]
        WSServer["WebSocket Server<br/>(graphql-ws)"]
    end

    subgraph "Application Services"
        NDFS["NetworkDocumentFolderService<br/>(Orchestration)"]
        PMS["ParticipantMatchingService<br/>(Matching Algorithm)"]
        PIIS["NetworkPIIService<br/>(Privacy Filtering)"]
        CacheService["NetworkCacheService<br/>(Multi-tier Caching)"]
        EventService["NetworkEventService<br/>(Pub/Sub)"]
    end

    subgraph "Data Layer"
        subgraph "Global Database"
            NetworkTables["Network Tables<br/>- network_participants<br/>- network_incidents<br/>- network_referrals<br/>- network_notes<br/>- network_audit_log"]
            DataStandards["Data Standards<br/>- data_standards<br/>- data_standard_forms"]
        end

        subgraph "Tenant Databases"
            TenantA["Org A Database<br/>- dsf_101_view<br/>- data_* tables"]
            TenantB["Org B Database<br/>- dsf_102_view<br/>- data_* tables"]
            TenantN["Org N Database<br/>- dsf_103_view<br/>- data_* tables"]
        end
    end

    subgraph "Infrastructure"
        Redis["Redis<br/>(Cache + Pub/Sub)"]
        BullQueue["Bull Queue<br/>(Background Jobs)"]
    end

    %% Client to API
    Browser --> ReactApp
    ReactApp -->|GraphQL Query/Mutation| ApolloServer
    ReactApp -->|WebSocket Subscribe| WSServer
    ReactApp -->|REST Legacy| RestAPI

    %% API to Services
    ApolloServer --> NDFS
    WSServer --> EventService
    RestAPI --> NDFS

    %% Service Dependencies
    NDFS --> PMS
    NDFS --> PIIS
    NDFS --> CacheService
    NDFS --> EventService
    PMS --> BullQueue

    %% Services to Data
    NDFS --> NetworkTables
    NDFS --> DataStandards
    NDFS --> TenantA
    NDFS --> TenantB
    NDFS --> TenantN

    PMS --> NetworkTables
    PIIS --> NetworkTables

    %% Services to Infrastructure
    CacheService --> Redis
    EventService --> Redis
    BullQueue --> Redis

    %% Styling
    classDef client fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef api fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef service fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef data fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef infra fill:#fce4ec,stroke:#880e4f,stroke-width:2px

    class Browser,ReactApp client
    class ApolloServer,RestAPI,WSServer api
    class NDFS,PMS,PIIS,CacheService,EventService service
    class NetworkTables,DataStandards,TenantA,TenantB,TenantN data
    class Redis,BullQueue infra
```

**Key Insights**:
- WebSocket server shares same port as HTTP (Apollo Server)
- Redis serves dual purpose: cache + pub/sub for real-time
- DSF views queried from multiple tenant databases in parallel
- Background jobs handle heavy matching operations

---

## 2. Database ER Diagram

**Purpose**: Entity-relationship diagram of all network-level tables

**Shows**: 10 network tables with all fields, relationships, foreign keys, primary keys

**Source**: [`diagrams/02-database-er-diagram.mmd`](diagrams/02-database-er-diagram.mmd)

```mermaid
erDiagram
    networks ||--o{ network_participants : contains
    networks ||--o{ network_incidents : contains
    networks ||--o{ network_referrals : contains
    networks ||--o{ network_notes : contains
    networks ||--o{ network_pii_settings : configures

    network_participants ||--o{ network_participant_sources : "has sources"
    network_participants ||--o{ network_participant_potential_matches : "matches with"
    network_participants ||--o{ network_incident_participants : "involved in"
    network_participants ||--o{ network_referrals : "subject of"

    network_incidents ||--o{ network_incident_org_responses : "tracked by orgs"
    network_incidents ||--o{ network_incident_participants : "involves"
    network_incidents ||--o{ network_notes : "has notes"

    network_participants ||--o{ network_notes : "has notes"

    organizations ||--o{ network_participant_sources : contributes
    organizations ||--o{ network_incident_org_responses : responds
    organizations ||--o{ network_referrals : "sends/receives"
    organizations ||--o{ network_pii_settings : "privacy config"
    organizations ||--o{ network_notes : authors

    network_participants {
        bigint id PK
        bigint network_id FK
        enum match_status
        decimal match_confidence_score
        timestamp created_at
        timestamp confirmed_at
        bigint confirmed_by_user_id
        boolean active
    }

    network_participant_sources {
        bigint id PK
        bigint network_participant_id FK
        bigint org_id FK
        bigint document_id
        bigint dsf_id
        string name_used_encrypted
        string ssn_last4_hash
        string dob_hash
        timestamp contributed_at
        bigint confirmed_by_org_user_id
    }

    network_participant_potential_matches {
        bigint id PK
        bigint network_id FK
        bigint participant_a_id FK
        bigint participant_b_id FK
        decimal match_score
        json match_fields
        enum status
        timestamp created_at
    }

    network_incidents {
        bigint id PK
        bigint network_id FK
        string incident_type
        enum severity
        string location
        timestamp occurred_at
        bigint reported_by_org_id FK
        text description
        json tags
        timestamp created_at
    }

    network_incident_org_responses {
        bigint id PK
        bigint network_incident_id FK
        bigint org_id FK
        enum status
        json planned_actions
        json current_actions
        json completed_actions
        timestamp updated_at
    }

    network_incident_participants {
        bigint network_incident_id FK
        bigint network_participant_id FK
        string role
    }

    network_referrals {
        bigint id PK
        bigint network_id FK
        bigint participant_id FK
        bigint from_org_id FK
        bigint to_org_id FK
        text reason
        enum status
        enum urgency
        timestamp created_at
        timestamp accepted_at
        timestamp completed_at
    }

    network_notes {
        bigint id PK
        bigint network_id FK
        bigint author_org_id FK
        bigint author_user_id FK
        text content
        bigint related_participant_id FK
        bigint related_incident_id FK
        timestamp created_at
        timestamp updated_at
    }

    network_pii_settings {
        bigint id PK
        bigint network_id FK
        bigint org_id FK
        boolean pii_sharing_enabled
        json fields_shared
        timestamp consent_confirmed_at
        bigint confirmed_by_user_id
    }

    network_audit_log {
        bigint id PK
        bigint network_id FK
        bigint user_id FK
        bigint org_id FK
        string action
        string resource_type
        bigint resource_id
        json pii_accessed
        string ip_address
        timestamp created_at
    }
```

**Key Design Decisions**:
- **Separation of concerns**: Network-level data (matches, incidents) separate from tenant data (DSF views)
- **PII security**: Encrypted fields for display, hashed fields for matching
- **Audit trail**: Complete logging of all PII access for compliance
- **Flexibility**: JSON fields for dynamic action tracking and custom tags

---

## 3. Sequence Diagrams

### 3a. Participant Matching Flow

**Purpose**: Step-by-step flow of how participants are matched

**Shows**: User requests → cache check → DSF queries → background matching → score calculation → real-time notification

**Source**: [`diagrams/03a-participant-matching-flow.mmd`](diagrams/03a-participant-matching-flow.mmd)

```mermaid
sequenceDiagram
    actor User
    participant React as React App
    participant API as GraphQL API
    participant NDF as NetworkDocumentFolderService
    participant Matching as ParticipantMatchingService
    participant Queue as Bull Queue
    participant DB as Database
    participant Redis as Redis Cache

    Note over User,Redis: New participant added to network via Data Standard mapping

    User->>React: View network participants
    React->>API: Query networkParticipants(network_id)

    API->>NDF: getNetworkParticipants()
    NDF->>Redis: Check cache (network:123:participants)

    alt Cache Hit
        Redis-->>NDF: Return cached data
        NDF-->>API: Participants list
    else Cache Miss
        NDF->>DB: Query network_participants table
        DB-->>NDF: Network participants

        loop For each participant
            NDF->>DB: Query DSF views (parallel)
            Note over NDF,DB: SELECT * FROM dsf_101_view<br/>SELECT * FROM dsf_102_view<br/>SELECT * FROM dsf_103_view
            DB-->>NDF: DSF view data
        end

        NDF->>NDF: Aggregate & enrich data
        NDF->>NDF: Apply PII filtering
        NDF->>Redis: Cache result (TTL: 5min)
        NDF-->>API: Participants list
    end

    API-->>React: Return participants
    React-->>User: Display participant list

    Note over User,Redis: Background matching process

    NDF->>Queue: Enqueue matching job<br/>(networkId, participantId)
    activate Queue

    Queue->>Matching: Process matching job
    activate Matching

    Matching->>DB: Load participant A
    Matching->>DB: Load all other participants in network

    loop For each other participant
        Matching->>Matching: Calculate match score<br/>- SSN hash match: 45pts<br/>- DOB hash match: 35pts<br/>- Name similarity: 30pts

        alt Score >= 70
            Matching->>DB: Insert into<br/>network_participant_potential_matches
        end
    end

    Matching->>Redis: Invalidate cache<br/>(network:123:participants)
    Matching->>Redis: Publish event<br/>(MATCH_DETECTED_123)

    deactivate Matching
    Queue-->>NDF: Job complete
    deactivate Queue

    Note over React,Redis: Real-time update via subscription

    Redis->>API: Pub/Sub: MATCH_DETECTED_123
    API->>React: WebSocket: matchDetected event
    React->>React: Update UI (show notification)
    React-->>User: "New potential match found!"
```

**Performance Optimizations**:
- Cache hit avoids expensive DSF queries (5-min TTL)
- Parallel DSF view queries across all orgs
- Background job prevents blocking user request
- PII filtering applied before caching

---

### 3b. Real-Time Update Flow

**Purpose**: How updates propagate to all connected clients via WebSocket subscriptions

**Shows**: WebSocket setup → user action → database update → Redis broadcast → all clients receive update

**Source**: [`diagrams/03b-realtime-update-flow.mmd`](diagrams/03b-realtime-update-flow.mmd)

```mermaid
sequenceDiagram
    actor UserA as User A (Org A)
    participant ReactA as React App A
    participant WS as WebSocket Server
    participant API as GraphQL API
    participant Redis as Redis Pub/Sub
    participant DB as Database
    participant ReactB as React App B
    actor UserB as User B (Org B)

    Note over UserA,UserB: Initial subscription setup

    UserA->>ReactA: Opens Network Folder
    ReactA->>WS: WebSocket: CONNECT
    WS-->>ReactA: Connection established

    ReactA->>WS: Subscribe: participantUpdated(network_id: 1)
    WS->>Redis: Subscribe to channel:<br/>PARTICIPANT_UPDATED_1
    WS-->>ReactA: Subscription active

    UserB->>ReactB: Opens Network Folder
    ReactB->>WS: WebSocket: CONNECT
    WS-->>ReactB: Connection established

    ReactB->>WS: Subscribe: participantUpdated(network_id: 1)
    WS->>Redis: Subscribe to channel:<br/>PARTICIPANT_UPDATED_1
    WS-->>ReactB: Subscription active

    Note over UserA,UserB: User A confirms a participant match

    UserA->>ReactA: Click "Confirm Match"
    ReactA->>API: Mutation: confirmParticipantMatch

    API->>DB: Update network_participant<br/>SET match_status = 'confirmed'
    API->>DB: Link sources to participant
    API->>DB: Remove from potential_matches
    API->>DB: Insert audit log entry

    DB-->>API: Success

    API->>Redis: DEL network:1:participants<br/>(invalidate cache)

    API->>Redis: PUBLISH PARTICIPANT_UPDATED_1<br/>{participant, change_type, org_id}

    Note over Redis: Redis broadcasts to all subscribers

    Redis->>WS: Event: PARTICIPANT_UPDATED_1

    par Broadcast to all connected clients
        WS->>ReactA: WebSocket: participantUpdated
        ReactA->>ReactA: Update local cache
        ReactA-->>UserA: UI updates (match confirmed ✓)

        WS->>ReactB: WebSocket: participantUpdated
        ReactB->>ReactB: Update local cache
        ReactB->>ReactB: Show toast notification
        ReactB-->>UserB: "Org A confirmed a match"
    end

    Note over UserA,UserB: Real-time collaboration achieved!
```

**Why Redis Pub/Sub?**
- Enables horizontal scaling (multiple API servers)
- Broadcasts to all subscribers instantly
- Decoupled from WebSocket server
- Reliable message delivery

---

### 3c. PII Filtering Flow

**Purpose**: How PII is filtered based on org permissions

**Shows**: Permission check → cache lookup → field-level filtering → audit logging

**Source**: [`diagrams/03c-pii-filtering-flow.mmd`](diagrams/03c-pii-filtering-flow.mmd)

```mermaid
sequenceDiagram
    actor User as User (Org C)
    participant React as React App
    participant API as GraphQL API
    participant NDF as NetworkDocumentFolderService
    participant PII as NetworkPIIService
    participant Redis as Redis Cache
    participant DB as Database

    Note over User,DB: User from Org C requests participant data

    User->>React: View participant detail
    React->>API: Query: networkParticipant<br/>(network_id: 1, participant_id: 42)

    API->>NDF: getParticipantDetail()
    NDF->>DB: Query network_participant<br/>JOIN network_participant_sources

    DB-->>NDF: Participant with sources from:<br/>- Org A (full PII)<br/>- Org B (partial PII)<br/>- Org C (no PII sharing)

    Note over NDF: Determine requesting org

    NDF->>NDF: Get requesting org_id from context<br/>(Org C)

    NDF->>PII: getPIIPermissions(network_id: 1)
    PII->>Redis: Check cache:<br/>network:1:pii_permissions

    alt Cache Hit
        Redis-->>PII: Return cached permissions
    else Cache Miss
        PII->>DB: Query network_pii_settings<br/>WHERE network_id = 1
        DB-->>PII: PII settings for all orgs
        PII->>PII: Build permissions map:<br/>Org A: [name, dob, ssn_last4]<br/>Org B: [name, dob]<br/>Org C: []
        PII->>Redis: Cache (TTL: 1 hour)
        Redis-->>PII: Cached
    end

    PII-->>NDF: Return permissions map

    loop For each participant source
        alt Source is from requesting org (Org C)
            NDF->>NDF: Show all fields<br/>(can see own data)
        else Source from org with PII sharing
            NDF->>PII: filterPIIFields(source, permissions)

            alt Org A shares full PII
                PII->>PII: Return:<br/>name: "Marcus Johnson"<br/>dob: "1995-03-15"<br/>ssn_last4: "4729"
            else Org B shares partial PII
                PII->>PII: Return:<br/>name: "Marcus Johnson"<br/>dob: "1995-03-15"<br/>ssn_last4: null (masked)
            else Org C shares no PII
                PII->>PII: Return:<br/>name: "● ● ● (PII masked)"<br/>dob: null<br/>ssn_last4: null
            end

            PII-->>NDF: Filtered source data
        end
    end

    Note over NDF,DB: Log PII access for audit

    NDF->>DB: Insert into network_audit_log<br/>{user_id, org_id, action: 'view_participant',<br/>pii_accessed: ['name', 'dob'], ip_address}

    NDF-->>API: Return filtered participant data
    API-->>React: Participant with appropriate PII masking
    React-->>User: Display:<br/>- Org A source: Full PII visible<br/>- Org B source: Name + DOB visible<br/>- Org C source: All PII masked

    Note over User,DB: Privacy preserved across organizational boundaries
```

**Privacy Guarantees**:
- Never expose PII to unauthorized orgs
- Users can always see their own org's data
- All PII access logged for audit trail
- Permissions cached (1-hour TTL) for performance
- Field-level granularity (not all-or-nothing)

---

## 4. Component Hierarchy

**Purpose**: Complete frontend and backend component structure

**Shows**: React component tree (views → organisms → molecules → atoms), backend services, dependencies

**Source**: [`diagrams/04-component-hierarchy.mmd`](diagrams/04-component-hierarchy.mmd)

```mermaid
graph TB
    subgraph "Frontend Components (React)"
        App["App Shell<br/>(Routing)"]

        subgraph "Views (Pages)"
            Dashboard["Dashboard View<br/>- Network overview<br/>- Activity feed<br/>- Quick stats"]
            People["People View<br/>- Participant list<br/>- Match review"]
            Incidents["Incidents View<br/>- Incident list<br/>- Org responses"]
            Referrals["Referrals View<br/>- Referral tracking"]
            Notes["Notes View<br/>- Collaboration notes"]
        end

        subgraph "Organisms (Complex Components)"
            Header["Network Header<br/>- Network selector<br/>- Connection status<br/>- User menu"]
            ParticipantList["Participant List<br/>- Virtual scrolling<br/>- Filters<br/>- Search"]
            MatchReviewModal["Match Review Modal<br/>- Side-by-side comparison<br/>- Score breakdown<br/>- Confirm/Reject actions"]
            IncidentTimeline["Incident Timeline<br/>- Event history<br/>- Multi-org responses"]
            OrgResponseTracker["Org Response Tracker<br/>- Status per org<br/>- Action tracking"]
        end

        subgraph "Molecules (Composite Components)"
            ParticipantCard["Participant Card<br/>- Avatar<br/>- Name + PII<br/>- Match status"]
            IncidentCard["Incident Card<br/>- Severity badge<br/>- Participants<br/>- Org count"]
            FilterBar["Filter Bar<br/>- Multiple filters<br/>- Clear all"]
            SearchInput["Search Input<br/>- Debounced<br/>- Clear button"]
        end

        subgraph "Atoms (Basic Components)"
            Button["Button<br/>- Variants<br/>- Sizes<br/>- Icons"]
            Badge["Badge<br/>- Status colors<br/>- Severity levels"]
            StatusDot["Status Dot<br/>- Connected/syncing"]
            PIIToggle["PII Toggle<br/>- Show/hide switch"]
        end

        subgraph "Hooks (State & Logic)"
            useParticipants["useNetworkParticipants<br/>- Fetch + cache<br/>- Real-time updates"]
            useSubscription["useParticipantSubscription<br/>- WebSocket connection<br/>- Event handling"]
            usePII["usePIIPermissions<br/>- Check visibility<br/>- Filter fields"]
            useConnection["useConnectionStatus<br/>- Monitor WS<br/>- Reconnect logic"]
        end

        subgraph "GraphQL (Relay)"
            Queries["Queries<br/>- NetworkParticipantsQuery<br/>- NetworkIncidentsQuery<br/>- PotentialMatchesQuery"]
            Mutations["Mutations<br/>- ConfirmMatchMutation<br/>- CreateIncidentMutation<br/>- UpdateResponseMutation"]
            Subscriptions["Subscriptions<br/>- ParticipantUpdatedSub<br/>- IncidentUpdatedSub<br/>- MatchDetectedSub"]
        end
    end

    subgraph "Backend Services (Node.js)"
        subgraph "GraphQL Layer"
            ApolloServer["Apollo Server<br/>- HTTP endpoint<br/>- WebSocket endpoint"]
            TypeDefs["Type Definitions<br/>- Schema<br/>- Enums<br/>- Interfaces"]
            Resolvers["Resolvers<br/>- Queries<br/>- Mutations<br/>- Subscriptions"]
        end

        subgraph "Application Services"
            NDFService["NetworkDocumentFolderService<br/>- Orchestration<br/>- DSF enrichment<br/>- Cache management"]
            MatchService["ParticipantMatchingService<br/>- Scoring algorithm<br/>- Hash generation<br/>- Match detection"]
            PIIService["NetworkPIIService<br/>- Permission checks<br/>- Field filtering<br/>- Audit logging"]
            CacheService["NetworkCacheService<br/>- Multi-tier cache<br/>- Invalidation<br/>- TTL management"]
            EventService["NetworkEventService<br/>- Redis Pub/Sub<br/>- Event broadcasting"]
        end

        subgraph "Repository Layer"
            Models["Sequelize Models<br/>- NetworkParticipant<br/>- NetworkIncident<br/>- NetworkReferral<br/>- etc."]
            Queries["Repository Queries<br/>- Raw SQL<br/>- DSF view queries<br/>- Cross-tenant joins"]
        end

        subgraph "Infrastructure"
            Redis["Redis Client<br/>- Cache operations<br/>- Pub/Sub channels"]
            BullQueue["Bull Queue<br/>- Background jobs<br/>- Matching worker"]
        end
    end

    %% Frontend relationships
    App --> Dashboard
    App --> People
    App --> Incidents
    App --> Referrals
    App --> Notes

    Dashboard --> Header
    People --> Header
    People --> ParticipantList
    People --> MatchReviewModal

    Incidents --> IncidentTimeline
    Incidents --> OrgResponseTracker

    ParticipantList --> ParticipantCard
    ParticipantList --> FilterBar
    ParticipantList --> SearchInput

    MatchReviewModal --> ParticipantCard
    MatchReviewModal --> Button
    MatchReviewModal --> Badge

    FilterBar --> Button
    SearchInput --> Button

    ParticipantCard --> Badge
    ParticipantCard --> StatusDot
    ParticipantCard --> PIIToggle

    %% Frontend hooks
    People --> useParticipants
    People --> useSubscription
    ParticipantCard --> usePII
    Header --> useConnection

    %% Frontend GraphQL
    useParticipants --> Queries
    MatchReviewModal --> Mutations
    useSubscription --> Subscriptions

    %% Backend relationships
    Queries --> ApolloServer
    Mutations --> ApolloServer
    Subscriptions --> ApolloServer

    ApolloServer --> TypeDefs
    ApolloServer --> Resolvers

    Resolvers --> NDFService
    Resolvers --> MatchService
    Resolvers --> PIIService

    NDFService --> MatchService
    NDFService --> PIIService
    NDFService --> CacheService
    NDFService --> EventService

    NDFService --> Models
    NDFService --> Queries

    MatchService --> Models
    PIIService --> Models

    CacheService --> Redis
    EventService --> Redis
    MatchService --> BullQueue

    %% Styling
    classDef frontend fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef backend fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef service fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef infra fill:#fce4ec,stroke:#880e4f,stroke-width:2px

    class App,Dashboard,People,Incidents,Referrals,Notes,Header,ParticipantList,MatchReviewModal,IncidentTimeline,OrgResponseTracker,ParticipantCard,IncidentCard,FilterBar,SearchInput,Button,Badge,StatusDot,PIIToggle,useParticipants,useSubscription,usePII,useConnection,Queries,Mutations,Subscriptions frontend

    class ApolloServer,TypeDefs,Resolvers backend

    class NDFService,MatchService,PIIService,CacheService,EventService,Models,Queries service

    class Redis,BullQueue infra
```

**Architectural Patterns**:
- **Atomic Design**: Components organized by complexity (atoms → molecules → organisms → templates → pages)
- **Custom Hooks**: Encapsulate state management and side effects
- **Relay**: GraphQL client with built-in caching and normalization
- **Service Layer**: Business logic separated from data access
- **Repository Pattern**: SQL queries isolated from business logic

---

## 5. State Machine Diagrams

### 5a. Participant Match States

**Purpose**: State machine for participant matching lifecycle

**Shows**: New participant → matching → verification → confirmation (all possible states and transitions)

**Source**: [`diagrams/05a-participant-match-states.mmd`](diagrams/05a-participant-match-states.mmd)

```mermaid
stateDiagram-v2
    [*] --> PendingVerification: New participant<br/>added to network

    PendingVerification --> MatchingInProgress: Background job<br/>starts matching

    MatchingInProgress --> NoMatchFound: Match score < 70
    MatchingInProgress --> PotentialMatch: Match score 70-89
    MatchingInProgress --> HighConfidence: Match score >= 90

    NoMatchFound --> UniqueParticipant: Create as<br/>standalone participant
    UniqueParticipant --> [*]: Active participant

    PotentialMatch --> UnderReview: User views<br/>comparison

    UnderReview --> MatchConfirmed: User clicks<br/>"Confirm Match"
    UnderReview --> MatchRejected: User clicks<br/>"Reject Match"
    UnderReview --> FlaggedForReview: User clicks<br/>"Needs Review"

    HighConfidence --> UnderReview: Requires human<br/>confirmation<br/>(never auto-merge)

    MatchConfirmed --> Linked: Link sources to<br/>network participant
    Linked --> AuditLogged: Log confirmation<br/>in audit trail
    AuditLogged --> CacheInvalidated: Invalidate network<br/>participant cache
    CacheInvalidated --> EventPublished: Publish<br/>PARTICIPANT_UPDATED
    EventPublished --> [*]: Active matched<br/>participant

    MatchRejected --> RejectionLogged: Log rejection<br/>with reason
    RejectionLogged --> SeparateParticipants: Create separate<br/>network participants
    SeparateParticipants --> [*]: Active as<br/>distinct participants

    FlaggedForReview --> AdminNotified: Notify network<br/>admin
    AdminNotified --> UnderReview: Admin reviews

    note right of MatchingInProgress
        Scoring Algorithm:
        - SSN hash match: 45 points
        - DOB hash match: 35 points
        - Name similarity: 30 points
        Total: 0-110 points
    end note

    note right of MatchConfirmed
        Actions on confirmation:
        1. Update match_status = 'confirmed'
        2. Link sources to participant
        3. Remove from potential_matches
        4. Insert audit log entry
        5. Invalidate cache
        6. Publish real-time event
    end note

    note right of UnderReview
        User sees:
        - Side-by-side comparison
        - Score breakdown
        - Matching fields highlighted
        - PII (if permission granted)
    end note
```

**Critical Design Decision**: Even matches with 95+ score require human confirmation. This prevents false positives which are worse than missed matches.

---

### 5b. Incident Response Workflow

**Purpose**: Multi-org incident response tracking

**Shows**: Incident reported → notification → parallel org responses → resolution

**Source**: [`diagrams/05b-incident-response-workflow.mmd`](diagrams/05b-incident-response-workflow.mmd)

```mermaid
stateDiagram-v2
    [*] --> Reported: Org reports<br/>new incident

    Reported --> NotificationSent: Publish to<br/>all network members

    NotificationSent --> MultiOrgResponse: All orgs see incident

    state MultiOrgResponse {
        [*] --> NotStarted

        NotStarted --> InProgress: Org begins<br/>response

        InProgress --> InProgress: Update actions:<br/>- Plan actions<br/>- Current work<br/>- Completed work

        InProgress --> Complete: All actions<br/>completed

        Complete --> [*]

        note right of InProgress
            Each org tracks:
            - Planned actions (JSON)
            - Current actions (JSON)
            - Completed actions (JSON)
            - Last updated timestamp
        end note
    }

    MultiOrgResponse --> AllOrgsResponded: Check if all orgs<br/>have responded

    AllOrgsResponded --> IncidentResolved: All orgs marked<br/>as complete

    IncidentResolved --> Archived: Archive after<br/>30 days

    Archived --> [*]

    state "Incident Status Checks" as StatusChecks {
        Critical --> NotificationImmediate: Send email +<br/>push notification
        High --> NotificationImmediate
        Medium --> NotificationPassive: Show in feed only
        Low --> NotificationPassive

        note right of Critical
            Severity Levels:
            - Critical: Immediate threat
            - High: Urgent response needed
            - Medium: Needs attention
            - Low: Informational
        end note
    }

    Reported --> StatusChecks: Determine<br/>notification strategy
    StatusChecks --> NotificationSent

    state "Parallel Org Responses" as ParallelResponses {
        state "Org A Response" as OrgA {
            [*] --> A_NotStarted
            A_NotStarted --> A_InProgress
            A_InProgress --> A_Complete
            A_Complete --> [*]
        }

        state "Org B Response" as OrgB {
            [*] --> B_NotStarted
            B_NotStarted --> B_InProgress
            B_InProgress --> B_Complete
            B_Complete --> [*]
        }

        state "Org C Response" as OrgC {
            [*] --> C_NotStarted
            C_NotStarted --> C_InProgress
            C_InProgress --> C_Complete
            C_Complete --> [*]
        }

        note right of OrgA
            Each org independently
            tracks their response
            without blocking others
        end note
    }

    MultiOrgResponse --> ParallelResponses: Track responses<br/>per org
    ParallelResponses --> AllOrgsResponded

    note right of MultiOrgResponse
        Real-time updates:
        - Org A updates → broadcast to all
        - Org B sees update instantly
        - No page refresh needed
    end note

    note left of IncidentResolved
        Resolution criteria:
        - All orgs marked complete
        - OR manually closed by lead org
        - OR auto-closed after 90 days
    end note
```

**Multi-Org Coordination**: Each organization tracks their own response independently without blocking others. Real-time updates keep everyone synchronized.

---

## Color Coding Legend

All diagrams use consistent color coding:

- 🔵 **Blue** (`#e1f5ff`): Client/Frontend components
- 🟠 **Orange** (`#fff3e0`): API layer (GraphQL HTTP/WebSocket)
- 🟣 **Purple** (`#f3e5f5`): Application services (business logic)
- 🟢 **Green** (`#e8f5e9`): Data layer (databases, models)
- 🔴 **Pink** (`#fce4ec`): Infrastructure (Redis, queues)

---

## Viewing Options

### Option 1: GitHub (Easiest)
Just view this file on GitHub - diagrams render automatically!

### Option 2: VS Code
1. Install **Mermaid Preview** extension
2. Open this file or any `.mmd` file
3. Right-click → "Open Preview"

### Option 3: Mermaid Live Editor
1. Go to https://mermaid.live/
2. Copy/paste diagram code
3. Export as PNG/SVG

### Option 4: Export to Images
```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Export all diagrams
cd diagrams/
for file in *.mmd; do
  mmdc -i "$file" -o "exports/${file%.mmd}.png" -b transparent
done
```

---

## Source Files

All diagrams are also available as standalone Mermaid files in [`diagrams/`](diagrams/):

- `01-system-architecture.mmd`
- `02-database-er-diagram.mmd`
- `03a-participant-matching-flow.mmd`
- `03b-realtime-update-flow.mmd`
- `03c-pii-filtering-flow.mmd`
- `04-component-hierarchy.mmd`
- `05a-participant-match-states.mmd`
- `05b-incident-response-workflow.mmd`

---

**Created**: March 26, 2025
**Last Updated**: March 26, 2025
**Maintainer**: Development Team

For questions about these diagrams, see:
- [`README.md`](../README.md) - Project overview
- [`ARCHITECTURE.md`](ARCHITECTURE.md) - Detailed architecture documentation
- [`IMPLEMENTATION_SUMMARY.md`](../IMPLEMENTATION_SUMMARY.md) - Implementation plan
