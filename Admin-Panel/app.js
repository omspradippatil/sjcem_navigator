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
    table: "notices",
    primaryKey: "id",
    select: "id,title,content,branch_id,created_by,is_active,priority,start_date,end_date,created_at",
    orderBy: { column: "created_at", ascending: false },
    searchable: ["title", "content", "branch_id"],
    branchField: "branch_id",
    columns: [
      { key: "title", label: "Title" },
      { key: "content", label: "Content" },
      { key: "branch_id", label: "Branch" },
      { key: "created_by", label: "Created By" },
      { key: "priority", label: "Priority" },
      { key: "is_active", label: "Active", type: "bool" },
      { key: "start_date", label: "Start Date" },
      { key: "end_date", label: "End Date" },
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
      {
        key: "priority",
        label: "Priority",
        type: "select",
        options: [
          { value: "low", label: "Low" },
          { value: "normal", label: "Normal" },
          { value: "high", label: "High" },
          { value: "urgent", label: "Urgent" },
        ],
        default: "normal",
      },
      { key: "is_active", label: "Active", type: "checkbox", default: true },
      { key: "start_date", label: "Start Date", type: "date" },
      { key: "end_date", label: "End Date", type: "date" },
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
  notificationBtn: document.getElementById("notification-btn"),
  notificationContainer: document.getElementById("notification-container"),
  notificationList: document.getElementById("notification-list"),
  clearNotifications: document.getElementById("clear-notifications"),
};

function isImportantActivity(actionText) {
  const text = String(actionText || "").toLowerCase();
  return IMPORTANT_ACTIVITY_KEYWORDS.some((keyword) => text.includes(keyword));
}

function isInBranchScope(branchId) {
  if (isMainAdmin()) {
    return true;
  }
  const userBranchId = state.currentUser?.branchId;
  if (!userBranchId) {
    return true;
  }
  if (branchId === null || branchId === undefined || branchId === "") {
    return true;
  }
  return String(userBranchId) === String(branchId);
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
    const { error } = await state.supabase.from("admin_panel_activity").insert(payload);
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
    let query = state.supabase
      .from("admin_panel_activity")
      .select("id,username,module_key,action,details,created_at")
      .order("created_at", { ascending: false })
      .limit(ACTIVITY_LOG_LIMIT);
    const branchId = !isMainAdmin() ? state.currentUser?.branchId : null;
    if (branchId) {
      query = query.eq("branch_id", branchId);
    }
    const { data, error } = await query;
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
  // It is git-ignored — real values live here; env.js.example is the safe committed template.
  if (window.ADMIN_PANEL_ENV && typeof window.ADMIN_PANEL_ENV === "object") {
    const envObj = window.ADMIN_PANEL_ENV;
    // Detect placeholder values from env.js.example
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
    // env.js still has placeholder values
    throw new Error(
      "env.js contains placeholder values. Copy env.js.example → env.js and fill in your real Supabase URL, anon key, and admin password."
    );
  }

  // env.js was not loaded at all
  throw new Error(
    "env.js not found. Copy Admin-Panel/env.js.example → Admin-Panel/env.js and fill in your values."
  );
}

function deobfuscate(str) {
  if (!str) return '';
  if (str.startsWith('OBF:')) {
    try {
      return atob(str.slice(4).split('').reverse().join(''));
    } catch {
      return str; // Fallback if decoding fails
    }
  }
  return str; // Plaintext (e.g., from local dev)
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

function renderQuickAccess() {
  if (!els.quickAccessGrid) {
    return;
  }
  const allowed = getAllowedModuleKeys().filter((key) => key !== "dashboard");
  let html = allowed
    .map((key) => {
      const module = MODULES[key];
      return `<article class="quick-card" data-module-quick="${module.key}">
        <h5>${escapeHtml(module.title)}</h5>
        <p>${escapeHtml(module.description || "Open module")}</p>
      </article>`;
    })
    .join("");
  
  // Add system health card
  html += `
    <article class="quick-card health-card">
      <h5>System Health</h5>
      <div class="health-status">
        <div class="health-item">
          <span class="health-label">Database:</span>
          <span class="health-value" id="health-db">Checking...</span>
        </div>
        <div class="health-item">
          <span class="health-label">API:</span>
          <span class="health-value" id="health-api">Checking...</span>
        </div>
        <div class="health-item">
          <span class="health-label">Last Backup:</span>
          <span class="health-value" id="health-backup">-</span>
        </div>
      </div>
      <button class="btn btn-secondary btn-sm" onclick="checkSystemHealth()">Refresh Health</button>
    </article>
  `;

  els.quickAccessGrid.innerHTML = html;
  void checkSystemHealth();
  void renderCharts();
}

let charts = {};

function destroyCharts() {
  Object.values(charts).forEach((chart) => {
    if (chart && typeof chart.destroy === "function") {
      chart.destroy();
    }
  });
  charts = {};
}

async function getDashboardAnalyticsData() {
  const analytics = {
    students: [],
    activityRows: [],
    teacherCount: Number.parseInt(els.kpiTeachers?.textContent || "0", 10) || 0,
    studentCount: Number.parseInt(els.kpiStudents?.textContent || "0", 10) || 0,
  };

  if (!state.supabase || !state.unlocked) {
    return analytics;
  }

  try {
    let studentsQuery = state.supabase.from("students").select("branch_id,semester");
    if (!isMainAdmin() && state.currentUser?.branchId) {
      studentsQuery = studentsQuery.eq("branch_id", state.currentUser.branchId);
    }
    const { data: studentsData, error: studentsError } = await studentsQuery;
    if (studentsError) {
      throw studentsError;
    }
    analytics.students = studentsData || [];
  } catch (error) {
    console.error("Unable to load student analytics", error);
  }

  try {
    const start = new Date();
    start.setDate(start.getDate() - 6);
    start.setHours(0, 0, 0, 0);

    let activityQuery = state.supabase
      .from("admin_panel_activity")
      .select("created_at,branch_id")
      .gte("created_at", start.toISOString());

    if (!isMainAdmin() && state.currentUser?.branchId) {
      activityQuery = activityQuery.eq("branch_id", state.currentUser.branchId);
    }

    const { data: activityData, error: activityError } = await activityQuery;
    if (activityError) {
      throw activityError;
    }
    analytics.activityRows = activityData || [];
  } catch (error) {
    console.error("Unable to load activity trend analytics", error);
  }

  return analytics;
}

async function renderCharts() {
  if (typeof window.Chart === "undefined") {
    return;
  }

  destroyCharts();

  const branchCtx = document.getElementById("branch-distribution-chart");
  const semesterCtx = document.getElementById("semester-distribution-chart");
  const ratioCtx = document.getElementById("teacher-student-ratio-chart");
  const activityCtx = document.getElementById("activity-trend-chart");

  if (!branchCtx && !semesterCtx && !ratioCtx && !activityCtx) {
    return;
  }

  const css = getComputedStyle(document.body);
  const textColor = (css.getPropertyValue("--text") || "#e8f4ff").trim();
  const mutedColor = (css.getPropertyValue("--muted") || "#9fb9cf").trim();
  const lineColor = (css.getPropertyValue("--line") || "rgba(167, 213, 255, 0.1)").trim();
  const primaryColor = (css.getPropertyValue("--primary") || "#29c3af").trim();
  const accentColor = (css.getPropertyValue("--accent") || "#35a6ea").trim();
  const warningColor = (css.getPropertyValue("--warning") || "#ffcc66").trim();

  const analytics = await getDashboardAnalyticsData();

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        labels: {
          color: textColor,
          font: { size: 11 },
        },
      },
    },
    scales: {
      x: {
        ticks: { color: mutedColor, font: { size: 10 } },
        grid: { color: lineColor },
      },
      y: {
        ticks: { color: mutedColor, font: { size: 10 }, precision: 0 },
        grid: { color: lineColor },
      },
    },
  };

  const branchCounts = new Map();
  analytics.students.forEach((student) => {
    const key = student.branch_id ? String(student.branch_id) : "unknown";
    branchCounts.set(key, (branchCounts.get(key) || 0) + 1);
  });

  let branchLabels = state.optionCache.branches.map((branch) => branch.name || String(branch.id));
  let branchValues = state.optionCache.branches.map((branch) =>
    branchCounts.get(String(branch.id)) || 0
  );
  if (!branchLabels.length) {
    branchLabels = ["No Data"];
    branchValues = [1];
  }

  if (branchCtx) {
    charts.branch = new Chart(branchCtx, {
      type: "doughnut",
      data: {
        labels: branchLabels,
        datasets: [
          {
            data: branchValues,
            backgroundColor: [
              primaryColor,
              accentColor,
              "#ff6e7d",
              warningColor,
              "#34d399",
              "#f59e0b",
              "#2dd4bf",
              "#60a5fa",
            ],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: textColor, font: { size: 10 }, padding: 8 },
          },
          title: {
            display: true,
            text: "Students By Branch",
            color: textColor,
            font: { size: 13 },
          },
        },
      },
    });
  }

  const semesterCounts = Array(8).fill(0);
  analytics.students.forEach((student) => {
    const sem = Number.parseInt(student.semester, 10);
    if (Number.isInteger(sem) && sem >= 1 && sem <= 8) {
      semesterCounts[sem - 1] += 1;
    }
  });

  if (semesterCtx) {
    charts.semester = new Chart(semesterCtx, {
      type: "bar",
      data: {
        labels: ["Sem 1", "Sem 2", "Sem 3", "Sem 4", "Sem 5", "Sem 6", "Sem 7", "Sem 8"],
        datasets: [
          {
            label: "Students",
            data: semesterCounts,
            backgroundColor: primaryColor,
            borderRadius: 4,
          },
        ],
      },
      options: {
        ...chartOptions,
        plugins: {
          ...chartOptions.plugins,
          title: { display: true, text: "Semester Distribution", color: textColor, font: { size: 13 } },
        },
      },
    });
  }

  const teacherCount = analytics.teacherCount;
  const studentCount = analytics.studentCount;

  if (ratioCtx) {
    charts.ratio = new Chart(ratioCtx, {
      type: "pie",
      data: {
        labels: ["Teachers", "Students"],
        datasets: [
          {
            data: [teacherCount, studentCount],
            backgroundColor: [accentColor, primaryColor],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: textColor, font: { size: 10 }, padding: 8 },
          },
          title: {
            display: true,
            text:
              teacherCount > 0
                ? `Teacher:Student Ratio (1:${Math.max(1, Math.round(studentCount / teacherCount))})`
                : "Teacher:Student Ratio",
            color: textColor,
            font: { size: 13 },
          },
        },
      },
    });
  }

  const trendLabels = [];
  const trendCounts = [];
  const trendMap = new Map();
  for (let i = 6; i >= 0; i -= 1) {
    const day = new Date();
    day.setDate(day.getDate() - i);
    day.setHours(0, 0, 0, 0);
    const key = day.toISOString().slice(0, 10);
    trendLabels.push(day.toLocaleDateString(undefined, { weekday: "short" }));
    trendMap.set(key, 0);
  }
  analytics.activityRows.forEach((entry) => {
    const key = String(entry.created_at || "").slice(0, 10);
    if (trendMap.has(key)) {
      trendMap.set(key, (trendMap.get(key) || 0) + 1);
    }
  });
  for (const key of trendMap.keys()) {
    trendCounts.push(trendMap.get(key) || 0);
  }

  if (activityCtx) {
    charts.activity = new Chart(activityCtx, {
      type: "line",
      data: {
        labels: trendLabels,
        datasets: [
          {
            label: "Admin Actions",
            data: trendCounts,
            borderColor: warningColor,
            backgroundColor: "rgba(255, 204, 102, 0.12)",
            fill: true,
            tension: 0.35,
          },
        ],
      },
      options: {
        ...chartOptions,
        plugins: {
          ...chartOptions.plugins,
          title: { display: true, text: "Weekly Activity Trend", color: textColor, font: { size: 13 } },
        },
      },
    });
  }
}

