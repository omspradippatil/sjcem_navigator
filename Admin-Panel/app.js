const state = {
  env: {},
  envSource: "",
  supabase: null,
  unlocked: false,
  activeModule: "teachers",
  rows: [],
  searchQuery: "",
  optionCache: {
    branches: [],
    teachers: [],
    rooms: [],
    subjects: [],
    polls: [],
  },
  editor: {
    mode: "create",
    module: null,
    row: null,
  },
};

const DAY_LABELS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

const MODULES = {
  teachers: {
    key: "teachers",
    title: "Teachers",
    eyebrow: "Users",
    table: "teachers",
    primaryKey: "id",
    select:
      "id,name,email,phone,branch_id,is_hod,is_admin,is_active,current_room_id,created_at,last_login",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "email", "phone", "branch_id"],
    columns: [
      { key: "name", label: "Name" },
      { key: "email", label: "Email" },
      { key: "phone", label: "Phone" },
      { key: "branch_id", label: "Branch" },
      { key: "is_hod", label: "HOD", type: "bool" },
      { key: "is_admin", label: "Admin", type: "bool" },
      { key: "is_active", label: "Active", type: "bool" },
    ],
    fields: [
      { key: "name", label: "Name", type: "text", required: true },
      { key: "email", label: "Email", type: "email", required: true },
      {
        key: "password_plain",
        label: "Password",
        type: "password",
        requiredOnCreate: true,
        help: "Used only to generate password_hash.",
      },
      { key: "phone", label: "Phone", type: "text" },
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
      },
      {
        key: "current_room_id",
        label: "Current Room",
        type: "select",
        optionsFrom: "rooms",
      },
      { key: "is_hod", label: "HOD", type: "checkbox" },
      { key: "is_admin", label: "Admin", type: "checkbox" },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
    ],
  },
  students: {
    key: "students",
    title: "Students",
    eyebrow: "Users",
    table: "students",
    primaryKey: "id",
    select:
      "id,name,email,roll_number,branch_id,semester,batch,phone,is_active,anonymous_id,last_login,created_at",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "email", "roll_number", "anonymous_id"],
    columns: [
      { key: "name", label: "Name" },
      { key: "email", label: "Email" },
      { key: "roll_number", label: "Roll Number" },
      { key: "branch_id", label: "Branch" },
      { key: "semester", label: "Semester" },
      { key: "batch", label: "Batch" },
      { key: "is_active", label: "Active", type: "bool" },
    ],
    fields: [
      { key: "name", label: "Name", type: "text", required: true },
      { key: "email", label: "Email", type: "email", required: true },
      {
        key: "password_plain",
        label: "Password",
        type: "password",
        requiredOnCreate: true,
        help: "Used only to generate password_hash.",
      },
      {
        key: "roll_number",
        label: "Roll Number",
        type: "text",
        required: true,
      },
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
      },
      {
        key: "semester",
        label: "Semester",
        type: "number",
        min: 1,
        max: 8,
        default: 1,
        required: true,
      },
      { key: "batch", label: "Batch", type: "text" },
      { key: "phone", label: "Phone", type: "text" },
      {
        key: "anonymous_id",
        label: "Anonymous ID",
        type: "text",
        help: "Auto-generated if empty.",
      },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
    ],
  },
  branches: {
    key: "branches",
    title: "Branches",
    eyebrow: "Academics",
    table: "branches",
    primaryKey: "id",
    select: "id,name,code,created_at",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "code"],
    columns: [
      { key: "name", label: "Name" },
      { key: "code", label: "Code" },
      { key: "created_at", label: "Created" },
    ],
    fields: [
      { key: "name", label: "Name", type: "text", required: true },
      { key: "code", label: "Code", type: "text", required: true },
    ],
  },
  rooms: {
    key: "rooms",
    title: "Rooms",
    eyebrow: "Infrastructure",
    table: "rooms",
    primaryKey: "id",
    select:
      "id,name,room_number,floor,branch_id,room_type,capacity,x_coordinate,y_coordinate,is_active,display_name,description,image_url,updated_at",
    orderBy: { column: "updated_at", ascending: false },
    searchable: ["name", "room_number", "room_type", "display_name"],
    columns: [
      { key: "name", label: "Name" },
      { key: "room_number", label: "Number" },
      { key: "floor", label: "Floor" },
      { key: "room_type", label: "Type" },
      { key: "capacity", label: "Capacity" },
      { key: "branch_id", label: "Branch" },
      { key: "is_active", label: "Active", type: "bool" },
    ],
    fields: [
      { key: "name", label: "Name", type: "text", required: true },
      {
        key: "room_number",
        label: "Room Number",
        type: "text",
        required: true,
      },
      { key: "display_name", label: "Display Name", type: "text" },
      { key: "room_type", label: "Type", type: "text", default: "classroom" },
      { key: "floor", label: "Floor", type: "number", default: 1, required: true },
      { key: "capacity", label: "Capacity", type: "number", default: 60 },
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
      },
      {
        key: "x_coordinate",
        label: "X Coordinate",
        type: "number",
        step: "any",
        required: true,
      },
      {
        key: "y_coordinate",
        label: "Y Coordinate",
        type: "number",
        step: "any",
        required: true,
      },
      { key: "image_url", label: "Image URL", type: "text" },
      { key: "description", label: "Description", type: "textarea", full: true },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
    ],
  },
  subjects: {
    key: "subjects",
    title: "Subjects",
    eyebrow: "Academics",
    table: "subjects",
    primaryKey: "id",
    select: "id,name,code,branch_id,semester,credits,is_lab,created_at",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "code", "semester"],
    columns: [
      { key: "name", label: "Name" },
      { key: "code", label: "Code" },
      { key: "branch_id", label: "Branch" },
      { key: "semester", label: "Semester" },
      { key: "credits", label: "Credits" },
      { key: "is_lab", label: "Lab", type: "bool" },
    ],
    fields: [
      { key: "name", label: "Name", type: "text", required: true },
      { key: "code", label: "Code", type: "text", required: true },
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
      },
      {
        key: "semester",
        label: "Semester",
        type: "number",
        min: 1,
        max: 8,
        required: true,
      },
      { key: "credits", label: "Credits", type: "number", default: 3 },
      { key: "is_lab", label: "Lab Subject", type: "checkbox", default: false },
    ],
  },
  timetable: {
    key: "timetable",
    title: "Timetable",
    eyebrow: "Schedules",
    table: "timetable",
    primaryKey: "id",
    select:
      "id,branch_id,semester,day_of_week,period_number,subject_id,teacher_id,room_id,start_time,end_time,is_break,break_name,batch,is_active",
    orderBy: { column: "day_of_week", ascending: true },
    searchable: ["branch_id", "semester", "period_number", "batch", "break_name"],
    columns: [
      { key: "branch_id", label: "Branch" },
      { key: "semester", label: "Sem" },
      { key: "day_of_week", label: "Day", transform: (v) => DAY_LABELS[v] || v },
      { key: "period_number", label: "Period" },
      { key: "subject_id", label: "Subject" },
      { key: "teacher_id", label: "Teacher" },
      { key: "room_id", label: "Room" },
      {
        key: "time",
        label: "Time",
        transform: (_, row) => `${row.start_time || "--"} - ${row.end_time || "--"}`,
      },
      { key: "batch", label: "Batch" },
      { key: "is_break", label: "Break", type: "bool" },
    ],
    fields: [
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
        required: true,
      },
      {
        key: "semester",
        label: "Semester",
        type: "number",
        min: 1,
        max: 8,
        required: true,
      },
      {
        key: "day_of_week",
        label: "Day of Week",
        type: "select",
        required: true,
        options: DAY_LABELS.map((label, index) => ({ value: String(index), label })),
      },
      {
        key: "period_number",
        label: "Period Number",
        type: "number",
        min: 1,
        max: 12,
        required: true,
      },
      {
        key: "subject_id",
        label: "Subject",
        type: "select",
        optionsFrom: "subjects",
      },
      {
        key: "teacher_id",
        label: "Teacher",
        type: "select",
        optionsFrom: "teachers",
      },
      {
        key: "room_id",
        label: "Room",
        type: "select",
        optionsFrom: "rooms",
      },
      { key: "start_time", label: "Start Time", type: "time", required: true },
      { key: "end_time", label: "End Time", type: "time", required: true },
      { key: "batch", label: "Batch", type: "text" },
      { key: "is_break", label: "Break Row", type: "checkbox", default: false },
      { key: "break_name", label: "Break Name", type: "text" },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
    ],
  },
  polls: {
    key: "polls",
    title: "Polls",
    eyebrow: "Engagement",
    table: "polls",
    primaryKey: "id",
    select:
      "id,title,description,branch_id,created_by,is_active,is_anonymous,allow_multiple_votes,target_all_branches,ends_at,created_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["title", "description", "branch_id"],
    columns: [
      { key: "title", label: "Title" },
      { key: "branch_id", label: "Branch" },
      { key: "created_by", label: "Created By" },
      { key: "is_active", label: "Active", type: "bool" },
      { key: "is_anonymous", label: "Anonymous", type: "bool" },
      { key: "allow_multiple_votes", label: "Multi Vote", type: "bool" },
      { key: "ends_at", label: "Ends" },
    ],
    fields: [
      { key: "title", label: "Title", type: "text", required: true },
      { key: "description", label: "Description", type: "textarea", full: true },
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
      },
      {
        key: "created_by",
        label: "Created By Teacher",
        type: "select",
        optionsFrom: "teachers",
      },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
      {
        key: "is_anonymous",
        label: "Anonymous Votes",
        type: "checkbox",
        default: true,
      },
      {
        key: "allow_multiple_votes",
        label: "Allow Multiple Votes",
        type: "checkbox",
        default: false,
      },
      {
        key: "target_all_branches",
        label: "Target All Branches",
        type: "checkbox",
        default: false,
      },
      { key: "ends_at", label: "Ends At", type: "datetime-local" },
    ],
  },
  poll_options: {
    key: "poll_options",
    title: "Poll Options",
    eyebrow: "Engagement",
    table: "poll_options",
    primaryKey: "id",
    select: "id,poll_id,option_text,vote_count,created_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["option_text", "poll_id"],
    columns: [
      { key: "poll_id", label: "Poll" },
      { key: "option_text", label: "Option" },
      { key: "vote_count", label: "Votes" },
      { key: "created_at", label: "Created" },
    ],
    fields: [
      {
        key: "poll_id",
        label: "Poll",
        type: "select",
        optionsFrom: "polls",
        required: true,
      },
      {
        key: "option_text",
        label: "Option Text",
        type: "text",
        required: true,
      },
      { key: "vote_count", label: "Vote Count", type: "number", default: 0 },
    ],
  },
  teacher_subjects: {
    key: "teacher_subjects",
    title: "Teacher Subject Mapping",
    eyebrow: "Academics",
    table: "teacher_subjects",
    primaryKey: "id",
    select: "id,teacher_id,subject_id,created_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["teacher_id", "subject_id"],
    columns: [
      { key: "teacher_id", label: "Teacher" },
      { key: "subject_id", label: "Subject" },
      { key: "created_at", label: "Created" },
    ],
    fields: [
      {
        key: "teacher_id",
        label: "Teacher",
        type: "select",
        optionsFrom: "teachers",
        required: true,
      },
      {
        key: "subject_id",
        label: "Subject",
        type: "select",
        optionsFrom: "subjects",
        required: true,
      },
    ],
  },
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
  addBtn: document.getElementById("add-btn"),
  searchInput: document.getElementById("search-input"),
  moduleNav: document.getElementById("module-nav"),
  moduleEyebrow: document.getElementById("module-eyebrow"),
  moduleTitle: document.getElementById("module-title"),
  dataHead: document.getElementById("data-head"),
  dataBody: document.getElementById("data-body"),
  dialog: document.getElementById("editor-dialog"),
  editorTitle: document.getElementById("editor-title"),
  editorBody: document.getElementById("editor-body"),
  saveEditor: document.getElementById("save-editor"),
  closeEditor: document.getElementById("close-editor"),
  cancelEditor: document.getElementById("cancel-editor"),
  kpiTeachers: document.getElementById("kpi-teachers"),
  kpiStudents: document.getElementById("kpi-students"),
  kpiRooms: document.getElementById("kpi-rooms"),
  kpiTimetable: document.getElementById("kpi-timetable"),
  kpiBranches: document.getElementById("kpi-branches"),
  kpiSubjects: document.getElementById("kpi-subjects"),
  kpiPolls: document.getElementById("kpi-polls"),
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
    throw new Error("SUPABASE_URL or SUPABASE_ANON_KEY is missing in config.");
  }

  state.supabase = window.supabase.createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function displayValue(column, row) {
  if (typeof column.transform === "function") {
    return column.transform(row[column.key], row);
  }
  const raw = row[column.key];
  if (column.type === "bool") {
    return raw ? "Yes" : "No";
  }
  if (raw === null || raw === undefined || raw === "") {
    return "-";
  }
  return String(raw);
}

