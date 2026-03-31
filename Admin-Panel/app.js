const MAIN_ADMIN_PASSWORD_FALLBACK = "om";

const DAY_LABELS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

const ACTIVITY_LOG_LIMIT = 3;

const IMPORTANT_ACTIVITY_KEYWORDS = [
  "deleted",
  "bulk deleted",
  "exported",
  "created",
  "updated",
  "restore",
  "backup",
  "failed",
];

const TIMETABLE_SESSION_TYPES = [
  { value: "lecture", label: "Lecture" },
  { value: "practical", label: "Practical" },
  { value: "break", label: "Break" },
];

const TIMETABLE_DURATION_MINUTES = {
  lecture: 60,
  practical: 120,
};

const REALTIME_SYNC_DEBOUNCE_MS = 250;
const DASHBOARD_HEALTH_POLL_INTERVAL_MS = 45000;
const LIVE_HEARTBEAT_SYNC_INTERVAL_MS = 10000;
const DASHBOARD_CHART_REFRESH_INTERVAL_MS = 10000;

const REALTIME_TABLES = [
  "teachers",
  "students",
  "branches",
  "rooms",
  "subjects",
  "timetable",
  "polls",
  "poll_options",
  "teacher_subjects",
  "admin_panel_users",
  "admin_panel_activity",
  "announcements",
];

const REALTIME_BRANCH_FIELDS = {
  teachers: "branch_id",
  students: "branch_id",
  rooms: "branch_id",
  subjects: "branch_id",
  timetable: "branch_id",
  polls: "branch_id",
  admin_panel_users: "branch_id",
  admin_panel_activity: "branch_id",
  announcements: "branch_id",
};

const OPTION_RELOAD_TABLES = new Set([
  "branches",
  "teachers",
  "rooms",
  "subjects",
  "polls",
  "admin_panel_users",
]);

const state = {
  env: {},
  envSource: "",
  supabase: null,
  unlocked: false,
  activeModule: "dashboard",
  rows: [],
  searchQuery: "",
  currentUser: null,
  activityFeed: [],
  optionCache: {
    branches: [],
    teachers: [],
    rooms: [],
    subjects: [],
    polls: [],
    panelUsers: [],
  },
  editor: {
    mode: "create",
    module: null,
    row: null,
  },
  selectedRows: new Set(),
  notifications: [],
  realtimeChannel: null,
  backupTimerId: null,
  ocr: {
    mode: "subjects",
  },
  live: {
    realtimeStatus: "DISCONNECTED",
    pendingTables: new Set(),
    syncTimerId: null,
    syncInProgress: false,
    syncQueued: false,
    healthTimerId: null,
    heartbeatTimerId: null,
    heartbeatIntervalMs: LIVE_HEARTBEAT_SYNC_INTERVAL_MS,
    lastSyncAt: null,
    lastHealthCheckAt: null,
    dashboardCardsBuilt: false,
    lastChartRenderAt: null,
  },
};