async function checkSystemHealth() {
  const dbEl = document.getElementById("health-db");
  const apiEl = document.getElementById("health-api");
  const backupEl = document.getElementById("health-backup");

  if (!dbEl || !apiEl || !backupEl) return;

  // Check database connection
  try {
    if (state.supabase) {
      const start = Date.now();
      const { error } = await state.supabase.from("branches").select("id", { head: true, count: "exact" });
      const duration = Date.now() - start;

      if (error) {
        dbEl.textContent = "Error";
        dbEl.style.color = "#ff6e7d";
      } else {
        dbEl.textContent = `OK (${duration}ms)`;
        dbEl.style.color = "#29c3af";
      }
    } else {
      dbEl.textContent = "Not connected";
      dbEl.style.color = "#ffcc66";
    }
  } catch (e) {
    dbEl.textContent = "Error";
    dbEl.style.color = "#ff6e7d";
  }

  // Check API reachability
  try {
    if (!navigator.onLine) {
      apiEl.textContent = "Offline";
      apiEl.style.color = "#ffcc66";
    } else {
      const baseUrl = deobfuscate(state.env.SUPABASE_URL);
      const anonKey = deobfuscate(state.env.SUPABASE_ANON_KEY);
      if (!baseUrl || !anonKey) {
        apiEl.textContent = "Config missing";
        apiEl.style.color = "#ffcc66";
      } else {
        const start = Date.now();
        const response = await fetch(`${baseUrl}/rest/v1/`, {
          method: "GET",
          headers: {
            apikey: anonKey,
            Authorization: `Bearer ${anonKey}`,
          },
          cache: "no-store",
        });
        const duration = Date.now() - start;
        if (response.ok || response.status === 401 || response.status === 404) {
          apiEl.textContent = `OK (${duration}ms)`;
          apiEl.style.color = "#29c3af";
        } else {
          apiEl.textContent = `Error (${response.status})`;
          apiEl.style.color = "#ff6e7d";
        }
      }
    }
  } catch (e) {
    apiEl.textContent = "Error";
    apiEl.style.color = "#ff6e7d";
  }

  // Check last backup
  const lastBackup = localStorage.getItem("lastBackup");
  if (lastBackup) {
    const backupDate = new Date(parseInt(lastBackup));
    backupEl.textContent = backupDate.toLocaleString();
    backupEl.style.color = "var(--text)";
  } else {
    backupEl.textContent = "Never";
    backupEl.style.color = "#ffcc66";
  }
}

function updateHeaderAndToolbar() {
  const module = MODULES[state.activeModule];
  els.moduleEyebrow.textContent = module.eyebrow;
  els.moduleTitle.textContent = module.title;

  const isDashboard = module.key === "dashboard";
  const isBackup = module.key === "db_backup";

  els.homeDashboard.classList.toggle("hidden", !isDashboard);
  els.tableSection.classList.toggle("hidden", isDashboard || isBackup);

  // Show/hide the backup panel
  let backupSection = document.getElementById("backup-section");
  if (isBackup && !backupSection) {
    backupSection = document.createElement("section");
    backupSection.id = "backup-section";
    backupSection.className = "grid-card";
    els.tableSection.parentNode.insertBefore(backupSection, els.tableSection.nextSibling);
  }
  if (backupSection) {
    backupSection.classList.toggle("hidden", !isBackup);
  }

  els.searchInput.disabled = isDashboard || isBackup;
  els.searchInput.placeholder =
    isDashboard || isBackup ? "Search disabled here" : "Search records...";

  const showAdd = !isDashboard && !isBackup && canCreateInModule(module);
  els.addBtn.classList.toggle("hidden", !showAdd);
  els.refreshBtn.classList.toggle("hidden", isBackup);

  const showExportPdf = !isDashboard && !isBackup && !module.noTable;
  els.exportPdfBtn.classList.toggle("hidden", !showExportPdf);

  const showBulkDelete = !isDashboard && !isBackup && !module.noTable && canDeleteInModule(module);
  const showBulkEdit = !isDashboard && !isBackup && !module.noTable && canEditInModule(module);
  els.bulkDeleteBtn.classList.toggle("hidden", !showBulkDelete);
  els.bulkEditBtn.classList.toggle("hidden", !showBulkEdit);

  updateBulkButtons();
}

function syncSelectAllCheckboxState() {
  const selectAll = document.getElementById("select-all-rows");
  if (!selectAll) {
    return;
  }

  const rowCheckboxes = Array.from(els.dataBody.querySelectorAll(".row-checkbox:not([disabled])"));
  if (!rowCheckboxes.length) {
    selectAll.checked = false;
    selectAll.indeterminate = false;
    selectAll.disabled = true;
    return;
  }

  rowCheckboxes.forEach((checkbox) => {
    checkbox.checked = state.selectedRows.has(String(checkbox.dataset.id));
  });

  const selectedCount = rowCheckboxes.filter((checkbox) => checkbox.checked).length;
  selectAll.disabled = false;
  selectAll.checked = selectedCount === rowCheckboxes.length;
  selectAll.indeterminate = selectedCount > 0 && selectedCount < rowCheckboxes.length;
}

function renderTable() {
  const module = MODULES[state.activeModule];
  if (module.noTable) {
    els.dataHead.innerHTML = "";
    els.dataBody.innerHTML = "";
    return;
  }

  const rows = getFilteredRows();
  const canEdit = canEditInModule(module);
  const canDelete = canDeleteInModule(module);
  const allowBulkOps = canEdit || canDelete;

  els.dataHead.innerHTML = `<tr>
    <th class="bulk-col"><input type="checkbox" id="select-all-rows" title="Select all" ${
      allowBulkOps ? "" : "disabled"
    }></th>
    ${module.columns
      .map((column) => `<th>${escapeHtml(column.label)}</th>`)
      .join("")}
    <th>Actions</th>
  </tr>`;

  if (!rows.length) {
    els.dataBody.innerHTML = `<tr><td colspan="${module.columns.length + 2}">No records found.</td></tr>`;
    syncSelectAllCheckboxState();
    return;
  }

  els.dataBody.innerHTML = rows
    .map((row) => {
      const cells = module.columns
        .map((column) => `<td>${escapeHtml(displayValue(column, row))}</td>`)
        .join("");

      const actionButtons = [
        canEdit
          ? `<button class="tiny" data-action="edit" data-id="${row[module.primaryKey]}">Edit</button>`
          : "",
        canDelete
          ? `<button class="tiny danger" data-action="delete" data-id="${row[module.primaryKey]}">Delete</button>`
          : "",
      ]
        .filter(Boolean)
        .join("");

      return `<tr data-row-id="${row[module.primaryKey]}">
        <td class="bulk-col"><input type="checkbox" class="row-checkbox" data-id="${row[module.primaryKey]}" ${
          allowBulkOps ? "" : "disabled"
        }></td>
        ${cells}
        <td><div class="row-actions">${actionButtons || "-"}</div></td>
      </tr>`;
    })
    .join("");

  syncSelectAllCheckboxState();
}

