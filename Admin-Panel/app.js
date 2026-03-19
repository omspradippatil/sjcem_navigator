const DAY_LABELS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

const state = {
  env: {},
  envSource: "",
  supabase: null,
  unlocked: false,
};

const els = {
  authCard: document.getElementById("auth-card"),
  dashboard: document.getElementById("dashboard"),
  loginForm: document.getElementById("admin-login-form"),
  passwordInput: document.getElementById("admin-password"),
  authMessage: document.getElementById("auth-message"),
  envSource: document.getElementById("env-source"),
  dataMessage: document.getElementById("data-message"),
  refreshBtn: document.getElementById("refresh-btn"),
  lockBtn: document.getElementById("lock-btn"),
  tabs: Array.from(document.querySelectorAll(".tab")),
  panels: {
    teachers: document.getElementById("panel-teachers"),
    rooms: document.getElementById("panel-rooms"),
    timetable: document.getElementById("panel-timetable"),
  },
  teachersBody: document.getElementById("teachers-body"),
  roomsBody: document.getElementById("rooms-body"),
  timetableBody: document.getElementById("timetable-body"),
  kpiTeachers: document.getElementById("kpi-teachers"),
  kpiStudents: document.getElementById("kpi-students"),
  kpiRooms: document.getElementById("kpi-rooms"),
  kpiTimetable: document.getElementById("kpi-timetable"),
};

function setStatus(el, message, type = "") {
  el.textContent = message;
  el.classList.remove("error", "success");
  if (type) {
    el.classList.add(type);
  }
}

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

    // Support quoted env values: KEY="value" or KEY='value'
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
  if (window.ADMIN_PANEL_ENV && typeof window.ADMIN_PANEL_ENV === "object") {
    state.env = { ...window.ADMIN_PANEL_ENV };
    state.envSource = "env.js";
    els.envSource.textContent = `${state.envSource} loaded`;
    return;
  }

  const candidates = ["./.env", ".env", "./.env.example", ".env.example"];
  let lastError = null;

  for (const candidate of candidates) {
    try {
      state.env = await loadEnvFrom(candidate);
      state.envSource = candidate.includes(".env.example")
        ? ".env.example"
        : ".env";
      break;
    } catch (error) {
      lastError = error;
    }
  }

  if (!state.envSource) {
    throw (
      lastError ||
      new Error(
        "Unable to load env config. Use env.js, or run a local server that serves .env files."
      )
    );
  }

  els.envSource.textContent = `${state.envSource} loaded`;
}