const MODULES = {
  dashboard: {
    key: "dashboard",
    title: "Dashboard",
    eyebrow: "Overview",
    description: "System snapshot and quick access.",
    noTable: true,
  },
  teachers: {
    key: "teachers",
    title: "Teachers",
    eyebrow: "Users",
    description: "Manage teacher and HOD records.",
    table: "teachers",
    primaryKey: "id",
    select:
      "id,name,email,phone,branch_id,is_hod,is_admin,is_active,default_room_id,current_room_id,created_at,last_login",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "email", "phone", "branch_id"],
    branchField: "branch_id",
    columns: [
      { key: "name", label: "Name" },
      { key: "email", label: "Email" },
      { key: "phone", label: "Phone" },
      { key: "branch_id", label: "Branch" },
      { key: "default_room_id", label: "Default Room" },
      { key: "current_room_id", label: "Current Room" },
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
        help: "Converted to SHA-256 password_hash.",
      },
      { key: "phone", label: "Phone", type: "text" },
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
      },
      {
        key: "default_room_id",
        label: "Default Room (Where Teacher Sits)",
        type: "select",
        optionsFrom: "rooms",
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
    description: "Manage student account and branch data.",
    table: "students",
    primaryKey: "id",
    select:
      "id,name,email,roll_number,branch_id,semester,batch,phone,is_active,anonymous_id,last_login,created_at",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "email", "roll_number", "anonymous_id"],
    branchField: "branch_id",
    columns: [
      { key: "name", label: "Name" },
      { key: "email", label: "Email" },
      { key: "roll_number", label: "Roll" },
      { key: "branch_id", label: "Branch" },
      { key: "semester", label: "Sem" },
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
        help: "Converted to SHA-256 password_hash.",
      },
      { key: "roll_number", label: "Roll Number", type: "text", required: true },
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
    description: "Department branch setup and naming.",
    table: "branches",
    primaryKey: "id",
    select: "id,name,code,created_at",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "code"],
    branchSelfScoped: true,
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
    description: "Room catalog and map coordinates.",
    table: "rooms",
    primaryKey: "id",
    select:
      "id,name,room_number,floor,branch_id,room_type,capacity,x_coordinate,y_coordinate,is_active,display_name,description,image_url,updated_at",
    orderBy: { column: "updated_at", ascending: false },
    searchable: ["name", "room_number", "room_type", "display_name"],
    branchField: "branch_id",
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
      { key: "room_number", label: "Room Number", type: "text", required: true },
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
    description: "Subject matrix and semester mapping.",
    table: "subjects",
    primaryKey: "id",
    select: "id,name,code,branch_id,semester,credits,is_lab,created_at",
    orderBy: { column: "name", ascending: true },
    searchable: ["name", "code", "semester"],
    branchField: "branch_id",
    columns: [
      { key: "name", label: "Name" },
      { key: "code", label: "Code" },
      { key: "branch_id", label: "Branch" },
      { key: "semester", label: "Sem" },
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
    description: "Create and maintain department timetable.",
    table: "timetable",
    primaryKey: "id",
    select:
      "id,branch_id,semester,day_of_week,period_number,subject_id,teacher_id,room_id,start_time,end_time,is_break,break_name,batch,is_active",
    orderBy: { column: "day_of_week", ascending: true },
    searchable: ["branch_id", "semester", "period_number", "batch", "break_name"],
    branchField: "branch_id",
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
      {
        key: "session_type",
        label: "Type",
        transform: (_, row) => resolveTimetableSessionType(row),
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
        key: "session_type",
        label: "Class Type",
        type: "select",
        required: true,
        default: "lecture",
        options: TIMETABLE_SESSION_TYPES,
        help: "Lecture is 1 hour, Practical is 2 hours, and Break is common for all break slots.",
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
      {
        key: "batch",
        label: "Batch",
        type: "text",
        help: "Optional for lecture. Use for practical split batches (e.g., B1/B2).",
      },
      { key: "is_break", label: "Break Row", type: "checkbox", default: false },
      { key: "break_name", label: "Break Name", type: "text" },
      {
        key: "apply_break_all_days",
        label: "Apply Break Time to All Days",
        type: "checkbox",
        default: false,
        help: "When enabled for Break, the same break time is set for every day.",
      },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
    ],
  },
  polls: {
    key: "polls",
    title: "Polls",
    eyebrow: "Engagement",
    description: "Department communication polls.",
    table: "polls",
    primaryKey: "id",
    select:
      "id,title,description,branch_id,created_by,is_active,is_anonymous,allow_multiple_votes,target_all_branches,ends_at,created_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["title", "description", "branch_id"],
    branchField: "branch_id",
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
    description: "Manage options inside polls.",
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
      { key: "option_text", label: "Option Text", type: "text", required: true },
      { key: "vote_count", label: "Vote Count", type: "number", default: 0 },
    ],
  },
  teacher_subjects: {
    key: "teacher_subjects",
    title: "Teacher Subject Mapping",
    eyebrow: "Academics",
    description: "Assign subjects to teachers.",
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
  admin_panel_users: {
    key: "admin_panel_users",
    title: "Panel Users",
    eyebrow: "Access",
    description: "Create teacher/HOD panel logins.",
    table: "admin_panel_users",
    primaryKey: "id",
    select: "id,username,display_name,role,branch_id,is_active,created_at,updated_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["username", "display_name", "role", "branch_id"],
    branchField: "branch_id",
    columns: [
      { key: "username", label: "Username" },
      { key: "display_name", label: "Display Name" },
      { key: "role", label: "Role" },
      { key: "branch_id", label: "Branch" },
      { key: "is_active", label: "Active", type: "bool" },
      { key: "created_at", label: "Created" },
    ],
    fields: [
      { key: "username", label: "Username", type: "text", required: true },
      { key: "display_name", label: "Display Name", type: "text" },
      {
        key: "password_plain",
        label: "Password",
        type: "password",
        requiredOnCreate: true,
        help: "Converted to SHA-256 password_hash.",
      },
      {
        key: "role",
        label: "Role",
        type: "select",
        required: true,
        options: [
          { value: "teacher", label: "Teacher" },
          { value: "hod", label: "HOD" },
        ],
      },
      {
        key: "branch_id",
        label: "Branch",
        type: "select",
        optionsFrom: "branches",
        required: true,
      },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
    ],
  },
  activity_logs: {
    key: "activity_logs",
    title: "Admin Activity",
    eyebrow: "Audit",
    description: "Browse the historical actions performed inside the panel.",
    table: "admin_panel_activity",
    primaryKey: "id",
    select: "id,username,module_key,action,details,branch_id,created_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["username", "module_key", "action", "details"],
    branchField: "branch_id",
    columns: [
      { key: "username", label: "User" },
      { key: "branch_id", label: "Branch" },
      { key: "module_key", label: "Module" },
      { key: "action", label: "Action" },
      { key: "details", label: "Details" },
      { key: "created_at", label: "When" },
    ],
    fields: [],
    readOnly: true,
  },
  db_backup: {
    key: "db_backup",
    title: "DB Backup",
    eyebrow: "System",
    description: "Export any table or the full database as JSON or CSV.",
    noTable: true,
    isBackup: true,
  },
  notices: {
    key: "notices",
    title: "Notice Board",
    eyebrow: "Communication",
    description: "Create and manage announcements for the college.",
    table: "announcements",
    primaryKey: "id",
    select: "id,title,content,branch_id,created_by,is_active,is_pinned,expires_at,created_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["title", "content", "branch_id"],
    branchField: "branch_id",
    columns: [
      { key: "title", label: "Title" },
      { key: "content", label: "Content" },
      { key: "branch_id", label: "Branch" },
      { key: "created_by", label: "Created By" },
      { key: "is_pinned", label: "Pinned", type: "bool" },
      { key: "is_active", label: "Active", type: "bool" },
      { key: "expires_at", label: "Expires At" },
    ],
    fields: [
      { key: "title", label: "Title", type: "text", required: true },
      { key: "content", label: "Content", type: "textarea", full: true, required: true },
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
      { key: "is_pinned", label: "Pinned", type: "checkbox", default: false },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
      { key: "expires_at", label: "Expires At", type: "datetime-local" },
    ],
  },
};

