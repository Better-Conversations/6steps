# Architecture Overview

This document describes the technical architecture of Six Steps.

## System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
│  (Turbo Frames + Stimulus Controllers + Tailwind CSS)           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         CONTROLLERS                             │
│  JourneySessionsController │ ConsentsController │ AdminController│
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CORE SERVICES                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Conversation    │  │ Safety          │  │ Question        │  │
│  │ Engine          │◄─┤ Monitor         │  │ Generator       │  │
│  │ (orchestrates)  │  │ (deterministic) │  │ (clean lang)    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│                       ┌─────────────────┐                        │
│                       │ Crisis          │                        │
│                       │ Resources       │                        │
│                       │ (UK/US/EU/AU)   │                        │
│                       └─────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                          MODELS                                 │
│  User │ JourneySession │ SessionIteration │ Consent │ Invite    │
│  SafetyAuditLog (compliance trail)                              │
│                                                                 │
│  Encrypted fields: email, responses, session content            │
│  Audited with: PaperTrail                                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    POSTGRESQL + ENCRYPTION                      │
│            Active Record Encryption (AES-256-GCM)               │
└─────────────────────────────────────────────────────────────────┘
```

## Core Services

| Service | Purpose | Key Characteristic |
|---------|---------|-------------------|
| `SafetyMonitor` | Crisis detection, depth scoring | **Deterministic** (regex-based, NOT AI) |
| `ConversationEngine` | Session flow orchestration | State machine integration |
| `QuestionGenerator` | Clean language questions | Reflects user's own words |
| `CrisisResources` | Helpline data by region | UK, US, EU, AU support |

## Safety Thresholds

| Score | Level | Action |
|-------|-------|--------|
| 0.0-0.3 | GREEN | Continue normally |
| 0.3-0.5 | AMBER | Insert grounding exercise |
| 0.5-0.7 | AMBER-RED | Suggest pause, show resources |
| 0.7-0.9 | RED | Redirect to integration phase |
| 0.9+ | DEEP RED | Show resources |

## Data Flow

1. User submits response → `JourneySessionsController`
2. Controller calls `ConversationEngine.process_response`
3. Engine invokes `SafetyMonitor.assess(text)`
4. SafetyMonitor returns depth score + any crisis flags
5. Based on score, engine decides: continue / ground / pause / escalate
6. All safety events logged to `SafetyAuditLog` (anonymized)

## Key Files

```
app/services/
├── safety_monitor.rb      # Crisis detection (COMPLIANCE-CRITICAL)
├── conversation_engine.rb # Session orchestration
├── question_generator.rb  # Clean language questions
└── crisis_resources.rb    # Regional helplines (USER-SAFETY)

app/models/
├── journey_session.rb     # Session state machine
├── consent.rb             # GDPR consent tracking
└── safety_audit_log.rb    # Compliance audit trail
```

## Why No AI

The system deliberately uses **deterministic rule-based processing** to:

1. Avoid EU AI Act High-Risk classification (Annex III, Section 5)
2. Ensure fully auditable, predictable behaviour
3. Enable exhaustive safety testing
4. Maintain session oversight capability

If AI features are ever considered, see `COMPLIANCE.md` Section 4 for mandatory steps.
