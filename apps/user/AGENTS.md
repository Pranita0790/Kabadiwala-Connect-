# Project Development Rules - Kabadiwala Connect (SIH26229)

This repository contains the collector-facing mobile application for SIH26229 — **“Kabadiwala Connect – Bringing the Informal Collector into the Formal Recycling Chain”**.

All AI agents and developers working on this project MUST strictly follow these rules:

## Technology Stack & Scope
- **Framework**: Flutter / Dart project.
- **Target Audience**: Informal e-waste collectors (kabadiwalas) with low digital literacy, limited English proficiency, and entry-level Android devices.
- **AI Integration**: AI/ML models are consumed through remote APIs; AI model training or model execution MUST NOT be implemented inside the Flutter app.

## Offline-First Architecture & Data Integrity
- **Offline-First Architecture**: The app must remain fully functional when internet connectivity is poor or unavailable.
- **Local Persistence**: Use SQLite (`sqflite`) as the primary local database.
- **Local-First Writes**: Every user-created record must be saved locally to SQLite BEFORE attempting network synchronization.
- **Unique Primary Keys**: Every locally created record must be assigned a unique client-side ID (UUID v4).
- **Synchronization State Machine**: Material lots and local records must track sync states explicitly: `PENDING_SYNC` → `SYNCING` → `SYNCED` | `FAILED`.

## Layer Separation & Code Quality
- **Separation of Concerns**: UI widgets MUST be kept strictly focused on presentation and user interaction. Business logic, SQLite queries, and API calls MUST NEVER be placed directly inside UI widgets.
- **Repository / Service Layer**: Keep database operations in a dedicated repository/DAO layer and API calls inside an API service.
- **API Contracts & Mocking**: Do not invent backend API endpoints. Use mock data for network services until official API contracts are finalized.
- **Maintainable Code**: Prefer simple, readable, and maintainable code over unnecessary abstractions or overly complex architecture.

## UX & Accessibility Guidelines
- **Low-Literacy Friendly UX**: Design for low-literacy users using clear visual icons, visual categories, and audio playback (Text-To-Speech) for price readouts.
- **Touch Targets**: Use large touch targets (minimum height 54px/56px) and high-contrast visuals suitable for small screens and field use.
- **No Hardcoded Strings**: NEVER hardcode user-facing strings in UI widgets. Use Flutter localization (`l10n`) supporting **English (`en`)**, **Hindi (`hi`)**, and **Marathi (`mr`)**.

## Quality Assurance & Verification
- **Verification**: Run static analysis (`flutter analyze`) and unit tests after significant changes to verify code quality.