function normalizeTime(value) {
  if (!value) {
    return null;
  }
  if (/^\d{2}:\d{2}:\d{2}$/.test(value)) {
    return value;
  }
  if (/^\d{2}:\d{2}$/.test(value)) {
    return `${value}:00`;
  }
  return value;
}

function buildModuleNav() {
  els.moduleNav.innerHTML = Object.values(MODULES)
    .map(
      (module) =>
        `<button class="module-btn ${
          state.activeModule === module.key ? "is-active" : ""
        }" data-module="${module.key}">${escapeHtml(module.title)}</button>`
    )
    .join("");
}

function toSearchString(row) {
  return Object.values(row)
    .map((v) => (v === null || v === undefined ? "" : String(v).toLowerCase()))
    .join(" ");
}

function getFilteredRows() {
  const q = state.searchQuery.trim().toLowerCase();
  if (!q) {
    return state.rows;
  }

  const module = MODULES[state.activeModule];
  return state.rows.filter((row) => {
    if (!module.searchable?.length) {
      return toSearchString(row).includes(q);
    }
    return module.searchable.some((key) =>
      String(row[key] ?? "")
        .toLowerCase()
        .includes(q)
    );
  });
}

function renderTable() {
  const module = MODULES[state.activeModule];
  const rows = getFilteredRows();

  els.dataHead.innerHTML = `<tr>${module.columns
    .map((column) => `<th>${escapeHtml(column.label)}</th>`)
    .join("")}<th>Actions</th></tr>`;

  if (!rows.length) {
    els.dataBody.innerHTML = `<tr><td colspan="${module.columns.length + 1}">No records found.</td></tr>`;
    return;
  }

  els.dataBody.innerHTML = rows
    .map((row) => {
      const cells = module.columns
        .map((column) => `<td>${escapeHtml(displayValue(column, row))}</td>`)
        .join("");

      return `<tr>
        ${cells}
        <td>
          <div class="row-actions">
            <button class="tiny" data-action="edit" data-id="${row[module.primaryKey]}">Edit</button>
            <button class="tiny danger" data-action="delete" data-id="${row[module.primaryKey]}">Delete</button>
          </div>
        </td>
      </tr>`;
    })
    .join("");
}

