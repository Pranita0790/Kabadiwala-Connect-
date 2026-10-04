# Backend on Render (no same-Wi‑Fi)

Collectors and the recycler dashboard talk to the **public HTTPS** API.
Local LAN IPs (`10.x`, `adb reverse`) are optional for developers only.

## Production URL

```
https://kabadiwala-backend-chd4.onrender.com
```

API base: `https://kabadiwala-backend-chd4.onrender.com/api`

Free-tier services **sleep** after idle time. The first request after sleep
can take 30–60s; the Flutter app probes Render with a long timeout.

## Deploy (Blueprint)

1. Push `render.yaml` on the deploy branch.
2. [Render Dashboard](https://dashboard.render.com) → **New** → **Blueprint**.
3. Connect `Pranita0790/Kabadiwala-Connect-` (or your fork).
4. Apply the blueprint (`kabadiwala-backend` + `kabadiwala-db`).
5. In the web service → **Environment**, set secrets:

| Variable | Required | Notes |
|----------|----------|--------|
| `GEMINI_API_KEY` | yes (for AI Copilot / analyze) | From Google AI Studio |
| `GEMINI_MODEL` | recommended | e.g. `gemini-2.0-flash` |
| `JWT_SECRET` | yes | Blueprint can auto-generate |
| `DATABASE_URL` | yes | Wired from Render Postgres |
| `DB_SSL` | yes | `true` on Render |
| `CORS_ORIGINS` | yes | Vercel dashboard + local Vite |
| `FIREBASE_PROJECT_ID` | if phone auth | Public project id |

6. Schema: `services/backend/src/server.js` runs `migrate up` on every boot
   (idempotent). Fresh Render Postgres gets tables + reference rates from
   `007_reference_data.sql` automatically after deploy.

7. Verify:

```bash
curl -sS https://kabadiwala-backend-chd4.onrender.com/health/live
curl -sS -X POST https://kabadiwala-backend-chd4.onrender.com/api/ai/copilot \
  -H "Content-Type: application/json" \
  -d "{\"message\":\"silver\",\"language\":\"en\"}"
```

If the hostname changed after a new Blueprint, update:

- `apps/collector/lib/services/backend_url.dart` (`productionRoot`)
- `apps/user/lib/services/api_service.dart`
- `docs/api/api-contract.md`
- Recycler dashboard `VITE_API_BASE_URL`

## Collector app

Default root is the Render URL (no Wi‑Fi IP needed).

Override only when debugging locally:

```bash
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:5000
```

Or Profile → Server URL in the app.

## Recycler dashboard

```bash
# apps/recycler-dashboard/.env.local
VITE_API_BASE_URL=https://kabadiwala-backend-chd4.onrender.com/api
```

## Architecture note

Flutter / dashboard → **Render Node** → Gemini (and optional AI service URL).
Do not point production Flutter at a laptop IP or at the Python AI service
directly (AGENTS.md §2).