const els = {
  authCard: document.getElementById("auth-card"),
  dashboard: document.getElementById("dashboard"),
  loginForm: document.getElementById("admin-login-form"),
  usernameInput: document.getElementById("admin-username"),
  passwordInput: document.getElementById("admin-password"),
  authMessage: document.getElementById("auth-message"),
  envSource: document.getElementById("env-source"),
  userBadge: document.getElementById("user-badge"),
  dataMessage: document.getElementById("data-message"),
  refreshBtn: document.getElementById("refresh-btn"),
  refreshIntervalSelect: document.getElementById("refresh-interval-select"),
  lockBtn: document.getElementById("lock-btn"),
  addBtn: document.getElementById("add-btn"),
  searchInput: document.getElementById("search-input"),
  moduleNav: document.getElementById("module-nav"),
  moduleEyebrow: document.getElementById("module-eyebrow"),
  moduleTitle: document.getElementById("module-title"),
  quickAccessGrid: document.getElementById("quick-access-grid"),
  activityLog: document.getElementById("activity-log"),
  homeDashboard: document.getElementById("home-dashboard"),
  tableSection: document.getElementById("table-section"),
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
  kpiPanelUsers: document.getElementById("kpi-panel-users"),
  themeToggle: document.getElementById("theme-toggle"),
  bulkDeleteBtn: document.getElementById("bulk-delete-btn"),
  bulkEditBtn: document.getElementById("bulk-edit-btn"),
  exportPdfBtn: document.getElementById("export-pdf-btn"),
  ocrSubjectsBtn: document.getElementById("ocr-subjects-btn"),
  notificationBtn: document.getElementById("notification-btn"),
  notificationContainer: document.getElementById("notification-container"),
  notificationList: document.getElementById("notification-list"),
  clearNotifications: document.getElementById("clear-notifications"),
  ocrDialog: document.getElementById("ocr-dialog"),
  ocrImageInput: document.getElementById("ocr-image-input"),
  ocrBranchSelect: document.getElementById("ocr-branch-select"),
  ocrUpdateExisting: document.getElementById("ocr-update-existing"),
  ocrRunBtn: document.getElementById("ocr-run-btn"),
  ocrParseBtn: document.getElementById("ocr-parse-btn"),
  ocrProgress: document.getElementById("ocr-progress"),
  ocrTextOutput: document.getElementById("ocr-text-output"),
  ocrSubjectPreview: document.getElementById("ocr-subject-preview"),
  closeOcr: document.getElementById("close-ocr"),
  cancelOcr: document.getElementById("cancel-ocr"),
  applyOcr: document.getElementById("apply-ocr"),
};