function updateHeader() {
  const module = MODULES[state.activeModule];
  els.moduleEyebrow.textContent = module.eyebrow;
  els.moduleTitle.textContent = module.title;
}

async function loadOptions() {
  const client = state.supabase;

  const [branchesRes, teachersRes, roomsRes, subjectsRes, pollsRes] =
    await Promise.all([
      client.from("branches").select("id,name,code").order("name"),
      client.from("teachers").select("id,name,email").order("name"),
      client.from("rooms").select("id,name,room_number").order("name"),
      client.from("subjects").select("id,name,code").order("name"),
      client.from("polls").select("id,title").order("created_at", { ascending: false }),
    ]);

  const firstError = [branchesRes, teachersRes, roomsRes, subjectsRes, pollsRes]
    .map((r) => r.error)
    .find(Boolean);
  if (firstError) {
    throw firstError;
  }

  state.optionCache.branches = branchesRes.data || [];
  state.optionCache.teachers = teachersRes.data || [];
  state.optionCache.rooms = roomsRes.data || [];
  state.optionCache.subjects = subjectsRes.data || [];
  state.optionCache.polls = pollsRes.data || [];
}

function optionLabel(source, item) {
  if (source === "branches") {
    return `${item.name || ""} (${item.code || "-"})`;
  }
  if (source === "teachers") {
    return `${item.name || ""} (${item.email || "-"})`;
  }
  if (source === "rooms") {
    return `${item.name || ""} (${item.room_number || "-"})`;
  }
  if (source === "subjects") {
    return `${item.name || ""} (${item.code || "-"})`;
  }
  if (source === "polls") {
    return item.title || "Untitled poll";
  }
  return item.name || item.id;
}

