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
        const { error } = await dbUpsertRestoreChunk(tableKey, chunk);
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