function applySelectScope(query, module) {
  if (isMainAdmin()) {
    return query;
  }

  const branchId = state.currentUser?.branchId;
  if (!branchId) {
    return query;
  }

  if (module.branchSelfScoped) {
    return query.eq("id", branchId);
  }

  if (module.branchField) {
    return query.eq(module.branchField, branchId);
  }

  return query;
}

function applyWriteScope(query, module) {
  if (isMainAdmin()) {
    return query;
  }

  const branchId = state.currentUser?.branchId;
  if (!branchId) {
    return query;
  }

  if (module.branchSelfScoped) {
    return query.eq("id", branchId);
  }

  if (module.branchField) {
    return query.eq(module.branchField, branchId);
  }

  return query;
}

async function loadOptions() {
  const client = state.supabase;
  const branchScopeId = !isMainAdmin() ? state.currentUser?.branchId : null;

  let branchesQuery = client.from("branches").select("id,name,code").order("name");
  let teachersQuery = client.from("teachers").select("id,name,email,branch_id").order("name");
  let roomsQuery = client.from("rooms").select("id,name,room_number,branch_id").order("name");
  let subjectsQuery = client.from("subjects").select("id,name,code,branch_id,is_lab").order("name");
  let pollsQuery = client.from("polls").select("id,title,branch_id").order("created_at", {
    ascending: false,
  });
  let panelUsersQuery = client
    .from("admin_panel_users")
    .select("id,username,display_name,branch_id")
    .order("created_at", { ascending: false });

  if (branchScopeId) {
    branchesQuery = branchesQuery.eq("id", branchScopeId);
    teachersQuery = teachersQuery.eq("branch_id", branchScopeId);
    roomsQuery = roomsQuery.eq("branch_id", branchScopeId);
    subjectsQuery = subjectsQuery.eq("branch_id", branchScopeId);
    pollsQuery = pollsQuery.eq("branch_id", branchScopeId);
    panelUsersQuery = panelUsersQuery.eq("branch_id", branchScopeId);
  }

  const [branchesRes, teachersRes, roomsRes, subjectsRes, pollsRes, panelUsersRes] =
    await Promise.all([
      branchesQuery,
      teachersQuery,
      roomsQuery,
      subjectsQuery,
      pollsQuery,
      panelUsersQuery,
    ]);

  const errors = [branchesRes, teachersRes, roomsRes, subjectsRes, pollsRes]
    .map((r) => r.error)
    .filter(Boolean);
  if (errors.length) {
    throw errors[0];
  }

  state.optionCache.branches = branchesRes.data || [];
  state.optionCache.teachers = teachersRes.data || [];
  state.optionCache.rooms = roomsRes.data || [];
  state.optionCache.subjects = subjectsRes.data || [];
  state.optionCache.polls = pollsRes.data || [];
  state.optionCache.panelUsers = panelUsersRes.error ? [] : panelUsersRes.data || [];
}

