# SJCEM HTML Admin Panel

This is a standalone admin panel built with strict HTML, CSS, and vanilla JavaScript.

## Files

- `index.html` - UI layout and structure
- `styles.css` - Professional styling
- `app.js` - Data loading and interactivity
- `env.js` - Browser-safe runtime config (recommended for Live Server)
- `.env.example` - Environment template

## Setup

1. Set your values in `env.js` (recommended).
2. Optional: also keep `.env` for non-browser tooling.
3. Start a static server from this folder, then open `index.html`.

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
- If your Supabase RLS policies block reads, configure policies for the required tables:
  - `teachers`
  - `students`
  - `rooms`
  - `timetable`