function initSupabase() {
  const url = state.env.SUPABASE_URL || "";
  const key = state.env.SUPABASE_ANON_KEY || "";

  if (!url || !key) {
    throw new Error("SUPABASE_URL or SUPABASE_ANON_KEY is missing in env file.");
  }

  state.supabase = window.supabase.createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

function unlockUI() {
  state.unlocked = true;
  els.authCard.classList.add("hidden");
  els.dashboard.classList.remove("hidden");
}

function lockUI() {
  state.unlocked = false;
  els.passwordInput.value = "";
  els.dashboard.classList.add("hidden");
  els.authCard.classList.remove("hidden");
  setStatus(els.authMessage, "Panel locked.", "success");
}

function activateTab(tabName) {
  els.tabs.forEach((tab) => {
    tab.classList.toggle("is-active", tab.dataset.tab === tabName);
  });

  Object.entries(els.panels).forEach(([name, panel]) => {
    panel.classList.toggle("hidden", name !== tabName);
  });
}

function asBadge(value) {
  return value ? "Yes" : "No";
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function renderRows(container, rows, cellsBuilder) {
  if (!rows.length) {
    container.innerHTML = '<tr><td colspan="6">No data available.</td></tr>';
    return;
  }

  container.innerHTML = rows
    .map((row) => {
      const cells = cellsBuilder(row)
        .map((cell) => `<td>${escapeHtml(cell)}</td>`)
        .join("");
      return `<tr>${cells}</tr>`;
    })
    .join("");
}

async function loadKpis() {
  const client = state.supabase;

  const [teachers, students, rooms, timetable] = await Promise.all([
    client.from("teachers").select("id", { count: "exact", head: true }),
    client.from("students").select("id", { count: "exact", head: true }),
    client.from("rooms").select("id", { count: "exact", head: true }),
    client.from("timetable").select("id", { count: "exact", head: true }),
  ]);

  const firstError = [teachers, students, rooms, timetable]
    .map((r) => r.error)
    .find(Boolean);
  if (firstError) {
    throw firstError;
  }

  els.kpiTeachers.textContent = String(teachers.count ?? 0);
  els.kpiStudents.textContent = String(students.count ?? 0);
  els.kpiRooms.textContent = String(rooms.count ?? 0);
  els.kpiTimetable.textContent = String(timetable.count ?? 0);
}

async function loadTeachers() {
  const { data, error } = await state.supabase
    .from("teachers")
    .select("name, email, branch_id, is_admin, is_hod")
    .order("created_at", { ascending: false })
    .limit(20);

  if (error) {
    throw error;
  }

  renderRows(els.teachersBody, data || [], (row) => [
    row.name || "-",
    row.email || "-",
    row.branch_id || "-",
    asBadge(row.is_admin),
    asBadge(row.is_hod),
  ]);
}

async function loadRooms() {
  const { data, error } = await state.supabase
    .from("rooms")
    .select("name, room_type, floor, capacity, x_coordinate, y_coordinate")
    .eq("is_active", true)
    .order("updated_at", { ascending: false })
    .limit(20);

  if (error) {
    throw error;
  }

  renderRows(els.roomsBody, data || [], (row) => [
    row.name || "-",
    row.room_type || "-",
    row.floor ?? "-",
    row.capacity ?? "-",
    `${row.x_coordinate ?? "-"}, ${row.y_coordinate ?? "-"}`,
  ]);
}

async function loadTimetable() {
  const { data, error } = await state.supabase
    .from("timetable")
    .select("branch_id, semester, day_of_week, period_number, start_time, end_time, batch")
    .order("day_of_week", { ascending: true })
    .order("period_number", { ascending: true })
    .limit(20);

  if (error) {
    throw error;
  }

  renderRows(els.timetableBody, data || [], (row) => [
    row.branch_id || "-",
    row.semester ?? "-",
    DAY_LABELS[row.day_of_week] || "-",
    row.period_number ?? "-",
    `${row.start_time || "--"} - ${row.end_time || "--"}`,
    row.batch || "All",
  ]);
}

async function refreshDashboard() {
  if (!state.unlocked) {
    return;
  }

  setStatus(els.dataMessage, "Refreshing data...");
  try {
    await Promise.all([loadKpis(), loadTeachers(), loadRooms(), loadTimetable()]);
    setStatus(els.dataMessage, "Dashboard updated.", "success");
  } catch (error) {
    const message = error?.message || "Failed to load data from Supabase.";
    setStatus(els.dataMessage, message, "error");
  }
}

function bindEvents() {
  els.loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const entered = els.passwordInput.value.trim();
    const expected = (state.env.ADMIN_PASSWORD || "").trim();

    if (!expected) {
      setStatus(
        els.authMessage,
        "ADMIN_PASSWORD is missing from your env file.",
        "error"
      );
      return;
    }

    if (!entered || entered !== expected) {
      setStatus(els.authMessage, "Invalid admin password.", "error");
      return;
    }

    try {
      initSupabase();
      unlockUI();
      setStatus(els.authMessage, "Access granted.", "success");
      await refreshDashboard();
    } catch (error) {
      setStatus(
        els.authMessage,
        error?.message || "Could not initialize Supabase client.",
        "error"
      );
    }
  });

  els.refreshBtn.addEventListener("click", refreshDashboard);
  els.lockBtn.addEventListener("click", lockUI);

  els.tabs.forEach((tab) => {
    tab.addEventListener("click", () => activateTab(tab.dataset.tab));
  });
}

async function init() {
  try {
    await bootstrapEnv();
    bindEvents();
  } catch (error) {
    setStatus(
      els.authMessage,
      error?.message ||
        "Unable to initialize environment. Run via a local server (not file://) and keep .env in Admin-Panel.",
      "error"
    );
  }
}

init();