async function loadKpis() {
  const client = state.supabase;
  const branchScopeId = !isMainAdmin() ? state.currentUser?.branchId : null;

  const countQuery = (table, field = "id", scopeField = null) => {
    let query = client.from(table).select(field, { count: "exact", head: true });
    if (branchScopeId && scopeField) {
      query = query.eq(scopeField, branchScopeId);
    }
    return query;
  };

  const [teachers, students, rooms, timetable, branches, subjects, polls, panelUsers] =
    await Promise.all([
      countQuery("teachers", "id", "branch_id"),
      countQuery("students", "id", "branch_id"),
      countQuery("rooms", "id", "branch_id"),
      countQuery("timetable", "id", "branch_id"),
      branchScopeId
        ? client.from("branches").select("id", { count: "exact", head: true }).eq("id", branchScopeId)
        : countQuery("branches"),
      countQuery("subjects", "id", "branch_id"),
      countQuery("polls", "id", "branch_id"),
      isMainAdmin()
        ? countQuery("admin_panel_users")
        : countQuery("admin_panel_users", "id", "branch_id"),
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
  els.kpiPanelUsers.textContent = panelUsers.error ? "N/A" : String(panelUsers.count ?? 0);
}

function inputValueForField(field, row = null) {
  if (state.activeModule === "timetable" && field.key === "session_type") {
    return deriveTimetableSessionTypeValue(row);
  }

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
  if (!canEditInModule(module) && mode === "edit") {
    setStatus(els.dataMessage, "You do not have permission to edit here.", "error");
    return;
  }
  if (!canCreateInModule(module) && mode === "create") {
    setStatus(els.dataMessage, "You do not have permission to add here.", "error");
    return;
  }

  state.editor = { mode, module: module.key, row };
  els.editorTitle.textContent = `${mode === "create" ? "Create" : "Edit"} ${module.title}`;
  renderEditorFields(module, row, mode);
  bindTimetableEditorBehavior();
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
  return raw;
}

function shouldSkipRequiredValidation(module, field, context = {}) {
  if (!module || !field) {
    return false;
  }

  // For department users, branch is auto-injected from account scope.
  if (!isMainAdmin() && module.branchField && field.key === module.branchField) {
    return true;
  }

  if (module.key !== "timetable") {
    return false;
  }

  const { timetableIsBreak = false, timetableAllDaysBreak = false } = context;
  if (timetableAllDaysBreak && field.key === "day_of_week") {
    return true;
  }

  if (timetableIsBreak && ["subject_id", "teacher_id", "room_id", "batch"].includes(field.key)) {
    return true;
  }

  return false;
}

async function collectEditorPayload() {
  const module = MODULES[state.activeModule];
  const payload = {};

  const timetableSessionTypeEl =
    module.key === "timetable"
      ? els.editorBody.querySelector('[data-field="session_type"]')
      : null;
  const timetableIsBreakEl =
    module.key === "timetable"
      ? els.editorBody.querySelector('[data-field="is_break"]')
      : null;
  const timetableAllDaysBreakEl =
    module.key === "timetable"
      ? els.editorBody.querySelector('[data-field="apply_break_all_days"]')
      : null;
  const timetableSessionType =
    module.key === "timetable"
      ? timetableSessionTypeEl?.value || (timetableIsBreakEl?.checked ? "break" : "lecture")
      : null;
  const timetableIsBreak = module.key === "timetable" && timetableSessionType === "break";
  const timetableAllDaysBreak =
    module.key === "timetable" && timetableIsBreak && Boolean(timetableAllDaysBreakEl?.checked);

  for (const field of module.fields) {
    const inputEl = els.editorBody.querySelector(`[data-field="${field.key}"]`);
    if (!inputEl) {
      continue;
    }

    let required = field.required || (state.editor.mode === "create" && field.requiredOnCreate);
    if (
      shouldSkipRequiredValidation(module, field, {
        timetableIsBreak,
        timetableAllDaysBreak,
      })
    ) {
      required = false;
    }
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

  if (module.key === "students" && !payload.anonymous_id) {
    payload.anonymous_id = randomAnonymousId();
  }

  if (module.key === "timetable") {
    const sessionType = payload.session_type || (payload.is_break ? "break" : "lecture");
    const isBreak = sessionType === "break";

    if (isBreak) {
      payload.is_break = true;
      payload.break_name = "Break";
      payload.subject_id = null;
      payload.teacher_id = null;
      payload.room_id = null;
      payload.batch = null;
      payload.apply_break_all_days = Boolean(payload.apply_break_all_days);
    } else {
      payload.is_break = false;
      payload.break_name = null;
      payload.apply_break_all_days = false;

      const startMinutes = timeToMinutes(payload.start_time);
      const endMinutes = timeToMinutes(payload.end_time);
      if (startMinutes === null || endMinutes === null) {
        throw new Error("Start Time and End Time must be valid.");
      }

      const duration = endMinutes - startMinutes;
      const requiredDuration = timetableDurationForType(sessionType);
      const expectedLabel = requiredDuration === 120 ? "2 hours" : "1 hour";
      if (duration !== requiredDuration) {
        const classLabel = sessionType === "practical" ? "Practical" : "Lecture";
        throw new Error(`${classLabel} duration must be exactly ${expectedLabel}.`);
      }

      if (sessionType === "lecture") {
        payload.batch = null;
      }
    }

    delete payload.session_type;
  }

  if (["teachers", "students", "admin_panel_users"].includes(module.key)) {
    payload.updated_at = new Date().toISOString();
  }

  if (!isMainAdmin()) {
    const branchId = state.currentUser?.branchId;
    if (module.branchSelfScoped) {
      throw new Error("Branch creation is restricted for department users.");
    }
    if (module.branchField && branchId) {
      payload[module.branchField] = branchId;
    }
  }

  return payload;
}

async function applyBreakToAllDays(module, payload) {
  for (let day = 0; day < DAY_LABELS.length; day += 1) {
    let deleteQuery = state.supabase
      .from(module.table)
      .delete()
      .eq("branch_id", payload.branch_id)
      .eq("semester", payload.semester)
      .eq("day_of_week", day)
      .eq("period_number", payload.period_number);
    deleteQuery = applyWriteScope(deleteQuery, module);
    const { error: deleteError } = await deleteQuery;
    if (deleteError) {
      throw deleteError;
    }

    const dayPayload = {
      ...payload,
      day_of_week: day,
    };

    let insertQuery = state.supabase.from(module.table).insert(dayPayload);
    insertQuery = applyWriteScope(insertQuery, module);
    const { error: insertError } = await insertQuery;
    if (insertError) {
      throw insertError;
    }
  }
}

async function saveEditor() {
  const module = MODULES[state.activeModule];
  try {
    const payload = await collectEditorPayload();
    delete payload[module.primaryKey];
    const applyBreakAllDays =
      module.key === "timetable" && payload.is_break && payload.apply_break_all_days;
    delete payload.apply_break_all_days;
    setStatus(els.dataMessage, "Saving...");

    if (applyBreakAllDays) {
      await applyBreakToAllDays(module, payload);
      addActivity(`Applied ${module.title} break to all days`, {
        moduleKey: module.key,
        details: "Synchronized break details for every day",
      });
      setStatus(els.dataMessage, `${module.title} break applied for all days.`, "success");
      closeEditor();
      await loadOptions();
      await loadKpis();
      await refreshModuleData();
      return;
    }

    if (state.editor.mode === "create") {
      let query = state.supabase.from(module.table).insert(payload);
      query = applyWriteScope(query, module);
      const { error } = await query;
      if (error) {
        throw error;
      }
      addActivity(`Created ${module.title} record`, {
        moduleKey: module.key,
        details: `${module.title} creation via panel`,
      });
      setStatus(els.dataMessage, `${module.title} record created.`, "success");
    } else {
      const id = state.editor.row[module.primaryKey];
      let query = state.supabase
        .from(module.table)
        .update(payload)
        .eq(module.primaryKey, id);
      query = applyWriteScope(query, module);
      const { error } = await query;
      if (error) {
        throw error;
      }
      addActivity(`Updated ${module.title} record`, {
        moduleKey: module.key,
        details: `${module.title} update via panel`,
      });
      setStatus(els.dataMessage, `${module.title} record updated.`, "success");
    }

    closeEditor();
    await loadOptions();
    await loadKpis();
    await refreshModuleData();
  } catch (error) {
    setStatus(els.dataMessage, error?.message || "Failed to save record.", "error");
  }
}

async function deleteRow(id) {
  const module = MODULES[state.activeModule];
  if (!canDeleteInModule(module)) {
    setStatus(els.dataMessage, "Delete permission denied.", "error");
    return;
  }

  const confirmed = confirm(`Delete this ${module.title} record? This cannot be undone.`);
  if (!confirmed) {
    return;
  }

  try {
    let query = state.supabase
      .from(module.table)
      .delete()
      .eq(module.primaryKey, id);
    query = applyWriteScope(query, module);
    const { error } = await query;
    if (error) {
      throw error;
    }

    addActivity(`Deleted ${module.title} record`, {
      moduleKey: module.key,
      details: `${module.title} deletion via panel`,
    });
    setStatus(els.dataMessage, `${module.title} record deleted.`, "success");
    await loadOptions();
    await loadKpis();
    await refreshModuleData();
  } catch (error) {
    setStatus(els.dataMessage, error?.message || "Failed to delete record.", "error");
  }
}

async function refreshModuleData() {
  const module = MODULES[state.activeModule];
  
  // Clear selected rows when refreshing data
  state.selectedRows.clear();
  updateBulkButtons();

  if (module.isBackup) {
    renderBackupModule();
    setStatus(els.dataMessage, "");
    return;
  }

  if (module.noTable) {
    await loadActivityFeed();
    renderQuickAccess();
    renderActivityLog();
    renderTable();
    setStatus(els.dataMessage, "Dashboard ready.", "success");
    return;
  }

  setStatus(els.dataMessage, `Loading ${module.title.toLowerCase()}...`);
  let query = state.supabase.from(module.table).select(module.select);
  query = applySelectScope(query, module);

  if (module.orderBy) {
    query = query.order(module.orderBy.column, { ascending: module.orderBy.ascending });
  }

  const { data, error } = await query;
  if (error) {
    throw error;
  }

  state.rows = data || [];
  renderTable();
  setStatus(els.dataMessage, `${module.title} loaded.`, "success");
}

// ─── DB BACKUP ──────────────────────────────────────────────────────────────

const BACKUP_TABLES = [
  { key: "teachers",            label: "Teachers",              select: "*" },
  { key: "students",            label: "Students",              select: "*" },
  { key: "branches",            label: "Branches",              select: "*" },
  { key: "rooms",               label: "Rooms",                 select: "*" },
  { key: "subjects",            label: "Subjects",              select: "*" },
  { key: "timetable",           label: "Timetable",             select: "*" },
  { key: "polls",               label: "Polls",                 select: "*" },
  { key: "poll_options",        label: "Poll Options",          select: "*" },
  { key: "teacher_subjects",    label: "Teacher Subjects",      select: "*" },
  { key: "admin_panel_users",   label: "Panel Users",           select: "id,username,display_name,role,branch_id,is_active,created_at,updated_at" },
  { key: "admin_panel_activity",label: "Activity Logs",         select: "*" },
];

function renderBackupModule() {
  let section = document.getElementById("backup-section");
  if (!section) {
    section = document.createElement("section");
    section.id = "backup-section";
    section.className = "grid-card";
    els.tableSection.parentNode.insertBefore(section, els.tableSection.nextSibling);
  }
  section.classList.remove("hidden");

  section.innerHTML = `
    <div class="backup-panel">

      <!-- ── BACKUP ── -->
      <div class="backup-header">
        <div>
          <h4>Database Backup</h4>
          <p class="muted">Export tables as JSON or CSV. All data is fetched directly from Supabase.</p>
        </div>
        <div class="backup-header-actions">
          <button id="backup-all-json" class="btn btn-primary">⬇ Full Backup (JSON)</button>
          <button id="backup-all-csv" class="btn btn-secondary">⬇ Full Backup (CSV)</button>
        </div>
      </div>

      <div id="backup-status-bar" class="backup-status-bar hidden">
        <div id="backup-progress-fill" class="backup-progress-fill"></div>
        <span id="backup-status-text" class="backup-status-text">Preparing...</span>
      </div>

      <div class="backup-table-grid">
        ${BACKUP_TABLES.map((t) => `
          <article class="backup-table-card">
            <div class="backup-table-info">
              <strong>${escapeHtml(t.label)}</strong>
              <span class="muted mini">${escapeHtml(t.key)}</span>
            </div>
            <div class="backup-table-actions">
              <button class="tiny" data-backup-table="${t.key}" data-backup-fmt="json">JSON</button>
              <button class="tiny" data-backup-table="${t.key}" data-backup-fmt="csv">CSV</button>
            </div>
          </article>
        `).join("")}
      </div>

      <!-- ── RESTORE ── -->
      <div class="restore-section">
        <div class="restore-header">
          <div>
            <h4>Restore from Backup</h4>
            <p class="muted">Upload a JSON backup file (full or single-table). Existing rows are upserted — nothing is deleted.</p>
          </div>
        </div>

        <div id="restore-drop-zone" class="restore-drop-zone">
          <div class="restore-drop-icon">⬆</div>
          <p class="restore-drop-label">Drop a <strong>.json</strong> backup here, or <label for="restore-file-input" class="restore-file-link">browse</label></p>
          <input id="restore-file-input" type="file" accept=".json,application/json" class="restore-file-hidden" />
          <p class="muted mini" id="restore-file-name">No file selected</p>
        </div>

        <div id="restore-status-bar" class="backup-status-bar hidden">
          <div id="restore-progress-fill" class="backup-progress-fill" style="background:linear-gradient(90deg,#ff9d4d,#ffcc66)"></div>
          <span id="restore-status-text" class="backup-status-text">Restoring...</span>
        </div>
      </div>

      <!-- ── AUTOMATED BACKUP ── -->
      <div class="auto-backup-section">
        <div class="restore-header">
          <div>
            <h4>Automated Backup</h4>
            <p class="muted">Schedule automatic backups to run at regular intervals.</p>
          </div>
        </div>
        <div class="auto-backup-controls">
          <div class="auto-backup-setting">
            <label for="backup-interval">Backup Interval:</label>
            <select id="backup-interval" class="backup-select">
              <option value="0">Disabled</option>
              <option value="86400000">Daily</option>
              <option value="604800000">Weekly</option>
              <option value="2592000000">Monthly</option>
            </select>
          </div>
          <div class="auto-backup-setting">
            <label for="backup-format">Backup Format:</label>
            <select id="backup-format" class="backup-select">
              <option value="json">JSON</option>
              <option value="csv">CSV</option>
            </select>
          </div>
          <button id="save-backup-schedule" class="btn btn-primary">Save Schedule</button>
          <button id="run-scheduled-backup" class="btn btn-secondary">Run Now</button>
        </div>
        <div class="auto-backup-status">
          <p id="backup-schedule-status" class="muted mini">No automatic backup scheduled.</p>
        </div>
      </div>
    </div>`;

  // Backup events
  section.querySelector("#backup-all-json").addEventListener("click", () => runFullBackup("json"));
  section.querySelector("#backup-all-csv").addEventListener("click", () => runFullBackup("csv"));
  section.querySelectorAll("[data-backup-table]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const tableKey = btn.dataset.backupTable;
      const fmt = btn.dataset.backupFmt;
      const tDef = BACKUP_TABLES.find((t) => t.key === tableKey);
      if (tDef) exportTable(tDef, fmt);
    });
  });

  // Restore events
  const dropZone = section.querySelector("#restore-drop-zone");
  const fileInput = section.querySelector("#restore-file-input");
  const fileNameEl = section.querySelector("#restore-file-name");

  dropZone.addEventListener("dragover", (e) => { e.preventDefault(); dropZone.classList.add("drag-over"); });
  dropZone.addEventListener("dragleave", () => dropZone.classList.remove("drag-over"));
  dropZone.addEventListener("drop", (e) => {
    e.preventDefault();
    dropZone.classList.remove("drag-over");
    const file = e.dataTransfer.files[0];
    if (file) handleRestoreFile(file, fileNameEl);
  });
  fileInput.addEventListener("change", () => {
    const file = fileInput.files[0];
    if (file) handleRestoreFile(file, fileNameEl);
    fileInput.value = "";
  });

  // Automated backup events
  const intervalSelect = section.querySelector("#backup-interval");
  const formatSelect = section.querySelector("#backup-format");
  const saveScheduleBtn = section.querySelector("#save-backup-schedule");
  const runNowBtn = section.querySelector("#run-scheduled-backup");
  const scheduleStatus = section.querySelector("#backup-schedule-status");

  // Load saved schedule
  const savedInterval = localStorage.getItem('backupInterval') || '0';
  const savedFormat = localStorage.getItem('backupFormat') || 'json';
  intervalSelect.value = savedInterval;
  formatSelect.value = savedFormat;
  updateBackupScheduleStatus();

  saveScheduleBtn.addEventListener("click", () => {
    const interval = intervalSelect.value;
    const format = formatSelect.value;
    
    localStorage.setItem('backupInterval', interval);
    localStorage.setItem('backupFormat', format);
    
    if (interval !== '0') {
      scheduleNextBackup();
      addNotification(`Automatic backup scheduled: ${getIntervalLabel(interval)}`, 'success');
    } else {
      clearScheduledBackup();
      addNotification('Automatic backup disabled', 'info');
    }
    
    updateBackupScheduleStatus();
  });

  runNowBtn.addEventListener("click", async () => {
    const format = formatSelect.value;
    try {
      await runFullBackup(format);
      addNotification('Manual backup completed successfully', 'success');
    } catch (error) {
      addNotification(`Backup failed: ${error.message}`, 'error');
    }
  });
}