function isImportantActivity(actionText) {
  const text = String(actionText || "").toLowerCase();
  return IMPORTANT_ACTIVITY_KEYWORDS.some((keyword) => text.includes(keyword));
}

function isMainAdmin() {
  return state.currentUser?.kind === "main";
}

function isDeptUser() {
  return state.currentUser?.kind === "dept";
}

function isHodUser() {
  return isDeptUser() && String(state.currentUser?.role || "").toLowerCase() === "hod";
}

function isTeacherUser() {
  return isDeptUser() && String(state.currentUser?.role || "").toLowerCase() === "teacher";
}

function canUseAdminUserModule() {
  return isMainAdmin();
}

function canCreateInModule(module) {
  if (!module.table) {
    return false;
  }
  if (module.readOnly) {
    return false;
  }
  if (isMainAdmin()) {
    return true;
  }
  if (isTeacherUser()) {
    return false;
  }
  if (isHodUser() && module.key === "admin_panel_users") {
    return false;
  }
  return isHodUser();
}

function canEditInModule(module) {
  if (!module.table) {
    return false;
  }
  if (module.readOnly) {
    return false;
  }
  if (isMainAdmin()) {
    return true;
  }
  if (isTeacherUser()) {
    return false;
  }
  if (isHodUser() && module.key === "admin_panel_users") {
    return false;
  }
  return isHodUser();
}

function canDeleteInModule(module) {
  if (!module.table) {
    return false;
  }
  if (module.readOnly) {
    return false;
  }
  if (isMainAdmin()) {
    return true;
  }
  if (isTeacherUser()) {
    return false;
  }
  if (isHodUser() && module.key === "admin_panel_users") {
    return false;
  }
  return isHodUser();
}

function getAllowedModuleKeys() {
  if (isMainAdmin()) {
    return [
      "dashboard",
      "teachers",
      "students",
      "branches",
      "rooms",
      "subjects",
      "timetable",
      "polls",
      "poll_options",
      "teacher_subjects",
      "admin_panel_users",
      "activity_logs",
      "db_backup",
      "notices",
    ];
  }

  if (isHodUser()) {
    return [
      "dashboard",
      "branches",
      "teachers",
      "students",
      "rooms",
      "subjects",
      "timetable",
      "polls",
      "poll_options",
      "teacher_subjects",
      "activity_logs",
      "notices",
    ];
  }

  return [
    "dashboard",
    "branches",
    "teachers",
    "students",
    "rooms",
    "subjects",
    "timetable",
    "polls",
    "activity_logs",
    "notices",
  ];
}

function setStatus(el, message, type = "") {
  el.textContent = message;
  el.classList.remove("error", "success");
  if (type) {
    el.classList.add(type);
  }
}

function getActivityActorName() {
  if (state.currentUser?.displayName) {
    return state.currentUser.displayName;
  }
  if (state.currentUser?.username) {
    return state.currentUser.username;
  }
  if (isMainAdmin()) {
    return "Main Admin";
  }
  return "Panel User";
}

function getActivityModuleLabel(moduleKey) {
  if (!moduleKey) {
    return "General";
  }
  const module = MODULES[moduleKey];
  return module?.title || moduleKey;
}

