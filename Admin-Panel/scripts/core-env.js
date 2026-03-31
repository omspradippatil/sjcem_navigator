function parseEnv(text) {
  const env = {};
  text.split("\n").forEach((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      return;
    }

    const normalized = trimmed.startsWith("export ")
      ? trimmed.slice(7).trim()
      : trimmed;
    const separator = normalized.indexOf("=");
    if (separator < 1) {
      return;
    }

    const key = normalized.slice(0, separator).trim();
    let value = normalized.slice(separator + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    env[key] = value;
  });
  return env;
}

async function loadEnvFrom(path) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Failed to load ${path}`);
  }
  const text = await response.text();
  return parseEnv(text);
}

async function bootstrapEnv() {
  // env.js is the single source of truth for browser-based config.
  // It is git-ignored; env.js.example is the committed template.
  if (window.ADMIN_PANEL_ENV && typeof window.ADMIN_PANEL_ENV === "object") {
    const envObj = window.ADMIN_PANEL_ENV;
    const isPlaceholder =
      !envObj.SUPABASE_URL ||
      (!envObj.SUPABASE_URL.startsWith("OBF:") && envObj.SUPABASE_URL.startsWith("YOUR_")) ||
      envObj.SUPABASE_URL === "https://your-project.supabase.co";

    if (!isPlaceholder) {
      state.env = { ...envObj };
      state.envSource = "env.js";
      els.envSource.textContent = "env.js loaded";
      return;
    }

    throw new Error(
      "env.js contains placeholder values. Copy env.js.example -> env.js and fill in your real Supabase URL, anon key, and admin password."
    );
  }

  throw new Error(
    "env.js not found. Copy Admin-Panel/env.js.example -> Admin-Panel/env.js and fill in your values."
  );
}

function deobfuscate(str) {
  if (!str) return "";
  if (str.startsWith("OBF:")) {
    try {
      return atob(str.slice(4).split("").reverse().join(""));
    } catch {
      return str;
    }
  }
  return str;
}

function initSupabase() {
  const url = deobfuscate(state.env.SUPABASE_URL);
  const key = deobfuscate(state.env.SUPABASE_ANON_KEY);

  if (!url || !key) {
    throw new Error("SUPABASE_URL or SUPABASE_ANON_KEY is missing in config.");
  }

  state.supabase = window.supabase.createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