function getIntervalLabel(intervalMs) {
  const intervals = {
    '86400000': 'Daily',
    '604800000': 'Weekly',
    '2592000000': 'Monthly'
  };
  return intervals[intervalMs] || 'Custom';
}

function updateBackupScheduleStatus() {
  const statusEl = document.getElementById('backup-schedule-status');
  if (!statusEl) return;
  
  const interval = localStorage.getItem('backupInterval') || '0';
  const lastBackup = localStorage.getItem('lastBackup');
  
  if (interval === '0') {
    statusEl.textContent = 'No automatic backup scheduled.';
    statusEl.style.color = 'var(--muted)';
  } else {
    const label = getIntervalLabel(interval);
    let status = `Automatic backup: ${label}`;
    
    if (lastBackup) {
      const backupDate = new Date(parseInt(lastBackup));
      status += ` | Last backup: ${backupDate.toLocaleDateString()}`;
    }
    
    statusEl.textContent = status;
    statusEl.style.color = 'var(--primary)';
  }
}

function scheduleNextBackup() {
  clearScheduledBackup();

  const interval = parseInt(localStorage.getItem("backupInterval") || "0", 10);
  if (interval === 0) return;

  const lastBackup = parseInt(localStorage.getItem("lastBackup") || "0", 10);
  const now = Date.now();
  const anchor = Number.isFinite(lastBackup) && lastBackup > 0 ? lastBackup : now;
  const nextBackup = anchor + interval;

  if (nextBackup <= now) {
    // Run backup now if overdue
    void runScheduledBackup();
    return;
  } else {
    // Schedule next backup
    const timeout = nextBackup - now;
    state.backupTimerId = setTimeout(() => {
      void runScheduledBackup();
    }, timeout);
  }
}

async function runScheduledBackup() {
  const format = localStorage.getItem("backupFormat") || "json";
  try {
    await runFullBackup(format);
    addNotification(`Scheduled backup completed (${format.toUpperCase()})`, 'success');
  } catch (error) {
    addNotification(`Scheduled backup failed: ${error.message}`, 'error');
  } finally {
    scheduleNextBackup();
  }
}

function clearScheduledBackup() {
  if (state.backupTimerId) {
    clearTimeout(state.backupTimerId);
    state.backupTimerId = null;
  }
}

// Initialize backup scheduler on load
function initBackupScheduler() {
  const interval = localStorage.getItem('backupInterval') || '0';
  if (interval !== '0') {
    scheduleNextBackup();
  }
}

async function fetchTableData(tDef) {
  const { data, error } = await state.supabase.from(tDef.key).select(tDef.select);
  if (error) throw new Error(`Failed to fetch ${tDef.key}: ${error.message}`);
  return data || [];
}

function downloadFile(filename, content, mimeType) {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(url); document.body.removeChild(a); }, 500);
}

function toCSV(rows) {
  if (!rows || !rows.length) return "";
  const keys = Object.keys(rows[0]);
  const escape = (v) => {
    const s = String(v == null ? "" : v);
    return s.includes(",") || s.includes("\"") || s.includes("\n")
      ? `"${s.replace(/"/g, '""')}"`
      : s;
  };
  const header = keys.map(escape).join(",");
  const body = rows.map((r) => keys.map((k) => escape(r[k])).join(",")).join("\n");
  return `${header}\n${body}`;
}

function backupTimestamp() {
  return new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-");
}

async function exportTable(tDef, fmt) {
  setStatus(els.dataMessage, `Exporting ${tDef.label}...`);
  try {
    const rows = await fetchTableData(tDef);
    const ts = backupTimestamp();
    if (fmt === "csv") {
      downloadFile(`sjcem_${tDef.key}_${ts}.csv`, toCSV(rows), "text/csv");
    } else {
      downloadFile(`sjcem_${tDef.key}_${ts}.json`, JSON.stringify(rows, null, 2), "application/json");
    }
    addActivity(`Exported ${tDef.label} (${fmt.toUpperCase()})`, {
      moduleKey: "db_backup",
      details: `${rows.length} rows exported`,
    });
    setStatus(els.dataMessage, `${tDef.label} exported (${rows.length} rows).`, "success");
  } catch (err) {
    setStatus(els.dataMessage, err?.message || "Export failed.", "error");
  }
}

async function runFullBackup(fmt) {
  const statusBar = document.getElementById("backup-status-bar");
  const progressFill = document.getElementById("backup-progress-fill");
  const statusText = document.getElementById("backup-status-text");

  if (statusBar) statusBar.classList.remove("hidden");

  const total = BACKUP_TABLES.length;
  const allData = {};
  const allCSVParts = [];
  let done = 0;

  try {
    for (const tDef of BACKUP_TABLES) {
      if (statusText) statusText.textContent = `Fetching ${tDef.label}...`;
      const rows = await fetchTableData(tDef);
      allData[tDef.key] = rows;
      if (fmt === "csv") {
        allCSVParts.push(`## ${tDef.label} (${tDef.key}) ##`);
        allCSVParts.push(toCSV(rows));
        allCSVParts.push("");
      }
      done += 1;
      const pct = Math.round((done / total) * 100);
      if (progressFill) progressFill.style.width = `${pct}%`;
    }

    const ts = backupTimestamp();
    if (fmt === "csv") {
      downloadFile(`sjcem_full_backup_${ts}.csv`, allCSVParts.join("\n"), "text/csv");
    } else {
      const meta = { exported_at: new Date().toISOString(), tables: Object.keys(allData).length };
      downloadFile(
        `sjcem_full_backup_${ts}.json`,
        JSON.stringify({ _meta: meta, ...allData }, null, 2),
        "application/json"
      );
    }

    const totalRows = Object.values(allData).reduce((s, r) => s + r.length, 0);
    localStorage.setItem("lastBackup", Date.now().toString());
    updateBackupScheduleStatus();
    void checkSystemHealth();
    addActivity(`Full DB Backup (${fmt.toUpperCase()})`, {
      moduleKey: "db_backup",
      details: `${total} tables, ${totalRows} total rows`,
    });
    if (statusText) statusText.textContent = `Backup complete — ${totalRows} rows across ${total} tables.`;
    setStatus(els.dataMessage, `Full backup complete.`, "success");
  } catch (err) {
    if (statusText) statusText.textContent = `Error: ${err?.message}`;
    setStatus(els.dataMessage, err?.message || "Backup failed.", "error");
    throw err;
  } finally {
    setTimeout(() => { if (statusBar) statusBar.classList.add("hidden"); }, 4000);
  }
}

// ─── RESTORE ────────────────────────────────────────────────────────────────

/** Parse uploaded JSON — supports full backup ({_meta, teachers:[…], …}) or single-table ([…]) */
function parseRestoreFile(json) {
  if (Array.isArray(json)) {
    // single-table array — unknown table; caller must supply table key
    return { type: "single-array", data: json };
  }
  if (json && typeof json === "object") {
    // full backup — keys are table names
    const tables = {};
    for (const [k, v] of Object.entries(json)) {
      if (k === "_meta") continue;
      if (Array.isArray(v)) tables[k] = v;
    }
    if (Object.keys(tables).length > 0) {
      return { type: "full", data: tables, meta: json._meta || null };
    }
  }
  throw new Error("Unrecognised backup format. Upload a JSON file exported from this panel.");
}