function renderActivityLog() {
  if (!els.activityLog) {
    return;
  }
  if (!state.activityFeed.length) {
    els.activityLog.innerHTML = "<li>No activity logged yet.</li>";
    return;
  }

  els.activityLog.innerHTML = state.activityFeed
    .slice(0, ACTIVITY_LOG_LIMIT)
    .map((entry) => {
      const moduleLabel = getActivityModuleLabel(entry.module_key);
      const timeLabel = entry.created_at
        ? new Date(entry.created_at).toLocaleString()
        : "-";
      const detailsLine = entry.details
        ? `<div class=\"activity-detail\">${escapeHtml(entry.details)}</div>`
        : "";
      return `<li>
        <div class=\"activity-main\">
          <strong>${escapeHtml(entry.username || "Panel User")}</strong>
          <span>${escapeHtml(entry.action)}</span>
        </div>
        <div class=\"activity-meta\">${escapeHtml(moduleLabel)} · ${escapeHtml(timeLabel)}</div>
        ${detailsLine}
      </li>`;
    })
    .join("");
}

function addActivity(message, options = {}) {
  const moduleKey = options.moduleKey || state.activeModule || "dashboard";
  const entry = {
    id: options.id || `local-${Date.now()}`,
    username: getActivityActorName(),
    module_key: moduleKey,
    action: message,
    details: options.details || null,
    created_at: options.createdAt || new Date().toISOString(),
  };
  state.activityFeed = [entry, ...state.activityFeed].slice(0, ACTIVITY_LOG_LIMIT);
  renderActivityLog();
  persistActivity({
    module_key: moduleKey,
    action: message,
    details: options.details || null,
  });

  if (isImportantActivity(message)) {
    addNotification(message, "info");
  }
}

async function persistActivity(log) {
  if (!state.supabase) {
    return;
  }
  try {
    const payload = {
      admin_panel_user_id: state.currentUser?.userId || null,
      username: getActivityActorName(),
      branch_id: state.currentUser?.branchId || null,
      module_key: log.module_key,
      action: log.action,
      details: log.details,
    };
    const { error } = await dbInsertActivity(payload);
    if (error) {
      console.error("Failed to persist activity", error);
    }
  } catch (error) {
    console.error("Failed to persist activity", error);
  }
}

async function loadActivityFeed() {
  if (!state.supabase) {
    state.activityFeed = [];
    renderActivityLog();
    return;
  }

  try {
    const branchId = !isMainAdmin() ? state.currentUser?.branchId : null;
    const { data, error } = await dbLoadActivityFeed(ACTIVITY_LOG_LIMIT, branchId);
    if (error) {
      console.error("Unable to load activity feed", error);
      return;
    }
    state.activityFeed = data || [];
    renderActivityLog();
  } catch (error) {
    console.error("Unable to load activity feed", error);
  }
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
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

function timeToMinutes(value) {
  if (!value) {
    return null;
  }

  const match = String(value).match(/^(\d{2}):(\d{2})(?::\d{2})?$/);
  if (!match) {
    return null;
  }

  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return null;
  }

  return hours * 60 + minutes;
}

function minutesToTime(totalMinutes) {
  if (!Number.isFinite(totalMinutes)) {
    return "";
  }

  const wrapped = ((Math.floor(totalMinutes) % 1440) + 1440) % 1440;
  const hours = String(Math.floor(wrapped / 60)).padStart(2, "0");
  const minutes = String(wrapped % 60).padStart(2, "0");
  return `${hours}:${minutes}`;
}

function timetableDurationForType(sessionType) {
  return TIMETABLE_DURATION_MINUTES[sessionType] || TIMETABLE_DURATION_MINUTES.lecture;
}

function isSubjectLab(subjectId) {
  if (!subjectId) {
    return false;
  }
  const subject = state.optionCache.subjects.find((item) => String(item.id) === String(subjectId));
  return Boolean(subject?.is_lab);
}

function resolveTimetableSessionType(row = {}) {
  if (row?.session_type === "break") {
    return "Break";
  }
  if (row?.is_break) {
    return "Break";
  }
  if (row?.session_type === "practical" || row?.session_type === "lecture") {
    return row.session_type === "practical" ? "Practical" : "Lecture";
  }
  if ((row?.batch && String(row.batch).trim()) || isSubjectLab(row?.subject_id)) {
    return "Practical";
  }
  return "Lecture";
}

