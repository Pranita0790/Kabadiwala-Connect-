# Kabadiwala Connect — Engineering Rules
## 0. Non-Negotiable Team Control

The Team Lead is the final authority for repository changes.

AI assistants are implementation assistants, not repository owners.

No AI assistant has implicit permission to perform Git write operations.

No code-generation request grants Git write permission.

Repository architecture, API contracts, database schema, security,
and Git operations must not be changed autonomously by AI.

## 1. Project Goal

Kabadiwala Connect is an offline-first digital platform connecting waste collectors,
recyclers, material intelligence, price discovery, traceability, earnings tracking,
and critical-mineral/EPR workflows.

The system contains:

- Collector Flutter mobile application
- Recycler React web dashboard
- Python AI/ML service
- Node.js + Express backend
- PostgreSQL database
- Shared API/data contracts
- Dataset and research documentation

---

## 2. Architecture Rules

Follow this high-level architecture:

Collector App
    ↓
Node.js Backend
    ↓
Python AI Service
    ↓
PostgreSQL

Recycler Dashboard
    ↓
Node.js Backend
    ↓
PostgreSQL

The backend is the primary application gateway.

Do not make the production Flutter application depend directly on
the Python AI service.

---

## 3. Repository Structure

- `apps/collector` → Flutter collector application
- `apps/recycler-dashboard` → React recycler dashboard
- `services/ai-service` → Python AI/ML service
- `services/backend` → Node.js + Express backend
- `packages/shared` → shared contracts/utilities where appropriate
- `docs` → architecture, API, database, and research documentation
- `data` → datasets and seed data
- `scripts` → development/automation scripts
- `tests` → integration and end-to-end tests

Do not place application code randomly in the repository root.

---

## 4. Ownership Boundaries

Respect the responsibility of each application/service.

### Collector App

Responsible for:

- Collector-facing UI
- Material capture
- Camera flow
- Material analysis result display
- Price information
- Recycler discovery
- QR workflow
- Earnings ledger
- Offline storage
- Background synchronization
- Hindi/Marathi/localized user experience

### Recycler Dashboard

Responsible for:

- Recycler-facing UI
- QR handover confirmation
- Lot management
- Rates
- Ledger confirmation
- Critical-material visibility
- Pickup scheduling

### AI Service

Responsible for:

- Material classification
- Critical mineral detection/rules
- Price estimation support
- Recycler recommendation support
- Anomaly detection
- AI model inference

### Backend

Responsible for:

- REST APIs
- Authentication/authorization
- Business rules
- PostgreSQL persistence
- Synchronization
- Conflict resolution
- Traceability records
- EPR-related records

---

## 5. API Contract Rule

The API contract is shared infrastructure.

Before changing:

- endpoint names
- request fields
- response fields
- authentication requirements
- status values
- database identifiers

update:

`docs/api/api-contract.md`

Do not silently break another team's integration.

---

## 6. Flutter Rules

The Collector app must remain offline-first.

Use this conceptual flow:

UI
 ↓
Controller/ViewModel
 ↓
Repository
 ↓
Local Database / Remote API
 ↓
Sync Manager

Do not put API calls directly inside UI widgets.

Core collector workflows must remain usable without an internet connection
where the product requirements allow it.

Avoid unnecessarily memory-heavy dependencies.

Compress/resize captured images before storing or uploading them.

---

## 7. AI/ML Rules

AI output must be treated as an inference, not absolute truth.

For critical minerals, do not claim that a photograph proves the exact
elemental composition of a material.

Use appropriate wording such as:

"Potential critical mineral detected"

when the system is using category/rule-based inference.

Document model limitations and dataset limitations.

Do not commit large trained model binaries or raw datasets unless
explicitly approved.

---

## 8. Database Rules

Database schema changes require documentation.

Before changing tables, fields, relationships, or indexes:

1. Update `docs/database/schema.md`
2. Consider migration requirements
3. Check API impact
4. Check frontend/mobile impact

Never delete production data through development scripts.

---

## 9. Security Rules

Never commit:

- passwords
- API keys
- JWT secrets
- database credentials
- private tokens
- `.env` files containing secrets

Use environment variables.

If a secret is accidentally exposed, stop and report it immediately.

---

## 10. Git Rules — Team Lead Controlled

Git operations are controlled by the Team Lead.

### Absolute AI restrictions

AI coding assistants MUST NOT execute any of the following commands
unless the Team Lead explicitly requests that exact Git operation:

