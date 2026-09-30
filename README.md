# Kabadiwala Connect

### Offline-First Digital Platform for Waste Collection, Material Intelligence & Traceability

Kabadiwala Connect is an offline-first digital platform designed to connect waste collectors and recyclers through structured digital material collection, AI-assisted material classification, indicative value estimation, critical-mineral flagging, and traceable lot records.

The system combines a Flutter-based Collector App, Node.js/Express backend gateway, FastAPI AI service, and a lightweight MobileNetV3-Small computer-vision model.

Built for **Smart India Hackathon 2026**.

---

## Problem

Informal waste collection and e-waste recycling often rely on manual identification, paper-based records, local relationships, and inconsistent price discovery.

This creates challenges such as:

- Limited material identification support
- Low price transparency
- Fragmented transaction records
- Difficulty maintaining traceability
- Poor connectivity in collection environments
- Limited visibility for downstream recyclers
- Difficulty identifying potentially valuable or critical-material-bearing waste

---

## Solution

Kabadiwala Connect provides a connected digital workflow for collectors and recyclers.

### Collector

The Collector App allows users to:

- Capture waste/material information
- Store records locally when connectivity is unavailable
- Create structured material lots
- Use AI-assisted image classification
- Receive confidence-based material predictions
- Generate traceable lot records
- Synchronize data when connectivity is available

### Recycler

The Recycler Dashboard provides a web interface for viewing and working with collected lot information.

---

## Key Features

### 1. Offline-First Collection

The Flutter application stores lot information locally using SQLite.

Records can remain in a pending synchronization state when connectivity is unavailable.

### 2. AI-Assisted Material Classification

Images are sent through the backend gateway to the FastAPI AI service.

The current deployed AI model uses **MobileNetV3-Small** for classification across five material categories:

- PCB
- Battery
- CRT
- LCD Panel
- Cable

A confidence threshold is used to avoid accepting low-confidence predictions as known material classifications.

### 3. Critical-Mineral Flagging

A rule-based engine evaluates the identified material and generates a critical-mineral flag where applicable.

This provides an additional intelligence layer beyond simple image classification.

### 4. Indicative Value Estimation

The system provides material/weight-based indicative value estimation to support transparent collection and transaction workflows.

### 5. Traceable Lot Records

Collected materials are represented as structured lots with unique identifiers, enabling digital tracking of collection records.

### 6. Backend AI Gateway

The production application architecture keeps the Flutter application separated from the Python AI service.

The mobile application communicates with the Node.js backend, which acts as the gateway to the AI service.

---

## System Architecture

```text
                    ┌──────────────────────────┐
                    │   Collector Mobile App   │
                    │      Flutter + Dart      │
                    │                          │
                    │   SQLite / Offline Data  │
                    └────────────┬─────────────┘
                                 │
                                 │ REST API
                                 ▼
                    ┌──────────────────────────┐
                    │   Node.js + Express       │
                    │      Backend Gateway      │
                    │                          │
                    │   AI Gateway + Lot APIs  │
                    └────────────┬─────────────┘
                                 │
                                 │ Image Analysis API
                                 ▼
                    ┌──────────────────────────┐
                    │    FastAPI AI Service    │
                    │                          │
                    │ Image Validation         │
                    │ Material Analysis        │
                    │ Rule Engine              │
                    │ Value Estimation         │
                    └────────────┬─────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │    MobileNetV3-Small     │
                    │    PyTorch Model         │
                    │                          │
                    │     5 Material Classes   │
                    └──────────────────────────┘


                    ┌──────────────────────────┐
                    │    Recycler Dashboard    │
                    │      React + Vite        │
                    └────────────┬─────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │   Node.js / Express API  │
                    └──────────────────────────┘