function deriveTimetableSessionTypeValue(row = null) {
  if (!row) {
    return "lecture";
  }
  const typeLabel = resolveTimetableSessionType(row);
  if (typeLabel === "Break") {
    return "break";
  }
  return typeLabel === "Practical" ? "practical" : "lecture";
}

function applyTimetableDefaultEndTime(force = false) {
  if (state.activeModule !== "timetable") {
    return;
  }

  const typeEl = els.editorBody.querySelector('[data-field="session_type"]');
  const startEl = els.editorBody.querySelector('[data-field="start_time"]');
  const endEl = els.editorBody.querySelector('[data-field="end_time"]');
  const breakEl = els.editorBody.querySelector('[data-field="is_break"]');
  if (!typeEl || !startEl || !endEl || breakEl?.checked || typeEl.value === "break") {
    return;
  }

  const startMinutes = timeToMinutes(startEl.value);
  if (startMinutes === null) {
    return;
  }

  if (!force && endEl.value) {
    return;
  }

  const duration = timetableDurationForType(typeEl.value || "lecture");
  endEl.value = minutesToTime(startMinutes + duration);
}

function bindTimetableEditorBehavior() {
  if (state.activeModule !== "timetable") {
    return;
  }

  const typeEl = els.editorBody.querySelector('[data-field="session_type"]');
  const subjectEl = els.editorBody.querySelector('[data-field="subject_id"]');
  const teacherEl = els.editorBody.querySelector('[data-field="teacher_id"]');
  const roomEl = els.editorBody.querySelector('[data-field="room_id"]');
  const batchEl = els.editorBody.querySelector('[data-field="batch"]');
  const breakNameEl = els.editorBody.querySelector('[data-field="break_name"]');
  const breakAllDaysEl = els.editorBody.querySelector('[data-field="apply_break_all_days"]');
  const dayOfWeekEl = els.editorBody.querySelector('[data-field="day_of_week"]');
  const startEl = els.editorBody.querySelector('[data-field="start_time"]');
  const breakEl = els.editorBody.querySelector('[data-field="is_break"]');
  if (!typeEl || !startEl) {
    return;
  }

  const syncDayOfWeekState = () => {
    if (!dayOfWeekEl) {
      return;
    }
    const isAllDaysBreak = typeEl.value === "break" && Boolean(breakAllDaysEl?.checked);
    dayOfWeekEl.disabled = isAllDaysBreak;
    dayOfWeekEl.required = !isAllDaysBreak;
  };

  const syncBreakState = () => {
    if (!breakEl) {
      return;
    }

    const isBreakType = typeEl.value === "break";
    breakEl.checked = isBreakType;

    if (isBreakType) {
      if (subjectEl) {
        subjectEl.value = "";
      }
      if (teacherEl) {
        teacherEl.value = "";
      }
      if (roomEl) {
        roomEl.value = "";
      }
      if (batchEl) {
        batchEl.value = "";
      }
      if (breakNameEl && !String(breakNameEl.value || "").trim()) {
        breakNameEl.value = "Break";
      }
      if (breakAllDaysEl) {
        breakAllDaysEl.disabled = false;
      }
      syncDayOfWeekState();
      return;
    }

    if (String(breakNameEl?.value || "").trim().toLowerCase() === "break") {
      breakNameEl.value = "";
    }
    if (breakAllDaysEl) {
      breakAllDaysEl.checked = false;
      breakAllDaysEl.disabled = true;
    }
    syncDayOfWeekState();
  };

  const setTypeFromSubject = () => {
    if (!subjectEl || breakEl?.checked || typeEl.value === "break") {
      return;
    }
    if (isSubjectLab(subjectEl.value)) {
      typeEl.value = "practical";
      applyTimetableDefaultEndTime(true);
    }
  };

  typeEl.addEventListener("change", () => {
    syncBreakState();
    applyTimetableDefaultEndTime(true);
  });
  startEl.addEventListener("change", () => applyTimetableDefaultEndTime(true));

  if (breakEl) {
    breakEl.addEventListener("change", () => {
      typeEl.value = breakEl.checked ? "break" : "lecture";
      syncBreakState();
      applyTimetableDefaultEndTime(true);
    });
  }

  if (breakAllDaysEl) {
    breakAllDaysEl.addEventListener("change", syncDayOfWeekState);
  }

  if (subjectEl) {
    subjectEl.addEventListener("change", setTypeFromSubject);
    setTypeFromSubject();
  }

  syncBreakState();
  syncDayOfWeekState();

  if (state.editor.mode === "create") {
    applyTimetableDefaultEndTime(true);
  }
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
  if (source === "panelUsers") {
    return item.username || item.id;
  }
  return item.name || item.id;
}