function inputValueForField(field, row = null) {
  if (row && row[field.key] !== undefined && row[field.key] !== null) {
    if (field.type === "datetime-local") {
      return String(row[field.key]).slice(0, 16);
    }
    if (field.type === "time") {
      return String(row[field.key]).slice(0, 5);
    }
    return row[field.key];
  }

  if (field.default !== undefined) {
    return field.default;
  }

  if (field.type === "checkbox") {
    return false;
  }

  return "";
}

function renderEditorFields(module, row, mode) {
  els.editorBody.innerHTML = module.fields
    .map((field) => {
      const value = inputValueForField(field, row);
      const required = field.required || (mode === "create" && field.requiredOnCreate);
      const fieldClass = field.full ? "field full" : "field";

      if (field.type === "checkbox") {
        return `<label class="${fieldClass}">
          <span>${escapeHtml(field.label)}</span>
          <input type="checkbox" data-field="${field.key}" ${value ? "checked" : ""} />
        </label>`;
      }

      if (field.type === "select") {
        const options = field.optionsFrom
          ? state.optionCache[field.optionsFrom] || []
          : field.options || [];

        const optionHtml = [`<option value="">-- Select --</option>`]
          .concat(
            options.map((opt) => {
              const optionValue = opt.value ?? opt.id;
              const label = opt.label ?? optionLabel(field.optionsFrom, opt);
              const selected = String(value) === String(optionValue) ? "selected" : "";
              return `<option value="${escapeHtml(optionValue)}" ${selected}>${escapeHtml(
                label
              )}</option>`;
            })
          )
          .join("");

        return `<label class="${fieldClass}">
          <span>${escapeHtml(field.label)}${required ? " *" : ""}</span>
          <select data-field="${field.key}" ${required ? "required" : ""}>${optionHtml}</select>
          ${field.help ? `<small class="muted">${escapeHtml(field.help)}</small>` : ""}
        </label>`;
      }

      if (field.type === "textarea") {
        return `<label class="${fieldClass}">
          <span>${escapeHtml(field.label)}${required ? " *" : ""}</span>
          <textarea data-field="${field.key}" rows="4" ${required ? "required" : ""}>${escapeHtml(
            value
          )}</textarea>
          ${field.help ? `<small class="muted">${escapeHtml(field.help)}</small>` : ""}
        </label>`;
      }

      return `<label class="${fieldClass}">
        <span>${escapeHtml(field.label)}${required ? " *" : ""}</span>
        <input
          data-field="${field.key}"
          type="${field.type || "text"}"
          value="${escapeHtml(value)}"
          ${field.min !== undefined ? `min="${field.min}"` : ""}
          ${field.max !== undefined ? `max="${field.max}"` : ""}
          ${field.step !== undefined ? `step="${field.step}"` : ""}
          ${required ? "required" : ""}
        />
        ${field.help ? `<small class="muted">${escapeHtml(field.help)}</small>` : ""}
      </label>`;
    })
    .join("");
}