function handleRestoreFile(file, fileNameEl) {
  if (!file.name.endsWith(".json")) {
    setStatus(els.dataMessage, "Only JSON backup files are supported for restore.", "error");
    return;
  }
  if (fileNameEl) fileNameEl.textContent = file.name;

  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const json = JSON.parse(e.target.result);
      const parsed = parseRestoreFile(json);

      if (parsed.type === "single-array") {
        // We don't know which table — ask user
        showRestoreTablePicker(file.name, parsed.data);
      } else {
        showRestoreConfirmDialog(file.name, parsed.data, parsed.meta);
      }
    } catch (err) {
      setStatus(els.dataMessage, `Cannot parse file: ${err.message}`, "error");
    }
  };
  reader.readAsText(file);
}

/** For single-table arrays where the table key is unknown, ask the user to pick */
function showRestoreTablePicker(filename, rows) {
  const options = BACKUP_TABLES.map((t) => `<option value="${t.key}">${escapeHtml(t.label)} (${t.key})</option>`).join("");
  const html = `
    <div class="restore-dialog-body">
      <p class="muted">The file <strong>${escapeHtml(filename)}</strong> contains <strong>${rows.length} rows</strong> but no table name. Select which table to restore into:</p>
      <div class="field">
        <label>Target Table</label>
        <select id="restore-table-pick">${options}</select>
      </div>
      <p class="restore-warning">⚠ Existing rows with the same primary key will be <strong>overwritten</strong>. Other rows are untouched.</p>
    </div>`;

  showRestoreModal("Select Target Table", html, () => {
    const tableKey = document.getElementById("restore-table-pick")?.value;
    if (!tableKey) return;
    const tableData = { [tableKey]: rows };
    runRestore(tableData);
  });
}

/** Full or known-table: show a preview of what will be restored */
function showRestoreConfirmDialog(filename, tableData, meta) {
  const rows = Object.entries(tableData);
  const totalRows = rows.reduce((s, [, v]) => s + v.length, 0);
  const metaLine = meta?.exported_at
    ? `<p class="muted mini">Backup taken: <strong>${new Date(meta.exported_at).toLocaleString()}</strong></p>`
    : "";

  const tableRows = rows
    .map(([key, data]) => {
      const tDef = BACKUP_TABLES.find((t) => t.key === key);
      const label = tDef?.label || key;
      return `<tr><td>${escapeHtml(label)}</td><td class="muted mini">${escapeHtml(key)}</td><td><strong>${data.length}</strong></td></tr>`;
    })
    .join("");

  const html = `
    <div class="restore-dialog-body">
      ${metaLine}
      <p class="muted">File: <strong>${escapeHtml(filename)}</strong> &nbsp;·&nbsp; <strong>${totalRows}</strong> total rows across <strong>${rows.length}</strong> tables.</p>
      <div class="restore-preview-table-wrap">
        <table class="restore-preview-table">
          <thead><tr><th>Table</th><th>Key</th><th>Rows</th></tr></thead>
          <tbody>${tableRows}</tbody>
        </table>
      </div>
      <p class="restore-warning">⚠ Existing rows with the same primary key will be <strong>overwritten (upserted)</strong>. No rows are deleted.</p>
    </div>`;

  showRestoreModal(`Confirm Restore — ${rows.length} table${rows.length !== 1 ? "s" : ""}`, html, () => {
    runRestore(tableData);
  });
}

/** Generic modal for restore confirmation */
function showRestoreModal(title, bodyHtml, onConfirm) {
  // Remove any existing restore modal
  document.getElementById("restore-modal")?.remove();

  const modal = document.createElement("dialog");
  modal.id = "restore-modal";
  modal.className = "editor-dialog";
  modal.innerHTML = `
    <form method="dialog" class="editor-shell">
      <header class="editor-header">
        <h4>${escapeHtml(title)}</h4>
        <button type="button" class="icon-btn" id="restore-modal-close">✕</button>
      </header>
      <div class="editor-body restore-modal-body" style="display:block;max-height:60vh;overflow:auto;padding:1rem">
        ${bodyHtml}
      </div>
      <footer class="editor-footer">
        <button type="button" class="btn btn-ghost" id="restore-modal-cancel">Cancel</button>
        <button type="button" class="btn btn-danger" id="restore-modal-confirm">Restore Now</button>
      </footer>
    </form>`;

  document.body.appendChild(modal);
  modal.showModal();

  const close = () => { modal.close(); modal.remove(); };
  modal.querySelector("#restore-modal-close").addEventListener("click", close);
  modal.querySelector("#restore-modal-cancel").addEventListener("click", close);
  modal.addEventListener("cancel", (e) => { e.preventDefault(); close(); });
  modal.querySelector("#restore-modal-confirm").addEventListener("click", () => {
    close();
    onConfirm();
  });
}

/** Actually perform the upsert restore */
async function runRestore(tableData) {
  const statusBar = document.getElementById("restore-status-bar");
  const progressFill = document.getElementById("restore-progress-fill");
  const statusText = document.getElementById("restore-status-text");

  if (statusBar) statusBar.classList.remove("hidden");
  if (progressFill) progressFill.style.width = "0%";

  const entries = Object.entries(tableData);
  const total = entries.length;
  let done = 0;
  let totalUpserted = 0;
  const errors = [];

  for (const [tableKey, rows] of entries) {
    const tDef = BACKUP_TABLES.find((t) => t.key === tableKey);
    const label = tDef?.label || tableKey;

    if (statusText) statusText.textContent = `Restoring ${label}… (${rows.length} rows)`;

    if (!rows.length) {
      done += 1;
      if (progressFill) progressFill.style.width = `${Math.round((done / total) * 100)}%`;
      continue;
    }

    try {
      // Upsert in chunks of 500 to avoid payload limits
      const CHUNK = 500;
      for (let i = 0; i < rows.length; i += CHUNK) {
        const chunk = rows.slice(i, i + CHUNK);
        const { error } = await state.supabase
          .from(tableKey)
          .upsert(chunk, { onConflict: "id", ignoreDuplicates: false });
        if (error) throw new Error(`${label}: ${error.message}`);
      }
      totalUpserted += rows.length;
    } catch (err) {
      errors.push(err.message);
      console.error("Restore error", err);
    }

    done += 1;
    if (progressFill) progressFill.style.width = `${Math.round((done / total) * 100)}%`;
  }

  if (errors.length) {
    const msg = `Restore finished with ${errors.length} error(s): ${errors[0]}`;
    if (statusText) statusText.textContent = msg;
    setStatus(els.dataMessage, msg, "error");
    addActivity("Restore completed with errors", { moduleKey: "db_backup", details: errors.join(" | ") });
  } else {
    const msg = `Restore complete — ${totalUpserted} rows upserted across ${total} table${total !== 1 ? "s" : ""}.`;
    if (statusText) statusText.textContent = msg;
    setStatus(els.dataMessage, msg, "success");
    addActivity(`DB Restore complete`, { moduleKey: "db_backup", details: `${totalUpserted} rows upserted, ${total} tables` });
  }

  setTimeout(() => { if (statusBar) statusBar.classList.add("hidden"); }, 6000);
}

async function switchModule(moduleKey) {
  const allowed = getAllowedModuleKeys();
  if (!allowed.includes(moduleKey)) {
    setStatus(els.dataMessage, "This module is not allowed for your account.", "error");
    return;
  }

  state.activeModule = moduleKey;
  state.searchQuery = "";
  els.searchInput.value = "";
  state.selectedRows.clear();
  updateBulkButtons();

  buildModuleNav();
  updateHeaderAndToolbar();
  await refreshModuleData();
}

function unlockUI() {
  state.unlocked = true;
  els.authCard.classList.add("hidden");
  els.dashboard.classList.remove("hidden");
  setCurrentUserBadge();
}

async function lockUI() {
  if (state.unlocked) {
    addActivity("Panel locked", {
      moduleKey: "auth",
      details: "User logged out",
    });
  }

  await unsubscribeRealtimeNotifications();

  state.unlocked = false;
  state.currentUser = null;
  state.activeModule = "dashboard";
  state.rows = [];
  state.searchQuery = "";
  state.activityFeed = [];
  state.selectedRows.clear();

  els.usernameInput.value = "";
  els.passwordInput.value = "";
  els.searchInput.value = "";

  els.dashboard.classList.add("hidden");
  els.authCard.classList.remove("hidden");
  els.notificationContainer.classList.add("hidden");
  setCurrentUserBadge();
  setStatus(els.authMessage, "Panel locked.", "success");

  addNotification("Panel locked successfully", 'info');
}

function toggleTheme() {
  const isLight = document.body.classList.contains("light-theme");
  if (isLight) {
    document.body.classList.remove("light-theme");
    localStorage.setItem("theme", "dark");
    els.themeToggle.title = "Switch to light mode";
    els.themeToggle.textContent = "🌙";
  } else {
    document.body.classList.add("light-theme");
    localStorage.setItem("theme", "light");
    els.themeToggle.title = "Switch to dark mode";
    els.themeToggle.textContent = "☀";
  }

  if (state.activeModule === "dashboard") {
    void renderCharts();
  }
}

function initTheme() {
  const savedTheme = localStorage.getItem("theme") || "dark";
  if (savedTheme === "light") {
    document.body.classList.add("light-theme");
    els.themeToggle.title = "Switch to dark mode";
    els.themeToggle.textContent = "☀";
  } else {
    els.themeToggle.title = "Switch to light mode";
    els.themeToggle.textContent = "🌙";
  }
}

