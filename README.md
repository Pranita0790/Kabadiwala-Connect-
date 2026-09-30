# Kabadiwala Connect

> Turning informal waste collection into a connected, traceable, AI-assisted recycling workflow.

Kabadiwala Connect is an offline-first digital platform connecting waste collectors and recyclers through structured material collection, AI-assisted material classification, indicative value estimation, critical-mineral intelligence, and digital traceability.

The system combines a Flutter Collector App, Node.js/Express backend gateway, FastAPI AI service, and MobileNetV3-Small computer vision model.

**Built for Smart India Hackathon 2026.**

**Public demo:** [kabadiwala-connect-xi.vercel.app](https://kabadiwala-connect-xi.vercel.app/)

**Collector APK:** [Download v1.1.0](https://github.com/Pranita0790/Kabadiwala-Connect-/releases/tag/v1.1.0)

---

## Why Kabadiwala Connect

Informal waste collection is often dependent on manual material identification, fragmented records, inconsistent valuation, and limited visibility between collectors and recyclers.

A collector may identify a material manually and sell it based on local rates, while downstream recyclers may have limited structured information about where the material came from, what it was classified as, or how the lot was recorded.

Kabadiwala Connect addresses this workflow by bringing collection, material intelligence, indicative valuation, and traceability into one digital system.

The platform is also designed around a practical constraint of field environments: **connectivity cannot always be assumed.**

---

## What Kabadiwala Connect Does

### 📱 Collector App

The Flutter-based Collector App allows field workers to:

- Create material lots
- Capture material information
- Capture images for AI analysis
- Receive AI-assisted material classification
- View classification confidence
- Check critical-mineral relevance
- Record quantity and indicative value
- Store records locally when offline
- Maintain records in `PENDING_SYNC` state
- Synchronize records when connectivity becomes available

### 🤖 AI Material Intelligence

The Collector App sends image-analysis requests through the Node.js backend gateway to the FastAPI AI service.

The current deployed model is:

- **Architecture:** MobileNetV3-Small
- **Framework:** PyTorch
- **Model version:** `sih-5class-v1`
- **Confidence threshold:** `0.60`

Currently deployed classes:

```text
PCB
Battery
CRT
LCD Panel
Cable
🔎 Critical-Mineral Intelligence

After material classification, a rule-based intelligence layer evaluates whether the identified material has potential critical-mineral relevance.

This provides decision-support intelligence for downstream handling and prioritization.

It is not intended to replace laboratory-grade material or chemical analysis.

💰 Indicative Value Estimation

The system combines material information, quantity, and available rate information to calculate an indicative value.

The result is an estimate for workflow support rather than a guaranteed market transaction price.

🔗 Traceability

Material information is structured into digital lot records so that collection information can be connected to downstream recycler workflows.

Why This Is Different

Kabadiwala Connect is not only an image-classification application.

The project connects four practical layers:

1. Offline-first collection

The Collector App uses local SQLite persistence so that material records can be created even when connectivity is unavailable.

2. Gateway-based AI architecture

The mobile application does not directly communicate with the Python AI service.

The production flow is:

Flutter Collector
       ↓
Node.js / Express Gateway
       ↓
FastAPI AI Service
       ↓
MobileNetV3-Small
       ↓
Material Intelligence

This keeps the client application separated from the internal AI service.

3. Material intelligence beyond classification

The AI prediction is used as an input to additional workflow logic such as:

Confidence evaluation
Critical-mineral relevance
Indicative value estimation
Traceability
4. Research-backed dataset workflow

The project includes dataset auditing, class compatibility analysis, curated training crops, contact sheets, and class-specific research.

Dataset processing tools are organized under:

scripts/dataset/
## Architecture

### Architecture Principle

The Node.js/Express backend is the primary application gateway.

The production Flutter application does not directly depend on the FastAPI service.

```mermaid
flowchart TB

    C["Collector App<br/>Flutter + SQLite"]

    B["Node.js / Express<br/>Backend Gateway"]

    AI["FastAPI<br/>AI Service"]

    M["MobileNetV3-Small<br/>PyTorch Model"]

    MC["Material<br/>Classification"]

    CM["Critical-Mineral<br/>Rule Engine"]

    VE["Indicative Value<br/>Estimation"]

    L["Traceable<br/>Lot Record"]

    R["Recycler Dashboard<br/>React + Vite"]

    C -->|"HTTPS / REST"| B
    B -->|"AI Request"| AI
    AI --> M
    M --> MC
    MC --> CM
    CM --> VE
    VE --> B
    B --> L
    L --> C

    R -->|"REST API"| B
    B --> R
AI Pipeline

The complete AI flow is:

Image Capture
     ↓
Flutter Collector App
     ↓
Node.js / Express
     ↓
FastAPI
     ↓
Image Preprocessing
     ↓
MobileNetV3-Small
     ↓
Material Classification
     ↓
Confidence
     ↓
Critical-Mineral Rules
     ↓
Indicative Value Logic
     ↓
Node.js Backend
     ↓
Collector App
Verified Integration

The AI pipeline has been tested through the real gateway path:

Node.js
   ↓
FastAPI
   ↓
MobileNetV3-Small
   ↓
Prediction
   ↓
FastAPI
   ↓
Node.js

A real PCB image was tested and produced approximately:

Material: PCB
Confidence: ~97.5%
Critical Mineral: true
Model Version: sih-5class-v1

The same AI result was also verified through the Node.js gateway.

Offline-First Workflow

The field workflow is designed around intermittent connectivity.

              Create Material Lot
                       │
                       ▼
              Store in Local SQLite
                       │
                       ▼
                  PENDING_SYNC
                       │
              ┌────────┴────────┐
              │                 │
        No Connectivity    Connectivity
              │                 │
              │                 ▼
              │             Synchronize
              │                 │
              └────────────┬────┘
                           ▼
                      Synced Record

This allows the collector workflow to continue without requiring continuous internet access.

Recycler Dashboard

The project includes a React-based Recycler Dashboard.

Current areas include:

Rate Board
Traceability
Material-related recycler workflows

The dashboard is currently a working UI prototype.

Some lot and transaction information is backed by mock or in-memory backend data as part of the SIH prototype.

Product Walkthrough

A typical demonstration flow is:

Open the Collector App.
Create a material lot.
Capture or select a material image.
Send the image through the Node.js AI gateway.
Run real MobileNetV3-Small inference through FastAPI.
Display the material and confidence.
Apply critical-mineral intelligence.
Calculate indicative value.
Store the lot locally.
Demonstrate the Recycler Dashboard and traceability workflow.

The Android Collector App is available through the GitHub release:

Download Kabadiwala Connect v1.1.0

Technology
Collector
Flutter
Dart
SQLite
sqflite
http
Backend
Node.js
Express.js
Axios
Multer
Jest
AI / ML
Python
FastAPI
PyTorch
torchvision
MobileNetV3-Small
Pillow
Recycler Dashboard
React
TypeScript
Vite
CSS
Deployment
Vercel — Recycler Dashboard
Render — Backend API
GitHub Releases — Collector APK
API
Node.js AI Gateway
POST /api/ai/analyze

Receives the image from the application and forwards the request to the FastAPI AI service.

FastAPI AI Service
POST /api/v1/analyze

Performs image analysis and material classification.

Health Check
GET /health
Backend API

The deployed backend is available at:

kabadiwala-backend-69wr.onrender.com/api

Testing

The Node.js AI gateway has been verified using Jest:

Test Suites: 1 passed
Tests:       6 passed
Failures:    0

The FastAPI service has also been verified through its health endpoint and real image inference.

The complete AI gateway path has been tested using a real PCB image.

Dataset & Research

The project includes a dedicated dataset research and curation workflow.

The research pipeline includes:

Public dataset source auditing
Class compatibility analysis
Dataset split inspection
Training crop generation
Contact-sheet generation
Class-specific auditing
Training-data curation

Dataset processing scripts are organized under:

scripts/dataset/

Research documentation is available under:

docs/research/
Deployed Model Classes

The currently deployed sih-5class-v1 model contains:

PCB
Battery
CRT
LCD Panel
Cable

The broader research and dataset pipeline may contain additional classes that are not currently deployed in this model.

Current Implementation Status
Implemented
Flutter Collector UI
Camera/image workflow
Local SQLite persistence
PENDING_SYNC state
Node.js / Express backend gateway
FastAPI AI service
PyTorch MobileNetV3-Small inference
Real Node.js → FastAPI AI integration
Material classification
Critical-mineral rule engine
Indicative value estimation
Recycler Dashboard prototype
Dataset research and curation tooling
Backend AI gateway tests
Android v1.1.0 release
Future Scope
PostgreSQL-backed production persistence
Production authentication and authorization
Automatic background synchronization
Expanded AI material classes
Larger and more diverse training datasets
Production-grade recycler workflows
Advanced price discovery
EPR workflow integration
Expanded analytics and traceability
Limitations / Non-goals

The current implementation is an SIH prototype, not a production deployment.

The deployed AI model currently supports five material classes.
Some recycler lot and transaction data is mocked or stored in-memory.
PostgreSQL is planned but is not currently connected to production routes.
Authentication and role-based access control are future scope.
Indicative values depend on available material-rate information.
Critical-mineral identification is rule-based and does not replace laboratory analysis.
AI performance can vary with image quality, lighting, viewpoint, and material condition.
Automatic background synchronization is planned for a future release.
Local Development
Backend

From the repository root:

cd services/backend
npm install
npm start

The backend runs on port 5000.

AI Service

In a second terminal:

cd services/ai-service
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

The FastAPI service runs on port 8000.

Collector App

In another terminal:

cd apps/collector
flutter pub get
flutter run

The Flutter application communicates through the Node.js backend gateway.

Demo Links
🌐 Recycler Dashboard

Open the Recycler Dashboard

📱 Collector App

Download Collector App v1.1.0

⚙️ Backend API

Open Backend API

💻 GitHub Repository

View GitHub Repository

Repository Structure
Kabadiwala Connect/
│
├── apps/
│   ├── collector/
│   └── recycler-dashboard/
│
├── services/
│   ├── backend/
│   └── ai-service/
│
├── packages/
│   └── shared/
│
├── data/
│   ├── raw/
│   ├── processed/
│   ├── seed/
│   └── external/
│
├── scripts/
│   └── dataset/
│
├── docs/
│   ├── architecture/
│   ├── api/
│   ├── database/
│   └── research/
│
├── tests/
│   ├── integration/
│   └── e2e/
│
├── README.md
├── AGENTS.md
└── CONTRIBUTING.md
Smart India Hackathon 2026

Kabadiwala Connect is built for Smart India Hackathon 2026.

The project focuses on improving waste-collection workflows through:

Offline-first technology
AI-assisted material identification
Material intelligence
Critical-mineral awareness
Indicative value estimation
Digital traceability
Collector–recycler connectivity

The prototype demonstrates how field-level collection data can be transformed into structured digital material intelligence while remaining usable in connectivity-constrained environments.

Status

Kabadiwala Connect is a Smart India Hackathon 2026 prototype with an implemented collector workflow, offline persistence, real AI classification pipeline, Node.js gateway, FastAPI service, critical-mineral intelligence, indicative value estimation, and deployed demonstration interfaces.