function openEditor(mode, row = null) {
  const module = MODULES[state.activeModule];
  state.editor = { mode, module: module.key, row };

  els.editorTitle.textContent = `${mode === "create" ? "Create" : "Edit"} ${module.title}`;
  renderEditorFields(module, row, mode);
  els.dialog.showModal();
}

function closeEditor() {
  els.dialog.close();
  state.editor = { mode: "create", module: null, row: null };
}

async function sha256(text) {
  const encoded = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function randomAnonymousId() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789";
  let suffix = "";
  for (let i = 0; i < 4; i += 1) {
    suffix += chars[Math.floor(Math.random() * chars.length)];
  }
  return `User#${suffix}`;
}

function castValue(field, inputEl) {
  if (field.type === "checkbox") {
    return inputEl.checked;
  }

  const raw = inputEl.value;
  if (raw === "") {
    return null;
  }

  if (field.type === "number") {
    return Number(raw);
  }

  if (field.type === "time") {
    return normalizeTime(raw);
  }

  if (field.type === "datetime-local") {
    return raw;
  }

  return raw;
}

async function collectEditorPayload() {
  const module = MODULES[state.activeModule];
  const payload = {};

  for (const field of module.fields) {
    const inputEl = els.editorBody.querySelector(`[data-field="${field.key}"]`);
    if (!inputEl) {
      continue;
    }

    const required = field.required || (state.editor.mode === "create" && field.requiredOnCreate);
    if (required && field.type !== "checkbox" && !inputEl.value) {
      throw new Error(`${field.label} is required.`);
    }

    const value = castValue(field, inputEl);

    if (field.key === "password_plain") {
      if (value) {
        payload.password_hash = await sha256(String(value));
      }
      continue;
    }

    payload[field.key] = value;
  }

  if (module.key === "students") {
    if (!payload.anonymous_id) {
      payload.anonymous_id = randomAnonymousId();
    }
    if (state.editor.mode === "create") {
      payload.updated_at = new Date().toISOString();
    }
  }

  if (module.key === "teachers") {
    payload.updated_at = new Date().toISOString();
  }

  return payload;
}