function updateRowSelection(id, selected) {
  const normalizedId = String(id);
  if (selected) {
    state.selectedRows.add(normalizedId);
  } else {
    state.selectedRows.delete(normalizedId);
  }
}

function updateBulkButtons() {
  if (!els.bulkDeleteBtn || !els.bulkEditBtn) {
    return;
  }

  const hasSelection = state.selectedRows.size > 0;
  els.bulkDeleteBtn.disabled = !hasSelection;
  els.bulkEditBtn.disabled = !hasSelection;

  if (hasSelection) {
    els.bulkDeleteBtn.textContent = `Bulk Delete (${state.selectedRows.size})`;
    els.bulkEditBtn.textContent = `Bulk Edit (${state.selectedRows.size})`;
  } else {
    els.bulkDeleteBtn.textContent = 'Bulk Delete';
    els.bulkEditBtn.textContent = 'Bulk Edit';
  }

  syncSelectAllCheckboxState();
}

async function bulkDelete() {
  if (state.selectedRows.size === 0) return;
  
  const module = MODULES[state.activeModule];
  const canDelete = canDeleteInModule(module);
  if (!canDelete) {
    setStatus(els.dataMessage, "You don't have permission to delete records in this module.", "error");
    return;
  }
  
  const confirmMessage = `Are you sure you want to delete ${state.selectedRows.size} selected record(s)?`;
  if (!confirm(confirmMessage)) return;
  
  const ids = Array.from(state.selectedRows);
  try {
    let query = state.supabase
      .from(module.table)
      .delete()
      .in(module.primaryKey, ids);
    query = applyWriteScope(query, module);
    const { error } = await query;
    
    if (error) throw error;
    
    addActivity(`Bulk deleted ${ids.length} ${module.title}`, {
      moduleKey: module.key,
      details: `Deleted IDs: ${ids.join(', ')}`,
    });
    
    state.selectedRows.clear();
    updateBulkButtons();
    await refreshModuleData();
    setStatus(els.dataMessage, `Successfully deleted ${ids.length} record(s).`, "success");
  } catch (error) {
    setStatus(els.dataMessage, `Bulk delete failed: ${error.message}`, "error");
  }
}

function getBulkEditableFields(module) {
  return (module.fields || []).filter(
    (field) =>
      ![
        "password_plain",
        "session_type",
        "apply_break_all_days",
      ].includes(field.key)
  );
}