function displayRefLabel(key, value) {
  if (value === null || value === undefined || value === "") {
    return "-";
  }

  if (key === "branch_id") {
    const branch = state.optionCache.branches.find((b) => String(b.id) === String(value));
    return branch ? `${branch.name} (${branch.code})` : String(value);
  }

  if (key === "teacher_id" || key === "created_by") {
    const teacher = state.optionCache.teachers.find((t) => String(t.id) === String(value));
    return teacher ? teacher.name : String(value);
  }

  if (key === "room_id" || key === "current_room_id" || key === "default_room_id") {
    const room = state.optionCache.rooms.find((r) => String(r.id) === String(value));
    return room ? `${room.name} (${room.room_number || "-"})` : String(value);
  }

  if (key === "subject_id") {
    const subject = state.optionCache.subjects.find((s) => String(s.id) === String(value));
    return subject ? `${subject.name} (${subject.code})` : String(value);
  }

  if (key === "poll_id") {
    const poll = state.optionCache.polls.find((p) => String(p.id) === String(value));
    return poll ? poll.title : String(value);
  }

  return String(value);
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
  if (
    ["branch_id", "teacher_id", "subject_id", "room_id", "poll_id", "created_by", "current_room_id", "default_room_id"].includes(
      column.key
    )
  ) {
    return displayRefLabel(column.key, raw);
  }

  return String(raw);
}

function toSearchString(row) {
  return Object.values(row)
    .map((value) => String(value ?? "").toLowerCase())
    .join(" ");
}

function getFilteredRows() {
  const query = state.searchQuery.trim().toLowerCase();
  if (!query) {
    return state.rows;
  }

  const module = MODULES[state.activeModule];
  return state.rows.filter((row) => {
    if (!module.searchable || !module.searchable.length) {
      return toSearchString(row).includes(query);
    }
    return module.searchable.some((key) =>
      String(row[key] ?? "")
        .toLowerCase()
        .includes(query)
    );
  });
}

function setCurrentUserBadge() {
  if (!state.currentUser) {
    els.userBadge.textContent = "Not logged in";
    return;
  }

  if (isMainAdmin()) {
    els.userBadge.textContent = "Main Admin - Full access";
    return;
  }

  const role = state.currentUser.role?.toUpperCase() || "USER";
  const access = isTeacherUser() ? "Read-only" : "Full (except Users Panel)";
  els.userBadge.textContent = `${state.currentUser.username} - ${role} (${access})`;
}

function buildModuleNav() {
  const allowed = getAllowedModuleKeys();
  els.moduleNav.innerHTML = allowed
    .map((key) => {
      const module = MODULES[key];
      return `<button class="module-btn ${state.activeModule === module.key ? "is-active" : ""}" data-module="${
        module.key
      }">${escapeHtml(module.title)}</button>`;
    })
    .join("");
}