function stripNullPrimary(payload, mode, module) {
  if (mode === "create") {
    delete payload[module.primaryKey];
  }
  return payload;
}

async function saveEditor() {
  const module = MODULES[state.activeModule];
  try {
    setStatus(els.dataMessage, "Saving...");
    const payload = await collectEditorPayload();
    stripNullPrimary(payload, state.editor.mode, module);

    if (state.editor.mode === "create") {
      const { error } = await state.supabase.from(module.table).insert(payload);
      if (error) {
        throw error;
      }
      setStatus(els.dataMessage, `${module.title} record created.`, "success");
    } else {
      const id = state.editor.row[module.primaryKey];
      const { error } = await state.supabase
        .from(module.table)
        .update(payload)
        .eq(module.primaryKey, id);
      if (error) {
        throw error;
      }
      setStatus(els.dataMessage, `${module.title} record updated.`, "success");
    }

    closeEditor();
    await refreshModuleData();
    await loadKpis();
    await loadOptions();
  } catch (error) {
    setStatus(
      els.dataMessage,
      error?.message || "Failed to save record.",
      "error"
    );
  }
}

async function deleteRow(id) {
  const module = MODULES[state.activeModule];
  const approved = confirm(
    `Delete this ${module.title.slice(0, -1).toLowerCase()} record? This cannot be undone.`
  );
  if (!approved) {
    return;
  }

  try {
    const { error } = await state.supabase
      .from(module.table)
      .delete()
      .eq(module.primaryKey, id);
    if (error) {
      throw error;
    }

    setStatus(els.dataMessage, `${module.title} record deleted.`, "success");
    await refreshModuleData();
    await loadKpis();
    await loadOptions();
  } catch (error) {
    setStatus(
      els.dataMessage,
      error?.message || "Failed to delete record.",
      "error"
    );
  }
}

async function refreshModuleData() {
  const module = MODULES[state.activeModule];
  setStatus(els.dataMessage, `Loading ${module.title.toLowerCase()}...`);

  let query = state.supabase.from(module.table).select(module.select);
  if (module.orderBy) {
    query = query.order(module.orderBy.column, {
      ascending: module.orderBy.ascending,
    });
  }

  const { data, error } = await query;
  if (error) {
    throw error;
  }

  state.rows = data || [];
  renderTable();
  setStatus(els.dataMessage, `${module.title} loaded.`, "success");
}