function renderBulkValueInput(field) {
  if (!field) {
    return "";
  }

  if (field.type === "checkbox") {
    return `<label class="field">
      <span>Value</span>
      <select id="bulk-edit-value">
        <option value="true">True</option>
        <option value="false">False</option>
      </select>
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
          return `<option value="${escapeHtml(optionValue)}">${escapeHtml(label)}</option>`;
        })
      )
      .join("");
    return `<label class="field">
      <span>Value</span>
      <select id="bulk-edit-value">${optionHtml}</select>
    </label>`;
  }

  if (field.type === "textarea") {
    return `<label class="field full">
      <span>Value</span>
      <textarea id="bulk-edit-value" rows="4"></textarea>
    </label>`;
  }

  return `<label class="field">
    <span>Value</span>
    <input id="bulk-edit-value" type="${field.type || "text"}" ${
      field.min !== undefined ? `min="${field.min}"` : ""
    } ${field.max !== undefined ? `max="${field.max}"` : ""} ${
      field.step !== undefined ? `step="${field.step}"` : ""
    } />
  </label>`;
}

function castBulkValue(field, valueEl, shouldClearValue) {
  if (shouldClearValue) {
    return null;
  }

  if (!valueEl) {
    return null;
  }

  if (field.type === "checkbox") {
    return valueEl.value === "true";
  }

  if (valueEl.value === "") {
    return null;
  }

  if (field.type === "number") {
    return Number(valueEl.value);
  }
  if (field.type === "time") {
    return normalizeTime(valueEl.value);
  }
  return valueEl.value;
}

function closeBulkEditDialog() {
  const dialog = document.getElementById("bulk-edit-dialog");
  if (!dialog) {
    return;
  }
  dialog.close();
  dialog.remove();
}

async function applyBulkEdit() {
  const module = MODULES[state.activeModule];
  const ids = Array.from(state.selectedRows);
  if (!ids.length) {
    return;
  }

  const fields = getBulkEditableFields(module);
  const fieldSelect = document.getElementById("bulk-edit-field");
  const clearValueEl = document.getElementById("bulk-clear-value");

  if (!fieldSelect) {
    return;
  }

  const selectedField = fields.find((field) => field.key === fieldSelect.value);
  if (!selectedField) {
    setStatus(els.dataMessage, "Please choose a valid field for bulk edit.", "error");
    return;
  }

  if (!isMainAdmin() && module.branchField && selectedField.key === module.branchField) {
    setStatus(els.dataMessage, "Branch cannot be modified by department users.", "error");
    return;
  }

  const shouldClearValue = Boolean(clearValueEl?.checked) && selectedField.type !== "checkbox";
  const valueEl = document.getElementById("bulk-edit-value");
  const value = castBulkValue(selectedField, valueEl, shouldClearValue);

  if (
    selectedField.required &&
    selectedField.type !== "checkbox" &&
    (value === null || value === "")
  ) {
    setStatus(els.dataMessage, `${selectedField.label} cannot be empty.`, "error");
    return;
  }

  const payload = {
    [selectedField.key]: value,
  };
  if (["teachers", "students", "admin_panel_users"].includes(module.key)) {
    payload.updated_at = new Date().toISOString();
  }

  try {
    let query = state.supabase.from(module.table).update(payload).in(module.primaryKey, ids);
    query = applyWriteScope(query, module);
    const { error } = await query;
    if (error) {
      throw error;
    }

    addActivity(`Bulk updated ${ids.length} ${module.title} record(s)`, {
      moduleKey: module.key,
      details: `Field ${selectedField.key} updated for IDs: ${ids.join(", ")}`,
    });

    closeBulkEditDialog();
    state.selectedRows.clear();
    updateBulkButtons();
    await refreshModuleData();
    setStatus(els.dataMessage, `Bulk edit applied to ${ids.length} record(s).`, "success");
  } catch (error) {
    setStatus(els.dataMessage, `Bulk edit failed: ${error.message}`, "error");
  }
}

function openBulkEditDialog() {
  const module = MODULES[state.activeModule];
  const fields = getBulkEditableFields(module);

  if (!fields.length) {
    setStatus(els.dataMessage, "No editable fields available for bulk edit.", "error");
    return;
  }

  closeBulkEditDialog();

  const dialog = document.createElement("dialog");
  dialog.id = "bulk-edit-dialog";
  dialog.className = "editor-dialog";
  dialog.innerHTML = `
    <form method="dialog" class="editor-shell">
      <header class="editor-header">
        <h4>Bulk Edit ${escapeHtml(module.title)}</h4>
        <button type="button" class="icon-btn" id="bulk-edit-close">✕</button>
      </header>
      <div class="editor-body" style="grid-template-columns:1fr;">
        <p class="muted">Apply one field change to <strong>${state.selectedRows.size}</strong> selected records.</p>
        <label class="field">
          <span>Field</span>
          <select id="bulk-edit-field">
            ${fields
              .map((field) => `<option value="${escapeHtml(field.key)}">${escapeHtml(field.label)}</option>`)
              .join("")}
          </select>
        </label>
        <div id="bulk-edit-value-wrap">${renderBulkValueInput(fields[0])}</div>
        <label class="field" id="bulk-clear-wrap">
          <span>
            <input type="checkbox" id="bulk-clear-value" />
            Clear value (set NULL)
          </span>
        </label>
      </div>
      <footer class="editor-footer">
        <button type="button" class="btn btn-ghost" id="bulk-edit-cancel">Cancel</button>
        <button type="button" class="btn btn-primary" id="bulk-edit-apply">Apply</button>
      </footer>
    </form>`;

  document.body.appendChild(dialog);
  dialog.showModal();

  const fieldSelect = dialog.querySelector("#bulk-edit-field");
  const valueWrap = dialog.querySelector("#bulk-edit-value-wrap");
  const clearWrap = dialog.querySelector("#bulk-clear-wrap");

  const refreshValueInput = () => {
    const selectedField = fields.find((field) => field.key === fieldSelect.value);
    valueWrap.innerHTML = renderBulkValueInput(selectedField);
    clearWrap.classList.toggle("hidden", selectedField?.type === "checkbox");
  };

  fieldSelect.addEventListener("change", refreshValueInput);
  dialog.querySelector("#bulk-edit-close").addEventListener("click", closeBulkEditDialog);
  dialog.querySelector("#bulk-edit-cancel").addEventListener("click", closeBulkEditDialog);
  dialog.querySelector("#bulk-edit-apply").addEventListener("click", () => {
    void applyBulkEdit();
  });
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeBulkEditDialog();
  });
}

function bulkEdit() {
  if (state.selectedRows.size === 0) return;

  const module = MODULES[state.activeModule];
  const canEdit = canEditInModule(module);
  if (!canEdit) {
    setStatus(els.dataMessage, "You don't have permission to edit records in this module.", "error");
    return;
  }

  openBulkEditDialog();
}

function exportToPdf() {
  const module = MODULES[state.activeModule];
  if (module.noTable) {
    setStatus(els.dataMessage, "This module doesn't have data to export.", "error");
    return;
  }

  const rows = getFilteredRows();
  if (!rows.length) {
    setStatus(els.dataMessage, "No data to export.", "error");
    return;
  }

  const { jsPDF } = window.jspdf;
  const doc = new jsPDF();
  
  // Title
  doc.setFontSize(18);
  doc.text(`${module.title} Export`, 14, 22);
  
  // Date
  doc.setFontSize(10);
  doc.text(`Generated: ${new Date().toLocaleString()}`, 14, 30);
  
  // Table data
  const tableData = rows.map(row => 
    module.columns.map(column => {
      const value = displayValue(column, row);
      return value || '';
    })
  );
  
  const headers = module.columns.map(column => column.label);
  
  // Generate table
  doc.autoTable({
    startY: 35,
    head: [headers],
    body: tableData,
    theme: 'grid',
    headStyles: {
      fillColor: [41, 195, 175],
      textColor: [255, 255, 255],
      fontStyle: 'bold'
    },
    alternateRowStyles: {
      fillColor: [245, 245, 245]
    },
    margin: { top: 35 }
  });
  
  // Save PDF
  const filename = `${module.title.toLowerCase()}_export_${new Date().toISOString().split('T')[0]}.pdf`;
  doc.save(filename);
  
  addActivity(`Exported ${module.title} to PDF`, {
    moduleKey: module.key,
    details: `Exported ${rows.length} records to ${filename}`,
  });
  
  setStatus(els.dataMessage, `Exported ${rows.length} records to PDF.`, "success");
}

function notificationsStorageKey() {
  return "adminPanelNotifications";
}

function saveNotifications() {
  const compact = state.notifications.slice(0, 50).map((notification) => ({
    id: notification.id,
    message: notification.message,
    type: notification.type,
    timestamp: notification.timestamp,
    read: Boolean(notification.read),
  }));
  localStorage.setItem(notificationsStorageKey(), JSON.stringify(compact));
}

function loadNotifications() {
  try {
    const raw = localStorage.getItem(notificationsStorageKey());
    if (!raw) {
      state.notifications = [];
      updateNotificationBadge();
      return;
    }
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      state.notifications = [];
      updateNotificationBadge();
      return;
    }
    state.notifications = parsed
      .filter((item) => item && item.message)
      .slice(0, 50)
      .map((item) => ({
        id: item.id || `${Date.now()}-${Math.random()}`,
        message: item.message,
        type: item.type || "info",
        timestamp: item.timestamp || new Date().toISOString(),
        read: Boolean(item.read),
      }));
  } catch (error) {
    console.error("Failed to load notifications", error);
    state.notifications = [];
  }

  updateNotificationBadge();
}

function handleRealtimeActivity(record) {
  if (!record || !isInBranchScope(record.branch_id)) {
    return;
  }

  const action = String(record.action || "");
  if (!isImportantActivity(action)) {
    return;
  }

  const actorName = String(record.username || "");
  if (actorName && actorName === getActivityActorName()) {
    return;
  }

  const moduleLabel = getActivityModuleLabel(record.module_key);
  addNotification(`${moduleLabel}: ${action}`, "info");
}

function handleRealtimeNotice(record) {
  if (!record || !isInBranchScope(record.branch_id)) {
    return;
  }
  if (record.is_active === false) {
    return;
  }

  const priority = String(record.priority || "normal").toLowerCase();
  const type = priority === "urgent" || priority === "high" ? "warning" : "info";
  addNotification(`Notice: ${record.title || "New announcement"}`, type);
}

async function unsubscribeRealtimeNotifications() {
  if (!state.supabase || !state.realtimeChannel) {
    return;
  }
  try {
    await state.supabase.removeChannel(state.realtimeChannel);
  } catch (error) {
    console.error("Failed to unsubscribe realtime channel", error);
  } finally {
    state.realtimeChannel = null;
  }
}

async function subscribeRealtimeNotifications() {
  if (!state.supabase || state.realtimeChannel) {
    return;
  }

  state.realtimeChannel = state.supabase
    .channel(`admin-panel-events-${Date.now()}`)
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "admin_panel_activity" },
      ({ new: row }) => handleRealtimeActivity(row)
    )
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "notices" },
      ({ new: row }) => handleRealtimeNotice(row)
    )
    .subscribe((status) => {
      if (status === "CHANNEL_ERROR") {
        console.error("Realtime channel error");
      }
    });
}

function toggleNotifications() {
  const isHidden = els.notificationContainer.classList.toggle("hidden");
  if (!isHidden) {
    markAllAsRead();
  }
  renderNotifications();
}

function addNotification(message, type = 'info') {
  const notification = {
    id: `${Date.now()}-${Math.random()}`,
    message,
    type,
    timestamp: new Date().toISOString(),
    read: false
  };

  state.notifications.unshift(notification);

  // Keep only last 50 notifications
  if (state.notifications.length > 50) {
    state.notifications = state.notifications.slice(0, 50);
  }

  saveNotifications();
  renderNotifications();
  updateNotificationBadge();
}

function renderNotifications() {
  if (!els.notificationList) {
    return;
  }
  els.notificationList.innerHTML = state.notifications.map(notification => `
    <div class="notification-item ${notification.read ? '' : 'unread'}">
      <div>${notification.message}</div>
      <div class="notification-time">${new Date(notification.timestamp).toLocaleTimeString()}</div>
    </div>
  `).join('');
}

function updateNotificationBadge() {
  const unreadCount = state.notifications.filter(n => !n.read).length;
  if (unreadCount > 0) {
    els.notificationBtn.textContent = `🔔 (${unreadCount})`;
  } else {
    els.notificationBtn.textContent = '🔔';
  }
}

function clearAllNotifications() {
  state.notifications = [];
  saveNotifications();
  renderNotifications();
  updateNotificationBadge();
}

function markAllAsRead() {
  state.notifications.forEach((n) => {
    n.read = true;
  });
  saveNotifications();
  renderNotifications();
  updateNotificationBadge();
}

async function loginAsPanelUser(username, password) {
  const { data, error } = await state.supabase
    .from("admin_panel_users")
    .select("id,username,password_hash,role,branch_id,is_active,display_name")
    .eq("username", username)
    .maybeSingle();

  if (error) {
    const raw = String(error.message || "").toLowerCase();
    if (raw.includes("permission denied") && raw.includes("admin_panel_users")) {
      throw new Error(
        "Permission denied on admin_panel_users. Run database/admin_panel_users.sql in Supabase SQL Editor."
      );
    }
    if (raw.includes("admin_panel_users")) {
      throw new Error(
        "admin_panel_users table is missing. Run database/admin_panel_users.sql in Supabase SQL Editor."
      );
    }
    throw error;
  }

  if (!data || data.is_active === false) {
    throw new Error("User not found or inactive.");
  }

  const hashed = await sha256(password);
  if (hashed !== data.password_hash) {
    throw new Error("Invalid username/password.");
  }

  if (!data.branch_id) {
    throw new Error("This user has no branch assigned. Contact main admin.");
  }

  state.currentUser = {
    kind: "dept",
    userId: data.id,
    username: data.username,
    displayName: data.display_name || data.username,
    role: data.role || "teacher",
    branchId: data.branch_id,
  };
}

async function handleLogin() {
  const username = els.usernameInput.value.trim();
  const password = els.passwordInput.value.trim();

  if (!password) {
    setStatus(els.authMessage, "Password is required.", "error");
    return;
  }

  initSupabase();

  const mainLoginAttempt = !username || username.toLowerCase() === "main";
  if (mainLoginAttempt) {
    const hashedInput = await sha256(password);
    const configuredHash = state.env.ADMIN_PASSWORD_HASH;
    const legacyPassword = state.env.ADMIN_PASSWORD;

    let isValid = false;
    
    // Deployed environments should use the build-generated HASH instead of plaintext
    if (configuredHash) {
      if (hashedInput === configuredHash.toLowerCase()) {
        isValid = true;
      }
    } else if (legacyPassword) {
      if (password === legacyPassword) {
        isValid = true;
      }
    } else {
      // Fallback if completely unconfigured
      const fallbackHash = await sha256(MAIN_ADMIN_PASSWORD_FALLBACK);
      if (hashedInput === fallbackHash) {
        isValid = true;
      }
    }

    if (!isValid) {
      setStatus(els.authMessage, "Invalid main admin password.", "error");
      return;
    }

    state.currentUser = {
      kind: "main",
      userId: null,
      username: "main",
      displayName: "Main Admin",
      role: "main-admin",
      branchId: null,
    };
  } else {
    await loginAsPanelUser(username, password);
  }

  await unsubscribeRealtimeNotifications();
  unlockUI();
  buildModuleNav();
  updateHeaderAndToolbar();
  await loadOptions();
  await loadKpis();
  await refreshModuleData();
  await subscribeRealtimeNotifications();
  addActivity(`Logged in as ${state.currentUser.username}`, {
    moduleKey: "auth",
    details: `Role: ${state.currentUser.role}`,
  });
  addNotification(`Welcome back, ${state.currentUser.username}!`, 'success');
  setStatus(els.authMessage, "Access granted.", "success");
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
      addActivity("Manual refresh", {
        moduleKey: state.activeModule,
        details: "Fetched latest data from Supabase",
      });
    } catch (error) {
      setStatus(els.dataMessage, error?.message || "Refresh failed.", "error");
    }
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