function bindEvents() {
  els.loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      await handleLogin();
    } catch (error) {
      setStatus(els.authMessage, error?.message || "Login failed.", "error");
    }
  });

  els.moduleNav.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-module]");
    if (!button) {
      return;
    }
    const moduleKey = button.dataset.module;
    if (!moduleKey || !MODULES[moduleKey]) {
      return;
    }
    try {
      await switchModule(moduleKey);
    } catch (error) {
      setStatus(els.dataMessage, error?.message || "Failed to switch module.", "error");
    }
  });

  els.quickAccessGrid.addEventListener("click", async (event) => {
    const card = event.target.closest("[data-module-quick]");
    if (!card) {
      return;
    }
    const moduleKey = card.dataset.moduleQuick;
    if (!moduleKey || !MODULES[moduleKey]) {
      return;
    }
    try {
      await switchModule(moduleKey);
    } catch (error) {
      setStatus(els.dataMessage, error?.message || "Failed to open module.", "error");
    }
  });

  els.refreshBtn.addEventListener("click", async () => {
    try {
      await loadOptions();
      await loadKpis();
      await refreshModuleData();
      state.live.lastSyncAt = Date.now();
      updateLiveHealthIndicators();
      addActivity("Manual refresh", {
        moduleKey: state.activeModule,
        details: "Fetched latest data from Supabase",
      });
    } catch (error) {
      setStatus(els.dataMessage, error?.message || "Refresh failed.", "error");
    }
  });

  els.refreshIntervalSelect.addEventListener("change", () => {
    const value = Number.parseInt(els.refreshIntervalSelect.value, 10);
    const intervalMs = setLiveRefreshInterval(value);
    const intervalSeconds = Math.round(intervalMs / 1000);
    setStatus(els.dataMessage, `Auto refresh set to ${intervalSeconds}s.`, "success");
    addActivity("Auto refresh interval updated", {
      moduleKey: state.activeModule,
      details: `Interval: ${intervalSeconds}s`,
    });
  });

  els.addBtn.addEventListener("click", () => openEditor("create", null));
  els.lockBtn.addEventListener("click", () => {
    void lockUI();
  });
  els.themeToggle.addEventListener("click", toggleTheme);

  // Bulk operations event listeners
  els.dataHead.addEventListener("change", (event) => {
    const selectAll = event.target.closest("#select-all-rows");
    if (!selectAll) {
      return;
    }
    const checkboxes = Array.from(els.dataBody.querySelectorAll(".row-checkbox:not([disabled])"));
    checkboxes.forEach((checkbox) => {
      updateRowSelection(checkbox.dataset.id, selectAll.checked);
    });
    updateBulkButtons();
  });

  els.bulkDeleteBtn.addEventListener("click", bulkDelete);
  els.bulkEditBtn.addEventListener("click", bulkEdit);
  els.exportPdfBtn.addEventListener("click", exportToPdf);
  els.ocrSubjectsBtn.addEventListener("click", openOcrDialog);

  els.ocrRunBtn.addEventListener("click", () => {
    void runFreeOcr();
  });
  els.ocrParseBtn.addEventListener("click", parseOcrTextToPreview);
  els.ocrTextOutput.addEventListener("paste", () => {
    requestAnimationFrame(parseOcrTextToPreview);
  });
  els.ocrTextOutput.addEventListener("input", () => {
    if (!els.ocrTextOutput.value.trim()) {
      renderOcrSubjectPreview([]);
      els.ocrProgress.textContent = "";
      return;
    }
    parseOcrTextToPreview();
  });
  els.applyOcr.addEventListener("click", () => {
    void applyOcrSubjects();
  });
  els.closeOcr.addEventListener("click", closeOcrDialog);
  els.cancelOcr.addEventListener("click", closeOcrDialog);
  els.ocrDialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeOcrDialog();
  });

  // Notification event listeners
  els.notificationBtn.addEventListener("click", toggleNotifications);
  els.clearNotifications.addEventListener("click", clearAllNotifications);

  document.addEventListener("click", (event) => {
    if (els.notificationContainer.classList.contains("hidden")) {
      return;
    }
    if (
      event.target.closest("#notification-container") ||
      event.target.closest("#notification-btn")
    ) {
      return;
    }
    els.notificationContainer.classList.add("hidden");
  });

  els.searchInput.addEventListener("input", () => {
    state.searchQuery = els.searchInput.value;
    renderTable();
  });

  els.dataBody.addEventListener("change", (event) => {
    const checkbox = event.target.closest(".row-checkbox");
    if (checkbox) {
      const id = checkbox.dataset.id;
      updateRowSelection(id, checkbox.checked);
      updateBulkButtons();
    }
  });

  els.dataBody.addEventListener("click", async (event) => {
    const actionButton = event.target.closest("button[data-action]");
    if (!actionButton) {
      return;
    }

    const action = actionButton.dataset.action;
    const id = actionButton.dataset.id;
    if (!action || !id) {
      return;
    }

    if (action === "edit") {
      const module = MODULES[state.activeModule];
      const row = state.rows.find((item) => String(item[module.primaryKey]) === String(id));
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
    loadNotifications();
    loadRefreshIntervalPreference();
    bindEvents();
    initTheme();
    initBackupScheduler();
    renderActivityLog();
    renderNotifications();
    setCurrentUserBadge();
  } catch (error) {
    setStatus(els.authMessage, error?.message || "Unable to initialize environment.", "error");
  }
}

init();