async function switchModule(moduleKey) {
  state.activeModule = moduleKey;
  state.searchQuery = "";
  els.searchInput.value = "";

  buildModuleNav();
  updateHeader();
  await refreshModuleData();
}

async function loadKpis() {
  const client = state.supabase;
  const [teachers, students, rooms, timetable, branches, subjects, polls] =
    await Promise.all([
      client.from("teachers").select("id", { count: "exact", head: true }),
      client.from("students").select("id", { count: "exact", head: true }),
      client.from("rooms").select("id", { count: "exact", head: true }),
      client.from("timetable").select("id", { count: "exact", head: true }),
      client.from("branches").select("id", { count: "exact", head: true }),
      client.from("subjects").select("id", { count: "exact", head: true }),
      client.from("polls").select("id", { count: "exact", head: true }),
    ]);

  const firstError = [teachers, students, rooms, timetable, branches, subjects, polls]
    .map((res) => res.error)
    .find(Boolean);
  if (firstError) {
    throw firstError;
  }

  els.kpiTeachers.textContent = String(teachers.count ?? 0);
  els.kpiStudents.textContent = String(students.count ?? 0);
  els.kpiRooms.textContent = String(rooms.count ?? 0);
  els.kpiTimetable.textContent = String(timetable.count ?? 0);
  els.kpiBranches.textContent = String(branches.count ?? 0);
  els.kpiSubjects.textContent = String(subjects.count ?? 0);
  els.kpiPolls.textContent = String(polls.count ?? 0);
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

function bindEvents() {
  els.loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const entered = els.passwordInput.value.trim();
    const expected = String(state.env.ADMIN_PASSWORD || "").trim();

    if (!expected) {
      setStatus(
        els.authMessage,
        "ADMIN_PASSWORD missing in config.",
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
      buildModuleNav();
      updateHeader();
      await loadOptions();
      await loadKpis();
      await refreshModuleData();
      setStatus(els.authMessage, "Access granted.", "success");
    } catch (error) {
      setStatus(
        els.authMessage,
        error?.message || "Could not initialize admin panel.",
        "error"
      );
    }
  });

  els.moduleNav.addEventListener("click", async (event) => {
    const target = event.target.closest("[data-module]");
    if (!target) {
      return;
    }

    const moduleKey = target.dataset.module;
    if (!moduleKey || !MODULES[moduleKey]) {
      return;
    }

    try {
      await switchModule(moduleKey);
    } catch (error) {
      setStatus(els.dataMessage, error?.message || "Failed to switch module.", "error");
    }
  });

  els.refreshBtn.addEventListener("click", async () => {
    try {
      await loadOptions();
      await loadKpis();
      await refreshModuleData();
    } catch (error) {
      setStatus(els.dataMessage, error?.message || "Refresh failed.", "error");
    }
  });

  els.addBtn.addEventListener("click", () => openEditor("create", null));
  els.lockBtn.addEventListener("click", lockUI);

  els.searchInput.addEventListener("input", () => {
    state.searchQuery = els.searchInput.value;
    renderTable();
  });

  els.dataBody.addEventListener("click", async (event) => {
    const target = event.target.closest("button[data-action]");
    if (!target) {
      return;
    }

    const { action, id } = target.dataset;
    if (!action || !id) {
      return;
    }

    if (action === "edit") {
      const module = MODULES[state.activeModule];
      const row = state.rows.find((item) => String(item[module.primaryKey]) === id);
      if (!row) {
        return;
      }
      openEditor("edit", row);
      return;
    }

    if (action === "delete") {
      await deleteRow(id);
    }
  });

  els.saveEditor.addEventListener("click", saveEditor);
  els.closeEditor.addEventListener("click", closeEditor);
  els.cancelEditor.addEventListener("click", closeEditor);
  els.dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeEditor();
  });
}

async function init() {
  try {
    await bootstrapEnv();
    bindEvents();
  } catch (error) {
    setStatus(
      els.authMessage,
      error?.message || "Unable to initialize environment.",
      "error"
    );
  }
}

init();