- `git commit`
- `git push`
- `git pull`
- `git fetch`
- `git merge`
- `git rebase`
- `git reset`
- `git revert`
- `git cherry-pick`
- `git branch -D`
- `git checkout` when it changes/switches project branches
- `git switch` when it changes/switches project branches
- `git clean`
- `git stash` when it modifies/stashes developer work
- `git remote`
- `git config`
- `git tag`

AI MUST NOT:

- push to GitHub
- force-push
- merge pull requests
- create or approve pull requests
- delete remote branches
- modify GitHub repository settings
- modify branch protection rules
- modify Git credentials
- modify Git hooks
- change the repository remote URL
- rewrite Git history

### Git inspection is allowed

AI MAY use read-only Git commands such as:

- `git status`
- `git diff`
- `git log`
- `git branch`
- `git remote -v`

These commands must only inspect repository state.

### Team Lead authority

The Team Lead has final authority over:

- commits
- pushes
- pulls
- merges
- rebases
- branch creation/deletion
- pull requests
- GitHub repository settings
- releases/tags

AI assistants must never assume permission.

If a Git operation would be useful, the AI must explain what
operation is needed and wait for explicit Team Lead instruction.

"Implement this feature" does NOT mean permission to commit or push.

"Fix the code" does NOT mean permission to commit or push.

Only an explicit instruction from the Team Lead authorizes the
corresponding Git operation.

### Branch policy

The `main` branch is protected.

Feature development must use:

`feature/<short-description>`

Examples:

- `feature/ai-service`
- `feature/flutter-camera`
- `feature/recycler-dashboard`
- `feature/backend-auth`

No developer or AI assistant may directly push feature work to `main`.

### Before any Git operation

The Team Lead must explicitly decide:

1. What Git operation should happen.
2. Which branch it applies to.
3. What changes are included.
4. Whether the operation is safe.

The AI must not make that decision automatically.

## 11. Code Quality Rules

Prefer:

- small functions
- clear names
- typed data structures
- reusable components
- explicit error handling
- tests for important business logic

Avoid:

- duplicated logic
- giant files
- hard-coded credentials
- unexplained magic values
- unnecessary dependencies
- business logic inside presentation code

Do not rewrite unrelated code while implementing a feature.

---

## 12. AI Coding Tool Rules

AI coding assistants may be used to implement tasks, but they must follow
this repository's architecture and contracts.

AI tools must not independently:

- redesign the architecture
- change API contracts
- replace the database technology
- replace the selected framework
- introduce major dependencies without justification
- delete another team's work
- modify unrelated modules

When requirements are unclear, preserve the existing architecture and
ask for clarification instead of inventing a new architecture.

---

## 13. Dependency Rules

Before adding a new dependency, check:

- Is it actually necessary?
- Does the selected framework already provide the capability?
- Is it maintained?
- Does it increase app size or memory usage significantly?
- Does it work with the project's target platforms?

Avoid dependency sprawl.

---

## 14. Testing Rules

Important business logic must have tests.

At minimum, test:

- material classification response handling
- critical mineral flag logic
- price calculation/estimation logic
- synchronization
- conflict handling
- handover/traceability state transitions
- authentication/authorization
- important API endpoints

Integration and end-to-end tests belong under `tests/`.

---

## 15. Documentation Rules

Architecture decisions belong in:

`docs/architecture/`

API decisions belong in:

`docs/api/`

Database decisions belong in:

`docs/database/`

Dataset/model documentation belongs in:

`docs/research/`

Do not keep important architecture decisions only inside chat messages.

---

## 16. Change Discipline

When implementing a feature:

1. Understand the existing architecture.
2. Identify the owning module.
3. Check the API/data contract.
4. Implement the smallest correct change.
5. Test it.
6. Document important changes.
7. Review the diff.
8. Commit only related changes.

Do not "clean up" unrelated files during feature work.

---

## 17. Source of Truth

When conflicts occur, use this priority:

1. Approved project requirements
2. Approved architecture/API/database documentation
3. Existing tested implementation
4. Task-specific instructions
5. AI-generated suggestions

AI suggestions must never silently override approved project decisions.

---

## 18. Definition of Done

A feature is not complete merely because the code compiles.

A feature is considered complete when:

- implementation is finished
- relevant tests pass
- API/data contracts remain consistent
- offline requirements are respected where applicable
- errors are handled
- documentation is updated when needed
- no secrets are committed
- unrelated files are untouched
- the Git diff has been reviewed
