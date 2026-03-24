# SJCEM HTML Admin Panel

This is a standalone admin panel built with strict HTML, CSS, and vanilla JavaScript.

## Files

- `index.html` - UI layout and structure
- `styles.css` - Professional styling
- `app.js` - Data loading and interactivity
- `env.js` - Browser-safe runtime config (recommended for Live Server)
- `.env.example` - Environment template
- `../database/admin_panel_users.sql` - Panel-user login table setup

## Setup

1. Set your values in `env.js` (recommended).
2. Run `database/admin_panel_users.sql` in Supabase SQL Editor.
3. Optional: keep `.env` for non-browser tooling.
4. Start a static server from this folder, then open `index.html`.

PowerShell example:

```powershell
python -m http.server 5500
```

Open:

```text
http://localhost:5500
```

## Notes

- The dashboard is intentionally HTML-only and does not depend on Flutter.
- The panel first reads `env.js`. If missing, it falls back to `.env` and then `.env.example`.
- Many dev servers block hidden files (`.env`), which is why `env.js` is the safest option.
- Login modes:
  - Main admin: leave username empty, use main password (`ADMIN_PASSWORD`, default fallback `om`).
  - Department user (teacher/HOD): login with username + password from `admin_panel_users` table.
- If your Supabase RLS policies block reads, configure policies for the required tables:
  - `teachers`
  - `students`
  - `rooms`
  - `timetable`
- The Admin Activity module (under Audit) surfaces the same history shown on the dashboard but with filtering and search, so you can review every recorded action.

## Activity logging

- The dashboard surfaces a new **Recent Admin Activity** feed that shows who performed what operation.
- Actions are stored in a new `admin_panel_activity` table that records the user, target module, action text, and timestamp.
- Run `database/admin_panel_users.sql` (or copy the `admin_panel_activity` section) in the Supabase SQL editor to create the table and policies before using the activity feed.
