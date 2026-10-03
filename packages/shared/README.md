# Shared Contracts

Cross-team contracts that more than one application depends on. Owned by the
Team Lead; changes here are API contract changes (`AGENTS.md` §5).

## Contents

| File | Purpose |
| --- | --- |
| `enums.json` | Canonical enum vocabulary (statuses, roles, material classes, traceability stages). |

## Why this exists

Before this package, the same status vocabulary was written three times and
had drifted apart:

- `services/backend` used `Pending` / `Accepted` / `Handover` / `Completed`
- `apps/collector` used `CREATED` / `PENDING_SYNC` / `PENDING_CONFIRMATION`
- `apps/recycler-dashboard` used the Title Cased backend strings

`enums.json` is now the one place a status is defined. The backend loads it in
`services/backend/src/config/constants.js`; the dashboard and mobile app should
load the same file rather than redeclaring literals.

## How to consume

Node.js (CommonJS):

```js
// e.g. from services/backend/src/config/ — four levels up is the repo root
const enums = require("../../../../packages/shared/contracts/enums.json");
```

Vite / TypeScript:

```ts
import enums from "../../../packages/shared/contracts/enums.json";
```

> Vite serves files outside the project root only when allowed. If a dashboard
> import fails with a filesystem error, add the shared directory to
> `server.fs.allow` in that app's `vite.config.ts` rather than copying the file.

## Change rule

Changing any value in `enums.json` requires updating `docs/api/api-contract.md`
in the same change. Do not rename a value that is already deployed — add a new
value and keep the old one for backward compatibility.
